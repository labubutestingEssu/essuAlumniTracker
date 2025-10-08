import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_role.dart';

class RoleBasedWidget extends StatelessWidget {
  final Widget adminWidget;
  final Widget alumniWidget;
  final Widget? loadingWidget;

  const RoleBasedWidget({
    super.key,
    required this.adminWidget,
    required this.alumniWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return FutureBuilder<UserRole>(
      future: authService.getCurrentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == UserRole.admin) {
          return adminWidget;
        }

        return alumniWidget;
      },
    );
  }
}

// Usage example:
// RoleBasedWidget(
//   adminWidget: AdminDashboard(),
//   alumniWidget: AlumniDashboard(),
// ) 