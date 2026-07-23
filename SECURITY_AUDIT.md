# MYNDASH — Security Audit (Web + Android)

**Date:** 2026-07-22
**Scope:** Flutter mobile (Android) + Flutter Web (myndash.online), Firebase
Realtime Database rules, in-repo Cloud Function (`sendCorpOtp`), Android/web
build config, hosting headers.
**Method:** white-box review of this repository + live verification against the
deployed `district-966f3` project (RTDB rules linter, HTTP header inspection,
in-browser CSP/console checks).

This is a **fresh, adversarial pass** and supersedes nothing in
`SECURITY_THREATS.md` (that earlier doc is still accurate for the items it
covers — admin backdoor removal, keystore signing, minification). This audit
goes deeper on the **data-integrity / competitive-cheating** surface, the
**email function**, and **web headers**, which are where the real live risk sits
today now that payments are retired.

**Severity key:** 🔴 Critical · 🟠 High · 🟡 Medium · 🔵 Low/Info
**Status key:** ✅ Fixed (in this pass) · 🟢 Fixed & deployed · ⚠️ Needs your action (outside this repo)

---

## The one root cause behind most findings

Two facts combine into the single most important thing to understand about this
app's security model:

1. **Anonymous auth is enabled** (`firebase_service.dart` → `signInAnonymously()`).
2. **Almost every RTDB rule is `auth != null`.**

Therefore **`auth != null` ≈ "anyone on the internet."** Any person can mint a
throwaway anonymous token in one unauthenticated HTTP call and then read/write
everything the rules grant to "authenticated" users — **directly against the
Firebase REST API, completely bypassing the app and all its client-side
validation and rate-limiting.** Every finding below that says "bypassable via
REST" traces back to this.

The **single highest-leverage fix** is not in this repo — it's enabling
**Firebase App Check** (device/app attestation) and enforcing it on RTDB +
Cloud Functions. That's what makes "you must go through the real app" actually
true. See **§8 (F-1)**. Everything else in this document is defense-in-depth
that matters *whether or not* you do App Check, but App Check is the keystone.

---

## A. Data integrity & competitive cheating

For a competitive "mind arena", a forged leaderboard is an existential product
risk, not a nuisance. This is the most important category here.

### 🔴 A-1 — Global leaderboard is forgeable (client-authoritative rank)
**Where:** `database.rules.json → profiles/$uid`; written by
`account_service.dart → updatePublicProfile()`.
**Problem:** `profiles/$uid` is writable by its owner with (previously) **no
value validation**. `contestRating`, `elo`, and `xp` are pushed straight from
the client. The global leaderboard (`fetchLeaderboard()`,
`orderByChild('contestRating')`) reads these. So anyone can `PUT` their own
`profiles/<uid>/contestRating = 999999` via REST and sit at #1 worldwide.
**Exploit:** anon-auth → REST write to own profile → instant top rank, fake XP,
fake elo. Repeatable, no app needed.
**Fix (this pass, 🟢 deployed):** added `.validate` bounds on the three ranked
leaves — `contestRating`/`elo` ∈ [0, 5000], `xp` ∈ [0, 1e9]. This kills the
absurd "2-billion-rating" forgery and all non-numeric/negative writes.
**Honest limitation:** this is **defense-in-depth, not a complete fix.** A
cheater can still write a *plausible* in-range value (e.g. `contestRating:
2950`). True integrity requires the rating to be **server-authoritative** —
written only by a Cloud Function that recomputes it from validated match
results, with the client rule flipped to `.write: false` on those leaves. Those
functions live outside this repo (see §C intro). **Recommended: App Check now
(§F-1) + server-authoritative rating next.**

### 🟠 A-2 — In-event (arena/contest) score forgery
**Where:** `database.rules.json → events/$id/scores/$uid`,
`official_arenas/$day/$bracket/scores/$uid`; written by
`submitHostedArenaScore()`.
**Problem:** a *registered* player may write their own `scores/$uid` node, but
the **score value was unvalidated** — a registered entrant could submit
`score: 100000000` for an arena they legitimately joined.
**Fix (this pass, 🟢 deployed):** added `.validate` on
`events/$id/scores/$uid/score` requiring a number in [0, 1e8].
**Honest limitation:** same as A-1 — bounds a plausible cheat, doesn't eliminate
it. `official_arenas`/`official_contests` score shapes are written by functions
outside this repo; I did **not** guess-validate those (a wrong shape would break
live scoring). Flagged for server-side validation there.

