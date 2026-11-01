import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Centralized service managing Firebase In-App Messaging (FIAM).
///
/// FIAM displays contextual, rich popups and modals (e.g. "Beauty Sale Is Here!")
/// directly inside the mobile application triggered by app foregrounding or
/// custom analytics events.
///
/// Note: Firebase In-App Messaging is supported by Google exclusively on
/// Android and iOS. On Web and Desktop platforms, operations are safely bypassed.
class InAppMessagingService {
  InAppMessagingService._();

  static FirebaseInAppMessaging? _fiamInstance;
  static bool _messagesSuppressed = false;

  /// Whether Firebase In-App Messaging is supported on the current platform.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns the configured [FirebaseInAppMessaging] instance if supported.
  static FirebaseInAppMessaging? get instance {
    if (!isSupported) return null;
    if (_fiamInstance != null) return _fiamInstance;
    if (FirebaseService.isInitialized) {
      try {
        _fiamInstance = FirebaseInAppMessaging.instance;
      } catch (e) {
        debugPrint('[InAppMessagingService] Notice initializing FIAM: $e');
      }
    }
    return _fiamInstance;
  }

  /// Initializes In-App Messaging and enables data collection on supported platforms.
  static Future<void> initialize() async {
    if (!isSupported) {
      debugPrint(
        '[InAppMessagingService] Web/Desktop platform detected: '
        'Firebase In-App Messaging is only supported on Android and iOS.',
      );
      return;
    }

    final fiam = instance;
    if (fiam == null) {
      debugPrint('[InAppMessagingService] Firebase not initialized or FIAM unavailable');
      return;
    }

    try {
      await fiam.setAutomaticDataCollectionEnabled(true);
      await fiam.setMessagesSuppressed(false);
      _messagesSuppressed = false;
      debugPrint('[InAppMessagingService] Initialized successfully. Automatic collection enabled.');
    } catch (e) {
      debugPrint('[InAppMessagingService] Error initializing FIAM: $e');
    }
  }

  /// Triggers a programmatic in-app messaging event configured in the Firebase Console.
  ///
  /// For instance, if the campaign trigger is set to 'beauty_sale' or 'app_open',
  /// invoking [triggerEvent] prompts the FIAM client to evaluate and render matching messages.
  static Future<void> triggerEvent(String eventName) async {
    if (!isSupported) {
      debugPrint('[InAppMessagingService] triggerEvent("$eventName") skipped: not supported on Web');
      return;
    }

    final fiam = instance;
    if (fiam == null) return;

    try {
      await fiam.triggerEvent(eventName);
      debugPrint('[InAppMessagingService] Successfully triggered FIAM event: $eventName');
    } catch (e) {
      debugPrint('[InAppMessagingService] Error triggering FIAM event $eventName: $e');
    }
  }

  /// Suppresses or un-suppresses in-app messages.
  ///
  /// Useful for suppressing promotional popups during sensitive flows such as:
  /// - Admin dashboard navigation (to keep admin workspace distraction-free).
  /// - Checkout / Payment processing.
  static Future<void> setMessagesSuppressed(bool suppress) async {
    if (!isSupported) return;
    final fiam = instance;
    if (fiam == null) return;

    if (_messagesSuppressed == suppress) return;

    try {
      await fiam.setMessagesSuppressed(suppress);
      _messagesSuppressed = suppress;
      debugPrint('[InAppMessagingService] In-app messages suppressed: $suppress');
    } catch (e) {
      debugPrint('[InAppMessagingService] Error setting messages suppressed: $e');
    }
  }

  /// Dedicated trigger for the "Beauty Sale Is Here!" campaign.
  ///
  /// Fires both standard triggers: 'beauty_sale_trigger' and 'on_foreground'.
  static Future<void> triggerBeautySaleCampaign() async {
    await triggerEvent('beauty_sale');
    await triggerEvent('beauty_sale_trigger');
  }
}

