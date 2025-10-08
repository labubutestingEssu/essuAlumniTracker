import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'app_drawer.dart';

/// A wrapper for all screens to provide consistent responsive behavior.
/// This ensures the app drawer is consistently applied across the application.
class ResponsiveScreenWrapper extends StatelessWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;
  final Color? backgroundColor;
  final PreferredSizeWidget? customAppBar;

  const ResponsiveScreenWrapper({
    Key? key,
    required this.body,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.backgroundColor,
    this.customAppBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // final bool isDesktop = Responsive.isDesktop(context);
    // final bool isTablet = Responsive.isTablet(context);
    final bool isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: customAppBar ?? AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: isMobile ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
        actions: actions,
      ),
      drawer: isMobile ? const AppDrawer() : null,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show drawer as a fixed side panel on tablet and desktop
          if (!isMobile) const SizedBox(width: 240, child: AppDrawer()),
          // Main content area
          Expanded(
            child: body,
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
} 