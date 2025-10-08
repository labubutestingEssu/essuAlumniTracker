import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../services/app_initialization_service.dart';
import '../../services/admin_initialization_service.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';

class SystemInitializationScreen extends StatefulWidget {
  const SystemInitializationScreen({Key? key}) : super(key: key);

  @override
  State<SystemInitializationScreen> createState() => _SystemInitializationScreenState();
}

class _SystemInitializationScreenState extends State<SystemInitializationScreen> {
  final AppInitializationService _appInitService = AppInitializationService();
  bool _isLoading = true;
  bool _isReinitializing = false;
  Map<String, dynamic> _initStatus = {};

  @override
  void initState() {
    super.initState();
    _loadInitializationStatus();
  }

  Future<void> _loadInitializationStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await _appInitService.getInitializationStatus();
      setState(() {
        _initStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _initStatus = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _reinitializeAdmins() async {
    final confirmed = await _showConfirmationDialog(
      'Reinitialize Admin Accounts',
      'This will create any missing default admin accounts. Existing accounts will not be affected. Continue?',
    );
    
    if (!confirmed) return;

    setState(() => _isReinitializing = true);
    
    try {
      await AdminInitializationService.forceReinitialize();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('College Admin accounts reinitialized successfully!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
      
      // Reload status
      await _loadInitializationStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reinitializing admin accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isReinitializing = false);
    }
  }

  Future<void> _sendPasswordResets() async {
    final confirmed = await _showConfirmationDialog(
      'Send Password Reset Emails',
      'This will send password reset emails to all default admin accounts. Continue?',
    );
    
    if (!confirmed) return;

    setState(() => _isReinitializing = true);
    
    try {
      final adminEmails = AdminInitializationService.getDefaultAdminEmails();
      int successCount = 0;
      int errorCount = 0;
      
      for (String email in adminEmails) {
        try {
          await AdminInitializationService.resetAdminPassword(email);
          successCount++;
        } catch (e) {
          errorCount++;
          print('Failed to send reset email to $email: $e');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset emails sent: $successCount successful, $errorCount failed'),
          backgroundColor: errorCount == 0 ? Theme.of(context).primaryColor : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending password reset emails: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isReinitializing = false);
    }
  }

  Future<void> _createMissingUserProfiles() async {
    final confirmed = await _showConfirmationDialog(
      'Create Missing User Profiles',
      'This will create Firestore user profiles for admin accounts that exist in Firebase Auth but are missing their user profiles. Continue?',
    );
    
    if (!confirmed) return;

    setState(() => _isReinitializing = true);
    
    try {
      await AdminInitializationService.createMissingUserProfiles();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Missing user profiles created successfully!'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
      
      // Reload status
      await _loadInitializationStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating missing user profiles: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isReinitializing = false);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return WillPopScope(
      onWillPop: () async {
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        return false;
      },
      child: ResponsiveScreenWrapper(
        title: 'System Initialization',
        customAppBar: const CustomAppBar(
          title: 'System Initialization',
          showBackButton: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 24),
                    _buildAdminAccountsCard(),
                    const SizedBox(height: 24),
                    _buildSurveyQuestionsCard(),
                    const SizedBox(height: 24),
                    _buildActionsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final isInitialized = _initStatus['isInitialized'] ?? false;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInitialized ? Icons.check_circle : Icons.warning,
                  color: isInitialized ? Theme.of(context).primaryColor : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isInitialized ? 'System is initialized' : 'System needs initialization',
              style: TextStyle(
                fontSize: 16,
                color: isInitialized ? Theme.of(context).primaryColor : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last checked: ${_initStatus['lastChecked'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminAccountsCard() {
    final adminInit = _initStatus['adminInitialization'] as Map<String, dynamic>?;
    final defaultEmails = _initStatus['defaultAdminEmails'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Accounts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (adminInit != null) ...[
              _buildInfoRow('Status', adminInit['completed'] == true ? 'Completed' : 'Pending'),
              _buildInfoRow('Total Admins', '${adminInit['totalAdmins'] ?? 0}'),
              _buildInfoRow('Created', '${adminInit['createdCount'] ?? 0}'),
              _buildInfoRow('Existing', '${adminInit['existingCount'] ?? 0}'),
              if (adminInit['completedAt'] != null)
                _buildInfoRow('Completed At', adminInit['completedAt'].toString()),
            ] else ...[
              const Text('College Admin initialization not yet completed'),
            ],
            const SizedBox(height: 16),
            const Text(
              'Default College Admin Emails:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ...defaultEmails.map((email) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text('• $email', style: const TextStyle(fontSize: 12)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyQuestionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Survey Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Total Questions', '${_initStatus['totalQuestions'] ?? 0}'),
            _buildInfoRow('Active Questions', '${_initStatus['activeQuestions'] ?? 0}'),
            _buildInfoRow('Has Questions', _initStatus['hasQuestions'] == true ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isReinitializing ? null : _reinitializeAdmins,
                icon: _isReinitializing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Reinitialize College Admin Accounts'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isReinitializing ? null : _sendPasswordResets,
                icon: const Icon(Icons.email),
                label: const Text('Send Password Reset Emails'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isReinitializing ? null : _createMissingUserProfiles,
                icon: _isReinitializing 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: const Text('Create Missing User Profiles'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadInitializationStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Status'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
} 