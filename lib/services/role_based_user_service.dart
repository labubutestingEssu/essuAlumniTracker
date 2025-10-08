import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/alumni_model.dart';
import '../models/admin_model.dart';
import '../models/user_role.dart';

class RoleBasedUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names for role-based tables
  static const String _alumniCollection = 'alumni';
  static const String _collegeAdminCollection = 'college_admin';
  static const String _adminCollection = 'admin';

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get the appropriate collection name based on role
  String getCollectionName(UserRole role) {
    switch (role) {
      case UserRole.alumni:
        return _alumniCollection;
      case UserRole.admin:
        return _collegeAdminCollection;
      case UserRole.super_admin:
        return _adminCollection;
    }
  }

  // Get the appropriate model class based on role
  dynamic getModelFromRole(UserRole role, DocumentSnapshot doc) {
    switch (role) {
      case UserRole.alumni:
        return AlumniModel.fromFirestore(doc);
      case UserRole.admin:
      case UserRole.super_admin:
        return AdminModel.fromFirestore(doc);
    }
  }

  // Create user in appropriate role-based table
  Future<bool> createUser(UserModel user) async {
    try {
      final collectionName = getCollectionName(user.role);
      final userData = user.toMap();
      
      // Add role-specific metadata
      userData['roleTable'] = collectionName;
      userData['lastSynced'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(collectionName).doc(user.uid).set(userData);
      
      print('✅ User created in $collectionName: ${user.uid}');
      return true;
    } catch (e) {
      print('❌ Error creating user: $e');
      return false;
    }
  }

  // Get user from appropriate role-based table
  Future<UserModel?> getUser(String userId, UserRole role) async {
    try {
      final collectionName = getCollectionName(role);
      final doc = await _firestore.collection(collectionName).doc(userId).get();
      
      if (doc.exists) {
        final model = getModelFromRole(role, doc);
        return model.toUserModel();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user: $e');
      return null;
    }
  }

  // Get current user (searches all role tables)
  Future<UserModel?> getCurrentUser() async {
    if (currentUserId == null) return null;
    
    try {
      // Try each role table
      for (final role in UserRole.values) {
        final user = await getUser(currentUserId!, role);
        if (user != null) return user;
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  // Update user in appropriate role-based table
  Future<bool> updateUser(UserModel user) async {
    try {
      final collectionName = getCollectionName(user.role);
      final userData = user.toMap();
      
      // Add role-specific metadata
      userData['roleTable'] = collectionName;
      userData['lastSynced'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(collectionName).doc(user.uid).update(userData);
      
      print('✅ User updated in $collectionName: ${user.uid}');
      return true;
    } catch (e) {
      print('❌ Error updating user: $e');
      return false;
    }
  }

  // Delete user from appropriate role-based table
  Future<bool> deleteUser(String userId, UserRole role) async {
    try {
      final collectionName = getCollectionName(role);
      await _firestore.collection(collectionName).doc(userId).delete();
      
      print('✅ User deleted from $collectionName: $userId');
      return true;
    } catch (e) {
      print('❌ Error deleting user: $e');
      return false;
    }
  }

  // Get all users from a specific role table
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final collectionName = getCollectionName(role);
      final snapshot = await _firestore.collection(collectionName).get();
      
      return snapshot.docs.map<UserModel>((doc) {
        final model = getModelFromRole(role, doc);
        return model.toUserModel();
      }).toList();
    } catch (e) {
      print('❌ Error getting users by role: $e');
      return [];
    }
  }

  // Get all users from all role tables (unified view)
  Future<List<UserModel>> getAllUsers() async {
    try {
      List<UserModel> allUsers = [];
      
      for (final role in UserRole.values) {
        final users = await getUsersByRole(role);
        allUsers.addAll(users);
      }
      
      return allUsers;
    } catch (e) {
      print('❌ Error getting all users: $e');
      return [];
    }
  }

  // Search users across all role tables
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      List<UserModel> results = [];
      
      for (final role in UserRole.values) {
        final collectionName = getCollectionName(role);
        final snapshot = await _firestore.collection(collectionName)
            .where('firstName', isGreaterThanOrEqualTo: query)
            .where('firstName', isLessThan: query + 'z')
            .get();
        
        results.addAll(snapshot.docs.map((doc) {
          final model = getModelFromRole(role, doc);
          return model.toUserModel();
        }));
      }
      
      return results;
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  // Update user settings (works with any role)
  Future<bool> updateUserSettings(UserModel user) async {
    try {
      final collectionName = getCollectionName(user.role);
      await _firestore.collection(collectionName).doc(user.uid).update({
        'darkMode': user.darkMode,
        'privacyLevel': user.privacyLevel,
        'fieldVisibility': user.fieldVisibility,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastSynced': FieldValue.serverTimestamp(),
      });
      
      print('✅ User settings updated in $collectionName: ${user.uid}');
      return true;
    } catch (e) {
      print('❌ Error updating user settings: $e');
      return false;
    }
  }

  // Update field visibility
  Future<bool> updateFieldVisibility(String field, bool isVisible) async {
    if (currentUserId == null) return false;
    
    try {
      final user = await getCurrentUser();
      if (user == null) return false;
      
      final updatedUser = user.updateFieldVisibility(field, isVisible);
      return await updateUserSettings(updatedUser);
    } catch (e) {
      print('❌ Error updating field visibility: $e');
      return false;
    }
  }

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (currentUserId == null) return false;
    
    try {
      UserModel? user = await getCurrentUser();
      return user?.role == UserRole.admin || user?.role == UserRole.super_admin;
    } catch (e) {
      print('❌ Error checking admin status: $e');
      return false;
    }
  }

  // Check if current user is super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    if (currentUserId == null) return false;
    
    try {
      UserModel? user = await getCurrentUser();
      return user?.role == UserRole.super_admin;
    } catch (e) {
      print('❌ Error checking super admin status: $e');
      return false;
    }
  }

  // Migrate user from old users table to role-based table
  Future<bool> migrateUser(UserModel user) async {
    try {
      // Create user in appropriate role table
      final success = await createUser(user);
      
      if (success) {
        // Optionally delete from old users table
        // await _firestore.collection('users').doc(user.uid).delete();
        print('✅ User migrated to role-based table: ${user.uid}');
      }
      
      return success;
    } catch (e) {
      print('❌ Error migrating user: $e');
      return false;
    }
  }

  // Migrate all users from old users table to role-based tables
  Future<void> migrateAllUsers() async {
    try {
      print('🔄 Starting migration of all users to role-based tables...');
      
      // Get all users from old users table
      final snapshot = await _firestore.collection('users').get();
      
      for (final doc in snapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        await migrateUser(user);
      }
      
      print('✅ Migration completed successfully');
    } catch (e) {
      print('❌ Error during migration: $e');
      rethrow;
    }
  }
}
