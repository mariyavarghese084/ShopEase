/**
 * ShopEase (AÈRA Luxury Fragrances & Cosmetics) - Firebase Cloud Functions
 *
 * Background Worker for processing `/notification_requests/{requestId}`
 * and dispatching Firebase Cloud Messaging (FCM) push notifications
 * using the Firebase Admin SDK.
 */

let onDocumentCreated;
let onRequest;
let admin;
let db;
let messaging;

try {
  const firestoreV2 = require("firebase-functions/v2/firestore");
  onDocumentCreated = firestoreV2.onDocumentCreated;
} catch (_) {}

try {
  const httpsV2 = require("firebase-functions/v2/https");
  onRequest = httpsV2.onRequest;
} catch (_) {}

try {
  admin = require("firebase-admin");
  if (admin && !admin.apps.length) {
    admin.initializeApp({
      projectId: process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT || "shopease-59a47",
    });
  }
  if (admin) {
    db = admin.firestore();
    messaging = admin.messaging();
  }
} catch (_) {}

/**
 * Extracts message IDs and structured error payloads from FCM multicast response.
 */
function extractFcmResults(tokens, response) {
  const messageIds = [];
  const errors = [];
  if (response && response.responses) {
    response.responses.forEach((resp, idx) => {
      if (resp.success && resp.messageId) {
        messageIds.push(resp.messageId);
      } else if (!resp.success && resp.error) {
        errors.push({
          token: tokens[idx] ? `${tokens[idx].substring(0, 10)}...` : "unknown",
          code: resp.error.code || "unknown_error",
          message: resp.error.message || String(resp.error),
        });
      }
    });
  }
  return { messageIds, errors };
}

/**
 * Finalizes status and telemetry in Firestore following FCM dispatch.
 * Guarantees reliable status transitions:
 * - queued -> processing -> sent (when at least one token successfully receives push)
 * - queued -> processing -> failed (when every send fails or recipient has no active tokens)
 */
async function finalizeRequestResult(docRef, {
  tokens,
  response,
  requestId,
  attemptCount = 1,
  noTokensReason = null,
}) {
  const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();

  if (noTokensReason) {
    await docRef.update({
      status: "failed",
      errorMessage: noTokensReason,
      fcmResponse: "no_active_tokens_registered",
      messageIds: [],
      successCount: 0,
      failureCount: 0,
      successfulSendCount: 0,
      failedSendCount: 0,
      totalTokens: 0,
      attemptCount: attemptCount || 1,
      processedAt: now,
    });
    return { success: false, delivered: 0, reason: noTokensReason };
  }

  const { messageIds, errors } = extractFcmResults(tokens, response);
  const isSuccess = response.successCount > 0;
  const isAllFailed = response.failureCount > 0 && response.successCount === 0;

  const updatePayload = {
    status: isSuccess ? "sent" : "failed",
    messageIds: messageIds,
    successCount: response.successCount,
    failureCount: response.failureCount,
    successfulSendCount: response.successCount,
    failedSendCount: response.failureCount,
    totalTokens: tokens.length,
    attemptCount: attemptCount || 1,
    processedAt: now,
    errorMessage: isAllFailed ? (errors[0]?.message || "FCM dispatch failed for all tokens") : null,
    errors: errors.length > 0 ? errors : null,
  };

  if (isSuccess) {
    updatePayload.sentAt = now;
  }

  await docRef.update(updatePayload);

  return {
    success: isSuccess,
    successCount: response.successCount,
    failureCount: response.failureCount,
    messageIds,
  };
}

/**
 * Cloud Function triggered on creation of a notification request document.
 */
if (onDocumentCreated) {
  exports.processNotificationRequest = onDocumentCreated(
    "notification_requests/{requestId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("[ShopEase:BackendWorker] No document data found in event.");
        return null;
      }

      const requestId = event.params.requestId;
      const data = snap.data();

      return await handleNotificationRequest(snap.ref, requestId, data);
    }
  );
} else {
  exports.processNotificationRequest = null;
}

/**
 * HTTPS trigger endpoint to process pending or backlogged requests on demand.
 * Restricts access to verified ShopEase administrators or authorized service keys.
 */
