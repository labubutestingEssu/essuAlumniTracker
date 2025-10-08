import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

abstract class WebNavigationHandler {
  void updateUrl(String path);
}

class WebNavigationHandlerImpl implements WebNavigationHandler {
  @override
  void updateUrl(String path) {
    // This will be overridden in the web implementation
  }
}

// Base navigation observer that works for all platforms
class BaseNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
  }
}

// Custom observer for web navigation
class WebNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (kIsWeb && route.settings.name != null) {
      // URL updates will be handled by the browser
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (kIsWeb && previousRoute?.settings.name != null) {
      // URL updates will be handled by the browser
    }
  }
} 