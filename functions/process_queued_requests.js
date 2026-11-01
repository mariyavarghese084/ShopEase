/**
 * ShopEase (AÈRA Luxury Fragrances & Cosmetics)
 * Standalone Backend Notification Dispatcher
 *
 * Processes pending or queued notification requests directly using Firebase Admin SDK.
 * Can be executed locally, as a Cloud Run job, or via a scheduled worker.
 *
 * Usage:
 *   node process_queued_requests.js                 # Processes all queued requests
 *   node process_queued_requests.js <requestId>     # Processes a single specific request (e.g. conf_order_ORD-946757)
 */

const admin = require("firebase-admin");

if (!process.env.GCLOUD_PROJECT && !process.env.FIREBASE_PROJECT) {
  process.env.GCLOUD_PROJECT = "shopease-59a47";
}

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "shopease-59a47",
  });
}

const { handleNotificationRequest } = require("./index");

let db;
try {
  db = admin.firestore();
} catch (e) {
  console.warn("[ShopEase:Dispatcher] Notice on Firestore initialization:", e.message);
}

async function run() {
  const targetRequestId = process.argv[2];

  console.log("=================================================");
  console.log("  ShopEase Push Notification Dispatch Worker");
  console.log("=================================================");

  if (targetRequestId) {
    console.log(`[ShopEase:Dispatcher] Targeting single request: ${targetRequestId}`);
    const docRef = db.collection("notification_requests").doc(targetRequestId);
    const snap = await docRef.get();

    if (!snap.exists) {
      console.error(`[ShopEase:Dispatcher] Error: Request ${targetRequestId} not found.`);
      process.exit(1);
    }

    const data = snap.data();
    console.log(`[ShopEase:Dispatcher] Current status: ${data.status}, Action: ${data.action}`);
    const result = await handleNotificationRequest(docRef, targetRequestId, data);
    console.log("[ShopEase:Dispatcher] Result:", JSON.stringify(result, null, 2));
  } else {
    console.log("[ShopEase:Dispatcher] Querying all requests with status in ['queued', 'queued_for_backend', 'pending']...");
    const snapshot = await db
      .collection("notification_requests")
      .where("status", "in", ["queued", "queued_for_backend", "pending"])
      .get();

    if (snapshot.empty) {
      console.log("[ShopEase:Dispatcher] No pending notification requests found.");
      return;
    }

    console.log(`[ShopEase:Dispatcher] Found ${snapshot.size} pending request(s). Processing...`);
    for (const doc of snapshot.docs) {
      console.log(`\n--- Processing ${doc.id} ---`);
      try {
        const result = await handleNotificationRequest(doc.ref, doc.id, doc.data());
        console.log(`[ShopEase:Dispatcher] Finished ${doc.id}:`, JSON.stringify(result));
      } catch (err) {
        console.error(`[ShopEase:Dispatcher] Failed processing ${doc.id}:`, err);
      }
    }
  }

  console.log("\n=================================================");
  console.log("  Dispatch processing complete.");
  console.log("=================================================");
}

if (require.main === module) {
  run().catch((err) => {
    console.error("[ShopEase:Dispatcher] Fatal Error:", err);
    process.exit(1);
  });
}

module.exports = { run };

