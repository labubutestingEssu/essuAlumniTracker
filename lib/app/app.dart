import 'package:flutter/material.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../utils/navigation_service.dart';
import '../utils/web_navigation.dart';
import 'package:flutter/foundation.dart';

class AlumniTrackerApp extends StatelessWidget {
  const AlumniTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final List<NavigatorObserver> observers = [
      if (kIsWeb) WebNavigatorObserver(WebNavigationHandlerImpl()),
    ];

    return MaterialApp(
      title: 'ESSU Alumni Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      navigatorKey: NavigationService.navigatorKey,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.getRoutes(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: observers,
    );
  }
}

// Custom observer for web navigation
class WebNavigatorObserver extends NavigatorObserver {
  final WebNavigationHandler handler;

  WebNavigatorObserver(this.handler);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kIsWeb && route.settings.name != null) {
      // Update browser URL
      final path = route.settings.name!;
      if (path != '/') {
        handler.updateUrl(path);
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kIsWeb && previousRoute?.settings.name != null) {
      // Update browser URL when popping
      final path = previousRoute!.settings.name!;
      handler.updateUrl(path == '/' ? '' : path);
    }
  }
}

