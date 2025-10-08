import 'dart:io';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';
import 'cloudinary_service.dart';
import 'unified_user_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Note: _collection is no longer used - all operations go through UnifiedUserService
  
  final CloudinaryService _cloudinaryService = CloudinaryService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    return await UnifiedUserService().getCurrentUser();
  }

  // Update user profile
  Future<bool> updateUserProfile({
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    String? batchYear,
    String? course,
    String? currentOccupation,
    String? company,
    String? location,
    String? bio,
    String? phone,
    String? studentId,
    String? profileImageUrl,
    String? facebookUrl,
    String? instagramUrl,
  }) async {
    if (currentUserId == null) return false;
    
    try {
      // Get current user
      UserModel? currentUser = await getCurrentUser();
      if (currentUser == null) return false;
      
      // Create updated user
      UserModel updatedUser = currentUser.copyWith(
        firstName: firstName ?? currentUser.firstName,
        lastName: lastName ?? currentUser.lastName,
        middleName: middleName ?? currentUser.middleName,
        suffix: suffix ?? currentUser.suffix,
        batchYear: batchYear ?? currentUser.batchYear,
        course: course ?? currentUser.course,
        currentOccupation: currentOccupation ?? currentUser.currentOccupation,
        company: company ?? currentUser.company,
        location: location ?? currentUser.location,
        bio: bio ?? currentUser.bio,
        phone: phone ?? currentUser.phone,
        studentId: studentId ?? currentUser.studentId,
        profileImageUrl: profileImageUrl ?? currentUser.profileImageUrl,
        facebookUrl: facebookUrl ?? currentUser.facebookUrl,
        instagramUrl: instagramUrl ?? currentUser.instagramUrl,
      );
      
      // Update using unified service
      return await UnifiedUserService().updateUser(updatedUser);
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }

  // Upload profile image using File (primarily for mobile)
  Future<String?> uploadProfileImage(File imageFile, {String? userId}) async {
    try {
      print('Starting profile image upload to Cloudinary');
      if (currentUserId == null && userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Determine which user ID to use for the folder path
      final targetUserId = userId ?? currentUserId;
      
      // Upload to Cloudinary
      final imageUrl = await _cloudinaryService.uploadImage(
        imageFile,
        folder: 'profiles/$targetUserId',
      );
      
      // If upload successful and we're updating the current user's profile (not a specific user)
      if (imageUrl != null && userId == null) {
        print('Profile image uploaded successfully: $imageUrl');
        // Update through UnifiedUserService
        final currentUser = await getCurrentUser();
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(profileImageUrl: imageUrl);
          await UnifiedUserService().updateUser(updatedUser);
        }
      } else if (imageUrl != null) {
        print('Profile image uploaded successfully for user $userId: $imageUrl');
      }
      
      return imageUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return getProfileImagePlaceholder(userId ?? currentUserId ?? 'unknown');
    }
  }

  // Upload profile image using XFile (works for both web and mobile)
  Future<String?> uploadProfileXFile(XFile imageFile, {String? userId}) async {
    try {
      print('Starting profile XFile upload to Cloudinary');
      if (currentUserId == null && userId == null) {
        throw Exception('User not authenticated');
      }
      
      // Determine which user ID to use for the folder path
      final targetUserId = userId ?? currentUserId;
      
      // Upload to Cloudinary using XFile method
      final imageUrl = await _cloudinaryService.uploadXFile(
        imageFile,
        folder: 'profiles/$targetUserId',
      );
      
      // If upload successful and we're updating the current user's profile (not a specific user)
      if (imageUrl != null && userId == null) {
        print('Profile image uploaded successfully: $imageUrl');
        // Update through UnifiedUserService
        final currentUser = await getCurrentUser();
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(profileImageUrl: imageUrl);
          await UnifiedUserService().updateUser(updatedUser);
        }
      } else if (imageUrl != null) {
        print('Profile image uploaded successfully for user $userId: $imageUrl');
      }
      
      return imageUrl;
    } catch (e) {
      print('Error uploading profile image from XFile: $e');
      return getProfileImagePlaceholder(userId ?? currentUserId ?? 'unknown');
    }
  }

  // Get a placeholder profile image
  String getProfileImagePlaceholder(String userId) {
    return 'https://placehold.co/400x400/4CAF50/ffffff/png?text=${userId.substring(0, math.min(3, userId.length))}';
  }

  // Change password
  Future<bool> changePassword(String newPassword) async {
    if (currentUserId == null || _auth.currentUser == null) return false;
    
    try {
      await _auth.currentUser!.updatePassword(newPassword);
      return true;
    } catch (e) {
      print('Error changing password: $e');
      return false;
    }
  }

  // Get user by ID with privacy settings applied
  Future<UserModel?> getUserById(String userId, {bool isAdmin = false}) async {
    try {
      // Use UnifiedUserService to get user from role-based collections
      UserModel? user = await UnifiedUserService().getUserData(userId);
      if (user == null) return null;
      
      // Admin can see everything, return the full user
      if (isAdmin) return user;
      
      // If not admin, apply privacy filters
      if (userId != currentUserId) {
        user = await _applyPrivacyFilters(user);
      }
      
      return user;
    } catch (e) {
      print('Error getting user by ID: $e');
      return null;
    }
  }
  
  // Apply privacy filters to a user model based on their settings
  Future<UserModel> _applyPrivacyFilters(UserModel user) async {
    // Get user's privacy settings
    UserModel? settings = await getUserSettings(user.uid);
    
    if (settings == null) {
      // Use the user's own settings if no separate settings found
      settings = user;
    }
    
    print('Applying privacy filters for user ${user.fullName} with settings: ${settings.fieldVisibility}');
    
    // Start with basic info that's always visible (name fields are always visible for basic identification)
    Map<String, dynamic> filteredData = {
      'uid': user.uid,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'middleName': user.middleName,
      'suffix': user.suffix,
      'role': user.role,
      'profileImageUrl': user.profileImageUrl,
    };
    
    // Apply field visibility settings
    if (settings.fieldVisibility['course'] == true) {
      filteredData['course'] = user.course;
    } else {
      filteredData['course'] = '';
    }
    
    if (settings.fieldVisibility['batchYear'] == true) {
      filteredData['batchYear'] = user.batchYear;
    } else {
      filteredData['batchYear'] = '';
    }
    
    if (settings.fieldVisibility['email'] == true) {
      filteredData['email'] = user.email;
    } else {
      filteredData['email'] = '';
    }
    
    if (settings.fieldVisibility['studentId'] == true) {
      filteredData['studentId'] = user.studentId;
    } else {
      filteredData['studentId'] = '';
    }
    
    // Only include optional fields if they exist and are visible
    if (user.bio != null && settings.fieldVisibility['bio'] == true) {
      filteredData['bio'] = user.bio;
    }
    
    if (user.currentOccupation != null && settings.fieldVisibility['currentOccupation'] == true) {
      filteredData['currentOccupation'] = user.currentOccupation;
    }
    
    if (user.company != null && settings.fieldVisibility['company'] == true) {
      filteredData['company'] = user.company;
    }
    
    if (user.location != null && settings.fieldVisibility['location'] == true) {
      filteredData['location'] = user.location;
    }
    
    if (user.phone != null && settings.fieldVisibility['phone'] == true) {
      filteredData['phone'] = user.phone;
    }
    
    print('After filtering, visible fields for ${user.fullName}: ${filteredData.keys.toList()}');
    
    // Create a filtered user model
    return UserModel(
      uid: user.uid,
      email: filteredData['email'] ?? '',
      firstName: filteredData['firstName'] ?? user.firstName,
      lastName: filteredData['lastName'] ?? user.lastName,
      middleName: filteredData['middleName'] ?? user.middleName,
      suffix: filteredData['suffix'] ?? user.suffix,
      studentId: filteredData['studentId'] ?? '',
      course: filteredData['course'] ?? '',
      batchYear: filteredData['batchYear'] ?? '',
      college: user.college,
      role: user.role,
      profileImageUrl: user.profileImageUrl,
      currentOccupation: filteredData['currentOccupation'],
      company: filteredData['company'],
      location: filteredData['location'],
      bio: filteredData['bio'],
      phone: filteredData['phone'],
      facebookUrl: user.facebookUrl,
      instagramUrl: user.instagramUrl,
      hasCompletedSurvey: user.hasCompletedSurvey,
      surveyCompletedAt: user.surveyCompletedAt,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      lastLogin: user.lastLogin,
    );
  }

  // Search for alumni with privacy filters applied
  Future<List<UserModel>> searchAlumni({
    String? query,
    String? batchYear,
    String? course,
    String? college,
    bool isAdmin = false,
  }) async {
    try {
      print('Search alumni called with admin: $isAdmin');
      
      // Use UnifiedUserService to get all users from role-based collections
      List<UserModel> allUsers = await UnifiedUserService().getAllUsers();
      
      // Apply filters if provided
      List<UserModel> results = allUsers.where((user) {
        // Apply batch year filter
        if (batchYear != null && user.batchYear != batchYear) {
          return false;
        }
        
        // Apply course filter
        if (course != null && user.course != course) {
          return false;
        }
        
        // Apply college filter
        if (college != null && user.college != college) {
          return false;
        }
        
        return true;
      }).toList();
      
      // Apply text search if query is provided (client-side filtering)
      if (query != null && query.isNotEmpty) {
        results = results.where((user) {
          String fullName = user.fullName.toLowerCase();
          String email = user.email.toLowerCase();
          String searchLower = query.toLowerCase();
          
          return fullName.contains(searchLower) || email.contains(searchLower);
        }).toList();
      }
      
      print('Found ${results.length} results, applying privacy filters (admin=$isAdmin)');
      
      // Apply privacy filters for non-admin users
      if (!isAdmin) {
        List<UserModel> filteredResults = [];
        for (var user in results) {
          // Skip filtering current user's data
          if (user.uid == currentUserId) {
            filteredResults.add(user);
            print('Added current user: ${user.fullName} (unfiltered)');
          } else {
            UserModel filteredUser = await _applyPrivacyFilters(user);
            filteredResults.add(filteredUser);
            print('Added filtered user: ${user.fullName}');
          }
        }
        return filteredResults;
      }
      
      print('Returning unfiltered results for admin');
      return results;
    } catch (e) {
      print('Error searching alumni: $e');
      return [];
    }
  }

  // Get user settings (now from user document)
  Future<UserModel?> getUserSettings([String? userId]) async {
    return await UnifiedUserService().getUserSettings(userId);
  }

  // Update user settings (now updates user document)
  Future<bool> updateUserSettings(UserModel user) async {
    return await UnifiedUserService().updateUserSettings(user);
  }
  
  // Update field visibility settings
  Future<bool> updateFieldVisibility(String field, bool isVisible) async {
    return await UnifiedUserService().updateFieldVisibility(field, isVisible);
  }

  // Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    return await UnifiedUserService().isCurrentUserAdmin();
  }

  // Check if current user is super admin
  Future<bool> isCurrentUserSuperAdmin() async {
    return await UnifiedUserService().isCurrentUserSuperAdmin();
  }

  // Get user stream by ID
  Stream<UserModel?> getUserStream(String uid) {
    // Note: This method is deprecated - use UnifiedUserService for real-time updates
    // For now, return a stream that gets the user once
    return Stream.fromFuture(UnifiedUserService().getUserData(uid));
  }

  // Update user
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      // Get current user data
      final user = await UnifiedUserService().getUserData(uid);
      if (user == null) {
        throw Exception('User not found');
      }
      
      // Create updated user model
      final updatedUser = user.copyWith(
        firstName: data['firstName'] ?? user.firstName,
        lastName: data['lastName'] ?? user.lastName,
        middleName: data['middleName'] ?? user.middleName,
        suffix: data['suffix'] ?? user.suffix,
        email: data['email'] ?? user.email,
        studentId: data['studentId'] ?? user.studentId,
        course: data['course'] ?? user.course,
        batchYear: data['batchYear'] ?? user.batchYear,
        college: data['college'] ?? user.college,
        phone: data['phone'] ?? user.phone,
        currentOccupation: data['currentOccupation'] ?? user.currentOccupation,
        company: data['company'] ?? user.company,
        location: data['location'] ?? user.location,
        bio: data['bio'] ?? user.bio,
        profileImageUrl: data['profileImageUrl'] ?? user.profileImageUrl,
        facebookUrl: data['facebookUrl'] ?? user.facebookUrl,
        instagramUrl: data['instagramUrl'] ?? user.instagramUrl,
      );
      
      // Update through UnifiedUserService
      await UnifiedUserService().updateUser(updatedUser);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      return await UnifiedUserService().getAllUsers();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // Get users by batch year
  Future<List<UserModel>> getUsersByBatchYear(String batchYear) async {
    try {
      final allUsers = await UnifiedUserService().getAllUsers();
      return allUsers.where((user) => user.batchYear == batchYear).toList();
    } catch (e) {
      throw Exception('Failed to get users by batch year: $e');
    }
  }

  // Get users by course
  Future<List<UserModel>> getUsersByCourse(String course) async {
    try {
      final allUsers = await UnifiedUserService().getAllUsers();
      return allUsers.where((user) => user.course == course).toList();
    } catch (e) {
      throw Exception('Failed to get users by course: $e');
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      return await UnifiedUserService().searchUsers(query);
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      UserModel? user = await UnifiedUserService().getUserData(uid);
      if (user == null) return null;
        
        // Check if current user is admin or if this is the current user's own data
        bool isCurrentUserAdminRole = await isCurrentUserAdmin();
        bool isOwnProfile = uid == currentUserId;
        
        // Apply privacy filters only if not admin and not viewing own profile
        if (!isCurrentUserAdminRole && !isOwnProfile) {
          return await _applyPrivacyFilters(user);
        }
        
        return user;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      UserModel? user = await getUserData(uid);
      return user?.role == UserRole.admin;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Update user role
  Future<void> updateUserRole(String uid, UserRole newRole) async {
    try {
      await UnifiedUserService().updateUserRole(uid, newRole);
    } catch (e) {
      print('Error updating user role: $e');
      throw Exception('Failed to update user role');
    }
  }

  // Create new user with default alumni role
  Future<void> createNewUser(UserModel user) async {
    try {
      await UnifiedUserService().createNewUser(user);
    } catch (e) {
      print('Error creating user: $e');
      throw Exception('Failed to create user');
    }
  }

  // Get all users with specific role
  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return UnifiedUserService().getUsersByRoleStream(role);
  }

  // Get current user role
  Future<UserRole> getCurrentUserRole(String uid) async {
    try {
      UserModel? user = await getUserData(uid);
      return user?.role ?? UserRole.alumni;
    } catch (e) {
      print('Error getting user role: $e');
      return UserRole.alumni;
    }
  }

  // Update profile image URL for a specific user (admin only)
  Future<bool> updateUserProfileImage(String userId, String imageUrl) async {
    try {
      return await UnifiedUserService().updateUserProfileImage(userId, imageUrl);
    } catch (e) {
      print('Error updating user profile image: $e');
      return false;
    }
  }

  // Delete user (Admin only)
  Future<bool> deleteUser(String userId) async {
    try {
      // Verify current user is super admin
      final currentUser = await getCurrentUser();
      if (currentUser?.role != UserRole.super_admin) {
        throw Exception('Only Admins can delete users');
      }

      // Prevent self-deletion
      if (userId == currentUserId) {
        throw Exception('Cannot delete your own account');
      }

      // Get user data before deletion for cleanup
      final userToDelete = await getUserData(userId);
      if (userToDelete == null) {
        throw Exception('User not found');
      }

      // Prevent deletion of other super admins (optional safety measure)
      if (userToDelete.role == UserRole.super_admin) {
        throw Exception('Cannot delete other Admin accounts');
      }

      print('Starting user deletion process for: ${userToDelete.fullName} (${userToDelete.uid})');

      // 1. Delete user's survey responses
      try {
        final surveyResponses = await _firestore
            .collection('survey_responses')
            .where('userId', isEqualTo: userId)
            .get();
        
        for (var doc in surveyResponses.docs) {
          await doc.reference.delete();
        }
        print('Deleted ${surveyResponses.docs.length} survey responses');
      } catch (e) {
        print('Warning: Could not delete survey responses: $e');
      }

      // 2. Note: Profile image deletion from Cloudinary would require additional setup
      // For now, we'll leave the image in Cloudinary to avoid API key requirements
      if (userToDelete.profileImageUrl != null && userToDelete.profileImageUrl!.isNotEmpty) {
        print('Note: Profile image remains in Cloudinary (${userToDelete.profileImageUrl})');
      }

      // 3. Delete user from role-based table
      bool success = await UnifiedUserService().deleteUserById(userId);
      if (!success) {
        throw Exception('Failed to delete user from role-based table');
      }
      print('Deleted user from role-based table');

      // Note: Old users table is no longer used - all data is in role-based tables

      print('User deletion completed. Note: Firebase Auth account may still exist');
      return true;
    } catch (e) {
      print('Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }
} 