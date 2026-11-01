import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import 'analytics_service.dart';
import 'in_app_messaging_service.dart';

/// Centralized service handling Firebase initialization and access.
class FirebaseService {
  FirebaseService._();

  static bool _isInitialized = false;
  static String? _initializationError;

  static bool get isInitialized => _isInitialized || Firebase.apps.isNotEmpty;
  static String? get initializationError => _initializationError;

  /// Returns the default [FirebaseAuth] instance.
  static FirebaseAuth get auth => FirebaseAuth.instance;

  /// Returns the default [FirebaseFirestore] instance.
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Initializes Firebase with platform-specific options before app startup.
  ///
  /// Initializes Analytics and In-App Messaging services synchronously
  /// so that event tracking and campaign hooks are available on first frame.
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _isInitialized = true;
      if (kDebugMode) {
        print('[FirebaseService] Successfully initialized Firebase Core');
      }

      // Initialize Analytics and In-App Messaging
      await AnalyticsService.initialize();
      await InAppMessagingService.initialize();
    } catch (e) {
      _isInitialized = false;
      _initializationError = e.toString();
      if (kDebugMode) {
        print('[FirebaseService] Firebase initialization notice: $e');
      }
    }
  }
}