### 🟡 A-3 — Arbitrary / abusive event creation
**Where:** `database.rules.json → events/$id`; `createArena()`.
**Problem:** `events/$id` write only checks `hostUid` ownership, with **no
content validation**. All of `createArena()`'s checks (title length, player
caps, topic list, background size) are **client-side only** and bypassable via
REST. An attacker can create events with offensive/spam titles, absurd player
caps, or an oversized `bg` blob — all shown to real users browsing arenas.
**Fix (this pass, 🟢 deployed):** added `.validate` on `events/$id/title`
(string ≤120 chars) and `events/$id/bg` (string ≤240 000 chars ≈ the client's
own 160 KB cap). Blocks the worst payload/spam abuse.
**Remaining:** per-field semantic caps (maxPlayers, fee) still enforced only
client-side; low impact, and full enforcement wants a create-arena Cloud
Function.

### 🟡 A-4 — Org name/identity spoofing
**Where:** `database.rules.json → orgs/$type/$key`; `joinOrg()`.
**Problem:** any user can create an org node (`.write: !data.exists()`), and the
displayed `name` field was **unvalidated server-side** — `validateOrgName()`
runs only in the app. So an attacker can create `orgs/college/harvard` with
`name` set to arbitrary text (impersonation, injected marketing).
**Fix (this pass, 🟢 deployed):** `.validate` on `orgs/$type/$key/name` (string,
3–48 chars). The reserved-name and charset checks remain app-side (low risk).
**Remaining:** `$type` is still unconstrained (someone can create
`orgs/whatever/...`); harmless today since nothing reads unknown types.

---

## B. Cloud Function — `sendCorpOtp` (in this repo)

> Note: the **7 competition functions** (arena/contest register/authorize/submit)
> and `verifyCorpOtp` are **not in this repo** — maintained separately. I can't
> audit code I can't see; their required invariants are listed in §C-3.
> `sendCorpOtp` **is** here, and had two real bugs — both fixed.

