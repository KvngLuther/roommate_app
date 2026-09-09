/**
 * functions/index.js — Paystack integration for Roommate Manager
 *
 * Two functions:
 *  1. initializePaystackPayment  – callable; called by Flutter to get an
 *     authorization URL.  Returns { reference, authorizationUrl, accessCode }.
 *
 *  2. paystackWebhook  – HTTP endpoint; called by Paystack after a successful
 *     charge.  Verifies the HMAC signature then writes a Settlement document
 *     into Firestore so the debt is marked as paid automatically.
 *
 * Setup:
 *  firebase functions:secrets:set PAYSTACK_SECRET
 *  (paste your sk_live_... or sk_test_... key when prompted)
 *
 * Deploy:
 *  firebase deploy --only functions
 *
 * Register webhook in Paystack dashboard:
 *  https://us-central1-roommate-app-2a6ab.cloudfunctions.net/paystackWebhook
 *  Events to enable: charge.success
 */

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const axios = require('axios');
const crypto = require('crypto');

initializeApp();
const db = getFirestore();

// Secret stored in Firebase Secret Manager (never hard-code keys)
const PAYSTACK_SECRET = defineSecret('PAYSTACK_SECRET');

// ─── Unique ID helper ──────────────────────────────────────────────────────
function generateId() {
  return crypto.randomUUID();
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. initializePaystackPayment  (Firebase Callable)
// ─────────────────────────────────────────────────────────────────────────────
exports.initializePaystackPayment = onCall(
  { secrets: [PAYSTACK_SECRET] },
  async (request) => {
    // Auth guard
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const { amount, email, debtorId, creditorId, householdId, note } =
      request.data;

    // Basic validation
    if (!amount || amount <= 0) {
      throw new HttpsError('invalid-argument', 'amount must be > 0');
    }
    if (!email) {
      throw new HttpsError('invalid-argument', 'email is required');
    }
    if (!debtorId || !creditorId || !householdId) {
      throw new HttpsError(
        'invalid-argument',
        'debtorId, creditorId, and householdId are required'
      );
    }

    try {
      const response = await axios.post(
        'https://api.paystack.co/transaction/initialize',
        {
          email,
          // Paystack expects the smallest currency unit (pesewas for GHS)
          amount: Math.round(amount * 100),
          currency: 'GHS',
          metadata: {
            debtorId,
            creditorId,
            householdId,
            note: note || '',
            initiatedBy: request.auth.uid,
          },
          // Optional: add a callback_url if you have a deep-link scheme set up
          // callback_url: 'roommateapp://payment-complete',
        },
        {
          headers: {
            Authorization: `Bearer ${PAYSTACK_SECRET.value()}`,
            'Content-Type': 'application/json',
          },
        }
      );

      const { authorization_url, access_code, reference } =
        response.data.data;

      return {
        authorizationUrl: authorization_url,
        accessCode: access_code,
        reference,
      };
    } catch (err) {
      console.error('[Paystack] initialize error:', err?.response?.data ?? err);
      throw new HttpsError(
        'internal',
        'Failed to initialise payment. Please try again.'
      );
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. paystackWebhook  (HTTP endpoint — called directly by Paystack)
// ─────────────────────────────────────────────────────────────────────────────
exports.paystackWebhook = onRequest(
  { secrets: [PAYSTACK_SECRET] },
  async (req, res) => {
    // Only POST allowed
    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    // ── Verify HMAC signature ──────────────────────────────────────────
    const signature = req.headers['x-paystack-signature'];
    const expectedHash = crypto
      .createHmac('sha512', PAYSTACK_SECRET.value())
      .update(JSON.stringify(req.body))
      .digest('hex');

    if (signature !== expectedHash) {
      console.warn('[Webhook] Invalid Paystack signature – request rejected');
      return res.status(400).send('Invalid signature');
    }

    const event = req.body;
    console.log('[Webhook] Event received:', event.event);

    // ── Handle charge.success ──────────────────────────────────────────
    if (event.event === 'charge.success') {
      const { metadata, amount, reference, status } = event.data;

      if (status !== 'success') {
        console.log('[Webhook] Non-success status, skipping:', status);
        return res.sendStatus(200);
      }

      const { debtorId, creditorId, householdId, note } = metadata ?? {};

      if (!debtorId || !creditorId || !householdId) {
        console.error('[Webhook] Missing metadata fields:', metadata);
        // Still 200 so Paystack doesn't retry
        return res.sendStatus(200);
      }

      try {
        const amountGHS = amount / 100; // convert pesewas → GHS

        // ── Idempotency: skip if reference already recorded ────────────
        const existing = await db
          .collection('households')
          .doc(householdId)
          .collection('settlements')
          .where('paystackReference', '==', reference)
          .limit(1)
          .get();

        if (!existing.empty) {
          console.log('[Webhook] Duplicate reference, skipping:', reference);
          return res.sendStatus(200);
        }

        // ── Write Settlement document ──────────────────────────────────
        const settlementId = generateId();
        await db
          .collection('households')
          .doc(householdId)
          .collection('settlements')
          .doc(settlementId)
          .set({
            id: settlementId,
            fromId: debtorId,
            toId: creditorId,
            amount: amountGHS,
            date: new Date().toISOString(),
            note: note || 'Paid via Paystack',
            paystackReference: reference,
            paidAt: FieldValue.serverTimestamp(),
          });

        console.log(
          `[Webhook] Settlement recorded: ${settlementId} (${amountGHS} GHS)`
        );

        // ── Optional: push notification to creditor ────────────────────
        await _notifyCreditor(householdId, creditorId, debtorId, amountGHS);
      } catch (err) {
        console.error('[Webhook] Firestore write error:', err);
        // Return 500 so Paystack retries — safe because of idempotency check
        return res.status(500).send('Internal error');
      }
    }

    return res.sendStatus(200);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Helper: push a Firestore notification that the creditor's app can display
// ─────────────────────────────────────────────────────────────────────────────
async function _notifyCreditor(householdId, creditorId, debtorId, amount) {
  try {
    await db
      .collection('households')
      .doc(householdId)
      .collection('notifications')
      .add({
        forRoommateId: creditorId,
        type: 'payment_received',
        fromRoommateId: debtorId,
        amount,
        message: `You received a payment of ₵${amount.toFixed(2)} via Paystack.`,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  } catch (err) {
    // Non-critical — don't let this fail the webhook
    console.warn('[Webhook] Could not write notification:', err.message);
  }
}