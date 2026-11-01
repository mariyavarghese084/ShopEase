/**
 * ShopEase (AÈRA Luxury Fragrances & Cosmetics) - Standalone FCM Notification Worker
 *
 * Designed to execute on GitHub Actions (or any standalone cron/runner)
 * without requiring Firebase Cloud Functions (no Firebase Blaze plan needed).
 *
 * Connects directly to Cloud Firestore & Firebase Cloud Messaging (FCM) v1
 * using standard HTTPS REST/gRPC Admin SDK endpoints via a service account
 * provided through the FIREBASE_SERVICE_ACCOUNT environment variable.
 */

const fs = require("fs");
const admin = require("firebase-admin");

/**
 * Safely parses the service account from environment variables.
 * Accepts:
 * - Raw JSON string
 * - Base64-encoded JSON string
 * - Path to a local JSON file (for local development/testing)
 *
 * NEVER prints or leaks the private key or secret contents.
 */
/**
 * Strips whitespace, Byte Order Marks (BOM), outer wrapping quotes,
 * and markdown code fence syntax commonly introduced when copying secrets.
 */
function sanitizeCredentialString(rawEnv) {
  if (!rawEnv || typeof rawEnv !== "string") {
    return "";
  }
  let s = rawEnv.trim();

  // 1. Strip UTF-8 Byte Order Mark (BOM) if present (common in Windows clipboard/PowerShell)
  if (s.charCodeAt(0) === 0xfeff) {
    s = s.slice(1).trim();
  }

  // 2. Strip Markdown code fences if secret contains ```json ... ```
  if (s.startsWith("```")) {
    s = s.replace(/^```[a-zA-Z0-9_-]*\r?\n?/, "").replace(/\r?\n?```$/, "").trim();
  }

  // 3. Strip outer single or double quotes wrapping the entire JSON or base64 string
  if (
    (s.startsWith('"') && s.endsWith('"') && s.length >= 2) ||
    (s.startsWith("'") && s.endsWith("'") && s.length >= 2)
  ) {
    s = s.slice(1, -1).trim();
  }

  return s;
}

/**
 * Validates required service account fields and normalizes escaped private key newlines.
 * Does NOT print any sensitive values or keys.
 */
function validateAndNormalizeServiceAccount(parsed, expectedProjectId = "shopease-59a47") {
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("Service account credential is not a valid JSON object.");
  }

  // Check required fields without printing secret values
  const missing = [];
  if (!parsed.project_id || typeof parsed.project_id !== "string" || !parsed.project_id.trim()) {
    missing.push("project_id");
  }
  if (!parsed.private_key || typeof parsed.private_key !== "string" || !parsed.private_key.trim()) {
    missing.push("private_key");
  }
  if (!parsed.client_email || typeof parsed.client_email !== "string" || !parsed.client_email.trim()) {
    missing.push("client_email");
  }

  if (missing.length > 0) {
    throw new Error(
      `Service account credential is missing required fields: [${missing.join(", ")}].`
    );
  }

  // Verify project_id matches the target Firebase project
  const targetProject = (expectedProjectId || "shopease-59a47").trim();
  if (parsed.project_id.trim() !== targetProject) {
    throw new Error(
      `Service account project_id mismatch: expected '${targetProject}', but credential is for another project.`
    );
  }

  // Normalize private key: ensure escaped newlines (\n) are converted to real newlines
  if (typeof parsed.private_key === "string" && parsed.private_key.includes("\\n")) {
    parsed.private_key = parsed.private_key.replace(/\\n/g, "\n");
  }

  return parsed;
}

/**
 * Safely parses the service account from environment variables.
 * Accepts:
 * - Raw JSON string (standard, multiline, or single-line)
 * - Base64-encoded JSON string (with or without wrapping whitespace)
 * - Quoted or markdown-wrapped JSON string
 * - Path to a local JSON file (for local development/testing)
 *
 * NEVER prints or leaks the private key or secret contents.
 */
