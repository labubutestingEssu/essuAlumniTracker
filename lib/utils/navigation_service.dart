import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    if (kIsWeb) {
      // For web, use pushNamed to enable browser back button functionality
      return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
    } else {
      // For mobile, use pushReplacementNamed to prevent stack buildup
      return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
    }
  }

  static void goBack() {
    if (navigatorKey.currentState!.canPop()) {
      navigatorKey.currentState!.pop();
    }
  }

  static Future<dynamic> navigateToWithReplacement(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }

  static void popUntilHome() {
    navigatorKey.currentState!.popUntil((route) => route.isFirst);
  }
} 