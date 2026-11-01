import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Centralized service managing Google Analytics for Firebase.
///
/// Records user engagement, e-commerce milestones, and screen transitions
/// required by Firebase In-App Messaging for campaign trigger evaluation.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics? _analyticsInstance;
  static FirebaseAnalyticsObserver? _observer;

  /// Returns the configured [FirebaseAnalytics] instance if available.
  static FirebaseAnalytics? get instance {
    if (_analyticsInstance != null) return _analyticsInstance;
    if (FirebaseService.isInitialized) {
      try {
        _analyticsInstance = FirebaseAnalytics.instance;
      } catch (e) {
        debugPrint('[AnalyticsService] Notice initializing FirebaseAnalytics: $e');
      }
    }
    return _analyticsInstance;
  }

  /// Navigation observer for automatic screen view tracking in [MaterialApp].
  static FirebaseAnalyticsObserver? get observer {
    if (_observer != null) return _observer;
    final analytics = instance;
    if (analytics != null) {
      _observer = FirebaseAnalyticsObserver(analytics: analytics);
    }
    return _observer;
  }

  /// Initializes analytics and logs the initial app open event.
  static Future<void> initialize() async {
    final analytics = instance;
    if (analytics == null) {
      debugPrint('[AnalyticsService] Offline/Mock: Analytics initialized in mock mode');
      return;
    }

    try {
      await analytics.setAnalyticsCollectionEnabled(true);
      await logAppOpen();
      debugPrint('[AnalyticsService] Firebase Analytics initialized successfully');
    } catch (e) {
      debugPrint('[AnalyticsService] Error initializing analytics collection: $e');
    }
  }

  /// Logs standard `app_open` event.
  static Future<void> logAppOpen() async {
    try {
      await instance?.logAppOpen();
      debugPrint('[AnalyticsService] Logged app_open event');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging app_open: $e');
    }
  }

  /// Logs a custom named event with optional contextual parameters.
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await instance?.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('[AnalyticsService] Logged event: $name params: $parameters');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging event $name: $e');
    }
  }

  /// Logs a screen view transition.
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await instance?.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
      debugPrint('[AnalyticsService] Logged screen_view: $screenName');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging screen_view $screenName: $e');
    }
  }

  /// Sets or clears the current user ID for audience segmentation.
  static Future<void> setUserId(String? userId) async {
    try {
      await instance?.setUserId(id: userId);
      debugPrint('[AnalyticsService] Updated analytics userId: $userId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting analytics userId: $e');
    }
  }

  /// Sets user properties (e.g. role: 'admin' | 'customer').
  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await instance?.setUserProperty(name: name, value: value);
      debugPrint('[AnalyticsService] Set user property: $name=$value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting user property: $e');
    }
  }

  /// Logs an e-commerce item view.
  static Future<void> logViewItem({
    required String itemId,
    required String itemName,
    String? itemCategory,
    double? price,
  }) async {
    try {
      await instance?.logViewItem(
        currency: 'USD',
        value: price,
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemName: itemName,
            itemCategory: itemCategory,
            price: price,
          ),
        ],
      );
      debugPrint('[AnalyticsService] Logged view_item: $itemId ($itemName)');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging view_item: $e');
    }
  }

  /// Logs an item added to shopping cart.
  static Future<void> logAddToCart({
    required String itemId,
    required String itemName,
    String? itemCategory,
    double? price,
    int quantity = 1,
  }) async {
    try {
      await instance?.logAddToCart(
        currency: 'USD',
        value: (price ?? 0) * quantity,
        items: [
          AnalyticsEventItem(
            itemId: itemId,
            itemName: itemName,
            itemCategory: itemCategory,
            price: price,
            quantity: quantity,
          ),
        ],
      );
      debugPrint('[AnalyticsService] Logged add_to_cart: $itemId x$quantity');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging add_to_cart: $e');
    }
  }

  /// Logs beginning of checkout flow.
  static Future<void> logBeginCheckout({
    required double value,
    required int itemCount,
  }) async {
    try {
      await instance?.logBeginCheckout(
        currency: 'USD',
        value: value,
      );
      debugPrint('[AnalyticsService] Logged begin_checkout: value=$value items=$itemCount');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging begin_checkout: $e');
    }
  }

  /// Logs successful order placement.
  static Future<void> logPurchase({
    required String orderId,
    required double value,
    required int itemCount,
  }) async {
    try {
      await instance?.logPurchase(
        currency: 'USD',
        transactionId: orderId,
        value: value,
      );
      debugPrint('[AnalyticsService] Logged purchase: orderId=$orderId value=$value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging purchase: $e');
    }
  }
}