function parseServiceAccount(rawEnv, expectedProjectId = "shopease-59a47") {
  if (!rawEnv || typeof rawEnv !== "string") {
    return null;
  }

  const s = sanitizeCredentialString(rawEnv);
  if (!s) {
    return null;
  }

  let parsed = null;

  // Strategy 1: Direct JSON parse
  try {
    const res = JSON.parse(s);
    if (res && typeof res === "object") {
      parsed = res;
    } else if (typeof res === "string") {
      // Handles double-stringified JSON (e.g. JSON in a quoted string)
      const inner = JSON.parse(res.trim());
      if (inner && typeof inner === "object") {
        parsed = inner;
      }
    }
  } catch (_) {}

  // Strategy 2: Extract JSON object bounded by outermost { and }
  if (!parsed) {
    const firstBrace = s.indexOf("{");
    const lastBrace = s.lastIndexOf("}");
    if (firstBrace !== -1 && lastBrace > firstBrace) {
      try {
        const candidate = s.slice(firstBrace, lastBrace + 1);
        const res = JSON.parse(candidate);
        if (res && typeof res === "object") {
          parsed = res;
        }
      } catch (_) {}
    }
  }

  // Strategy 3: Base64-encoded JSON
  if (!parsed) {
    try {
      const cleanB64 = s.replace(/[\r\n\t\s]/g, "");
      const decoded = Buffer.from(cleanB64, "base64").toString("utf8").trim();
      const cleanDecoded = sanitizeCredentialString(decoded);

      try {
        const res = JSON.parse(cleanDecoded);
        if (res && typeof res === "object") {
          parsed = res;
        }
      } catch (_) {
        const firstBrace = cleanDecoded.indexOf("{");
        const lastBrace = cleanDecoded.lastIndexOf("}");
        if (firstBrace !== -1 && lastBrace > firstBrace) {
          const res = JSON.parse(cleanDecoded.slice(firstBrace, lastBrace + 1));
          if (res && typeof res === "object") {
            parsed = res;
          }
        }
      }
    } catch (_) {}
  }

  // Strategy 4: Local file path
  if (!parsed && fs.existsSync(s)) {
    try {
      const fileContent = fs.readFileSync(s, "utf8");
      parsed = parseServiceAccount(fileContent, expectedProjectId);
      return parsed;
    } catch (e) {
      throw new Error(`Failed to read service account file from path: ${e.message}`);
    }
  }

  if (!parsed) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT was provided but could not be parsed as raw JSON, base64-encoded JSON, or a valid file path."
    );
  }

  return validateAndNormalizeServiceAccount(parsed, expectedProjectId);
}

/**
 * Initializes Firebase Admin SDK with credentials.
 */
function initFirebase({ serviceAccount, projectId } = {}) {
  const targetProjectId =
    projectId ||
    process.env.FIREBASE_PROJECT_ID ||
    process.env.GCLOUD_PROJECT ||
    "shopease-59a47";

  const sa =
    serviceAccount ||
    parseServiceAccount(
      process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_KEY,
      targetProjectId
    );

  let app;
  if (admin.apps.length > 0) {
    app = admin.app();
  } else {
    const appOptions = {
      projectId: targetProjectId,
    };

    if (sa) {
      appOptions.credential = admin.credential.cert(sa);
      const maskedEmail = sa.client_email
        ? `${sa.client_email.split("@")[0].substring(0, 4)}***@${(sa.client_email.split("@")[1] || "").substring(0, 8)}...`
        : "configured";
      console.log(`[ShopEase:Worker] Authenticated via Service Account: ${maskedEmail}`);
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      try {
        appOptions.credential = admin.credential.applicationDefault();
        console.log("[ShopEase:Worker] Authenticated via GOOGLE_APPLICATION_CREDENTIALS.");
      } catch (err) {
        console.warn("[ShopEase:Worker] Warning loading application default credentials:", err.message);
      }
    } else {
      console.warn(
        "[ShopEase:Worker] Notice: FIREBASE_SERVICE_ACCOUNT is not configured. Live Firestore and FCM requests will require authentication."
      );
    }

    app = admin.initializeApp(appOptions);
  }

  return {
    admin,
    app,
    db: admin.firestore(app),
    messaging: admin.messaging(app),
    projectId: targetProjectId,
  };
}