if (onRequest) {
  exports.processPendingNotificationRequests = onRequest(async (req, res) => {
    try {
      // 1. Authenticate caller (Admin token or admin dispatch secret)
      const authHeader = req.headers.authorization || "";
      const secretHeader = req.headers["x-admin-secret"] || req.headers["x-dispatch-secret"] || "";
      const configuredSecret = process.env.ADMIN_DISPATCH_SECRET;

      let isAuthorized = false;
      let authenticatedUid = null;

      if (configuredSecret && secretHeader && secretHeader === configuredSecret) {
        isAuthorized = true;
      } else if (authHeader.startsWith("Bearer ")) {
        const idToken = authHeader.split("Bearer ")[1];
        try {
          const decoded = await admin.auth().verifyIdToken(idToken);
          authenticatedUid = decoded.uid;
          const userDoc = await db.collection("customers").doc(authenticatedUid).get();
          if (userDoc.exists && userDoc.data().role === "admin") {
            isAuthorized = true;
          }
        } catch (authErr) {
          console.warn("[ShopEase:BackendWorker] ID token verification failed:", authErr.message);
        }
      }

      if (!isAuthorized) {
        return res.status(403).json({
          error: "Forbidden: Caller is not authorized to trigger pending notification requests. Administrator privilege required.",
        });
      }

      console.log(`[ShopEase:BackendWorker] Authorized pending request batch initiated by: ${authenticatedUid || "admin_secret"}`);

      // 2. Controlled batch query (maximum 50 requests per execution)
      const batchSize = Math.min(parseInt(req.query.limit, 10) || 50, 50);
      const snapshot = await db
        .collection("notification_requests")
        .where("status", "in", ["queued", "queued_for_backend", "pending"])
        .limit(batchSize)
        .get();

      if (snapshot.empty) {
        return res.json({ success: true, message: "No pending requests found", processed: 0 });
      }

      console.log(`[ShopEase:BackendWorker] Processing ${snapshot.size} queued request(s)...`);
      const results = [];
      for (const doc of snapshot.docs) {
        const result = await handleNotificationRequest(doc.ref, doc.id, doc.data());
        results.push({ requestId: doc.id, result });
      }

      return res.json({ success: true, count: results.length, results });
    } catch (err) {
      console.error("[ShopEase:BackendWorker] HTTP processing error:", err);
      return res.status(500).json({ error: err.message });
    }
  });
} else {
  exports.processPendingNotificationRequests = null;
}

/**
 * Core dispatch logic separated for modularity and unit testability.
 */
