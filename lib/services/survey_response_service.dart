import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_response_model.dart';
import 'unified_user_service.dart';
import '../models/survey_question_model.dart';
import '../models/user_role.dart';

class SurveyResponseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'survey_responses';

  // Submit or update a survey response
  Future<void> submitSurveyResponse(SurveyResponseModel response) async {
    try {
      if (response.id.isEmpty) {
        // Create new response
        DocumentReference docRef = await _firestore.collection(_collection).add(response.toMap());
        
        // Update the response with its ID
        await docRef.update({'id': docRef.id});
        
        // Update the user's survey completion status in role-based table
        try {
          final user = await UnifiedUserService().getUserData(response.userId);
          if (user != null) {
            final updatedUser = user.copyWith(
              hasCompletedSurvey: response.isCompleted,
              surveyCompletedAt: response.isCompleted ? response.completedAt : null,
            );
            await UnifiedUserService().updateUser(updatedUser);
            print('✅ Survey status updated in role-based table');
          } else {
            print('❌ User not found in role-based tables: ${response.userId}');
          }
        } catch (e) {
          print('❌ Error updating survey status: $e');
        }
      } else {
        // Update existing response
        await _firestore.collection(_collection).doc(response.id).update(response.toMap());
        
        // Update the user's survey completion status in role-based table
        try {
          final user = await UnifiedUserService().getUserData(response.userId);
          if (user != null) {
            final updatedUser = user.copyWith(
              hasCompletedSurvey: response.isCompleted,
              surveyCompletedAt: response.isCompleted ? response.completedAt : null,
            );
            await UnifiedUserService().updateUser(updatedUser);
            print('✅ Survey status updated in role-based table');
          } else {
            print('❌ User not found in role-based tables: ${response.userId}');
          }
        } catch (e) {
          print('❌ Error updating survey status: $e');
        }
      }
    } catch (e) {
      print('Error submitting survey response: $e');
      throw Exception('Failed to submit survey response');
    }
  }

  // Get survey response by user ID
  Future<SurveyResponseModel?> getSurveyResponseByUserId(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;
      
      return SurveyResponseModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      print('Error getting survey response: $e');
      return null;
    }
  }

  // Save partial response (for auto-save functionality)
  Future<void> savePartialResponse(SurveyResponseModel response) async {
    try {
      final partialResponse = response.copyWith(
        isCompleted: false,
        updatedAt: DateTime.now(),
      );
      
      await submitSurveyResponse(partialResponse);
    } catch (e) {
      print('Error saving partial response: $e');
      throw Exception('Failed to save partial response');
    }
  }

  // Get all survey responses (for admin)
  Future<List<SurveyResponseModel>> getAllSurveyResponses() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyResponseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all survey responses: $e');
      return [];
    }
  }

  // Get completed survey responses only
  Future<List<SurveyResponseModel>> getCompletedSurveyResponses() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyResponseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting completed survey responses: $e');
      return [];
    }
  }

  // Get survey responses by college
  Future<List<SurveyResponseModel>> getSurveyResponsesByCollege(String college) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('college', isEqualTo: college)
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyResponseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting survey responses by college: $e');
      return [];
    }
  }

  // Get survey responses by batch year
  Future<List<SurveyResponseModel>> getSurveyResponsesByBatchYear(String batchYear) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('batchYear', isEqualTo: batchYear)
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyResponseModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting survey responses by batch year: $e');
      return [];
    }
  }

  // Delete a survey response
  Future<void> deleteSurveyResponse(String responseId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(responseId).delete();
      
      // Update the user's survey completion status in role-based table
      try {
        final user = await UnifiedUserService().getUserData(userId);
        if (user != null) {
          final updatedUser = user.copyWith(
            hasCompletedSurvey: false,
            surveyCompletedAt: null,
          );
          await UnifiedUserService().updateUser(updatedUser);
          print('✅ Survey status updated in role-based table');
        } else {
          print('❌ User not found in role-based tables: $userId');
        }
      } catch (e) {
        print('❌ Error updating survey status: $e');
      }
    } catch (e) {
      print('Error deleting survey response: $e');
      throw Exception('Failed to delete survey response');
    }
  }

  // Get survey statistics
  Future<Map<String, dynamic>> getSurveyStatistics() async {
    try {
      final allResponses = await getAllSurveyResponses();
      final completedResponses = allResponses.where((r) => r.isCompleted).toList();
      
      // Get total users count from role-based collections
      final allUsers = await UnifiedUserService().getAllUsers();
      int totalAlumni = allUsers.where((user) => user.role == UserRole.alumni).length;
      int totalResponses = allResponses.length;
      int completedCount = completedResponses.length;
      int partialCount = totalResponses - completedCount;
      
      // Calculate completion rate
      double completionRate = totalAlumni > 0 ? completedCount / totalAlumni : 0.0;
      
      // Get college-wise statistics
      Map<String, int> collegeStats = {};
      for (var response in completedResponses) {
        collegeStats[response.college] = (collegeStats[response.college] ?? 0) + 1;
      }
      
      // Get batch year statistics
      Map<String, int> batchYearStats = {};
      for (var response in completedResponses) {
        batchYearStats[response.batchYear] = (batchYearStats[response.batchYear] ?? 0) + 1;
      }
      
      return {
        'totalAlumni': totalAlumni,
        'totalResponses': totalResponses,
        'completedResponses': completedCount,
        'partialResponses': partialCount,
        'completionRate': completionRate,
        'collegeStats': collegeStats,
        'batchYearStats': batchYearStats,
      };
    } catch (e) {
      print('Error getting survey statistics: $e');
      return {
        'totalAlumni': 0,
        'totalResponses': 0,
        'completedResponses': 0,
        'partialResponses': 0,
        'completionRate': 0.0,
        'collegeStats': {},
        'batchYearStats': {},
      };
    }
  }

  // Generate analytics for specific questions
  Future<Map<String, dynamic>> getQuestionAnalytics(String questionId, QuestionType questionType) async {
    try {
      final responses = await getCompletedSurveyResponses();
      Map<String, dynamic> analytics = {};
      
      switch (questionType) {
        case QuestionType.multipleChoice:
        case QuestionType.dropdown:
          Map<String, int> optionCounts = {};
          for (var response in responses) {
            final answer = response.getResponse<String>(questionId);
            if (answer != null && answer.isNotEmpty) {
              optionCounts[answer] = (optionCounts[answer] ?? 0) + 1;
            }
          }
          analytics = {
            'type': 'multipleChoice',
            'totalResponses': responses.length,
            'optionCounts': optionCounts,
          };
          break;
          
        case QuestionType.checkboxList:
          Map<String, int> optionCounts = {};
          for (var response in responses) {
            final answers = response.getResponse<List>(questionId);
            if (answers != null) {
              for (var answer in answers) {
                if (answer != null && answer.toString().isNotEmpty) {
                  optionCounts[answer.toString()] = (optionCounts[answer.toString()] ?? 0) + 1;
                }
              }
            }
          }
          analytics = {
            'type': 'multipleChoice',
            'totalResponses': responses.length,
            'optionCounts': optionCounts,
          };
          break;
          
        case QuestionType.rating:
          List<int> ratings = [];
          for (var response in responses) {
            final rating = response.getResponse<int>(questionId);
            if (rating != null) {
              ratings.add(rating);
            }
          }
          
          double average = ratings.isNotEmpty ? ratings.reduce((a, b) => a + b) / ratings.length : 0.0;
          Map<int, int> ratingCounts = {};
          for (var rating in ratings) {
            ratingCounts[rating] = (ratingCounts[rating] ?? 0) + 1;
          }
          
          analytics = {
            'type': 'rating',
            'totalResponses': responses.length,
            'average': average,
            'ratingCounts': ratingCounts,
            'allRatings': ratings,
          };
          break;
          
        case QuestionType.numberInput:
          List<double> numbers = [];
          for (var response in responses) {
            final number = response.getResponse<num>(questionId);
            if (number != null) {
              numbers.add(number.toDouble());
            }
          }
          
          double average = numbers.isNotEmpty ? numbers.reduce((a, b) => a + b) / numbers.length : 0.0;
          double min = numbers.isNotEmpty ? numbers.reduce((a, b) => a < b ? a : b) : 0.0;
          double max = numbers.isNotEmpty ? numbers.reduce((a, b) => a > b ? a : b) : 0.0;
          
          analytics = {
            'type': 'number',
            'totalResponses': responses.length,
            'average': average,
            'min': min,
            'max': max,
            'allNumbers': numbers,
          };
          break;
          
        case QuestionType.textInput:
        case QuestionType.textArea:
          List<String> textResponses = [];
          for (var response in responses) {
            final text = response.getResponse<String>(questionId);
            if (text != null && text.isNotEmpty) {
              textResponses.add(text);
            }
          }
          
          analytics = {
            'type': 'text',
            'totalResponses': responses.length,
            'textResponses': textResponses,
            'responseCount': textResponses.length,
          };
          break;
          
        default:
          analytics = {
            'type': 'other',
            'totalResponses': responses.length,
            'message': 'Analytics not supported for this question type',
          };
      }
      
      return analytics;
    } catch (e) {
      print('Error getting question analytics: $e');
      return {
        'type': 'error',
        'totalResponses': 0,
        'error': e.toString(),
      };
    }
  }

  // Export survey responses to CSV format
  Future<String> exportResponsesToCSV(List<SurveyQuestionModel> questions) async {
    try {
      final responses = await getCompletedSurveyResponses();
      
      // Build CSV headers
      List<String> headers = [
        'Response ID',
        'User ID',
        'Full Name',
        'College',
        'Course',
        'Batch Year',
        'Completed At',
      ];
      
      // Add question headers
      for (var question in questions) {
        if (question.type != QuestionType.section) {
          headers.add(question.title);
        }
      }
      
      // Build CSV rows
      List<List<String>> csvRows = [headers];
      
      for (var response in responses) {
        List<String> row = [
          response.id,
          response.userId,
          response.fullName,
          response.college,
          response.course,
          response.batchYear,
          response.completedAt?.toIso8601String() ?? '',
        ];
        
        // Add response values
        for (var question in questions) {
          if (question.type != QuestionType.section) {
            final answer = response.getResponse<dynamic>(question.id);
            String cellValue = '';
            
            if (answer != null) {
              if (answer is List) {
                cellValue = answer.join('; ');
              } else {
                cellValue = answer.toString();
              }
            }
            
            // Escape commas in cell values
            if (cellValue.contains(',')) {
              cellValue = '"$cellValue"';
            }
            
            row.add(cellValue);
          }
        }
        
        csvRows.add(row);
      }
      
      // Convert to CSV string
      return csvRows.map((row) => row.join(',')).join('\n');
    } catch (e) {
      print('Error exporting responses to CSV: $e');
      throw Exception('Failed to export responses');
    }
  }
} 