/**
 * Builds cross-platform FCM multicast message payload for Android & Web.
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
 * Cleans up invalid or expired registration tokens to maintain healthy push registry.
 */
async function cleanupInvalidTokens(db, uid, tokens, deviceRefs, response) {
  const invalidRefs = [];

  if (!response || !response.responses) {
    return 0;
  }

  response.responses.forEach((resp, idx) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code || "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        if (deviceRefs && deviceRefs[idx]) {
          invalidRefs.push(deviceRefs[idx]);
        }
      }
    }
  });

  if (invalidRefs.length > 0 && db && typeof db.batch === "function") {
    const batch = db.batch();
    const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();
    for (const ref of invalidRefs) {
      batch.update(ref, {
        isActive: false,
        invalidatedAt: now,
        invalidationReason: "unregistered_token",
      });
    }
    await batch.commit();
    console.log(
      `[ShopEase:Worker] Marked ${invalidRefs.length} obsolete device token(s) as inactive for user: ${uid}`
    );
  }
  return invalidRefs.length;
}

/**
 * Finalizes status and telemetry in Firestore following FCM dispatch.
 */
async function finalizeRequestResult(docRef, {
  tokens = [],
  response = null,
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
      failedAt: now,
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
  } else {
    updatePayload.failedAt = now;
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
 * Retrieves all active devices for a given user UID.
 * Supports primary path customers/{uid}/devices and fallback users/{uid}/devices.
 */
async function getActiveDevicesForUser(db, uid) {
  const tokens = [];
  const deviceRefs = [];
  const deviceMeta = [];

  let devicesSnap;
  try {
    devicesSnap = await db
      .collection("customers")
      .doc(uid)
      .collection("devices")
      .where("isActive", "==", true)
      .get();
  } catch (_) {
    devicesSnap = { docs: [] };
  }

  for (const doc of devicesSnap.docs) {
    const data = doc.data() || {};
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
    let legacySnap;
    try {
      legacySnap = await db
        .collection("users")
        .doc(uid)
        .collection("devices")
        .where("isActive", "==", true)
        .get();
    } catch (_) {
      legacySnap = { docs: [] };
    }

    for (const doc of legacySnap.docs) {
      const data = doc.data() || {};
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
 * Atomically claims a notification request using Firestore transactions.
 * Guarantees that only one worker can process a request, preventing duplicate push delivery.
 */
async function claimRequest(db, docRef, maxAttempts = 5) {
  if (!db || typeof db.runTransaction !== "function") {
    // Non-transactional fallback for unit test mocks lacking transaction support
    const snap = await docRef.get();
    if (!snap.exists) return { claimed: false, reason: "document_not_found" };
    const data = snap.data() || {};
    const validStatuses = ["queued", "queued_for_backend", "pending"];
    if (!validStatuses.includes(data.status)) {
      return { claimed: false, reason: `status_is_${data.status}`, data };
    }
    const attempts = (data.attemptCount || 0) + 1;
    if (attempts > maxAttempts) {
      await docRef.update({
        status: "failed",
        errorMessage: `Max retry attempts reached (${data.attemptCount}/${maxAttempts})`,
      });
      return { claimed: false, reason: "max_attempts_exceeded", data };
    }
    await docRef.update({
      status: "processing",
      attemptCount: attempts,
    });
    return { claimed: true, data: { ...data, status: "processing", attemptCount: attempts }, requestId: docRef.id };
  }

  return await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(docRef);
    if (!snap.exists) {
      return { claimed: false, reason: "document_not_found" };
    }

    const data = snap.data() || {};
    const currentStatus = data.status;

    // 1. Only process valid queued statuses
    const validStatuses = ["queued", "queued_for_backend", "pending"];
    if (!validStatuses.includes(currentStatus)) {
      return { claimed: false, reason: `status_is_${currentStatus}`, data };
    }

    // 2. Retry limits: if request exceeded max retry attempts, mark it permanently failed
    const currentAttempts = data.attemptCount || 0;
    if (currentAttempts >= maxAttempts) {
      const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();
      transaction.update(docRef, {
        status: "failed",
        errorMessage: `Max retry attempts reached (${currentAttempts}/${maxAttempts})`,
        failedAt: now,
        processedAt: now,
      });
      return { claimed: false, reason: "max_attempts_exceeded", data };
    }

    // 3. Atomically advance to "processing" to lock out concurrent workers
    const nextAttempts = currentAttempts + 1;
    const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();
    transaction.update(docRef, {
      status: "processing",
      processingStartedAt: now,
      attemptCount: nextAttempts,
    });

    return {
      claimed: true,
      data: { ...data, status: "processing", attemptCount: nextAttempts },
      requestId: docRef.id,
    };
  });
}

/**
 * Dispatches a single claimed notification request to FCM.
 */
async function dispatchNotificationRequest({ db, messaging, docRef, requestId, data }) {
  const action = data.action;
  const attemptCount = data.attemptCount || 1;

  console.log(`[ShopEase:Worker] Dispatching request ${requestId} (action: ${action}, attempt: ${attemptCount})`);

  switch (action) {
    case "customer_order_confirmation": {
      const customerUid = data.customerUid;
      const orderId = data.orderId;

      if (!customerUid) {
        return await finalizeRequestResult(docRef, {
          tokens: [],
          requestId,
          attemptCount,
          noTokensReason: "Missing customerUid in request payload.",
        });
      }

      const { tokens, deviceRefs } = await getActiveDevicesForUser(db, customerUid);
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
          requestId,
          orderId: orderId || "",
          route: targetRoute,
          targetRoute: targetRoute,
          action: "customer_order_confirmation",
        },
      });

      const response = await messaging.sendEachForMulticast(payload);
      await cleanupInvalidTokens(db, customerUid, tokens, deviceRefs, response);
      return await finalizeRequestResult(docRef, {
        tokens,
        response,
        requestId,
        attemptCount,
      });
    }

    case "order_status_update": {
      const customerUid = data.customerUid;
      const orderId = data.orderId;

      if (!customerUid) {
        return await finalizeRequestResult(docRef, {
          tokens: [],
          requestId,
          attemptCount,
          noTokensReason: "Missing customerUid in request payload.",
        });
      }

      const { tokens, deviceRefs } = await getActiveDevicesForUser(db, customerUid);
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
        data.body || `Your order status is now: ${data.newStatusLabel || data.newStatus}.`;
      const targetRoute = data.targetRoute || data.route || "/customer/orders";

      const payload = buildFcmMulticastMessage({
        tokens,
        title,
        body,
        data: {
          type: "order",
          requestId,
          orderId: orderId || "",
          route: targetRoute,
          targetRoute: targetRoute,
          action: "order_status_update",
          newStatus: data.newStatus || "",
        },
      });

      const response = await messaging.sendEachForMulticast(payload);
      await cleanupInvalidTokens(db, customerUid, tokens, deviceRefs, response);
      return await finalizeRequestResult(docRef, {
        tokens,
        response,
        requestId,
        attemptCount,
      });
    }

    case "admin_new_order_alert": {
      const orderId = data.orderId;
      const adminsSnap = await db
        .collection("customers")
        .where("role", "==", "admin")
        .get();

      const allAdminTokens = [];
      const allAdminDeviceRefs = [];

      for (const adminDoc of adminsSnap.docs) {
        const adminUid = adminDoc.id;
        const { tokens, deviceRefs } = await getActiveDevicesForUser(db, adminUid);
        for (let i = 0; i < tokens.length; i++) {
          allAdminTokens.push({ token: tokens[i], ref: deviceRefs[i], uid: adminUid });
        }
      }

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
          requestId,
          orderId: orderId || "",
          route: targetRoute,
          targetRoute: targetRoute,
          action: "admin_new_order_alert",
        },
      });

      const response = await messaging.sendEachForMulticast(payload);
      return await finalizeRequestResult(docRef, {
        tokens: tokenList,
        response,
        requestId,
        attemptCount,
      });
    }

    case "admin_broadcast": {
      const audience = data.audience || "all";
      const notification = data.notification || {};
      const title = notification.title || data.title || "ShopEase Announcement";
      const body = notification.body || data.body || "Special update from AÈRA ShopEase.";
      const imageUrl = notification.imageUrl || data.imageUrl || null;
      const targetRoute =
        notification.targetRoute || notification.route || data.targetRoute || data.route || "/";

      let targetTokens = [];
      let deviceRefs = [];

      if (audience === "customer") {
        const recipientUid = data.recipientUid || notification.recipientId;
        if (!recipientUid) {
          return await finalizeRequestResult(docRef, {
            tokens: [],
            requestId,
            attemptCount,
            noTokensReason: "Missing recipientUid for direct customer broadcast.",
          });
        }
        const res = await getActiveDevicesForUser(db, recipientUid);
        targetTokens = res.tokens;
        deviceRefs = res.deviceRefs;
      } else {
        const devicesSnap = await db
          .collectionGroup("devices")
          .where("isActive", "==", true)
          .get();

        for (const d of devicesSnap.docs) {
          const t = d.data().token;
          if (t && !targetTokens.includes(t)) {
            targetTokens.push(t);
            deviceRefs.push(d.ref);
          }
        }
      }

      if (targetTokens.length === 0) {
        return await finalizeRequestResult(docRef, {
          tokens: [],
          requestId,
          attemptCount,
          noTokensReason: `No active tokens found for broadcast audience '${audience}'`,
        });
      }

      // Batch in chunks of 500 (FCM sendEachForMulticast maximum limit)
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
            requestId,
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

        await cleanupInvalidTokens(db, "broadcast", chunkTokens, chunkRefs, response);
      }

      const combinedResponse = {
        successCount: totalSuccess,
        failureCount: totalFailure,
        responses: allMessageIds
          .map((id) => ({ success: true, messageId: id }))
          .concat(
            allErrors.map((err) => ({
              success: false,
              error: { code: err.code, message: err.message },
            }))
          ),
      };

      return await finalizeRequestResult(docRef, {
        tokens: targetTokens,
        response: combinedResponse,
        requestId,
        attemptCount,
      });
    }

    default: {
      console.warn(`[ShopEase:Worker] Unsupported action: ${action}`);
      return await finalizeRequestResult(docRef, {
        tokens: [],
        requestId,
        attemptCount,
        noTokensReason: `Unsupported notification action: ${action}`,
      });
    }
  }
}

