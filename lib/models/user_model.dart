import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class UserModel {
  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffix;
  final String studentId;
  final String? facultyId; // For admin/college admin users
  final String course;
  final String batchYear;
  final String college;
  final UserRole role;
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
  
  // User settings fields (migrated from user_settings collection)
  final bool darkMode;
  final String privacyLevel;
  final Map<String, bool> fieldVisibility;

  UserModel({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.suffix,
    required this.studentId,
    this.facultyId,
    required this.course,
    required this.batchYear,
    required this.college,
    this.role = UserRole.alumni,
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
      'facultyId': false,    // Hidden by default
      'phone': false,        // Hidden by default
      'bio': true,           // Visible by default
      'course': true,        // Visible by default
      'batchYear': true,     // Visible by default
      'company': true,       // Visible by default
      'currentOccupation': true, // Visible by default
      'location': true,      // Visible by default
    };
  }

  // Create a UserModel from a Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    final studentIdValue = data['studentId'] ?? '';
    final facultyIdValue = data['facultyId'];
    final roleValue = UserRole.fromString(data['role'] ?? 'alumni');
    
    print('📦 UserModel.fromFirestore - uid: ${doc.id}, role: $roleValue, studentId: "$studentIdValue", facultyId: "$facultyIdValue"');
    
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      middleName: data['middleName'],
      suffix: data['suffix'],
      studentId: studentIdValue,
      facultyId: facultyIdValue,
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
      role: UserRole.fromString(data['role'] ?? 'alumni'),
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

  // Convert UserModel to a Map for Firestore
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
      'role': role.toString().split('.').last,
      'hasCompletedSurvey': hasCompletedSurvey,
      'darkMode': darkMode,
      'privacyLevel': privacyLevel,
      'fieldVisibility': fieldVisibility,
    };
    
    // Add optional fields only if they are not null
    if (middleName != null) map['middleName'] = middleName;
    if (suffix != null) map['suffix'] = suffix;
    if (facultyId != null) map['facultyId'] = facultyId;
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

  // Create a copy of UserModel with some fields updated
  UserModel copyWith({
    String? uid,
    String? email,
    String? firstName,
    String? lastName,
    String? middleName,
    String? suffix,
    String? studentId,
    String? facultyId,
    String? course,
    String? batchYear,
    String? college,
    UserRole? role,
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
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      middleName: middleName ?? this.middleName,
      suffix: suffix ?? this.suffix,
      studentId: studentId ?? this.studentId,
      facultyId: facultyId ?? this.facultyId,
      course: course ?? this.course,
      batchYear: batchYear ?? this.batchYear,
      college: college ?? this.college,
      role: role ?? this.role,
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

  // Helper getter to construct full name from separate parts
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
  UserModel updateFieldVisibility(String field, bool isVisible) {
    if (!fieldVisibility.containsKey(field)) return this;
    
    Map<String, bool> updatedVisibility = Map.from(fieldVisibility);
    updatedVisibility[field] = isVisible;
    
    return copyWith(fieldVisibility: updatedVisibility);
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final studentIdValue = map['studentId'] ?? '';
    final facultyIdValue = map['facultyId'];
    final roleValue = UserRole.fromString(map['role'] ?? 'alumni');
    
    print('📦 UserModel.fromMap - uid: ${map['uid']}, role: $roleValue, studentId: "$studentIdValue", facultyId: "$facultyIdValue"');
    
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      middleName: map['middleName'],
      suffix: map['suffix'],
      studentId: studentIdValue,
      facultyId: facultyIdValue,
      course: map['course'] ?? '',
      batchYear: map['batchYear'] ?? '',
      college: map['college'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      currentOccupation: map['currentOccupation'],
      company: map['company'],
      location: map['location'],
      bio: map['bio'],
      phone: map['phone'],
      facebookUrl: map['facebookUrl'],
      instagramUrl: map['instagramUrl'],
      hasCompletedSurvey: map['hasCompletedSurvey'] ?? false,
      surveyCompletedAt: (map['surveyCompletedAt'] as Timestamp?)?.toDate(),
      role: UserRole.fromString(map['role'] ?? 'alumni'),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
      darkMode: map['darkMode'] ?? false,
      privacyLevel: map['privacyLevel'] ?? 'alumni-only',
      fieldVisibility: _parseFieldVisibility(map['fieldVisibility']),
    );
  }
} 