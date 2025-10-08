import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'unified_user_service.dart';

class AdminInitializationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Parse full name into separate name components
  static Map<String, String?> _parseFullName(String fullName) {
    final nameParts = fullName.trim().split(' ');
    
    if (nameParts.isEmpty) {
      return {'firstName': '', 'lastName': '', 'middleName': null, 'suffix': null};
    }
    
    String firstName = nameParts[0];
    String lastName = '';
    String? middleName;
    String? suffix;
    
    if (nameParts.length == 1) {
      lastName = '';
    } else if (nameParts.length == 2) {
      lastName = nameParts[1];
    } else if (nameParts.length == 3) {
      middleName = nameParts[1];
      lastName = nameParts[2];
    } else {
      // For names with more than 3 parts, assume middle parts are middle names
      // and last part is last name
      middleName = nameParts.sublist(1, nameParts.length - 1).join(' ');
      lastName = nameParts.last;
    }
    
    // Check for common suffixes
    final commonSuffixes = ['Jr.', 'Sr.', 'III', 'IV', 'Jr', 'Sr'];
    for (final suffix_check in commonSuffixes) {
      if (lastName.endsWith(suffix_check)) {
        suffix = suffix_check;
        lastName = lastName.replaceAll(suffix_check, '').trim().replaceAll(',', '');
        break;
      }
    }
    
    return {
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName?.isEmpty == true ? null : middleName,
      'suffix': suffix,
    };
  }

  // Default admin accounts for department deans
  static final List<Map<String, dynamic>> _defaultAdmins = [
    {
      'fullName': 'Dr. Ernesto T. Anacta',
      'email': 'ernesto.anacta@essu.edu.ph',
      'college': 'College of Engineering',
      'position': 'Dean',
      'studentId': 'ADMIN-ENG-001',
    },
    {
      'fullName': 'Dr. Anthony D. Cuanico',
      'email': 'anthony.cuanico@essu.edu.ph',
      'college': 'College of Arts and Sciences',
      'position': 'Dean',
      'studentId': 'ADMIN-CAS-001',
    },
    {
      'fullName': 'Dr. Arnel A. Balbin',
      'email': 'arnel.balbin@essu.edu.ph',
      'college': 'College of Education',
      'position': 'Dean',
      'studentId': 'ADMIN-COED-001',
    },
    {
      'fullName': 'Dr. Dymphna Ann C. Calumpiano',
      'email': 'dymphna.calumpiano@essu.edu.ph',
      'college': 'College of Business Administration',
      'position': 'Dean',
      'studentId': 'ADMIN-CBA-001',
    },
    {
      'fullName': 'Dr. Rowena P. Capada',
      'email': 'rowena.capada@essu.edu.ph',
      'college': 'College of Technology',
      'position': 'Dean',
      'studentId': 'ADMIN-COT-001',
    },
    {
      'fullName': 'Dr. Judith Eljera',
      'email': 'judith.eljera@essu.edu.ph',
      'college': 'College of Agriculture and Fisheries',
      'position': 'Dean',
      'studentId': 'ADMIN-CAF-001',
    },
    {
      'fullName': 'Mark Bency M. Elpedes',
      'email': 'mark.elpedes@essu.edu.ph',
      'college': 'College of Nursing and Allied Sciences',
      'position': 'Dean',
      'studentId': 'ADMIN-CNAS-001',
    },
    {
      'fullName': 'Dr. Jeffrey A. Co',
      'email': 'jeffrey.co@essu.edu.ph',
      'college': 'College of Computing Studies',
      'position': 'Dean',
      'studentId': 'ADMIN-CCS-001',
    },
    {
      'fullName': 'Dr. Alirose A. Lalosa',
      'email': 'alirose.lalosa@essu.edu.ph',
      'college': 'College of Hospitality Management',
      'position': 'Dean',
      'studentId': 'ADMIN-CHM-001',
    },
    {
      'fullName': 'Dr. Eleazar S. Balbada',
      'email': 'eleazar.balbada@essu.edu.ph',
      'college': 'College of Criminal Justice Education',
      'position': 'Dean',
      'studentId': 'ADMIN-CCJE-001',
    },
    {
      'fullName': 'Prof. Mark Van P. Macawile',
      'email': 'mark.macawile@essu.edu.ph',
      'college': 'Student and Alumni Affairs',
      'position': 'Dean',
      'studentId': 'ADMIN-SAA-001',
    },
    {
      'fullName': 'Engr. Arnaldo N. Villalon',
      'email': 'arnaldo.villalon@essu.edu.ph',
      'college': 'External Programs Offerings',
      'position': 'Dean',
      'studentId': 'ADMIN-EPO-001',
    },
  ];


  /// Initialize all default admin accounts
  static Future<void> initializeDefaultAdmins() async {
    try {
      debugPrint('Starting admin initialization...');
      
      // Check if initialization has already been done
      final initDoc = await _firestore.collection('system').doc('admin_initialization').get();
      if (initDoc.exists && initDoc.data()?['completed'] == true) {
        debugPrint('Admin initialization already completed.');
        // Still check for missing Firestore documents
        await _checkForMissingFirestoreDocuments();
        return;
      }

      // Note: We don't store current user to avoid session disruption
      
      int createdCount = 0;
      int existingCount = 0;
      
      for (final adminData in _defaultAdmins) {
        try {
          // Check if Firestore user document already exists
          final firestoreUserExists = await _checkUserExists(adminData['email']);
          if (firestoreUserExists) {
            debugPrint('Admin already exists in Firestore: ${adminData['email']}');
            existingCount++;
            continue;
          }

          // Check if Firebase Auth user exists
          final authUserExists = await _checkAuthUserExists(adminData['email']);
          
          if (authUserExists) {
            // Auth user exists but Firestore document doesn't - skip for now
            // We'll handle this with the manual createMissingUserProfiles method
            debugPrint('Auth user exists but no Firestore document for: ${adminData['email']}');
            debugPrint('Use "Create Missing User Profiles" button to create Firestore documents');
            continue;
          } else {
            // Neither exists - skip creating new accounts to avoid disrupting current session
            debugPrint('Admin account does not exist: ${adminData['email']} - skipping creation to avoid session disruption');
            continue;
          }
          
          
        } catch (e) {
          debugPrint('Error setting up admin ${adminData['email']}: $e');
          // Continue with next admin even if one fails
        }
      }

      // Note: We don't sign out here to avoid disrupting the current user's session
      // The admin initialization should not affect the currently logged-in user
      
      // Mark initialization as completed
      await _firestore.collection('system').doc('admin_initialization').set({
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'createdCount': createdCount,
        'existingCount': existingCount,
        'totalAdmins': _defaultAdmins.length,
      });

      debugPrint('Admin initialization completed. Created: $createdCount, Existing: $existingCount');
      
    } catch (e) {
      debugPrint('Error during admin initialization: $e');
      // Don't throw error to prevent app startup failure
    }
  }

  /// Check if a user with the given email already exists in Firestore
  static Future<bool> _checkUserExists(String email) async {
    try {
      // Check in role-based collections
      final allUsers = await UnifiedUserService().getAllUsers();
      return allUsers.any((user) => user.email == email);
    } catch (e) {
      debugPrint('Error checking if user exists in Firestore: $e');
      return false;
    }
  }

  /// Check if a Firebase Auth user exists with the given email
  static Future<bool> _checkAuthUserExists(String email) async {
    try {
      // Try to get user by email - this will throw if user doesn't exist
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      // If error occurs, user likely doesn't exist
      return false;
    }
  }


    /// Create Firestore user documents for existing Auth users
  static Future<void> createMissingUserProfiles() async {
    try {
      debugPrint('=== STARTING: Creating missing user profiles for existing admin accounts ===');
      
      // Get all existing users from role-based collections to check which ones are missing
      final existingUsers = await UnifiedUserService().getAllUsers();
      final existingEmails = existingUsers
          .map((user) => user.email)
          .toSet();
      
      debugPrint('Found ${existingEmails.length} existing user profiles in Firestore');
      debugPrint('Checking ${_defaultAdmins.length} default admin accounts');
      
      int createdCount = 0;
      
      for (final adminData in _defaultAdmins) {
        final email = adminData['email'] as String;
        
        // Skip if user profile already exists
        if (existingEmails.contains(email)) {
          debugPrint('User profile already exists for: $email');
          continue;
        }
        
        try {
          debugPrint('Creating user profile for: $email');
          
          // Parse the full name into separate components
          final nameParts = _parseFullName(adminData['fullName']);
          
          final userModel = UserModel(
            uid: '', // Will be generated by UnifiedUserService
            email: email,
            firstName: nameParts['firstName']!,
            lastName: nameParts['lastName']!,
            middleName: nameParts['middleName'],
            suffix: nameParts['suffix'],
            studentId: '', // Admins don't have student IDs
            facultyId: adminData['studentId'], // Use as faculty ID for admins
            course: adminData['position'],
            batchYear: DateTime.now().year.toString(),
            college: adminData['college'],
            role: UserRole.admin,
            phone: null,
            currentOccupation: adminData['position'],
            company: 'Eastern Samar State University',
            location: 'Borongan City, Eastern Samar',
          );

          // Create in role-based table
          final success = await UnifiedUserService().createUser(userModel);
          if (success) {
            debugPrint('✅ Successfully created admin profile in role-based table: ${adminData['fullName']} ($email)');
            createdCount++;
          } else {
            debugPrint('❌ Failed to create admin profile: ${adminData['fullName']} ($email)');
          }
          
        } catch (e) {
          debugPrint('❌ Error creating profile for $email: $e');
        }
      }
      
      debugPrint('=== COMPLETED: Created $createdCount missing user profiles ===');
      
      if (createdCount == 0) {
        debugPrint('No missing profiles found - all admin accounts already have Firestore documents');
      }
      
    } catch (e) {
      debugPrint('=== ERROR: Error creating missing user profiles: $e ===');
      rethrow;
    }
  }

  /// Reset admin passwords (for super admin use)
  static Future<void> resetAdminPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } catch (e) {
      debugPrint('Error sending password reset email to $email: $e');
      rethrow;
    }
  }

  /// Get list of all default admin emails
  static List<String> getDefaultAdminEmails() {
    return _defaultAdmins.map((admin) => admin['email'] as String).toList();
  }

  /// Get default admin data by email
  static Map<String, dynamic>? getDefaultAdminData(String email) {
    try {
      return _defaultAdmins.firstWhere((admin) => admin['email'] == email);
    } catch (e) {
      return null;
    }
  }

  /// Check initialization status
  static Future<Map<String, dynamic>?> getInitializationStatus() async {
    try {
      final doc = await _firestore.collection('system').doc('admin_initialization').get();
      return doc.data();
    } catch (e) {
      debugPrint('Error getting initialization status: $e');
      return null;
    }
  }

  /// Check for missing Firestore documents for existing Auth users
  static Future<void> _checkForMissingFirestoreDocuments() async {
    try {
      debugPrint('Checking for missing Firestore documents...');
      
      for (final adminData in _defaultAdmins) {
        final email = adminData['email'] as String;
        
        // Check if Auth user exists
        final authUserExists = await _checkAuthUserExists(email);
        if (!authUserExists) continue;
        
        // Check if Firestore document exists
        final firestoreUserExists = await _checkUserExists(email);
        if (!firestoreUserExists) {
          debugPrint('Auth user exists but no Firestore document for: $email');
          debugPrint('Use "Create Missing User Profiles" button to create Firestore documents');
        }
      }
    } catch (e) {
      debugPrint('Error checking for missing Firestore documents: $e');
    }
  }

  /// Force re-initialization (for development/testing)
  static Future<void> forceReinitialize() async {
    try {
      // Delete initialization marker
      await _firestore.collection('system').doc('admin_initialization').delete();
      
      // Run initialization again
      await initializeDefaultAdmins();
    } catch (e) {
      debugPrint('Error during force re-initialization: $e');
      rethrow;
    }
  }
} 