### 🟠 B-1 — HTML/content injection into outbound email (phishing via your domain)
**Where:** `functions/index.js`.
**Problem:** `orgName` (client-supplied, `.trim()`'d only) was interpolated
**raw** into the email HTML body: `... + orgName + ...`. Since the email ships
from your **verified sending domain**, an attacker could set
`orgName = "<a href='https://evil.example'>Verify now</a>"` and send a
legitimate-looking, DKIM-signed phishing email *from you* to any address.
**Fix (this pass, ✅ code — you must deploy):** added `escapeHtml()` (escapes
`& < > " '`) + an 80-char cap on `orgName` before it touches the template. The
`code` was already regex-validated (`^\d{6}$`), so that leg was safe.

### 🟠 B-2 — Open email relay / email-bombing / Resend cost-burn
**Where:** `functions/index.js`.
**Problem:** the callable accepted an arbitrary `to` and sent to it with **no
server-side rate limit** and **no binding between recipient and caller**. The
client's `corp_otp` limiter (5/day) is advisory — calling the callable directly
(with any anon token) ignores it. So anyone could email-bomb any inbox and burn
your Resend quota/credits at will.
**Fix (this pass, ✅ code — you must deploy):** added **server-enforced** daily
quotas via the Admin SDK (RTDB transactions under `otp_send_limits/`, locked
`.read/.write: false` so only the server touches them):
- **≤ 8 sends per calling uid per day**, and
- **≤ 4 sends per recipient address per day.**
Exceeding either throws `resource-exhausted`. This closes the third-party
email-bomb and the cost-abuse vector at the only place it can be enforced.

**⚠️ Action required:** these two fixes are code changes — **deploy them:**
```bash
firebase deploy --only functions --project district-966f3
```
(The `RESEND_API_KEY` / `RESEND_FROM` secrets are already set in your project;
you don't need to re-enter them, and I never see them.)

---

## C. Authentication & authorization

### 🟠 C-1 — Anonymous auth makes the whole DB internet-readable
Covered in the intro. `profiles`, `usernames`, `avatars`, `events`, `orgs`,
`squads`, `banks`, `bots`, `contest_scores`, `drops` are all readable by any
anon token via REST. This enables full **user-base enumeration** (every
username→uid, every display name, every college/company, every avatar) and is
the amplifier for every "bypassable via REST" note above.
**Status:** ⚠️ Not fixable in-repo without breaking guest UX. Mitigate with **App
Check (§F-1)**; longer term, decide whether guests need *write* access at all,
and consider gating sensitive reads behind real (non-anon) auth.

### 🔵 C-3 — Off-repo function invariants (verify these yourself)
`verifyCorpOtp` and the 7 competition functions must, server-side:
- store only a **hash** of the OTP, never plaintext; enforce **expiry** (~10 min)
  and an **attempt lockout** (~5 tries); **bind** the code to the requesting uid.
- for register/authorize/submit: **recompute** eligibility, capacity, timing and
  **scores** server-side; never trust client-supplied ratings/scores; write
  results via Admin SDK to nodes the client cannot write directly (the rules
  already set `official_*/registrations|reg|scores → .write: false`, which is
  correct and depends on those functions being the sole writer).

---

## D. Android application

### 🔵 D-1 — App config posture: good
`AndroidManifest.xml`: `usesCleartextTraffic="false"` ✅, `allowBackup="false"`
✅ (prevents `adb backup` local data exfil), only `INTERNET` + `CAMERA`
permissions, single exported activity (the launcher — required, no injectable
`intent-filter`/deep-link surface). `build.gradle.kts`: real upload keystore
with debug-key fallback only when absent, R8 minify + resource shrink on.
Nothing to fix.

### 🔵 D-2 — Restrict the Firebase API keys (do this in Cloud Console) — ⚠️ your action
The API keys in `google-services.json` / `firebase_options.dart` are **public
client config** (expected, not a leak). But if **unrestricted**, they can be
used from *anywhere* to hit Identity Toolkit / your Firebase APIs and burn quota
or drive abuse. In **Google Cloud Console → APIs & Services → Credentials**:
- **Android key** → Application restriction: *Android apps* → add package
  `com.district.reflex_duel` + your release SHA-256.
- **Web key** → Application restriction: *HTTP referrers* → `myndash.online/*`,
  `district-966f3.web.app/*`, `district-966f3.firebaseapp.com/*`.
Not code — do it in the console.

### 🔵 D-3 — Back up the upload keystore (still true)
Losing `android/key.properties` + `android/app/upload-keystore.jks` = permanently
unable to update this listing. Store both in a password manager + encrypted
offsite backup. (Carried over from `SECURITY_THREATS.md §2`.)

---

## E. Web / hosting

### 🟡 E-1 — Security response headers — ✅ added & deployed
`firebase.json` now sends on every response:
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` 🟢
- `Permissions-Policy: geolocation=(), microphone=(), camera=(), payment=(),
  usb=(), interest-cohort=()` 🟢 (locks down powerful web APIs the app doesn't
  use on web; the image picker uses a file input, not `getUserMedia`).
- Existing `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`,
  `Referrer-Policy: strict-origin-when-cross-origin` retained.

### 🟡 E-2 — Content-Security-Policy — ✅ added in **Report-Only** (deliberate)
A full CSP (`default-src 'self'` + explicit allow-list for the Firebase/Google
auth, RTDB, functions, and CanvasKit origins) is deployed **as
`Content-Security-Policy-Report-Only`**.

**Why Report-Only and not enforcing:** I verified in-browser that a first draft
of the *enforcing* policy **blanked the app** — CanvasKit fetches its `.wasm`
(and Roboto) cross-origin from `gstatic.com`, which the initial `connect-src`
didn't allow. I widened the policy to include those origins and re-verified (no
CSP violations in console, Flutter engine boots), **but** I could not get a
final compositing screenshot from this environment to 100% confirm pixels
render. An enforcing CSP that's subtly wrong blanks the site for **every**
user, and a Flutter-canvas app has almost no DOM/script-injection surface for a
CSP to protect anyway (the real injection risk here was the email — fixed in
§B-1). So Report-Only is the correct risk trade: **it cannot break anything**
and still surfaces violations.

**To promote it to enforcing (2 minutes, do this yourself):**
1. Open `https://myndash.online` in a normal desktop Chrome, open DevTools →
   Console. Use the app normally (sign in with Google, open an arena).
2. If you see **no** `Content-Security-Policy-Report-Only` violation errors, edit
   `firebase.json`: rename the header key
   `"Content-Security-Policy-Report-Only"` → `"Content-Security-Policy"`, then
   `firebase deploy --only hosting --project district-966f3`.
3. If you *do* see a violation for some origin, add that origin to the matching
   directive first, redeploy, re-check, then flip to enforcing.

---

## F. The keystone recommendation

### 🔴→mitigation F-1 — Enable Firebase App Check — ⚠️ your action (highest impact)
Everything marked "bypassable via REST" above exists because a raw token +
`curl` is indistinguishable from your real app. **App Check** fixes that class
wholesale by requiring a device/app-attestation token (Play Integrity on
Android, reCAPTCHA Enterprise on web) on every RTDB and Cloud Functions call.
Steps:
1. Firebase Console → App Check → register the Android app (Play Integrity) and
   the web app (reCAPTCHA Enterprise).
2. Add the `firebase_app_check` Flutter package and activate it at startup
   (before other Firebase calls).
3. **Roll out in monitoring mode first**, watch the App Check metrics until
   legitimate traffic is ~100% verified, *then* click **Enforce** on Realtime
   Database and on Cloud Functions.
I can wire up the client package (step 2) whenever you want — say the word — but
the registration + enforce toggles (steps 1 & 3) are console actions and must be
rolled out carefully to avoid locking out real users.

---

## G. Injection & secrets (checked, mostly N/A — documented so you know it was looked at)

- **SQL injection:** N/A — no SQL anywhere; RTDB accessed via typed SDK.
- **RTDB path injection:** safe — every user-controlled path segment is
  whitelist-sanitized before use (`usernameRx = ^[a-z0-9_]{6,20}$`;
  `orgKey()` strips to `[a-z0-9_]`; event ids are `push()` keys).
- **XSS in-app:** N/A — Flutter renders text to a canvas, not a DOM, so
  malicious usernames/bios/titles are drawn as literal text, never executed.
  The **one** place user text became live markup was the outbound email — that
  was the real bug, fixed in **§B-1**.
- **Secrets hygiene:** ✅ `RESEND_API_KEY`/`RESEND_FROM` are server-side
  `defineSecret`; no client-embedded secrets found. `google-services.json`
  in git is expected public config. Contact email/phone added to the profile
  editor are stored **device-local only** (not synced to cloud), so they're not
  exposed in `profiles`.
- **Avatar payload DoS:** ✅ hardened — `avatars/$uid` now `.validate`s a string
  ≤ ~700 KB (base64), so a user can't park a huge blob that every viewer
  downloads.

---

## Summary table

| # | Finding | Severity | Status |
|---|---|---|---|
| A-1 | Global leaderboard forgeable (client-written rating/elo/xp) | 🔴 | 🟢 Bounds deployed · true fix = server-authoritative rating |
| A-2 | In-event score forgery | 🟠 | 🟢 Bounds deployed (hosted); official scores flagged (off-repo) |
| A-3 | Arbitrary/abusive event creation | 🟡 | 🟢 Title/bg validated |
| A-4 | Org name spoofing | 🟡 | 🟢 Name validated |
| B-1 | Email HTML injection (phishing via your domain) | 🟠 | ✅ Fixed — **deploy functions** |
| B-2 | Email-bomb / Resend cost abuse (no server rate limit) | 🟠 | ✅ Fixed — **deploy functions** |
| C-1 | Anonymous auth ⇒ whole DB internet-readable/enumerable | 🟠 | ⚠️ Mitigate via App Check |
| C-3 | Off-repo function invariants | 🔵 | ⚠️ Verify yourself |
| D-1 | Android manifest/build posture | 🔵 | ✅ Good, no change |
| D-2 | Unrestricted Firebase API keys | 🔵 | ⚠️ Restrict in Cloud Console |
| D-3 | Back up upload keystore | 🔵 | ⚠️ Do it now |
| E-1 | Missing HSTS / Permissions-Policy | 🟡 | 🟢 Added & deployed |
| E-2 | No CSP | 🟡 | 🟢 Added Report-Only; flip to enforce after your check |
| F-1 | **App Check not enabled** (keystone) | 🔴→mit | ⚠️ Your action — highest impact |
| G-* | SQLi / path-inj / in-app XSS / secrets | 🔵 | ✅ N/A or already good |

## What I changed in this pass (already deployed unless noted)
- `database.rules.json` — value `.validate` on `profiles` rating/elo/xp,
  `events` title/bg/score, `orgs` name, `avatars` size; locked
  `otp_send_limits`. **Deployed** (rules linter passed).
- `firebase.json` — HSTS, Permissions-Policy, CSP (Report-Only). **Deployed &
  header-verified.**
- `functions/index.js` — HTML-escape `orgName`, server-side OTP send quotas.
  **Code done — you must run `firebase deploy --only functions`.**

## What's yours to do (in priority order)
1. **Deploy the function fixes:** `firebase deploy --only functions --project district-966f3` (closes B-1, B-2).
2. **Enable App Check** in monitoring → enforce (F-1) — the keystone that makes REST-bypass stop working. I can wire the client package on request.
3. **Restrict the API keys** in Cloud Console (D-2).
4. **Back up the keystore** (D-3).
5. Verify the CSP in desktop Chrome and flip it to enforcing (E-2).
6. Move **rating + official scores server-side** for real competitive integrity (A-1, A-2).