/**
 * Main batch processing loop.
 */
async function processQueuedRequests({ db, messaging, limit = 50, dryRun = false } = {}) {
  console.log(`[ShopEase:Worker] Querying queued notification requests (limit: ${limit}, dryRun: ${dryRun})...`);

  const snapshot = await db
    .collection("notification_requests")
    .where("status", "in", ["queued", "queued_for_backend", "pending"])
    .limit(limit)
    .get();

  if (snapshot.empty) {
    console.log("[ShopEase:Worker] No queued notification requests found. Worker finished.");
    return { total: 0, sent: 0, failed: 0, skipped: 0 };
  }

  // Sort in-memory by createdAt ascending so older requests are processed first
  const docs = snapshot.docs.slice().sort((a, b) => {
    const dataA = a.data() || {};
    const dataB = b.data() || {};
    const timeA = dataA.createdAt?.toMillis ? dataA.createdAt.toMillis() : (dataA.createdAt || 0);
    const timeB = dataB.createdAt?.toMillis ? dataB.createdAt.toMillis() : (dataB.createdAt || 0);
    return timeA - timeB;
  });

  console.log(`[ShopEase:Worker] Found ${docs.length} pending request(s) to process.`);

  let sentCount = 0;
  let failedCount = 0;
  let skippedCount = 0;

  for (const doc of docs) {
    const requestId = doc.id;
    if (dryRun) {
      console.log(`[ShopEase:Worker] [DryRun] Would claim and process request: ${requestId}`);
      skippedCount++;
      continue;
    }

    // 1. Atomically claim request to prevent duplicate processing
    let claim;
    try {
      claim = await claimRequest(db, doc.ref);
    } catch (err) {
      console.error(`[ShopEase:Worker] Failed to claim request ${requestId}:`, err.message);
      skippedCount++;
      continue;
    }

    if (!claim.claimed) {
      console.log(`[ShopEase:Worker] Skipped request ${requestId} (${claim.reason})`);
      skippedCount++;
      continue;
    }

    // 2. Dispatch claimed request
    try {
      const result = await dispatchNotificationRequest({
        db,
        messaging,
        docRef: doc.ref,
        requestId,
        data: claim.data,
      });

      if (result.success) {
        sentCount++;
      } else {
        failedCount++;
      }
    } catch (err) {
      console.error(`[ShopEase:Worker] Error processing request ${requestId}:`, err.message);
      failedCount++;
      try {
        const now = admin && admin.firestore ? admin.firestore.FieldValue.serverTimestamp() : new Date();
        await doc.ref.update({
          status: "failed",
          errorMessage: err.message || "Unknown worker processing error",
          failedAt: now,
          processedAt: now,
        });
      } catch (_) {}
    }
  }

  const summary = {
    total: docs.length,
    sent: sentCount,
    failed: failedCount,
    skipped: skippedCount,
  };

  console.log(
    `[ShopEase:Worker] Batch complete. Total: ${summary.total}, Sent: ${summary.sent}, Failed: ${summary.failed}, Skipped: ${summary.skipped}`
  );
  return summary;
}