async function handleNotificationRequest(docRef, requestId, data) {
  const action = data.action;
  console.log(
    `[ShopEase:BackendWorker] Triggered for request: ${requestId}, action: ${action}`
  );

  // 1. Idempotency Check & Status Validation
  if (data.status === "sent" || data.status === "processed" || data.status === "processing") {
    console.log(
      `[ShopEase:BackendWorker] Request ${requestId} already ${data.status}. Skipping to prevent duplicate dispatch.`
    );
    return { skipped: true, status: data.status };
  }

  const validQueuedStatuses = ["queued", "queued_for_backend", "pending"];
  if (data.status && !validQueuedStatuses.includes(data.status)) {
    console.log(
      `[ShopEase:BackendWorker] Request ${requestId} status is '${data.status}'. Not in valid queued statuses [${validQueuedStatuses.join(", ")}]. Skipping.`
    );
    return { skipped: true, status: data.status };
  }

  // 2. Atomic claim to prevent duplicate sends across concurrent workers
  let attemptCount = 1;
  if (db && typeof db.runTransaction === "function") {
    try {
      const claim = await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(docRef);
        if (!snap.exists) {
          return { shouldSkip: true, reason: "document_not_found" };
        }
        const docData = snap.data() || {};
        const currentStatus = docData.status;

        if (currentStatus === "sent" || currentStatus === "processing" || currentStatus === "processed") {
          return { shouldSkip: true, status: currentStatus, data: docData };
        }

        if (currentStatus && !validQueuedStatuses.includes(currentStatus)) {
          return { shouldSkip: true, status: currentStatus, data: docData };
        }

        const attempts = (docData.attemptCount || 0) + 1;
        transaction.update(docRef, {
          status: "processing",
          processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
          attemptCount: attempts,
        });

        return { shouldSkip: false, data: docData, attemptCount: attempts };
      });

      if (claim.shouldSkip) {
        console.log(`[ShopEase:BackendWorker] Atomic claim skipped request ${requestId} (status: ${claim.status || claim.reason}).`);
        return { skipped: true, status: claim.status };
      }

      data = claim.data || data;
      attemptCount = claim.attemptCount || 1;
    } catch (err) {
      console.warn(`[ShopEase:BackendWorker] Transaction notice for ${requestId}:`, err.message);
      try {
        await docRef.update({
          status: "processing",
          processingStartedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
          attemptCount: (data.attemptCount || 0) + 1,
        });
        attemptCount = (data.attemptCount || 0) + 1;
      } catch (_) {}
    }
  } else {
    try {
      await docRef.update({
        status: "processing",
        processingStartedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
        attemptCount: (data.attemptCount || 0) + 1,
      });
      attemptCount = (data.attemptCount || 0) + 1;
    } catch (_) {}
  }

  try {
    let result;
    switch (action) {
      case "customer_order_confirmation":
        result = await handleCustomerOrderConfirmation(docRef, data, attemptCount);
        break;

      case "order_status_update":
        result = await handleCustomerOrderStatusUpdate(docRef, data, attemptCount);
        break;

      case "admin_new_order_alert":
        result = await handleAdminNewOrderAlert(docRef, data, attemptCount);
        break;

      case "admin_broadcast":
        result = await handleAdminBroadcast(docRef, data, attemptCount);
        break;

      default:
        console.warn(`[ShopEase:BackendWorker] Unknown action: ${action}`);
        await docRef.update({
          status: "failed",
          errorMessage: `Unsupported notification action: ${action}`,
          successfulSendCount: 0,
          failedSendCount: 0,
          successCount: 0,
          failureCount: 0,
          attemptCount: attemptCount,
          processedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
        });
        return { success: false, reason: "unknown_action" };
    }

    return result;
  } catch (error) {
    console.error(`[ShopEase:BackendWorker] Unexpected error in request ${requestId}:`, error);
    try {
      const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();
      await docRef.update({
        status: "failed",
        errorMessage: error.message || String(error),
        successfulSendCount: 0,
        failedSendCount: 0,
        successCount: 0,
        failureCount: 0,
        attemptCount: attemptCount,
        failedAt: now,
        processedAt: now,
      });
    } catch (_) {}
    return { success: false, error: error.message };
  }
}

/**
 * Dispatches order confirmation push to the ordering customer.
 */
async function handleCustomerOrderConfirmation(docRef, data, attemptCount = 1) {
  const customerUid = data.customerUid;
  const orderId = data.orderId;
  const requestId = data.requestId || docRef.id;

  if (!customerUid) {
    await docRef.update({
      status: "failed",
      errorMessage: "Missing customerUid in request payload.",
      attemptCount: attemptCount,
      processedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
    });
    return { success: false, reason: "missing_customer_uid" };
  }

  const { tokens, deviceRefs } = await getActiveDevicesForUser(customerUid);
  console.log(
    `[ShopEase:FCM] Retrieved ${tokens.length} active device token(s) for customer ${customerUid}`
  );

  if (tokens.length === 0) {
    return await finalizeRequestResult(docRef, {
      tokens: [],
      requestId,
      attemptCount,
      noTokensReason: `No active FCM tokens registered for customer ${customerUid}`,
    });
  }

  const title = data.title || `Order Confirmed: #${orderId}`;
  const body =
    data.body ||
    `Thank you for your order! Your items are being prepared with luxury packaging.`;
  const targetRoute = data.targetRoute || data.route || "/customer/orders";

  const payload = buildFcmMulticastMessage({
    tokens,
    title,
    body,
    data: {
      type: "order",
      requestId: requestId,
      orderId: orderId || "",
      route: targetRoute,
      targetRoute: targetRoute,
      action: "customer_order_confirmation",
    },
  });

  const response = await messaging.sendEachForMulticast(payload);
  console.log(
    `[ShopEase:FCM] FCM send response for ${requestId}: success=${response.successCount}, failure=${response.failureCount}`
  );

  await cleanupInvalidTokens(customerUid, tokens, deviceRefs, response);

  return await finalizeRequestResult(docRef, {
    tokens,
    response,
    requestId,
    attemptCount,
  });
}

