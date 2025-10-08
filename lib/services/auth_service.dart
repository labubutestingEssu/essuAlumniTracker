import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'package:flutter/foundation.dart';
import 'unified_user_service.dart';

class AuthService {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login in role-based table
      if (userCredential.user != null) {
        try {
          // Try to get user from role-based tables first
          final user = await UnifiedUserService().getUserData(userCredential.user!.uid);
          if (user != null) {
            // Update in role-based table
            final updatedUser = user.copyWith(lastLogin: DateTime.now());
            await UnifiedUserService().updateUser(updatedUser);
            print('✅ Last login updated in role-based table');
          } else {
            print('❌ User not found in role-based tables. This user may need to be migrated.');
            // Don't try to update old table as it's been migrated
            // Just log the issue for debugging
            print('⚠️ User ${userCredential.user!.uid} not found in any role-based table');
          }
        } catch (e) {
          print('❌ Error updating last login: $e');
          // Don't fallback to old table as it's been migrated
        }
      }

      return userCredential;
    } catch (e) {
      print('Sign in error: $e');
      throw Exception(e.toString());
    }
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? middleName,
    String? suffix,
    required String studentId,
    required String course,
    required String batchYear,
    required String college,
    UserRole role = UserRole.alumni,
    String? phone,
    String? facebookUrl,
    String? instagramUrl,
  }) async {
    try {
      UserCredential userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Create user model with specified role
        UserModel newUser = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          firstName: firstName,
          lastName: lastName,
          middleName: middleName,
          suffix: suffix,
          studentId: studentId,
          course: course,
          batchYear: batchYear,
          college: college,
          role: role,
          phone: phone,
          facebookUrl: facebookUrl,
          instagramUrl: instagramUrl,
        );

        // Save user data to appropriate role-based table
        try {
          final success = await UnifiedUserService().createUser(newUser);
          if (success) {
            print('✅ User created in role-based table: ${newUser.role}');
          } else {
            print('❌ Failed to create user in role-based table');
            throw Exception('Failed to create user in role-based table');
          }
        } catch (e) {
          print('❌ Error creating user in role-based table: $e');
          throw Exception('Failed to create user: $e');
        }
      }

      return userCredential;
    } catch (e) {
      print('Registration error: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  Future<void> resetPassword({required String email}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> updateUsername({required String newUsername}) async {
    await currentUser!.updateDisplayName(newUsername);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }

  Future<void> resetPasswordFromCurrentPAssword({
    required String currentPassword,
    required String newPassword,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: currentUser!.email!,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  // New methods for role-based functionality
  Future<UserRole> getCurrentUserRole() async {
    try {
      if (currentUser != null) {
        final user = await UnifiedUserService().getUserData(currentUser!.uid);
        if (user != null) {
          return user.role;
        }
      }
      return UserRole.alumni;
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.alumni;
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    final role = await getCurrentUserRole();
    return role == UserRole.admin || role == UserRole.super_admin;
  }

  Future<bool> isCurrentUserSuperAdmin() async {
    return await getCurrentUserRole() == UserRole.super_admin;
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final user = await UnifiedUserService().getUserData(userId);
      if (user != null) {
        return user.toMap();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }
}
