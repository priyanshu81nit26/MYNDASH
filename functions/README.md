# MYNDASH Cloud Functions

## Resend organization-verification email

`sendCorpOtp` sends college/corporate verification codes through Resend from a
Firebase callable function. The API key and sender live only in Firebase Secret
Manager; neither value belongs in Flutter, a `.env` file committed to Git, or a
`--dart-define`.

### Setup

1. Create a Resend account and verify a sending domain.
2. Create a Resend API key with sending access.
3. From the repository root, install function dependencies:

   ```bash
   cd functions
   npm install
   cd ..
   ```

4. Store the two secrets in Firebase:

   ```bash
   firebase functions:secrets:set RESEND_API_KEY --project district-966f3
   firebase functions:secrets:set RESEND_FROM --project district-966f3
   ```

   Enter the values only when the CLI prompts. `RESEND_FROM` must use the
   verified domain. For this project use
   `MYNDASH <noreply@raksham.online>`.

5. Deploy the email function:

   ```bash
   firebase deploy --only functions:sendCorpOtp,functions:verifyCorpOtp,database --project district-966f3
   ```

6. Send one organization-verification code from the app and confirm delivery
   in Resend Logs. Then remove the previous exposed API key from the Resend API
   Keys dashboard.

If Resend returns HTTP 403, first confirm that `RESEND_FROM` exactly matches a
verified domain. Inspect logs with:

```bash
firebase functions:log --only sendCorpOtp --project district-966f3
```

## Payments

Payments and subscriptions are intentionally disabled in v1. Do not add payment
secrets or deploy legacy payment callables. See
`../docs/payments-v1-retired.md`.

If either retired callable was ever deployed, remove it explicitly:

```bash
firebase functions:delete createRazorpayOrder verifyRazorpayPayment --project district-966f3
```
