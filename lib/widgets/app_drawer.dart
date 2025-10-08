import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/responsive.dart';
import '../../models/user_role.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final AuthService _authService = AuthService();
  UserRole? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getCurrentUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    }
  }

  void _navigateTo(BuildContext context, String route) {
    if (Responsive.isMobile(context)) {
      Navigator.pop(context); // Close drawer on mobile
    }
    NavigationService.navigateTo(route);
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _authService.signOut();
      if (context.mounted) {
        NavigationService.navigateToWithReplacement(AppRoutes.login);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDrawerHeader(BuildContext context, bool isDesktop) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.school,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ESSU Alumni',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Eastern Samar State University',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required BuildContext context,
    bool isActive = false,
    bool isImplemented = true,
    bool isNew = false,
    bool isAdminOnly = false,
  }) {
    final isDesktop = Responsive.isDesktop(context);
    final isAdmin = _userRole?.isAdmin ?? false;
    
    // Skip admin-only items for non-admin users
    if (isAdminOnly && !isAdmin) {
      return const SizedBox.shrink();
    }
    
    return ListTile(
      leading: Icon(
        icon,
        size: isDesktop ? 22 : 24,
        color: isActive 
            ? Theme.of(context).primaryColor 
            : !isImplemented 
                ? Colors.grey 
                : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive 
                    ? Theme.of(context).primaryColor 
                    : !isImplemented 
                        ? Colors.grey 
                        : null,
              ),
            ),
          ),
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: onTap,
      dense: isDesktop,
      enabled: isImplemented,
      visualDensity: isDesktop 
          ? const VisualDensity(horizontal: -4, vertical: -2)
          : const VisualDensity(horizontal: -4, vertical: -1),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 20,
        vertical: isDesktop ? 4 : 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isAdmin = _userRole?.isAdmin ?? false;
    final isSuperAdmin = _userRole == UserRole.super_admin;

    if (_isLoading) {
      return const Drawer(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Drawer(
      elevation: isDesktop ? 0 : 2,
      shape: isDesktop ? const RoundedRectangleBorder() : null,
      child: Column(
        children: [
          _buildDrawerHeader(context, isDesktop),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person_outline,
                  title: 'Profile',
                  onTap: () => _navigateTo(context, AppRoutes.profile),
                  context: context,
                  isActive: currentRoute == AppRoutes.profile,
                  isImplemented: true,
                ),
                _buildDrawerItem(
                  icon: Icons.people_outline,
                  title: 'Alumni Directory',
                  onTap: () => _navigateTo(context, AppRoutes.alumniDirectory),
                  context: context,
                  isActive: currentRoute == AppRoutes.alumniDirectory,
                  isImplemented: true,
                ),
                if (isAdmin) ...[
                  _buildDrawerItem(
                    icon: Icons.person_add_outlined,
                    title: 'Create User Account',
                    onTap: () => _navigateTo(context, AppRoutes.createAlumniAccount),
                    context: context,
                    isActive: currentRoute == AppRoutes.createAlumniAccount,
                    isImplemented: true,
                    isAdminOnly: true,
                  ),
                  // _buildDrawerItem(
                  //   icon: Icons.settings_system_daydream_outlined,
                  //   title: 'System Initialization',
                  //   onTap: () => _navigateTo(context, AppRoutes.systemInitialization),
                  //   context: context,
                  //   isActive: currentRoute == AppRoutes.systemInitialization,
                  //   isImplemented: true,
                  //   isAdminOnly: true,
                  // ),
                ],
                // Survey Question Management - Only for Admins
                if (isSuperAdmin) ...[
                  _buildDrawerItem(
                    icon: Icons.quiz_outlined,
                    title: 'Manage Survey Questions',
                    onTap: () => _navigateTo(context, AppRoutes.surveyQuestionManagement),
                    context: context,
                    isActive: currentRoute == AppRoutes.surveyQuestionManagement,
                    isImplemented: true,
                    isAdminOnly: true,
                  ),
                ],
                // Other admin features (available to all admins)
                if (isAdmin) ...[
                  _buildDrawerItem(
                    icon: Icons.assessment_outlined,
                    title: 'Survey Results',
                    onTap: () => _navigateTo(context, AppRoutes.surveyResults),
                    context: context,
                    isActive: currentRoute == AppRoutes.surveyResults,
                    isImplemented: true,
                    isAdminOnly: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.table_view_outlined,
                    title: 'Survey Data Viewer',
                    onTap: () => _navigateTo(context, AppRoutes.surveyDataViewer),
                    context: context,
                    isActive: currentRoute == AppRoutes.surveyDataViewer,
                    isImplemented: true,
                    isAdminOnly: true,
                    isNew: false,
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics_outlined,
                    title: 'College Reports',
                    onTap: () => _navigateTo(context, AppRoutes.collegeReports),
                    context: context,
                    isActive: currentRoute == AppRoutes.collegeReports,
                    isImplemented: true,
                    isAdminOnly: true,
                  ),
                  _buildDrawerItem(
                    icon: Icons.file_download_outlined,
                    title: 'Export Data',
                    onTap: () => _navigateTo(context, AppRoutes.exportData),
                    context: context,
                    isActive: currentRoute == AppRoutes.exportData,
                    isImplemented: true,
                    isAdminOnly: true,
                  ),
                ],
                if (!isAdmin) ...[
                  _buildDrawerItem(
                    icon: Icons.assignment_outlined,
                    title: 'Alumni Survey',
                    onTap: () => _navigateTo(context, AppRoutes.surveyForm),
                    context: context,
                    isActive: currentRoute == AppRoutes.surveyForm,
                    isImplemented: true,
                  ),
                ],
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => _navigateTo(context, AppRoutes.settings),
                  context: context,
                  isActive: currentRoute == AppRoutes.settings,
                  isImplemented: true,
                ),
                const Divider(height: 32),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () => _logout(context),
                  context: context,
                  isImplemented: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