/**
 * Dispatches order fulfillment status update push to customer.
 */
async function handleCustomerOrderStatusUpdate(docRef, data, attemptCount = 1) {
  const customerUid = data.customerUid;
  const orderId = data.orderId;
  const requestId = data.requestId || docRef.id;

  if (!customerUid) {
    await docRef.update({
      status: "failed",
      errorMessage: "Missing customerUid in request payload.",
      attemptCount: attemptCount,
      processedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
    });
    return { success: false, reason: "missing_customer_uid" };
  }

  const { tokens, deviceRefs } = await getActiveDevicesForUser(customerUid);
  console.log(
    `[ShopEase:FCM] Retrieved ${tokens.length} active device token(s) for customer ${customerUid}`
  );

  if (tokens.length === 0) {
    return await finalizeRequestResult(docRef, {
      tokens: [],
      requestId,
      attemptCount,
      noTokensReason: `No active FCM tokens registered for customer ${customerUid}`,
    });
  }

  const title = data.title || `Order #${orderId} Updated`;
  const body =
    data.body ||
    `Your order status is now: ${data.newStatusLabel || data.newStatus}.`;
  const targetRoute = data.targetRoute || data.route || "/customer/orders";

  const payload = buildFcmMulticastMessage({
    tokens,
    title,
    body,
    data: {
      type: "order",
      requestId: requestId,
      orderId: orderId || "",
      route: targetRoute,
      targetRoute: targetRoute,
      action: "order_status_update",
      newStatus: data.newStatus || "",
    },
  });

  const response = await messaging.sendEachForMulticast(payload);
  console.log(
    `[ShopEase:FCM] FCM send response for ${requestId}: success=${response.successCount}, failure=${response.failureCount}`
  );

  await cleanupInvalidTokens(customerUid, tokens, deviceRefs, response);

  return await finalizeRequestResult(docRef, {
    tokens,
    response,
    requestId,
    attemptCount,
  });
}

/**
 * Dispatches alert to store administrators when a new order is received.
 */
async function handleAdminNewOrderAlert(docRef, data, attemptCount = 1) {
  const orderId = data.orderId;
  const requestId = data.requestId || docRef.id;

  // Retrieve all users with role 'admin'
  const adminsSnap = await db
    .collection("customers")
    .where("role", "==", "admin")
    .get();

  const allAdminTokens = [];
  const allAdminDeviceRefs = [];

  for (const adminDoc of adminsSnap.docs) {
    const adminUid = adminDoc.id;
    const { tokens, deviceRefs } = await getActiveDevicesForUser(adminUid);
    for (let i = 0; i < tokens.length; i++) {
      allAdminTokens.push({ token: tokens[i], ref: deviceRefs[i], uid: adminUid });
    }
  }

  console.log(
    `[ShopEase:FCM] Retrieved ${allAdminTokens.length} active admin token(s) across ${adminsSnap.size} admin(s)`
  );

  if (allAdminTokens.length === 0) {
    return await finalizeRequestResult(docRef, {
      tokens: [],
      requestId,
      attemptCount,
      noTokensReason: "No active admin FCM tokens registered",
    });
  }

  const tokenList = allAdminTokens.map((item) => item.token);
  const title = data.title || `New Order Placed: #${orderId}`;
  const body =
    data.body ||
    `Received a new order from ${data.customerName || "Customer"} for $${data.orderTotal || "0.00"}.`;
  const targetRoute = data.targetRoute || data.route || "/admin/orders";

  const payload = buildFcmMulticastMessage({
    tokens: tokenList,
    title,
    body,
    data: {
      type: "admin_alert",
      requestId: requestId,
      orderId: orderId || "",
      route: targetRoute,
      targetRoute: targetRoute,
      action: "admin_new_order_alert",
    },
  });

  const response = await messaging.sendEachForMulticast(payload);
  console.log(
    `[ShopEase:FCM] FCM send response for admin alert ${requestId}: success=${response.successCount}, failure=${response.failureCount}`
  );

  return await finalizeRequestResult(docRef, {
    tokens: tokenList,
    response,
    requestId,
    attemptCount,
  });
}