// Module exports for CLI and testing
module.exports = {
  sanitizeCredentialString,
  validateAndNormalizeServiceAccount,
  parseServiceAccount,
  initFirebase,
  buildFcmMulticastMessage,
  extractFcmResults,
  cleanupInvalidTokens,
  finalizeRequestResult,
  getActiveDevicesForUser,
  claimRequest,
  dispatchNotificationRequest,
  processQueuedRequests,
};

// Direct CLI entrypoint
if (require.main === module) {
  (async () => {
    try {
      const args = process.argv.slice(2);
      const isDryRun = args.includes("--dry-run") || process.env.DRY_RUN === "true";
      const limitArg = args.find((a) => a.startsWith("--limit="));
      const limit = limitArg
        ? parseInt(limitArg.split("=")[1], 10)
        : parseInt(process.env.BATCH_LIMIT, 10) || 50;

      const hasCredentials = !!(
        process.env.FIREBASE_SERVICE_ACCOUNT ||
        process.env.FIREBASE_SERVICE_ACCOUNT_KEY ||
        process.env.GOOGLE_APPLICATION_CREDENTIALS
      );

      if (!hasCredentials) {
        console.error(
          "[ShopEase:Worker] ERROR: Missing FIREBASE_SERVICE_ACCOUNT secret/environment variable.\n" +
          "To dispatch notifications, configure FIREBASE_SERVICE_ACCOUNT in GitHub Repository Secrets or local environment."
        );
        process.exit(1);
      }

      const firebaseContext = initFirebase();
      await processQueuedRequests({
        db: firebaseContext.db,
        messaging: firebaseContext.messaging,
        limit,
        dryRun: isDryRun,
      });
      process.exit(0);
    } catch (err) {
      console.error("[ShopEase:Worker] Fatal worker error:", err.message);
      process.exit(1);
    }
  })();
}
