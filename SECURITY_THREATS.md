# MYNDASH — Security Threat Report

Full-codebase review for Play Store readiness. Findings ranked by severity.
This is the **second pass**: the first pass (below) only documented issues;
this pass actually resolved everything that was safe to resolve without
risking a live regression, and clearly marks the few things that still need
your action (an infra decision, or a live-payment test I can't run myself).

Severity key: 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Info / hardening.

---

## 🔴 1. Hardcoded admin/QA login backdoor — ✅ REMOVED

**Where:** `lib/services/account_service.dart`.

A literal `admin@gmail.com` / `123456789` credential pair granted permanent
free PRO on sign-in, gated behind `kDebugMode` but still shipping as plain
text in every build. `_isAdminCreds`, `_adminLogin`, `_grantAdminLocal`, and
both call sites are gone. Nothing replaces them — there is no admin login
path in the app anymore.

---

## 🔴 2. Release build signed with the debug keystore — ✅ FIXED

**Where:** `android/app/build.gradle.kts`, `android/key.properties` (new,
gitignored), `android/app/upload-keystore.jks` (new, gitignored).

Generated a real 2048-bit RSA upload key (valid 27 years), wired it as the
`release` signing config, with a safe fallback to the debug key only when
`key.properties` is absent (so a fresh clone without the keystore can still
build for local testing). **Verified** — the shipped APK's actual signer
certificate now shows:

```
Signer #1 certificate DN: CN=MYNDASH, OU=MYNDASH, O=MYNDASH, L=Unknown, ST=Unknown, C=IN
Signer #1 certificate SHA-256 digest: be9e90ac654949c2526c9e7cf3189e7cf68a48d57b80cf42d4bf1691e0d95015
```

(confirmed via `apksigner verify --print-certs` against the actual built
APK — this isn't a config that merely *looks* right, the binary was checked).

**⚠️ You must back up `android/key.properties` and
`android/app/upload-keystore.jks` somewhere durable outside this machine**
(password manager + encrypted cloud backup). Both are gitignored on
purpose — they must never be committed — but that also means **losing them
means losing the ability to ever update this app under the same Play Store
listing again.** The store/key passwords are only recorded in
`key.properties` itself; save that file's contents somewhere safe now.

---

## 🔴 3. Client-authoritative entitlements — ⚠️ Cloud Functions written, NOT deployed yet

**Where:** `functions/index.js` (new), `functions/README.md` (new,
deployment steps), `database.rules.json` → `users/$uid`.

The root problem: `users/$uid` must stay writable by its own user for
legitimate gameplay fields (coins, xp, match history), which means nothing
stops the same user from also writing `isPro: true` directly — no
server-side check ever verified a payment actually happened.

**What's done:** wrote `createRazorpayOrder` + `verifyRazorpayPayment`,
two Cloud Functions that:
- Create the Razorpay order server-side (server decides the price from a
  fixed `{30: ₹199, 365: ₹1499}` table — never trusts a client-supplied
  amount).
- Verify the HMAC-SHA256 payment signature server-side using
  `RAZORPAY_KEY_SECRET` (a secret that has never been visible to me and
  never will be — see the setup steps in `functions/README.md`).
- Are the only code path that writes `isPro`/`proUntil`, via the Admin SDK
  (which bypasses RTDB rules entirely).
- Are idempotent (an order can't be replayed to extend Pro twice) and
  ownership-checked (can't redeem someone else's order).

**What's deliberately NOT done:** deploying these functions, or wiring
`payments.dart` to call them. Both require your `RAZORPAY_KEY_SECRET`,
which must be set via `firebase functions:secrets:set` **in your own
terminal** — I should never see that value, including pasted into this
chat. Wiring the client to call a function that isn't deployed yet, or
flipping the RTDB rule to block direct `isPro` writes before the
replacement is live and tested, would both break real purchases
immediately. `functions/README.md` has the exact 5-step order (secrets →
deploy → test → wire client → lock the rule) — please don't skip ahead to
step 5.

---

## 🟠 4. Razorpay payment success trusted client-side — ⚠️ same fix as §3, same status

**Where:** `lib/services/payments.dart`.

This and §3 are the same root cause and the same fix — `verifyRazorpayPayment`
(above) closes both once deployed and wired in. No separate work needed
beyond finishing §3's rollout.

**Also flagged in `PLAY_STORE_CHECKLIST.md`:** Play policy generally
requires Google Play Billing for digital in-app purchases; Razorpay-only
IAP risks listing rejection — a policy question separate from this security
one, worth solving in the same pass since you'll be touching this code
anyway.

---

## 🟠 5. Overly-permissive RTDB rules — ✅ MOSTLY FIXED, `rooms` deliberately left alone

**Where:** `database.rules.json` — deployed to production, verified by
Firebase's own rules linter (`firebase deploy --only database` reported
"rules syntax ... is valid").

**Fixed** (scoped to per-user ownership, verified against actual write
call-sites in `account_service.dart` before touching each rule):
- `choc/$day/$user`, `drops/$dropKey/$user`,
  `official_arenas/$day/$bracket/{reg,scores}/$user`,
  `squad_mania/$month/{scores/$round,claims}/$sid/$user` — each now
  requires `root.child('usernames').child($user).val() === auth.uid`,
  i.e. you can only write the leaf keyed by *your own* username. This
  closes a real griefing vector (anyone could previously overwrite another
  player's leaderboard score, arena registration, or squad-mania claim).
- `orgs/$type/$key` — creating a brand-new org stays open (unchanged,
  low-risk, write-once-ish), but `members/$user` sub-writes to an
  *existing* org now require the same username-ownership check — closes
  impersonation of another user's org membership.
- `social/$ownerUid/{requests,followers,following}/$actorUser` — the owner
  keeps full control of their own node (e.g. account deletion), but the
  actor-keyed entries (a follow request/relationship someone else places
  into your node) now require the actor to own `$actorUser` — closes
  forging a follow-request/relationship from a username that isn't yours.
- `banks` → `.write: false`. This node was only ever written by the
  now-removed admin-seeding path (§1); it's dead from the client's
  perspective, so this is a pure lockdown with zero functional change.

**Deliberately NOT touched: `rooms/$code`.** I found something during this
pass that changes the picture from the first draft of this doc: `rooms`
is shared by **two different systems with incompatible data shapes** —
the original Reflex Duel room model (`host`/`guest` as bare UID strings,
plus a `players` map keyed by UID) and the newer unified game-room model
(`host`/`guest` as `{u, elo}` maps). A single ownership rule has to
correctly authorize both shapes at once, across room creation, guest
claiming (via `runTransaction`), in-match state writes, resign/forfeit,
and rematch resets — for **every game in the app** (chess, darts, cube,
art heist, word finder, scribble, plus the original Reflex Duel). I wrote
out a candidate rule (see the git history of this file / ask me) but chose
**not to deploy it blind**: I can't integration-test two real devices
joining a room against a rule change from here, and a mistake would break
matchmaking across the whole platform, not just one feature. This is
still open — recommended next step is testing a scoped rule in Firebase's
Rules Playground with real sample data from both shapes before deploying.

**Also newly discovered, unrelated to any of the above:** this Firebase
project has **26 deployed Cloud Functions**
(`createCommunity`, `joinCommunity`, `createEvent`, `registerForEvent`,
`onUserCreated`, etc. — a whole "Community/Events" feature set) that **do
not exist anywhere in this repository** — no `functions/` directory in git
history, no `cloud_functions` package dependency, no call sites anywhere
in `lib/`. These are live, billed, and running, but nothing in this
codebase calls or maintains them. This is either dead infrastructure from
an earlier prototype that was never cleaned up, or a separate app
sharing this Firebase project. I did not touch or delete anything (that's
a destructive action outside this task's scope and I don't know what, if
anything, still depends on them) — but you should check
`firebase functions:list --project district-966f3` yourself and decide
whether to keep paying for and exposing that surface.

---

## 🟡 6. Rate limiting — ✅ FIXED for the endpoints that matter most

**Where:** `lib/services/account_service.dart` (`_rateLimitCheck` /
`_rateLimitRecord`), `database.rules.json` → `config/limits` (new).

Replaced the one hardcoded hard-lockout that existed (`maxArenasPerDay = 2`,
flat 30-minute cooldown) with a generic, reusable limiter:
- **Configurable, not hardcoded**: thresholds are read from
  `config/limits/$key` in RTDB (readable by clients, `.write: false` so
  only you — via the Firebase console or a future Admin SDK script — can
  retune them, no redeploy needed). Falls back to sane defaults only when
  that node is empty/unreachable.
- **Exponential backoff, not a hard cutoff**: `backoffMs = baseMs × 2^attempts`
  (capped at ×32), so repeated attempts get progressively slower instead of
  a single fixed wait.
- **Extended to every write-heavy action that needed it**, not just arenas:
  `arena` (hosting), `room_create` (covers both friend-invite rooms *and*
  matchmaking, since matchmaking creates a room internally too), and
  `corp_otp` (OTP email sends — directly closes the "email-bombing a
  third-party inbox" risk flagged in the first draft of this doc).

**Still the same honest caveat as before**: this is check-then-record from
the client against an RTDB counter, the same trust model the rest of this
app already uses (no other backend exists for game logic either). It stops
casual and scripted abuse *through the app*, and is a real, meaningful
upgrade over what existed — but someone hitting the Firebase REST API
directly with their own token could still race past the check-then-record
gap. Fully tamper-proof enforcement needs the write itself to go through a
Cloud Function transaction, same category of fix as §3.

The OTP *verification* side (`verifyCorpEmailOtp`) was already solid before
this pass (CSPRNG code, hash-only storage, 10-min expiry, uid binding,
5-try lockout) and wasn't touched.

---

## 🟡 7. Secrets hygiene — unchanged from first pass, still good

`RAZORPAY_KEY_ID` / `RESEND_API_KEY` load via `--dart-define`, not
hardcoded. `google-services.json` / `firebase_options.dart` being in git is
expected (public client config). The one residual, structural limitation
(dart-define values are still extractable from the compiled binary) is
exactly what §3/§4's Cloud Functions work resolves for the values that
actually matter (Razorpay verification moves server-side; `RESEND_API_KEY`
could follow the same pattern later if email-sending volume ever justifies
it — lower priority since OTP send is now rate-limited per §6).

---

## 🔵 8. SQL injection — not applicable, unchanged

Still true: no SQL surface anywhere in this app (Firebase RTDB only,
accessed exclusively through typed SDK calls). Username keys are
whitelist-regex validated before ever touching a path. Nothing to fix.

---

## 🔵 9. Error-message info leakage — ✅ FIXED

**Where:** `lib/services/account_service.dart` (`resendVerification`),
`lib/services/payments.dart` (`buyPro`'s checkout-open catch).

Both spots that surfaced a raw `$e` exception string directly to the user
now log the detail via `debugPrint` (visible in your own debug console,
never shipped to the user) and return a fixed, generic message instead.

---

## 🔵 10. Optional hardening — ✅ MOSTLY DONE

- **ProGuard/R8 minification: ✅ enabled.** `isMinifyEnabled` /
  `isShrinkResources` are on in the release build type, with a
  `proguard-rules.pro` carrying Razorpay's own documented required keep
  rules (their WebView/JS-bridge checkout needs specific classes/methods
  preserved, or R8 can silently break the checkout flow — these rules are
  lifted from Razorpay's official Android integration docs, not guessed).
  **Verified the release build actually compiles and runs through R8
  successfully** — I could not personally exercise a live sign-in or
  payment on a device from here, so please do one manual smoke test of
  Google/email sign-in and the Razorpay checkout on the next release build
  before wide rollout, just in case a stripped class surfaces at runtime
  rather than at compile time.
- **Security headers on Firebase Hosting: ✅ added** `X-Content-Type-Options:
  nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy:
  strict-origin-when-cross-origin` to `firebase.json`. **Deliberately did
  NOT add a Content-Security-Policy** — this app integrates Firebase Auth
  popups, Google Sign-In, and Razorpay checkout, all cross-origin; a wrong
  CSP allow-list can silently break login/payment on web with no clear
  error, and I can't test that live from here. Worth doing as a dedicated,
  tested follow-up if you want it.
- **COPPA / Families Policy**: unchanged from first pass — the under-12
  Kids Mode gate already exists and is fine; cross-check target-audience
  selection in Play Console per `PLAY_STORE_CHECKLIST.md` item 5.

---

## Summary table

| # | Finding | Severity | Status |
|---|---|---|---|
| 1 | Hardcoded admin/QA login backdoor | 🔴 Critical | ✅ **Fixed** |
| 2 | Release APK signed with debug keystore | 🔴 Critical | ✅ **Fixed & verified** — back up the keystore! |
| 3 | Client-authoritative entitlements | 🔴 Critical | ⚠️ Functions written, **not deployed** — needs your Razorpay secret + a live test |
| 4 | Razorpay payment unverified server-side | 🟠 High | ⚠️ Same as #3 |
| 5 | Overly-permissive RTDB rules | 🟠 High | ✅ **Fixed** for 7 nodes; `rooms` deliberately left open (dual-shape, high regression risk — needs Rules Playground testing) |
| 6 | No rate limiting / hardcoded hard-lockout | 🟡 Medium | ✅ **Fixed** — configurable + exponential backoff, extended to 3 endpoints |
| 7 | Secrets hygiene | 🟡 Medium | Unchanged — already good |
| 8 | SQL injection | 🔵 N/A | Not applicable |
| 9 | Error message info leakage | 🔵 Low | ✅ **Fixed** |
| 10 | Optional hardening | 🔵 Info | ✅ Minification + headers done; CSP deliberately skipped |
| — | 26 orphaned Cloud Functions with no matching code in this repo | 🔵 Info | **New finding** — not touched, needs your review |

**What's left for you specifically:**
1. Back up `android/key.properties` + `android/app/upload-keystore.jks` — losing them is permanent.
2. Run `functions/README.md`'s 5 steps when you're ready to close §3/§4 for real (needs your Razorpay secret, which I never see).
3. Decide what to do about the 26 orphaned functions.
4. If you want `rooms` locked down too, say so and I'll design + Rules-Playground-test it properly rather than deploying blind.
# Payment status update — 19 July 2026

Razorpay, PRO subscriptions, simulated checkout, payment Cloud Functions, and
the payment-reviewer login have been retired. Payment-related sections below
are historical threat analysis only and must not be used as setup instructions.
See `docs/payments-v1-retired.md` for the current state.
