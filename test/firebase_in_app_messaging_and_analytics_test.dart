import 'package:flutter_test/flutter_test.dart';
import 'package:shopease/services/analytics_service.dart';
import 'package:shopease/services/in_app_messaging_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Analytics Service Tests', () {
    test('AnalyticsService initializes gracefully without crashing', () async {
      await expectLater(AnalyticsService.initialize(), completes);
    });

    test('AnalyticsService logs standard and e-commerce events safely', () async {
      await expectLater(AnalyticsService.logAppOpen(), completes);

      await expectLater(
        AnalyticsService.logEvent(
          name: 'beauty_sale_trigger',
          parameters: {'campaign': 'Beauty Sale Is Here!'},
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logScreenView(screenName: 'CustomerHome'),
        completes,
      );

      await expectLater(
        AnalyticsService.logViewItem(
          itemId: 'p1',
          itemName: 'Yara Rose Perfume',
          itemCategory: 'Perfumes',
          price: 49.99,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logAddToCart(
          itemId: 'p1',
          itemName: 'Yara Rose Perfume',
          price: 49.99,
          quantity: 2,
        ),
        completes,
      );

      await expectLater(
        AnalyticsService.logPurchase(
          orderId: 'ord_123',
          value: 99.98,
          itemCount: 2,
        ),
        completes,
      );
    });

    test('AnalyticsService sets user properties and identifiers safely', () async {
      await expectLater(AnalyticsService.setUserId('cust_test_123'), completes);
      await expectLater(
        AnalyticsService.setUserProperty(name: 'role', value: 'customer'),
        completes,
      );
      await expectLater(AnalyticsService.setUserId(null), completes);
    });
  });

  group('Firebase In-App Messaging Service Tests', () {
    test('InAppMessagingService initializes safely', () async {
      await expectLater(InAppMessagingService.initialize(), completes);
    });

    test('InAppMessagingService triggers events and campaigns safely', () async {
      await expectLater(
        InAppMessagingService.triggerEvent('on_foreground'),
        completes,
      );

      await expectLater(
        InAppMessagingService.triggerBeautySaleCampaign(),
        completes,
      );
    });

    test('InAppMessagingService manages suppression states for admin and customer views', () async {
      // Suppress when in admin view
      await expectLater(
        InAppMessagingService.setMessagesSuppressed(true),
        completes,
      );

      // Un-suppress when returning to customer store
      await expectLater(
        InAppMessagingService.setMessagesSuppressed(false),
        completes,
      );
    });
  });
}

