# ShopEase – AÈRA Luxury Cosmetics & Fragrances

A cross-platform e-commerce and store administration application built with **Flutter**, **Firebase Cloud Firestore**, and **Firebase Authentication**, featuring an **AÈRA Luxury Cosmetics** design language (Wine Red `#8A4652`, Champagne Gold `#C8A87D`, and Soft Warm Ivory `#FAF5F0`).

---

## Architecture & Technology Stack

* **Frontend Framework**: Flutter (Android & Web)
* **State Management**: Provider
* **Architecture Pattern**: MVC + Repository Pattern
* **Backend Services**:
  * **Firebase Authentication**: Email/password authentication with role-based routing (`customer` vs. `admin`)
  * **Cloud Firestore**: Real-time cross-customer isolation, order management, audit histories, and catalog collections
  * **Firebase Storage**: Product photography and media assets
  * **Firebase Cloud Messaging (FCM)**: Push notification dispatching via scheduled GitHub Actions worker

---

## Core Features

### Customer Experience
* **Curated Catalog**: Search and filter luxury beauty items by collection, notes, and pricing.
* **Product Details**: High-resolution photography, fragrance volume selector, accord breakdown, and stock validation.
* **Bag & Checkout**: Real-time quantity adjustments, subtotal/tax calculation, and address fulfillment forms.
* **Order Tracking**: Visual status progression (`placed` → `processing` → `shipped` → `delivered`), courier tracking details, and order history.
* **Customer Profile**: Profile management, order records, and saved favorites.

### Store Administration
* **Executive Analytics**: Real-time KPI ribbons (Gross Revenue, Total Orders, Active Customers, Catalog Inventory).
* **Catalog Management**: Add, update, and manage beauty merchandise specifications, stock adjustments, and visibility.
* **Fulfillment Operations**: Cross-customer order directory, historical item price snapshots, status transitions, and audit records.
* **Customer Directory**: Customer profiles, purchase metrics, and lifetime value tracking.
* **Notification Center**: Role-targeted broadcast notifications and automated order update dispatching.

---

## Project Structure

```text
lib/
├── controllers/          # Business logic and ChangeNotifier controllers
│   ├── admin_customer_controller.dart
│   ├── admin_order_controller.dart
│   ├── admin_product_controller.dart
│   ├── auth_controller.dart
│   ├── cart_controller.dart
│   ├── home_controller.dart
│   ├── notification_controller.dart
│   └── order_controller.dart
├── core/                 # Shared utilities, constants, theme, and routing
│   ├── constants/
│   ├── routes/
│   ├── theme/
│   └── utils/
├── models/               # Domain data models with serialization
│   ├── category_model.dart
│   ├── customer_model.dart
│   ├── order_model.dart
│   └── product_model.dart
├── repositories/         # Firestore and local data abstraction layer
│   ├── admin_order_repository.dart
│   ├── cart_repository.dart
│   ├── customer_repository.dart
│   ├── notification_repository.dart
│   ├── order_repository.dart
│   └── product_repository.dart
├── services/             # Firebase integration & platform services
│   ├── analytics_service.dart
│   ├── in_app_messaging_service.dart
│   ├── notification_service.dart
│   ├── product_image_storage_service.dart
│   └── push_dispatch_service.dart
├── views/                # Presentation layer (Admin & Customer modules)
│   ├── admin/
│   ├── auth/
│   ├── customer/
│   └── splash/
└── widgets/              # Reusable luxury UI components
    └── luxury_ui_components.dart
```

---

## Getting Started

### Prerequisites
* Flutter SDK (3.x or higher)
* Dart SDK (3.x or higher)
* Android Studio / Xcode (optional for mobile builds)
* Google Chrome (for web development)

### Setup & Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/mariyavarghese084/ShopEase.git
   cd ShopEase/shopease
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the static code analysis**:
   ```bash
   flutter analyze
   ```

4. **Execute automated test suite**:
   ```bash
   flutter test
   ```

5. **Run the application**:
   ```bash
   # Run on Chrome
   flutter run -d chrome

   # Run on Android device / emulator
   flutter run -d android
   ```

6. **Build release packages**:
   ```bash
   # Flutter Web
   flutter build web

   # Android Debug APK
   flutter build apk --debug
   ```

---

## Security & Best Practices

* **Role-Based Access Control**: Strict `AdminGuard` protecting administrative modules from unauthenticated or non-admin users.
* **Environment Credentials**: Sensitive credentials, service accounts, and private keys are never committed; automated background dispatching uses GitHub Repository Secrets.
* **Data Sanitization**: Price calculations, quantity bounds, and stock adjustments validate server-side rules and constraints.
