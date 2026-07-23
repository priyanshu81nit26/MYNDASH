# MYNDASH — Google Play Launch Checklist

What's already done in the code, and what you must do in the Play Console.

## ✅ Done in this codebase

| Requirement | Where |
|---|---|
| Terms of Service in-app | Drawer → Terms of Service (`lib/screens/legal.dart`) |
| Privacy Policy in-app | Drawer → Privacy Policy (`lib/screens/legal.dart`) |
| Consent at sign-up | Auth screen shows "By continuing you agree…" with tappable links |
| Account deletion in-app (required since 2024) | Profile → "Delete account & data" — removes cloud profile, username, social node, auth user, local data |
| No cleartext HTTP | `AndroidManifest.xml` → `usesCleartextTraffic="false"` |
| Backup off (no stale account data restored) | `AndroidManifest.xml` → `allowBackup="false"` |
| Kids Mode gating | Under-12s: no store redemptions and no public social |
| XP not purchasable (anti-gambling optics) | Store items need earned XP, coins alone insufficient |
| Payments disabled | No SDK, checkout bridge, subscription, or purchasable coin pack in v1 |

## 📋 You must do in Play Console

1. **Host the Privacy Policy at a public URL** — Play requires a *web* link, not
   just in-app text. Copy the text from `lib/screens/legal.dart` to a free host
   (GitHub Pages / Firebase Hosting — you already have Firebase Hosting set up)
   and paste the URL in Play Console → App content → Privacy policy.
2. **Data safety form** — declare:
   - Collected: name, email, user IDs (account); photos (optional avatar, stored on device); app interactions (gameplay stats).
   - Shared: none. Sold: none. Encrypted in transit: yes. Deletable: yes (in-app).
   - Payment info: not collected; checkout is disabled in this version.
3. **Account deletion URL** — Play also asks for a web link describing deletion.
   Add a section on the same hosted policy page: "Delete in-app via Profile →
   Delete account, or email priyanshukaffota@gmail.com."
4. **Content rating questionnaire** — quiz/puzzle game; note it has user
   interaction (chat-free social, usernames) and simulated gambling: **No**
   (entry-fee arenas use virtual coins → answer the "digital goods" questions
   accordingly; be accurate here or expect rejection).
5. **Target audience** — pick 13+, do NOT tick "appeals to children" unless you
   want the full Families policy (stricter). Kids Mode alone doesn't force it.
6. **Real-prize store caution** — physical rewards for gameplay can be read as
   sweepstakes in some countries. Keep the "promotional, subject to
   verification" wording (already in the ToS) and consider geo-limiting.
7. **Payments** — no payment or subscription is active in v1. Revisit Play
   Billing and all applicable policies before enabling any future digital sale.
8. **Signing & release** — ✅ done. Release builds now sign with a real
   upload keystore (`android/app/upload-keystore.jks` + `android/key.properties`,
   both gitignored) — verified against the actual built APK's certificate,
   see `SECURITY_THREATS.md` §2. **Back up that keystore + its passwords
   somewhere durable** — losing them means you can never update this app
   under the same listing again.
9. **Firebase security rules** — ✅ mostly done. 7 nodes (`choc`, `drops`,
   `official_arenas`, `squad_mania`, `orgs`, `social`, `banks`) now scope
   writes to the actual owning account instead of any authenticated user.
   `rooms` was deliberately left as-is (a rule change there needs
   Rules-Playground testing first — two incompatible room shapes share that
   node; see `SECURITY_THREATS.md` §5 for the full explanation).

## ⚠️ Honest notes

- The hardcoded admin/QA login backdoor has been **removed** (see
  `SECURITY_THREATS.md` §1). The `adminOverride` flag itself is now
  unreachable through any client code path; demo store orders are still
  fine-for-testing-only — review before production.
- App label is "MYNDASH" but the package/app id still says `reflex_duel` — set a
  proper `applicationId` (e.g. `com.mynd.app`) in `android/app/build.gradle`
  **before** first upload; it can never be changed after.
