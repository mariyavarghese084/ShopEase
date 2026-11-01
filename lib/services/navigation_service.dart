import 'package:flutter/material.dart';

/// Global navigation service for programmatic routing when a BuildContext is unavailable.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static BuildContext? get currentContext => navigatorKey.currentContext;

  static Future<T?>? navigateTo<T extends Object?>(String routeName, {Object? arguments}) =>
      navigatorKey.currentState?.pushNamed<T>(routeName, arguments: arguments);

  static void goBack<T extends Object?>([T? result]) =>
      navigatorKey.currentState?.pop<T>(result);
}
