import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';
import 'user_model.dart';

class AlumniModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix;
  final String studentId;
  final String course;
  final String batchYear;
  final String college;
  final String? profileImageUrl;
  final String? currentOccupation;
  final String? company;
  final String? location;
  final String? bio;
  final String? phone;
  final String? facebookUrl;
  final String? instagramUrl;
  final bool hasCompletedSurvey;
  final DateTime? surveyCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLogin;
  
  // User settings fields
  final bool darkMode;
  final String privacyLevel;
  final Map<String, bool> fieldVisibility;

  AlumniModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.suffix,
    required this.studentId,
    required this.course,
    required this.batchYear,
    required this.college,
    this.profileImageUrl,
    this.currentOccupation,
    this.company,
    this.location,
    this.bio,
    this.phone,
    this.facebookUrl,
    this.instagramUrl,
    this.hasCompletedSurvey = false,
    this.surveyCompletedAt,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
    this.darkMode = false,
    this.privacyLevel = 'alumni-only',
    Map<String, bool>? fieldVisibility,
  }) : fieldVisibility = fieldVisibility ?? _defaultFieldVisibility();

  // Default field visibility settings
  static Map<String, bool> _defaultFieldVisibility() {
    return {
      'fullName': true,      // Always visible
      'email': false,        // Hidden by default
      'studentId': false,    // Hidden by default
      'phone': false,        // Hidden by default
      'bio': true,           // Visible by default
      'course': true,        // Visible by default
      'batchYear': true,     // Visible by default
      'company': true,       // Visible by default
      'currentOccupation': true, // Visible by default
      'location': true,      // Visible by default
    };
  }

  // Create from Firestore document
  factory AlumniModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return AlumniModel(
      uid: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      middleName: data['middleName'],
      suffix: data['suffix'],
      studentId: data['studentId'] ?? '',
      course: data['course'] ?? '',
      batchYear: data['batchYear'] ?? '',
      college: data['college'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      currentOccupation: data['currentOccupation'],
      company: data['company'],
      location: data['location'],
      bio: data['bio'],
      phone: data['phone'],
      facebookUrl: data['facebookUrl'],
      instagramUrl: data['instagramUrl'],
      hasCompletedSurvey: data['hasCompletedSurvey'] ?? false,
      surveyCompletedAt: data['surveyCompletedAt'] != null 
          ? (data['surveyCompletedAt'] as Timestamp).toDate() 
          : null,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      lastLogin: data['lastLogin'] != null 
          ? (data['lastLogin'] as Timestamp).toDate() 
          : null,
      darkMode: data['darkMode'] ?? false,
      privacyLevel: data['privacyLevel'] ?? 'alumni-only',
      fieldVisibility: _parseFieldVisibility(data['fieldVisibility']),
    );
  }

  // Parse field visibility from Firestore data
  static Map<String, bool> _parseFieldVisibility(dynamic data) {
    Map<String, bool> fieldVisibility = _defaultFieldVisibility();
    if (data != null && data is Map<String, dynamic>) {
      data.forEach((key, value) {
        if (fieldVisibility.containsKey(key) && value is bool) {
          fieldVisibility[key] = value;
        }
      });
    }
    return fieldVisibility;
  }

  // Convert to a Map for Firestore
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = {
      'uid': uid,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'studentId': studentId,
      'course': course,
      'batchYear': batchYear,
      'college': college,
      'hasCompletedSurvey': hasCompletedSurvey,
      'darkMode': darkMode,
      'privacyLevel': privacyLevel,
      'fieldVisibility': fieldVisibility,
    };
    
    // Add optional fields only if they are not null
    if (middleName != null) map['middleName'] = middleName;
    if (suffix != null) map['suffix'] = suffix;
    if (profileImageUrl != null) map['profileImageUrl'] = profileImageUrl;
    if (currentOccupation != null) map['currentOccupation'] = currentOccupation;
    if (company != null) map['company'] = company;
    if (location != null) map['location'] = location;
    if (bio != null) map['bio'] = bio;
    if (phone != null) map['phone'] = phone;
    if (facebookUrl != null) map['facebookUrl'] = facebookUrl;
    if (instagramUrl != null) map['instagramUrl'] = instagramUrl;
    if (surveyCompletedAt != null) map['surveyCompletedAt'] = surveyCompletedAt;
    
    // Add timestamps
    if (createdAt != null) {
      map['createdAt'] = createdAt;
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    
    map['updatedAt'] = FieldValue.serverTimestamp();
    
    if (lastLogin != null) map['lastLogin'] = lastLogin;
    
    return map;
  }

  // Create a copy with updated values
  AlumniModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    String? studentId,
    String? course,
    String? batchYear,
    String? college,
    String? profileImageUrl,
    String? currentOccupation,
    String? company,
    String? location,
    String? bio,
    String? phone,
    String? facebookUrl,
    String? instagramUrl,
    bool? hasCompletedSurvey,
    DateTime? surveyCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    bool? darkMode,
    String? privacyLevel,
    Map<String, bool>? fieldVisibility,
  }) {
    return AlumniModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      suffix: suffix ?? this.suffix,
      studentId: studentId ?? this.studentId,
      course: course ?? this.course,
      batchYear: batchYear ?? this.batchYear,
      college: college ?? this.college,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      currentOccupation: currentOccupation ?? this.currentOccupation,
      company: company ?? this.company,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      hasCompletedSurvey: hasCompletedSurvey ?? this.hasCompletedSurvey,
      surveyCompletedAt: surveyCompletedAt ?? this.surveyCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
      darkMode: darkMode ?? this.darkMode,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      fieldVisibility: fieldVisibility ?? Map.from(this.fieldVisibility),
    );
  }

  // Helper getter to construct full name
  String get fullName {
    final List<String> nameParts = [
      firstName,
      if (middleName != null && middleName!.isNotEmpty) middleName!,
      lastName,
      if (suffix != null && suffix!.isNotEmpty) suffix!,
    ];
    return nameParts.join(' ');
  }

  // Helper to update field visibility
  AlumniModel updateFieldVisibility(String field, bool isVisible) {
    if (!fieldVisibility.containsKey(field)) return this;
    
    Map<String, bool> updatedVisibility = Map.from(fieldVisibility);
    updatedVisibility[field] = isVisible;
    
    return copyWith(fieldVisibility: updatedVisibility);
  }

  // Convert to UserModel for compatibility
  UserModel toUserModel() {
    return UserModel(
      uid: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      middleName: middleName,
      suffix: suffix,
      studentId: studentId,
      course: course,
      batchYear: batchYear,
      college: college,
      role: UserRole.alumni,
      profileImageUrl: profileImageUrl,
      currentOccupation: currentOccupation,
      company: company,
      location: location,
      bio: bio,
      phone: phone,
      facebookUrl: facebookUrl,
      instagramUrl: instagramUrl,
      hasCompletedSurvey: hasCompletedSurvey,
      surveyCompletedAt: surveyCompletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastLogin: lastLogin,
      darkMode: darkMode,
      privacyLevel: privacyLevel,
      fieldVisibility: fieldVisibility,
    );
  }
}
