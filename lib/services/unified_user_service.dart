import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'role_based_user_service.dart';

class UnifiedUserService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final RoleBasedUserService _roleService = RoleBasedUserService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize the service
  static Future<void> initialize() async {
    // Service is ready to use
    print('✅ UnifiedUserService initialized');
  }

  /// Get current user data (searches all role tables)
  Future<UserModel?> getCurrentUser() async {
    if (currentUserId == null) return null;
    
    try {
      return await _roleService.getCurrentUser();
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  /// Get user data by ID (searches all role tables)
  Future<UserModel?> getUserData(String uid) async {
    try {
      // Try each role table
      for (final role in UserRole.values) {
        final user = await _roleService.getUser(uid, role);
        if (user != null) return user;
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Create new user (automatically goes to correct role table)
  Future<bool> createUser(UserModel user) async {
    try {
      return await _roleService.createUser(user);
    } catch (e) {
      print('❌ Error creating user: $e');
      return false;
    }
  }

  /// Update user data (automatically updates correct role table)
  Future<bool> updateUser(UserModel user) async {
    try {
      return await _roleService.updateUser(user);
    } catch (e) {
      print('❌ Error updating user: $e');
      return false;
    }
  }

  /// Delete user (automatically deletes from correct role table)
  Future<bool> deleteUser(String uid, UserRole role) async {
    try {
      return await _roleService.deleteUser(uid, role);
    } catch (e) {
      print('❌ Error deleting user: $e');
      return false;
    }
  }

  /// Get all users (from all role tables)
  Future<List<UserModel>> getAllUsers() async {
    try {
      return await _roleService.getAllUsers();
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      return await _roleService.getUsersByRole(role);
    } catch (e) {
      print('❌ Error getting users by role: $e');
      return [];
    }
  }

  /// Get users by role with stream (real-time updates)
  Stream<List<UserModel>> getUsersByRoleStream(UserRole role) {
    try {
      final collectionName = _roleService.getCollectionName(role);
      return _firestore.collection(collectionName).snapshots().map<List<UserModel>>((snapshot) {
        return snapshot.docs.map<UserModel>((doc) {
          final model = _roleService.getModelFromRole(role, doc);
          return model.toUserModel();
        }).toList();
      });
    } catch (e) {
      print('❌ Error getting users by role stream: $e');
      return Stream.value([]);
    }
  }

  /// Search users across all role tables
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      return await _roleService.searchUsers(query);
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  /// Get user settings (from correct role table)
  Future<UserModel?> getUserSettings([String? userId]) async {
    try {
      if (userId != null) {
        return await getUserData(userId);
      }
      return await getCurrentUser();
    } catch (e) {
      print('❌ Error getting user settings: $e');
      return null;
    }
  }

  /// Update user settings (automatically updates correct role table)
  Future<bool> updateUserSettings(UserModel user) async {
    try {
      return await _roleService.updateUserSettings(user);
    } catch (e) {
      print('❌ Error updating user settings: $e');
      return false;
    }
  }

  /// Update field visibility
  Future<bool> updateFieldVisibility(String field, bool isVisible) async {
    try {
      return await _roleService.updateFieldVisibility(field, isVisible);
    } catch (e) {
      print('❌ Error updating field visibility: $e');
      return false;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      return await _roleService.isCurrentUserAdmin();
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  /// Check if current user is super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    try {
      return await _roleService.isCurrentUserSuperAdmin();
    } catch (e) {
      print('❌ Error checking super admin status: $e');
      return false;
    }
  }

  /// Get users with pagination (from all role tables)
  Future<List<UserModel>> getUsersWithPagination({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      // This is a simplified implementation
      // In a real app, you might want to implement proper pagination
      return await getAllUsers();
    } catch (e) {
      print('❌ Error getting users with pagination: $e');
      return [];
    }
  }

  /// Get user count by role
  Future<Map<UserRole, int>> getUserCountsByRole() async {
    try {
      Map<UserRole, int> counts = {};
      
      for (final role in UserRole.values) {
        final users = await getUsersByRole(role);
        counts[role] = users.length;
      }
      
      return counts;
    } catch (e) {
      print('❌ Error getting user counts by role: $e');
      return {};
    }
  }

  /// Update user profile (with privacy filters)
  Future<bool> updateUserProfile({
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    String? bio,
    String? currentOccupation,
    String? company,
    String? location,
    String? phone,
    String? facebookUrl,
    String? instagramUrl,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return false;

      final updatedUser = currentUser.copyWith(
        firstName: firstName ?? currentUser.firstName,
        lastName: lastName ?? currentUser.lastName,
        middleName: middleName ?? currentUser.middleName,
        suffix: suffix ?? currentUser.suffix,
        bio: bio ?? currentUser.bio,
        currentOccupation: currentOccupation ?? currentUser.currentOccupation,
        company: company ?? currentUser.company,
        location: location ?? currentUser.location,
        phone: phone ?? currentUser.phone,
        facebookUrl: facebookUrl ?? currentUser.facebookUrl,
        instagramUrl: instagramUrl ?? currentUser.instagramUrl,
      );

      return await updateUser(updatedUser);
    } catch (e) {
      print('❌ Error updating user profile: $e');
      return false;
    }
  }

  /// Update user role (moves user between tables)
  Future<bool> updateUserRole(String uid, UserRole newRole) async {
    try {
      // Get current user data
      final currentUser = await getUserData(uid);
      if (currentUser == null) return false;

      // Create new user with updated role
      final updatedUser = currentUser.copyWith(role: newRole);
      
      // Delete from old table
      await deleteUser(uid, currentUser.role);
      
      // Create in new table
      return await createUser(updatedUser);
    } catch (e) {
      print('❌ Error updating user role: $e');
      return false;
    }
  }

  /// Create new user (goes to correct role table)
  Future<bool> createNewUser(UserModel user) async {
    try {
      return await createUser(user);
    } catch (e) {
      print('❌ Error creating new user: $e');
      return false;
    }
  }

  /// Update profile image
  Future<bool> updateUserProfileImage(String userId, String imageUrl) async {
    try {
      final user = await getUserData(userId);
      if (user == null) return false;

      final updatedUser = user.copyWith(profileImageUrl: imageUrl);
      return await updateUser(updatedUser);
    } catch (e) {
      print('❌ Error updating profile image: $e');
      return false;
    }
  }

  /// Delete user (from correct role table)
  Future<bool> deleteUserById(String userId) async {
    try {
      final user = await getUserData(userId);
      if (user == null) return false;

      return await deleteUser(userId, user.role);
    } catch (e) {
      print('❌ Error deleting user: $e');
      return false;
    }
  }


}
