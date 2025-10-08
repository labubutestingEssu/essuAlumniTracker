import '../models/user_role.dart';
import 'user_service.dart';

class ExportFilterService {
  final UserService _userService = UserService();

  /// Get the current user's college and role for export filtering
  /// Returns a map with 'college' and 'role' keys
  /// If user is super_admin or admin, college will be null (no filtering)
  /// If user is college admin, college will contain their assigned college
  Future<Map<String, dynamic>> getCurrentUserFilterInfo() async {
    try {
      final currentUser = await _userService.getCurrentUser();
      
      if (currentUser == null) {
        return {
          'college': null,
          'role': UserRole.alumni,
          'canExportAll': false,
        };
      }

      // Super admin and admin can export everything
      if (currentUser.role == UserRole.super_admin || currentUser.role == UserRole.admin) {
        return {
          'college': null,
          'role': currentUser.role,
          'canExportAll': true,
        };
      }

      // College admin can only export their college data
      return {
        'college': currentUser.college.isNotEmpty ? currentUser.college : null,
        'role': currentUser.role,
        'canExportAll': false,
      };
    } catch (e) {
      print('Error getting current user filter info: $e');
      return {
        'college': null,
        'role': UserRole.alumni,
        'canExportAll': false,
      };
    }
  }

  /// Check if the current user can export data from a specific college
  /// Returns true if user can export all data or if the college matches their assigned college
  Future<bool> canExportCollegeData(String? targetCollege) async {
    final filterInfo = await getCurrentUserFilterInfo();
    
    // If user can export all data, they can export any college
    if (filterInfo['canExportAll'] == true) {
      return true;
    }

    // If user is college admin, they can only export their own college
    final userCollege = filterInfo['college'] as String?;
    if (userCollege == null) {
      return false; // User has no college assigned
    }

    // Check if target college matches user's college
    return targetCollege == userCollege;
  }

  /// Get the appropriate query filter for Firestore based on user role
  /// Returns null if no filtering needed, or a map with filter conditions
  Future<Map<String, dynamic>?> getFirestoreFilter() async {
    final filterInfo = await getCurrentUserFilterInfo();
    
    // If user can export all data, no filtering needed
    if (filterInfo['canExportAll'] == true) {
      return null;
    }

    // If user is college admin, filter by their college
    final userCollege = filterInfo['college'] as String?;
    if (userCollege != null) {
      return {'college': userCollege};
    }

    // If user has no college assigned, they can't export any data
    return {'college': 'NO_COLLEGE_ASSIGNED'}; // This will return no results
  }
}
