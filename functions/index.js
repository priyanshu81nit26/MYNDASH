/**
 * MYNDASH Cloud Functions.
 *
 * Payments are "upcoming" for now, so the Razorpay verification functions were
 * removed along with the razorpay dependency — re-add them (and the dep) when
 * paid coins/Pro go live. What's here today is the transactional-email sender
 * used for corporate/college verification, which must run server-side so it
 * works on web and keeps the Resend key out of the shipped app.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

// Admin SDK — used here only to enforce a SERVER-side send quota that the
// client cannot bypass (the client-side limiter in account_service.dart is
// advisory: anyone calling this callable directly could ignore it). The
// default RTDB instance is regional, so pass its URL explicitly.
if (admin.apps.length === 0) {
  admin.initializeApp({
    databaseURL:
      "https://district-966f3-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

// Resend transactional email — the key stays server-side so it's never in the
// shipped app, and this works from web (dart:io HttpClient does not). RESEND_FROM
// must be an address on a domain you've verified at resend.com/domains, e.g.
// "MYNDASH <noreply@yourdomain.com>".
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const RESEND_FROM = defineSecret("RESEND_FROM");

// Server-side send quotas (NOT bypassable from the client). Keyed in RTDB under
// otp_send_limits/. A caller (uid) may send a bounded number of codes per day,
// and any single recipient address may only receive a bounded number per day —
// this is what actually closes the "email-bomb a third party / burn Resend
// credits" abuse path, because it's enforced here rather than in the app.
const MAX_SENDS_PER_UID_PER_DAY = 8;
const MAX_SENDS_PER_RECIPIENT_PER_DAY = 4;

/** HTML-entity-escape untrusted text before putting it in an email body, so a
 *  crafted orgName can't inject markup/links into a message that ships from our
 *  verified sending domain (a phishing vector otherwise). */
function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** UTC day bucket, e.g. "2026-07-22" — quotas reset at UTC midnight. */
function dayKey() {
  return new Date().toISOString().slice(0, 10);
}

/** Atomically increments a daily counter and returns the new value. */
async function bumpDailyCounter(path, day) {
  const ref = admin.database().ref(path);
  const res = await ref.transaction((cur) => {
    if (!cur || cur.day !== day) return { day, count: 1 };
    return { day, count: (cur.count || 0) + 1 };
  });
  return res.snapshot.val()?.count ?? 0;
}

/**
 * Sends a corporate/college verification OTP by email via Resend, server-side.
 * The client generates the 6-digit code, stores only its hash in RTDB, and
 * calls this to deliver the plaintext to the recipient's inbox — so the Resend
 * key never ships in the app and this works on web too. Verification still
 * happens entirely against the client-stored hash (unchanged).
 */
exports.sendCorpOtp = onCall(
  { secrets: [RESEND_API_KEY, RESEND_FROM] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");

    const { to, code, orgName, college } = request.data || {};
    if (!to || !code) {
      throw new HttpsError("invalid-argument", "Missing email or code.");
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(String(to))) {
      throw new HttpsError("invalid-argument", "Invalid email address.");
    }
    if (!/^\d{6}$/.test(String(code))) {
      throw new HttpsError("invalid-argument", "Bad code.");
    }

    // ---- server-side abuse limits (cannot be bypassed by the client) ----
    const day = dayKey();
    const recipient = String(to).trim().toLowerCase();
    // Normalise the recipient into a safe RTDB key (no . # $ [ ] /).
    const recipientKey = recipient.replace(/[.#$/[\]]/g, "_");
    const [uidCount, recipCount] = await Promise.all([
      bumpDailyCounter(`otp_send_limits/uid/${uid}`, day),
      bumpDailyCounter(`otp_send_limits/to/${recipientKey}`, day),
    ]);
    if (
      uidCount > MAX_SENDS_PER_UID_PER_DAY ||
      recipCount > MAX_SENDS_PER_RECIPIENT_PER_DAY
    ) {
      logger.warn("OTP send blocked by server quota", {
        uid,
        recipientKey,
        uidCount,
        recipCount,
      });
      throw new HttpsError(
        "resource-exhausted",
        "Too many verification emails — try again tomorrow."
      );
    }

    // Untrusted, client-supplied display text — escape + length-cap before it
    // ever touches the email HTML.
    const safeOrg = orgName ? escapeHtml(String(orgName).slice(0, 80)) : "";
    const kind = college ? "College" : "Workplace";

    const html = `
<div style="font-family:Inter,Arial,sans-serif;background:#050507;color:#F2F3F8;padding:32px;border-radius:16px;max-width:420px;margin:auto">
  <h2 style="letter-spacing:6px;color:#00E5FF;margin:0 0 8px">MYNDASH</h2>
  <p style="color:#8A8FA3;font-size:13px;margin:0 0 20px">${kind} verification${safeOrg ? " · " + safeOrg : ""}</p>
  <p style="font-size:15px;margin:0 0 14px">Your verification code:</p>
  <div style="font-size:34px;font-weight:800;letter-spacing:10px;background:#0B0B12;border:1px solid #232336;border-radius:12px;padding:16px;text-align:center">${code}</div>
  <p style="color:#8A8FA3;font-size:12px;margin:18px 0 0">Expires in 10 minutes. If you didn't request this, ignore it.</p>
</div>`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY.value()}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: RESEND_FROM.value(),
        to: [recipient],
        subject: `${code} is your MYNDASH verification code`,
        html,
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      logger.error("Resend send failed", { status: res.status, body });
      // A 403 here almost always means RESEND_FROM isn't on a verified domain.
      throw new HttpsError("internal", "Email service error.");
    }
    return { ok: true };
  }
);
