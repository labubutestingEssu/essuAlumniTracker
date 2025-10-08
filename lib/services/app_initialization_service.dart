import 'package:cloud_firestore/cloud_firestore.dart';
import 'survey_question_service.dart';
import 'admin_initialization_service.dart';
import '../models/survey_question_model.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final SurveyQuestionService _surveyQuestionService = SurveyQuestionService();
  bool _isInitialized = false;

  /// Initialize the app with default data if needed
  Future<void> initializeApp() async {
    if (_isInitialized) return;

    try {
      print('Initializing app...');
      
      // Initialize survey questions if they don't exist
      await _initializeSurveyQuestions();
      
      // Initialize default admin accounts - DISABLED (already created)
      // await _initializeAdminAccounts();
      
      _isInitialized = true;
      print('App initialization completed successfully');
    } catch (e) {
      print('Error during app initialization: $e');
      // Don't throw error, let app continue but log the issue
    }
  }

  /// Initialize default admin accounts - DISABLED (already created)
  // Future<void> _initializeAdminAccounts() async {
  //   try {
  //     print('Initializing default admin accounts...');
  //     await AdminInitializationService.initializeDefaultAdmins();
  //     print('Admin accounts initialization completed');
  //   } catch (e) {
  //     print('Error initializing admin accounts: $e');
  //     // Log error but don't throw - this is not critical for app startup
  //   }
  // }

  /// Initialize default survey questions if none exist
  /// This should only be called when an admin user is authenticated
  Future<void> _initializeSurveyQuestions() async {
    try {
      print('Checking for existing survey questions...');
      
      // Check if survey questions already exist
      final existingQuestions = await _surveyQuestionService.getAllQuestions();
      
      if (existingQuestions.isEmpty) {
        print('No survey questions found. Survey questions will be initialized when an admin user accesses the system.');
        // Don't initialize here - let admin users initialize when they first access the system
      } else {
        print('Survey questions already exist (${existingQuestions.length} questions found)');
      }
    } catch (e) {
      print('Error checking survey questions: $e');
      // Log error but don't throw - this is not critical for app startup
    }
  }

  /// Initialize survey questions for admin users
  Future<void> initializeSurveyQuestionsForAdmin() async {
    try {
      print('Admin user detected. Checking survey questions...');
      
      // Check if survey questions already exist
      final existingQuestions = await _surveyQuestionService.getAllQuestions();
      
      if (existingQuestions.isEmpty) {
        print('No survey questions found. Initializing default questions...');
        await _surveyQuestionService.initializeDefaultQuestions();
        print('Default survey questions initialized successfully');
      } else {
        print('Survey questions already exist (${existingQuestions.length} questions found)');
        
        // Check if college_degree question needs to be updated to dropdown
        final collegeDegreeQuestion = existingQuestions.where((q) => q.id == 'college_degree').firstOrNull;
        if (collegeDegreeQuestion != null && 
            (collegeDegreeQuestion.type.toString() != 'QuestionType.dropdown' || 
             collegeDegreeQuestion.configuration['loadFromDatabase'] != 'courses')) {
          print('Updating college_degree question to dropdown with course loading...');
          await _surveyQuestionService.updateCollegeDegreeQuestion();
        }
        
        // Check if privacy section needs to be updated with detailed text
        final privacySection = existingQuestions.where((q) => q.id == 'section_privacy').firstOrNull;
        if (privacySection != null && 
            (privacySection.description == null || 
             !privacySection.description!.contains('PURPOSE:') ||
             !privacySection.description!.contains('Storage, Retention, Disposal:'))) {
          print('Updating privacy section with detailed purpose and data privacy text...');
          await _surveyQuestionService.updatePrivacySection();
        }
      }
    } catch (e) {
      print('Error initializing survey questions for admin: $e');
      throw Exception('Failed to initialize survey questions: $e');
    }
  }

  /// Force re-initialization of survey questions (for admin use)
  Future<void> reinitializeSurveyQuestions({bool replaceExisting = false}) async {
    try {
      if (replaceExisting) {
        print('Replacing existing survey questions with defaults...');
        // Get all existing questions
        final existingQuestions = await _surveyQuestionService.getAllQuestions();
        
        // Delete existing questions
        for (var question in existingQuestions) {
          await _surveyQuestionService.permanentlyDeleteQuestion(question.id);
        }
        
        print('Deleted ${existingQuestions.length} existing questions');
      }
      
      // Initialize default questions
      await _surveyQuestionService.initializeDefaultQuestions();
      print('Survey questions reinitialized successfully');
    } catch (e) {
      print('Error reinitializing survey questions: $e');
      throw Exception('Failed to reinitialize survey questions: $e');
    }
  }

  /// Check if the app has been properly initialized
  bool get isInitialized => _isInitialized;

  /// Get initialization status with details
  Future<Map<String, dynamic>> getInitializationStatus() async {
    try {
      final questions = await _surveyQuestionService.getAllQuestions();
      final activeQuestions = questions.where((q) => q.isActive).length;
      final adminStatus = await AdminInitializationService.getInitializationStatus();
      
      return {
        'isInitialized': _isInitialized,
        'totalQuestions': questions.length,
        'activeQuestions': activeQuestions,
        'hasQuestions': questions.isNotEmpty,
        'adminInitialization': adminStatus,
        'defaultAdminEmails': AdminInitializationService.getDefaultAdminEmails(),
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'isInitialized': _isInitialized,
        'totalQuestions': 0,
        'activeQuestions': 0,
        'hasQuestions': false,
        'adminInitialization': null,
        'error': e.toString(),
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }
} 