/**
 * Handles admin-composed broadcasts (to all customers or a specific customer).
 */
async function handleAdminBroadcast(docRef, data, attemptCount = 1) {
  const requestId = data.requestId || docRef.id;
  const audience = data.audience || "all";
  const notification = data.notification || {};
  const title = notification.title || data.title || "ShopEase Announcement";
  const body = notification.body || data.body || "Special update from AÈRA ShopEase.";
  const imageUrl = notification.imageUrl || data.imageUrl || null;
  const targetRoute = notification.targetRoute || notification.route || data.targetRoute || data.route || "/";

  let targetTokens = [];
  let deviceRefs = [];

  if (audience === "customer") {
    const recipientUid = data.recipientUid || notification.recipientId;
    if (!recipientUid) {
      await docRef.update({
        status: "failed",
        errorMessage: "Missing recipientUid for direct customer broadcast.",
        attemptCount: attemptCount,
        processedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
      });
      return { success: false, reason: "missing_recipient_uid" };
    }
    const res = await getActiveDevicesForUser(recipientUid);
    targetTokens = res.tokens;
    deviceRefs = res.deviceRefs;
  } else {
    // Audience: all registered devices
    const devicesSnap = await db
      .collectionGroup("devices")
      .where("isActive", "==", true)
      .get();

    for (const d of devicesSnap.docs) {
      const token = d.data().token;
      if (token && !targetTokens.includes(token)) {
        targetTokens.push(token);
        deviceRefs.push(d.ref);
      }
    }
  }

  console.log(
    `[ShopEase:FCM] Broadcast (${audience}) targeting ${targetTokens.length} active device token(s)`
  );

  if (targetTokens.length === 0) {
    return await finalizeRequestResult(docRef, {
      tokens: [],
      requestId,
      attemptCount,
      noTokensReason: `No active tokens found for broadcast audience '${audience}'`,
    });
  }

  // Batch into chunks of 500 (FCM sendEachForMulticast maximum limit)
  let totalSuccess = 0;
  let totalFailure = 0;
  const allMessageIds = [];
  const allErrors = [];

  for (let i = 0; i < targetTokens.length; i += 500) {
    const chunkTokens = targetTokens.slice(i, i + 500);
    const chunkRefs = deviceRefs.slice(i, i + 500);

    const payload = buildFcmMulticastMessage({
      tokens: chunkTokens,
      title,
      body,
      imageUrl,
      data: {
        type: notification.type || "announcement",
        requestId: requestId,
        route: targetRoute,
        targetRoute: targetRoute,
        action: "admin_broadcast",
      },
    });

    const response = await messaging.sendEachForMulticast(payload);
    totalSuccess += response.successCount;
    totalFailure += response.failureCount;

    const { messageIds: chunkIds, errors: chunkErrs } = extractFcmResults(chunkTokens, response);
    allMessageIds.push(...chunkIds);
    allErrors.push(...chunkErrs);

    await cleanupInvalidTokens("broadcast", chunkTokens, chunkRefs, response);
  }

  const combinedResponse = {
    successCount: totalSuccess,
    failureCount: totalFailure,
    responses: allMessageIds.map((id) => ({ success: true, messageId: id })).concat(
      allErrors.map((err) => ({ success: false, error: { code: err.code, message: err.message } }))
    ),
  };

  return await finalizeRequestResult(docRef, {
    tokens: targetTokens,
    response: combinedResponse,
    requestId,
    attemptCount,
  });
}

/**
 * Retrieves all active devices for a given user UID.
 * Supports primary path customers/{uid}/devices and fallback users/{uid}/devices.
 */
