import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyResponseModel {
  final String id;
  final String userId;
  final String userUid;
  final String fullName;
  final String college;
  final String course;
  final String batchYear;
  final Map<String, dynamic> responses; // Dynamic responses keyed by question ID
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  SurveyResponseModel({
    required this.id,
    required this.userId,
    required this.userUid,
    required this.fullName,
    required this.college,
    required this.course,
    required this.batchYear,
    required this.responses,
    required this.isCompleted,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  // Create from Firestore document
  factory SurveyResponseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return SurveyResponseModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userUid: data['userUid'] ?? '',
      fullName: data['fullName'] ?? '',
      college: data['college'] ?? '',
      course: data['course'] ?? '',
      batchYear: data['batchYear'] ?? '',
      responses: Map<String, dynamic>.from(data['responses'] ?? {}),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userUid': userUid,
      'fullName': fullName,
      'college': college,
      'course': course,
      'batchYear': batchYear,
      'responses': responses,
      'isCompleted': isCompleted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'completedAt': completedAt,
    };
  }

  // Create a copy with updated values
  SurveyResponseModel copyWith({
    String? id,
    String? userId,
    String? userUid,
    String? fullName,
    String? college,
    String? course,
    String? batchYear,
    Map<String, dynamic>? responses,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return SurveyResponseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userUid: userUid ?? this.userUid,
      fullName: fullName ?? this.fullName,
      college: college ?? this.college,
      course: course ?? this.course,
      batchYear: batchYear ?? this.batchYear,
      responses: responses ?? this.responses,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Helper method to get a response value by question ID
  T? getResponse<T>(String questionId) {
    return responses[questionId] as T?;
  }

  // Helper method to set a response value
  SurveyResponseModel setResponse(String questionId, dynamic value) {
    final newResponses = Map<String, dynamic>.from(responses);
    newResponses[questionId] = value;
    
    return copyWith(
      responses: newResponses,
      updatedAt: DateTime.now(),
    );
  }

  // Helper method to remove a response
  SurveyResponseModel removeResponse(String questionId) {
    final newResponses = Map<String, dynamic>.from(responses);
    newResponses.remove(questionId);
    
    return copyWith(
      responses: newResponses,
      updatedAt: DateTime.now(),
    );
  }

  // Helper method to check if a required question is answered
  bool isQuestionAnswered(String questionId) {
    return responses.containsKey(questionId) && 
           responses[questionId] != null && 
           responses[questionId] != '';
  }

  // Helper method to get completion percentage
  double getCompletionPercentage(List<String> requiredQuestionIds) {
    if (requiredQuestionIds.isEmpty) return 1.0;
    
    int answeredCount = 0;
    for (String questionId in requiredQuestionIds) {
      if (isQuestionAnswered(questionId)) {
        answeredCount++;
      }
    }
    
    return answeredCount / requiredQuestionIds.length;
  }
} 