/**
 * Comprehensive Unit and Integration Tests for Standalone FCM Notification Worker.
 *
 * Verifies:
 * 1. Service account credential parsing (raw JSON, Base64 JSON, and error handling)
 * 2. Multi-platform FCM payload formatting (Android channel & sound, WebPush tags)
 * 3. Atomic claim mechanism & duplicate dispatch prevention
 * 4. Empty token handling (recipient without registered devices)
 * 5. 100% Successful FCM delivery status update
 * 6. Partial FCM failure handling and invalid token cleanup
 * 7. Complete FCM failure handling
 * 8. Max retry attempt enforcement (toxic message / retry safety)
 * 9. Batch queue processing loop with mixed workloads
 */

const assert = require("assert");
const {
  sanitizeCredentialString,
  validateAndNormalizeServiceAccount,
  parseServiceAccount,
  buildFcmMulticastMessage,
  extractFcmResults,
  cleanupInvalidTokens,
  finalizeRequestResult,
  claimRequest,
  dispatchNotificationRequest,
  processQueuedRequests,
} = require("../worker");

async function runWorkerTests() {
  console.log("==================================================================");
  console.log("  Running ShopEase Standalone FCM Worker Complete Test Suite");
  console.log("==================================================================\n");

  // ── Test 1: Service Account Parsing & Sanitization ───────────────────────────
  {
    console.log("Test 1: Service Account credential parsing, sanitization, and decoding...");

    // 1A: Standard raw JSON string
    const sampleSa = {
      type: "service_account",
      project_id: "shopease-59a47",
      private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASC...\n-----END PRIVATE KEY-----\n",
      client_email: "firebase-adminsdk@shopease-59a47.iam.gserviceaccount.com",
    };
    const parsedRaw = parseServiceAccount(JSON.stringify(sampleSa));
    assert.strictEqual(parsedRaw.project_id, "shopease-59a47");
    assert.strictEqual(parsedRaw.client_email, sampleSa.client_email);

    // 1B: Base64-encoded JSON string
    const base64Sa = Buffer.from(JSON.stringify(sampleSa)).toString("base64");
    const parsedBase64 = parseServiceAccount(base64Sa);
    assert.strictEqual(parsedBase64.project_id, "shopease-59a47");
    assert.strictEqual(parsedBase64.client_email, sampleSa.client_email);

    // 1C: Base64-encoded JSON with internal newlines / spaces (e.g. wrapped lines)
    const base64WithNewlines = base64Sa.substring(0, 40) + "\r\n  " + base64Sa.substring(40);
    const parsedB64Wrapped = parseServiceAccount(base64WithNewlines);
    assert.strictEqual(parsedB64Wrapped.project_id, "shopease-59a47");

    // 1D: UTF-8 Byte Order Mark (BOM \uFEFF) prefixed JSON (common when copying from PowerShell/Windows)
    const bomJson = "\uFEFF" + JSON.stringify(sampleSa);
    const parsedBom = parseServiceAccount(bomJson);
    assert.strictEqual(parsedBom.project_id, "shopease-59a47");

    // 1E: JSON wrapped in single or double quotes
    const singleQuoted = `'${JSON.stringify(sampleSa)}'`;
    const parsedSingle = parseServiceAccount(singleQuoted);
    assert.strictEqual(parsedSingle.project_id, "shopease-59a47");

    // 1F: Markdown code fence block (```json ... ```)
    const markdownWrapped = "```json\n" + JSON.stringify(sampleSa, null, 2) + "\n```";
    const parsedMarkdown = parseServiceAccount(markdownWrapped);
    assert.strictEqual(parsedMarkdown.project_id, "shopease-59a47");

    // 1G: Private key with escaped newlines (\\n) normalized to real newlines (\n)
    const saWithEscapedNewlines = {
      ...sampleSa,
      private_key: "-----BEGIN PRIVATE KEY-----\\nLINE1\\nLINE2\\n-----END PRIVATE KEY-----\\n",
    };
    const parsedEscaped = parseServiceAccount(JSON.stringify(saWithEscapedNewlines));
    assert.strictEqual(
      parsedEscaped.private_key,
      "-----BEGIN PRIVATE KEY-----\nLINE1\nLINE2\n-----END PRIVATE KEY-----\n"
    );

    // 1H: Missing required field validation (without printing values)
    const incompleteSa = {
      project_id: "shopease-59a47",
      // Missing private_key and client_email
    };
    assert.throws(() => {
      parseServiceAccount(JSON.stringify(incompleteSa));
    }, /missing required fields: \[private_key, client_email\]/);

    // 1I: Project ID mismatch verification
    const wrongProjectSa = {
      ...sampleSa,
      project_id: "wrong-project-999",
    };
    assert.throws(() => {
      parseServiceAccount(JSON.stringify(wrongProjectSa));
    }, /project_id mismatch: expected 'shopease-59a47'/);

    // 1J: Null, undefined, empty string handling
    assert.strictEqual(parseServiceAccount(null), null);
    assert.strictEqual(parseServiceAccount(""), null);

    // 1K: Invalid non-JSON string
    assert.throws(() => {
      parseServiceAccount("not_a_valid_json_or_base64_payload");
    }, /FIREBASE_SERVICE_ACCOUNT was provided but could not be parsed/);

    console.log("  ✓ Test 1 Passed: Robust parsing verified for Raw JSON, Base64, BOM, Quotes, Markdown, Escaped Keys, and Validation.\n");
  }

  // ── Test 2: Outgoing FCM Multicast Payload ──────────────────────────────────
  {
    console.log("Test 2: Cross-platform FCM payload schema validation...");
    const payload = buildFcmMulticastMessage({
      tokens: ["token_android_1", "token_web_2"],
      title: "Order Confirmed: #ORD-999",
      body: "Your luxury fragrance is confirmed.",
      imageUrl: "https://shopease.app/images/sample.jpg",
      data: {
        type: "order",
        requestId: "conf_order_ORD-999",
        orderId: "ORD-999",
        targetRoute: "/customer/orders",
      },
    });

    assert.strictEqual(payload.tokens.length, 2);
    assert.strictEqual(payload.notification.title, "Order Confirmed: #ORD-999");
    assert.strictEqual(payload.android.priority, "high");
    assert.strictEqual(payload.android.notification.channelId, "shopease_high_importance");
    assert.strictEqual(payload.android.notification.imageUrl, "https://shopease.app/images/sample.jpg");
    assert.strictEqual(payload.webpush.headers.Urgency, "high");
    assert.strictEqual(payload.webpush.notification.tag, "conf_order_ORD-999");
    assert.strictEqual(payload.data.click_action, "FLUTTER_NOTIFICATION_CLICK");

    console.log("  ✓ Test 2 Passed: Android & Web push payload structure verified.\n");
  }

  // ── Test 3: Atomic Claim & Duplicate Prevention ──────────────────────────────
  {
    console.log("Test 3: Atomic claim mechanism and concurrency / duplicate prevention...");

    // Mock document with initial queued status
    let docData = {
      status: "queued",
      attemptCount: 0,
      createdAt: { toMillis: () => 1700000000000 },
    };
    let updateRecord = {};

    const mockDocRef = {
      id: "req_test_atomic_1",
      get: async () => ({ exists: true, data: () => docData }),
      update: async (patch) => {
        updateRecord = { ...updateRecord, ...patch };
        docData = { ...docData, ...patch };
      },
    };

    const mockDb = {
      runTransaction: async (fn) => {
        const mockTransaction = {
          get: async (ref) => await ref.get(),
          update: (ref, patch) => {
            updateRecord = { ...updateRecord, ...patch };
            docData = { ...docData, ...patch };
          },
        };
        return await fn(mockTransaction);
      },
    };

    // 1st Worker claims queued request
    const claim1 = await claimRequest(mockDb, mockDocRef);
    assert.strictEqual(claim1.claimed, true);
    assert.strictEqual(claim1.data.status, "processing");
    assert.strictEqual(claim1.data.attemptCount, 1);
    assert.strictEqual(updateRecord.status, "processing");

    // 2nd Concurrent Worker tries to claim the same request while status is 'processing'
    const claim2 = await claimRequest(mockDb, mockDocRef);
    assert.strictEqual(claim2.claimed, false);
    assert.strictEqual(claim2.reason, "status_is_processing");

    // 3rd Worker tries to claim when status has transitioned to 'sent'
    docData.status = "sent";
    const claim3 = await claimRequest(mockDb, mockDocRef);
    assert.strictEqual(claim3.claimed, false);
    assert.strictEqual(claim3.reason, "status_is_sent");

    console.log("  ✓ Test 3 Passed: Atomic claiming prevents concurrent workers from duplicate processing.\n");
  }

  // ── Test 4: Max Retry Attempt & Toxic Request Safety ─────────────────────────
  {
    console.log("Test 4: Retry limits and toxic payload protection...");

    let toxicDocData = {
      status: "queued",
      attemptCount: 5, // Already reached max 5 attempts
    };
    let toxicUpdate = {};

    const mockToxicDocRef = {
      id: "req_toxic_1",
      get: async () => ({ exists: true, data: () => toxicDocData }),
      update: async (patch) => {
        toxicUpdate = { ...toxicUpdate, ...patch };
        toxicDocData = { ...toxicDocData, ...patch };
      },
    };

    const mockDb = {
      runTransaction: async (fn) => {
        const mockTransaction = {
          get: async (ref) => await ref.get(),
          update: (ref, patch) => {
            toxicUpdate = { ...toxicUpdate, ...patch };
            toxicDocData = { ...toxicDocData, ...patch };
          },
        };
        return await fn(mockTransaction);
      },
    };

    const claim = await claimRequest(mockDb, mockToxicDocRef, 5);
    assert.strictEqual(claim.claimed, false);
    assert.strictEqual(claim.reason, "max_attempts_exceeded");
    assert.strictEqual(toxicUpdate.status, "failed");
    assert.ok(toxicUpdate.errorMessage.includes("Max retry attempts reached"));

    console.log("  ✓ Test 4 Passed: Repeatedly failing requests are safely abandoned to prevent infinite retry loops.\n");
  }

  // ── Test 5: Empty Token Handling ────────────────────────────────────────────
  {
    console.log("Test 5: Empty token handling when recipient has no registered devices...");

    let finalizedPayload = null;
    const mockDocRef = {
      id: "req_no_tokens_1",
      update: async (patch) => {
        finalizedPayload = patch;
      },
    };

    const result = await finalizeRequestResult(mockDocRef, {
      tokens: [],
      requestId: "req_no_tokens_1",
      attemptCount: 1,
      noTokensReason: "No active FCM tokens registered for customer cust_123",
    });

    assert.strictEqual(result.success, false);
    assert.strictEqual(finalizedPayload.status, "failed");
    assert.strictEqual(finalizedPayload.successCount, 0);
    assert.strictEqual(finalizedPayload.failureCount, 0);
    assert.strictEqual(finalizedPayload.totalTokens, 0);
    assert.strictEqual(finalizedPayload.fcmResponse, "no_active_tokens_registered");

    console.log("  ✓ Test 5 Passed: Requests with 0 active tokens transition cleanly to failed status.\n");
  }

  // ── Test 6: 100% Successful FCM Dispatch ────────────────────────────────────
  {
    console.log("Test 6: Successful FCM dispatch and telemetry recording...");

    let finalizedPayload = null;
    const mockDocRef = {
      id: "req_success_1",
      update: async (patch) => {
        finalizedPayload = patch;
      },
    };

    const mockTokens = ["tok_android_active", "tok_web_active"];
    const mockFcmResponse = {
      successCount: 2,
      failureCount: 0,
      responses: [
        { success: true, messageId: "projects/shopease/messages/msg_1" },
        { success: true, messageId: "projects/shopease/messages/msg_2" },
      ],
    };

    const result = await finalizeRequestResult(mockDocRef, {
      tokens: mockTokens,
      response: mockFcmResponse,
      requestId: "req_success_1",
      attemptCount: 1,
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(finalizedPayload.status, "sent");
    assert.strictEqual(finalizedPayload.successCount, 2);
    assert.strictEqual(finalizedPayload.failureCount, 0);
    assert.strictEqual(finalizedPayload.totalTokens, 2);
    assert.deepStrictEqual(finalizedPayload.messageIds, [
      "projects/shopease/messages/msg_1",
      "projects/shopease/messages/msg_2",
    ]);
    assert.ok(finalizedPayload.sentAt !== undefined);

    console.log("  ✓ Test 6 Passed: Successful dispatch properly sets status 'sent' with message IDs.\n");
  }

  // ── Test 7: Partial FCM Failure & Token Invalidation ────────────────────────
  {
    console.log("Test 7: Partial FCM failure and invalid token cleanup...");

    let tokenInvalidated = false;
    let invalidatedPayload = null;

    const mockDeviceRef = {
      update: async (patch) => {
        tokenInvalidated = true;
        invalidatedPayload = patch;
      },
    };

    const mockBatch = {
      update: (ref, patch) => {
        tokenInvalidated = true;
        invalidatedPayload = patch;
      },
      commit: async () => {},
    };

    const mockDb = {
      batch: () => mockBatch,
    };

    const tokens = ["tok_valid", "tok_unregistered"];
    const deviceRefs = [null, mockDeviceRef];
    const mockFcmResponse = {
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true, messageId: "msg_valid_1" },
        {
          success: false,
          error: {
            code: "messaging/registration-token-not-registered",
            message: "The registration token is not registered.",
          },
        },
      ],
    };

    const cleanupCount = await cleanupInvalidTokens(
      mockDb,
      "cust_456",
      tokens,
      deviceRefs,
      mockFcmResponse
    );

    assert.strictEqual(cleanupCount, 1);
    assert.strictEqual(tokenInvalidated, true);
    assert.strictEqual(invalidatedPayload.isActive, false);
    assert.strictEqual(invalidatedPayload.invalidationReason, "unregistered_token");

    // Finalize request
    let finalizedPayload = null;
    const mockDocRef = {
      id: "req_partial_1",
      update: async (patch) => {
        finalizedPayload = patch;
      },
    };

    const result = await finalizeRequestResult(mockDocRef, {
      tokens,
      response: mockFcmResponse,
      requestId: "req_partial_1",
      attemptCount: 1,
    });

    // Since successCount > 0, status is considered sent
    assert.strictEqual(result.success, true);
    assert.strictEqual(finalizedPayload.status, "sent");
    assert.strictEqual(finalizedPayload.successCount, 1);
    assert.strictEqual(finalizedPayload.failureCount, 1);

    console.log("  ✓ Test 7 Passed: Invalid tokens deactivated and partial delivery recorded.\n");
  }

  // ── Test 8: Complete FCM Failure ────────────────────────────────────────────
  {
    console.log("Test 8: Complete FCM failure handling...");

    let finalizedPayload = null;
    const mockDocRef = {
      id: "req_all_failed_1",
      update: async (patch) => {
        finalizedPayload = patch;
      },
    };

    const tokens = ["tok_1", "tok_2"];
    const mockFcmResponse = {
      successCount: 0,
      failureCount: 2,
      responses: [
        { success: false, error: { code: "messaging/server-unavailable", message: "FCM unavailable" } },
        { success: false, error: { code: "messaging/server-unavailable", message: "FCM unavailable" } },
      ],
    };

    const result = await finalizeRequestResult(mockDocRef, {
      tokens,
      response: mockFcmResponse,
      requestId: "req_all_failed_1",
      attemptCount: 1,
    });

    assert.strictEqual(result.success, false);
    assert.strictEqual(finalizedPayload.status, "failed");
    assert.strictEqual(finalizedPayload.successCount, 0);
    assert.strictEqual(finalizedPayload.failureCount, 2);
    assert.strictEqual(finalizedPayload.errorMessage, "FCM unavailable");

    console.log("  ✓ Test 8 Passed: Complete FCM failure transitions status to 'failed'.\n");
  }

  // ── Test 9: End-to-End Batch Queue Processing ───────────────────────────────
  {
    console.log("Test 9: End-to-end batch processing with mixed queue scenarios...");

    // Create 4 mock requests:
    // 1. Order confirmation (should succeed)
    // 2. Order status update (should succeed)
    // 3. Request for user with 0 tokens (should fail)
    // 4. Request already in 'processing' (should be skipped)

    const requests = [
      {
        id: "req_batch_1",
        data: {
          action: "customer_order_confirmation",
          customerUid: "cust_valid_1",
          orderId: "ORD-101",
          status: "queued",
          createdAt: { toMillis: () => 1000 },
        },
      },
      {
        id: "req_batch_2",
        data: {
          action: "order_status_update",
          customerUid: "cust_valid_2",
          orderId: "ORD-102",
          newStatus: "shipped",
          newStatusLabel: "Shipped",
          status: "queued",
          createdAt: { toMillis: () => 2000 },
        },
      },
      {
        id: "req_batch_3",
        data: {
          action: "customer_order_confirmation",
          customerUid: "cust_no_devices",
          orderId: "ORD-103",
          status: "queued",
          createdAt: { toMillis: () => 3000 },
        },
      },
      {
        id: "req_batch_4",
        data: {
          action: "customer_order_confirmation",
          customerUid: "cust_valid_1",
          orderId: "ORD-104",
          status: "processing", // Already being processed
          createdAt: { toMillis: () => 4000 },
        },
      },
    ];

    const mockDocs = requests.map((req) => {
      let currentData = { ...req.data };
      return {
        id: req.id,
        ref: {
          id: req.id,
          get: async () => ({ exists: true, data: () => currentData }),
          update: async (patch) => {
            currentData = { ...currentData, ...patch };
          },
        },
        data: () => currentData,
      };
    });

    const mockDb = {
      collection: (name) => {
        if (name === "notification_requests") {
          return {
            where: () => ({
              limit: () => ({
                get: async () => ({
                  empty: false,
                  docs: mockDocs,
                }),
              }),
            }),
          };
        }
        if (name === "customers") {
          return {
            doc: (uid) => ({
              collection: (subName) => ({
                where: () => ({
                  get: async () => {
                    if (uid === "cust_no_devices") {
                      return { docs: [] };
                    }
                    return {
                      docs: [
                        {
                          id: `dev_${uid}`,
                          ref: { update: async () => {} },
                          data: () => ({
                            token: `fcm_token_${uid}`,
                            isActive: true,
                            platform: "android",
                          }),
                        },
                      ],
                    };
                  },
                }),
              }),
            }),
          };
        }
        return { doc: () => ({ collection: () => ({ where: () => ({ get: async () => ({ docs: [] }) }) }) }) };
      },
      runTransaction: async (fn) => {
        const mockTransaction = {
          get: async (ref) => await ref.get(),
          update: (ref, patch) => {
            ref.update(patch);
          },
        };
        return await fn(mockTransaction);
      },
      batch: () => ({
        update: () => {},
        commit: async () => {},
      }),
    };

    const mockMessaging = {
      sendEachForMulticast: async (payload) => ({
        successCount: payload.tokens.length,
        failureCount: 0,
        responses: payload.tokens.map((_, i) => ({
          success: true,
          messageId: `mock_msg_${i}`,
        })),
      }),
    };

    const summary = await processQueuedRequests({
      db: mockDb,
      messaging: mockMessaging,
      limit: 50,
      dryRun: false,
    });

    assert.strictEqual(summary.total, 4);
    assert.strictEqual(summary.sent, 2); // req_batch_1 and req_batch_2
    assert.strictEqual(summary.failed, 1); // req_batch_3 (no devices)
    assert.strictEqual(summary.skipped, 1); // req_batch_4 (already processing)

    console.log("  ✓ Test 9 Passed: End-to-end batch processing dispatched, failed, and skipped correctly.\n");
  }

  console.log("==================================================================");
  console.log("  All 9 Standalone FCM Worker Tests PASSED Successfully (100%)");
  console.log("==================================================================\n");
}

if (require.main === module) {
  runWorkerTests().catch((err) => {
    console.error("Test execution failed:", err);
    process.exit(1);
  });
}

module.exports = { runWorkerTests };

