import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/app_drawer.dart';
import '../../utils/responsive.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../providers/theme_provider.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  bool _isSaving = false;
  UserModel? _settings;
  Map<String, bool> _fieldVisibility = {};
  
  bool _darkMode = false;
  bool _isAdmin = false;
  String _privacyLevel = 'alumni-only';
  // String? _userSettingsId;
  
  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _checkAdminStatus();
  }
  
  Future<void> _loadUserSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }
      
      final settings = await _userService.getUserSettings();
      
      if (settings != null) {
        setState(() {
          _settings = settings;
          _darkMode = settings.darkMode;
          _privacyLevel = settings.privacyLevel;
          _fieldVisibility = Map.from(settings.fieldVisibility);
          // _userSettingsId = settings.userId;
        });
        print("Loaded settings with fieldVisibility: ${settings.fieldVisibility}");
      } else {
        print("No settings found, using defaults");
        setState(() {
          _fieldVisibility = _defaultFieldVisibility();
          // _userSettingsId = userId;
        });
      }
    } catch (e) {
      print("Error loading settings: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });
    
    // Get providers
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    
    try {
      // Save theme setting
      await themeProvider.setDarkMode(_darkMode);
      
      // Save other settings
      await _savePrivacySettings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    } catch (e) {
      print("Error saving settings: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _savePrivacySettings() async {
    try {
      print("Saving settings with fieldVisibility: $_fieldVisibility");
      final updatedSettings = _settings!.copyWith(
        darkMode: _darkMode,
        privacyLevel: _privacyLevel,
        fieldVisibility: _fieldVisibility,
      );
      
      await _userService.updateUserSettings(updatedSettings);
    } catch (e) {
      print("Error saving privacy settings: $e");
      throw e; // Re-throw to be caught by the parent
    }
  }
  
  Future<void> _updateFieldVisibility(String field, bool value) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('No user logged in');
      }
      
      setState(() {
        _fieldVisibility[field] = value;
      });
      
      print("Updating field visibility: $field -> $value");
      final success = await _userService.updateFieldVisibility(field, value);
      
      if (!success) {
        // Revert the change if the update failed
        setState(() {
          _fieldVisibility[field] = !value;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update privacy setting'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error updating field visibility: $e");
      // Revert the change if there was an error
      setState(() {
        _fieldVisibility[field] = !value;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating privacy setting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return WillPopScope(
      onWillPop: () async {
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        drawer: Responsive.isMobile(context) ? const AppDrawer() : null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Responsive.isDesktop(context)
                ? Row(
                    children: [
                      const SizedBox(width: 240, child: AppDrawer()),
                      Expanded(child: _buildContent(themeProvider)),
                    ],
                  )
                : _buildContent(themeProvider),
      ),
    );
  }

  Widget _buildContent(ThemeProvider themeProvider) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_isAdmin) _buildAdminSection(),
        _buildPrivacySection(),
        const SizedBox(height: 24),
        _buildSection(
          'Appearance',
          [
            _buildSwitchTile(
              'Dark Mode',
              'Use dark theme',
              themeProvider.isDarkMode,
              (value) {
                setState(() {
                  _darkMode = value;
                });
                themeProvider.setDarkMode(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          'Account',
          [
            _buildActionTile(
              'Change Password',
              'Update your account password',
              Icons.lock_outline,
              () => _showChangePasswordDialog(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          'About',
          [
            _buildActionTile(
              'Terms of Service',
              'Read our terms of service',
              Icons.description_outlined,
              () => _showTermsOfService(),
            ),
            _buildActionTile(
              'Privacy Policy',
              'View our privacy policy',
              Icons.privacy_tip_outlined,
              () => _showPrivacyPolicy(),
            ),
            _buildActionTile(
              'App Version',
              '1.0.0',
              Icons.info_outline,
              null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _logout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Logout'),
        ),
      ],
    );
  }
  
  Widget _buildPrivacySection() {
    return _buildSection(
      'Privacy',
      [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Visibility',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Control which information is visible to other alumni. Your name is always visible.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildPrivacyControls(),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildPrivacyControls() {
    // Determine which ID field to show based on role
    final userRole = _settings?.role;
    final shouldShowIdField = userRole == UserRole.alumni || userRole == UserRole.admin;
    
    // Use facultyId for college admin, studentId for alumni
    final idFieldKey = userRole == UserRole.admin ? 'facultyId' : 'studentId';
      
    return Column(
      children: [
        _buildFieldVisibilityTile('Bio/About Me', 'bio'),
        _buildFieldVisibilityTile('Course/Program', 'course'),
        _buildFieldVisibilityTile('Batch Year', 'batchYear'),
        // Only show ID field visibility for alumni (Student ID) and college admin (Faculty ID)
        // Super admins don't need ID visibility toggle
        if (shouldShowIdField)
          _buildFieldVisibilityTile(_getIdFieldLabel(), idFieldKey),
        _buildFieldVisibilityTile('Email Address', 'email'),
        _buildFieldVisibilityTile('Phone Number', 'phone'),
        _buildFieldVisibilityTile('Current Occupation', 'currentOccupation'),
        _buildFieldVisibilityTile('Company', 'company'),
        _buildFieldVisibilityTile('Location', 'location'),
      ],
    );
  }
  
  Widget _buildFieldVisibilityTile(String title, String field) {
    final isVisible = _fieldVisibility[field] ?? false;
    
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(isVisible ? 'Visible to other alumni' : 'Hidden from other alumni'),
      value: isVisible,
      onChanged: (value) => _updateFieldVisibility(field, value),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                
                try {
                  final success = await _userService.changePassword(
                    newPasswordController.text,
                  );
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to change password. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error changing password: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  // void _exportData() {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('Exporting your data...'),
  //       behavior: SnackBarBehavior.floating,
  //     ),
  //   );
  // }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            'These are the terms of service for the ESSU Alumni Tracker app. By using this application, you agree to these terms.\n\n'
            'This application is designed for Eastern Samar State University alumni to connect with each other and stay updated with university information.\n\n'
            'We respect your privacy and will only use your information in accordance with our privacy policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy for ESSU Alumni Tracker\n\n'
            'We collect personal information to help you connect with other alumni and to provide you with updates about university information.\n\n'
            'You can control which personal information is visible to other alumni through the privacy settings.\n\n'
            'We do not share your personal information with third parties without your consent.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  Map<String, bool> _defaultFieldVisibility() {
    return {
      'email': true,
      'phone': false,
      'address': false,
      'workExperience': true,
      'education': true,
      'skills': true,
    };
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _userService.isCurrentUserAdmin();
      setState(() {
        _isAdmin = isAdmin;
      });
      print("User is admin: $_isAdmin");
    } catch (e) {
      print("Error checking admin status: $e");
      setState(() {
        _isAdmin = false;
      });
    }
  }

  // Helper method to check if user should show Faculty ID instead of Student ID
  bool _shouldShowFacultyId() {
    return _settings?.role == UserRole.admin;
  }

  // Helper method to get the appropriate ID field label
  String _getIdFieldLabel() {
    return _shouldShowFacultyId() ? 'Faculty ID' : 'Student ID';
  }

  Widget _buildAdminSection() {
    return Column(
      children: [
        _buildSection(
          'Admin Controls',
          [
            _buildActionTile(
              'Program Management',
              'Add, edit, or remove university programs',
              Icons.school,
              () => Navigator.pushNamed(context, '/admin/courses'),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
} 