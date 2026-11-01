# ShopEase Firebase Cloud Functions - Push Dispatch Worker

This directory contains the Firebase Cloud Function responsible for processing `/notification_requests/{requestId}` and delivering push notifications through the Firebase Admin SDK to authenticated customer and admin devices.

## Architecture

1. **Trigger**: `onDocumentCreated("notification_requests/{requestId}")`
2. **Security**:
   - Runs in Google Cloud trusted environment using Application Default Credentials (ADC).
   - Zero private keys, service account JSON files, or secrets are bundled in the Flutter client code.
   - Bypasses Firestore rules securely from the backend to read customer tokens and update dispatch status.
3. **Idempotency & Duplicate Prevention**:
   - Atomic status lock: If a document is already `processing` or `processed`, the worker safely ignores it.
4. **Token Management & Health**:
   - Queries `/customers/{uid}/devices` where `isActive == true`.
   - Sends notifications using `admin.messaging().sendEachForMulticast()`.
   - Automatically marks expired or unregistered tokens (`messaging/registration-token-not-registered`) as `isActive: false` to keep the registry clean.
5. **Audience Support**:
   - `customer_order_confirmation`: Direct to ordering customer devices.
   - `order_status_update`: Direct to customer on fulfillment transitions.
   - `admin_new_order_alert`: Broadcast to all users with `role: 'admin'`.
   - `admin_broadcast`: Broadcast to all registered devices or specific selected customer.

## Deployment Instructions

To deploy these functions to your Firebase project:

```bash
# 1. Install dependencies
cd functions
npm install

# 2. Deploy to Firebase
firebase deploy --only functions
```