async function getActiveDevicesForUser(uid) {
  let devicesSnap = await db
    .collection("customers")
    .doc(uid)
    .collection("devices")
    .where("isActive", "==", true)
    .get();

  const tokens = [];
  const deviceRefs = [];
  const deviceMeta = [];

  for (const doc of devicesSnap.docs) {
    const data = doc.data();
    const t = (data.token || data.fcmToken || "").trim();
    if (t && !tokens.includes(t)) {
      tokens.push(t);
      deviceRefs.push(doc.ref);
      deviceMeta.push({
        token: t,
        platform: data.platform || "unknown",
        deviceId: doc.id,
      });
    }
  }

  // Fallback to legacy path users/{uid}/devices if no tokens found in customers/{uid}/devices
  if (tokens.length === 0) {
    const legacySnap = await db
      .collection("users")
      .doc(uid)
      .collection("devices")
      .where("isActive", "==", true)
      .get();

    for (const doc of legacySnap.docs) {
      const data = doc.data();
      const t = (data.token || data.fcmToken || "").trim();
      if (t && !tokens.includes(t)) {
        tokens.push(t);
        deviceRefs.push(doc.ref);
        deviceMeta.push({
          token: t,
          platform: data.platform || "unknown",
          deviceId: doc.id,
        });
      }
    }
  }

  return { tokens, deviceRefs, deviceMeta };
}

/**
 * Cleans up invalid or expired registration tokens to maintain healthy push registry.
 */
async function cleanupInvalidTokens(uid, tokens, deviceRefs, response) {
  const invalidRefs = [];

  response.responses.forEach((resp, idx) => {
    if (!resp.success && resp.error) {
      console.error(
        `[ShopEase:FCM] Delivery error for token ${tokens[idx].substring(0, 10)}...:`,
        resp.error.code,
        resp.error.message
      );
      if (
        resp.error.code === "messaging/registration-token-not-registered" ||
        resp.error.code === "messaging/invalid-registration-token"
      ) {
        if (deviceRefs[idx]) {
          invalidRefs.push(deviceRefs[idx]);
        }
      }
    }
  });

  if (invalidRefs.length > 0 && db && typeof db.batch === "function") {
    const batch = db.batch();
    for (const ref of invalidRefs) {
      batch.update(ref, {
        isActive: false,
        invalidatedAt: admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
        invalidationReason: "unregistered_token",
      });
    }
    await batch.commit();
    console.log(
      `[ShopEase:FCM] Marked ${invalidRefs.length} obsolete device token(s) as inactive for ${uid}`
    );
  }
}

/**
 * Builds platform-compliant FCM multicast payload for Android & Web.
 */
function buildFcmMulticastMessage({ tokens, title, body, imageUrl, data }) {
  const messageData = { ...(data || {}) };
  if (!messageData.click_action) {
    messageData.click_action = "FLUTTER_NOTIFICATION_CLICK";
  }
  if (!messageData.route && messageData.targetRoute) {
    messageData.route = messageData.targetRoute;
  }
  if (!messageData.targetRoute && messageData.route) {
    messageData.targetRoute = messageData.route;
  }

  const message = {
    tokens,
    notification: {
      title,
      body,
    },
    data: messageData,
    android: {
      priority: "high",
      notification: {
        channelId: "shopease_high_importance",
        sound: "default",
        defaultSound: true,
        defaultVibrateTimings: true,
        visibility: "public",
        notificationPriority: "priority_max",
      },
    },
    webpush: {
      headers: {
        Urgency: "high",
      },
      notification: {
        title,
        body,
        icon: "favicon.png",
        badge: "icons/Icon-192.png",
        data: messageData,
        tag: messageData.requestId || messageData.id || "shopease-notification",
      },
    },
  };

  if (imageUrl) {
    message.notification.imageUrl = imageUrl;
    message.android.notification.imageUrl = imageUrl;
    message.webpush.notification.image = imageUrl;
  }

  return message;
}

// Export internal functions for unit testing and modular use
module.exports = {
  handleNotificationRequest,
  handleCustomerOrderConfirmation,
  handleCustomerOrderStatusUpdate,
  handleAdminNewOrderAlert,
  handleAdminBroadcast,
  buildFcmMulticastMessage,
  cleanupInvalidTokens,
  getActiveDevicesForUser,
  finalizeRequestResult,
  extractFcmResults,
  processNotificationRequest: exports.processNotificationRequest,
  processPendingNotificationRequests: exports.processPendingNotificationRequests,
};
