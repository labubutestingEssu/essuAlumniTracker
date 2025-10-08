import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_question_model.dart';
import '../utils/batch_year_utils.dart';
import 'course_service.dart';

class SurveyQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'survey_questions';
  final CourseService _courseService = CourseService();

  // Get all active survey questions ordered by order
  Future<List<SurveyQuestionModel>> getActiveQuestions() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final questions = querySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();
      
      return questions;
    } catch (e) {
      print('Error getting active questions: $e');
      
      // If index is still building, try without orderBy as fallback
      if (e.toString().contains('index') || e.toString().contains('building')) {
        print('Index still building, trying fallback query...');
        try {
          QuerySnapshot fallbackSnapshot = await _firestore
              .collection(_collection)
              .where('isActive', isEqualTo: true)
              .get();

          final questions = fallbackSnapshot.docs
              .map((doc) => SurveyQuestionModel.fromFirestore(doc))
              .toList();
          
          // Sort manually by order
          questions.sort((a, b) => a.order.compareTo(b.order));

          print('Fallback query successful, got ${questions.length} questions');
          return questions;
        } catch (fallbackError) {
          print('Fallback query also failed: $fallbackError');
        }
      }
      
      return [];
    }
  }

  // Get all questions (including inactive) for admin management
  Future<List<SurveyQuestionModel>> getAllQuestions() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all questions: $e');
      return [];
    }
  }

  // Get a specific question by ID
  Future<SurveyQuestionModel?> getQuestionById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(id)
          .get();

      if (doc.exists) {
        return SurveyQuestionModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting question: $e');
      return null;
    }
  }

  // Create a new question
  Future<String?> createQuestion(SurveyQuestionModel question) async {
    try {
      // Get the next order number based on section
      int nextOrder;
      if (question.sectionId != null && question.sectionId!.isNotEmpty) {
        nextOrder = await _getNextOrderInSection(question.sectionId);
      } else {
        nextOrder = await _getNextOrder();
      }
      
      final questionToCreate = question.copyWith(
        order: nextOrder,
        createdAt: DateTime.now(),
      );

      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(questionToCreate.toMap());
      
      return docRef.id;
    } catch (e) {
      print('Error creating question: $e');
      throw Exception('Failed to create question');
    }
  }

  // Update an existing question
  Future<void> updateQuestion(SurveyQuestionModel question) async {
    try {
      final updatedQuestion = question.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection(_collection)
          .doc(question.id)
          .update(updatedQuestion.toMap());
    } catch (e) {
      print('Error updating question: $e');
      throw Exception('Failed to update question');
    }
  }

  // Delete a question (set to inactive)
  Future<void> deleteQuestion(String id) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'isActive': false,
            'updatedAt': DateTime.now(),
          });
    } catch (e) {
      print('Error deleting question: $e');
      throw Exception('Failed to delete question');
    }
  }

  // Permanently delete a question
  Future<void> permanentlyDeleteQuestion(String id) async {
    try {
      print('Attempting to permanently delete question with ID: $id');
      
      // First check if the document exists
      final docSnapshot = await _firestore
          .collection(_collection)
          .doc(id)
          .get();
      
      if (!docSnapshot.exists) {
        print('Question with ID $id does not exist');
        throw Exception('Question not found');
      }
      
      print('Question found, proceeding with deletion...');
      
      await _firestore
          .collection(_collection)
          .doc(id)
          .delete();
      
      print('Question with ID $id successfully deleted');
    } catch (e) {
      print('Error permanently deleting question: $e');
      throw Exception('Failed to permanently delete question: $e');
    }
  }

  // Reorder questions
  Future<void> reorderQuestions(List<SurveyQuestionModel> questions) async {
    try {
      WriteBatch batch = _firestore.batch();
      
      for (int i = 0; i < questions.length; i++) {
        final question = questions[i];
        final docRef = _firestore.collection(_collection).doc(question.id);
        batch.update(docRef, {
          'order': i + 1,
          'updatedAt': DateTime.now(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error reordering questions: $e');
      throw Exception('Failed to reorder questions');
    }
  }

  // Toggle question active status
  Future<void> toggleQuestionStatus(String id, bool isActive) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(id)
          .update({
            'isActive': isActive,
            'updatedAt': DateTime.now(),
          });
    } catch (e) {
      print('Error toggling question status: $e');
      throw Exception('Failed to toggle question status');
    }
  }

  // Initialize survey with default questions from your initial survey
  Future<void> initializeDefaultQuestions() async {
    try {
      // Check if questions already exist
      final existingQuestions = await getAllQuestions();
      
      if (existingQuestions.isNotEmpty) {
        print('Survey questions already exist (${existingQuestions.length} questions). Skipping initialization.');
        return;
      }

      print('Creating default survey questions from initial survey...');
      // Create default questions from your initial survey
      final defaultQuestions = SurveyQuestionModel.createInitialQuestions();
      
      if (defaultQuestions.isEmpty) {
        print('No default questions defined. Skipping initialization.');
        return;
      }

      WriteBatch batch = _firestore.batch();
      
      for (var question in defaultQuestions) {
        final docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, question.toMap());
      }
      
      await batch.commit();
      print('Default survey questions initialized successfully (${defaultQuestions.length} questions created).');
    } catch (e) {
      print('Error initializing default questions: $e');
      throw Exception('Failed to initialize default questions: $e');
    }
  }

  // Get questions by type
  Future<List<SurveyQuestionModel>> getQuestionsByType(QuestionType type) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type.toString())
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      return querySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting questions by type: $e');
      return [];
    }
  }

  // Search questions by title or description
  Future<List<SurveyQuestionModel>> searchQuestions(String query) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('order')
          .get();

      final allQuestions = querySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();

      // Client-side filtering since Firestore doesn't support text search natively
      return allQuestions.where((question) {
        final titleMatch = question.title.toLowerCase().contains(query.toLowerCase());
        final descriptionMatch = question.description?.toLowerCase().contains(query.toLowerCase()) ?? false;
        return titleMatch || descriptionMatch;
      }).toList();
    } catch (e) {
      print('Error searching questions: $e');
      return [];
    }
  }

  // Get the next order number for new questions
  Future<int> _getNextOrder() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 1;
      }

      final lastQuestion = SurveyQuestionModel.fromFirestore(querySnapshot.docs.first);
      return lastQuestion.order + 1;
    } catch (e) {
      print('Error getting next order: $e');
      return 1;
    }
  }

  // Get the next order number within a specific section
  Future<int> _getNextOrderInSection(String? sectionId) async {
    try {
      Query query = _firestore.collection(_collection);
      
      if (sectionId != null && sectionId.isNotEmpty) {
        query = query.where('sectionId', isEqualTo: sectionId);
      }
      
      QuerySnapshot querySnapshot = await query
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // If no questions in this section, find the last order of the previous section
        if (sectionId != null) {
          return await _getLastOrderOfPreviousSection(sectionId);
        }
        return 1;
      }

      final lastQuestion = SurveyQuestionModel.fromFirestore(querySnapshot.docs.first);
      return lastQuestion.order + 1;
    } catch (e) {
      print('Error getting next order in section: $e');
      return await _getNextOrder(); // Fallback to global order
    }
  }

  // Get the last order number of the previous section
  Future<int> _getLastOrderOfPreviousSection(String currentSectionId) async {
    try {
      // Define section order
      final sectionOrder = [
        'section_privacy',
        'section_personal', 
        'section_education',
        'section_employment',
        'section_self_employment',
      ];
      
      final currentIndex = sectionOrder.indexOf(currentSectionId);
      if (currentIndex <= 0) return 0; // First section or invalid section
      
      final previousSectionId = sectionOrder[currentIndex - 1];
      
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('sectionId', isEqualTo: previousSectionId)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 0;
      }

      final lastQuestion = SurveyQuestionModel.fromFirestore(querySnapshot.docs.first);
      return lastQuestion.order;
    } catch (e) {
      print('Error getting last order of previous section: $e');
      return 0;
    }
  }

  // Duplicate a question
  Future<String?> duplicateQuestion(String questionId) async {
    try {
      final originalQuestion = await getQuestionById(questionId);
      if (originalQuestion == null) {
        throw Exception('Question not found');
      }

      final duplicatedQuestion = originalQuestion.copyWith(
        id: '', // Will be set by Firestore
        title: '${originalQuestion.title} (Copy)',
        createdAt: DateTime.now(),
        updatedAt: null,
      );

      return await createQuestion(duplicatedQuestion);
    } catch (e) {
      print('Error duplicating question: $e');
      throw Exception('Failed to duplicate question');
    }
  }

  // Export questions as JSON for backup/migration
  Future<List<Map<String, dynamic>>> exportQuestions() async {
    try {
      final questions = await getAllQuestions();
      return questions.map((q) => q.toMap()).toList();
    } catch (e) {
      print('Error exporting questions: $e');
      throw Exception('Failed to export questions');
    }
  }

  // Import questions from JSON
  Future<void> importQuestions(List<Map<String, dynamic>> questionsData, {bool replaceExisting = false}) async {
    try {
      if (replaceExisting) {
        // Delete existing questions
        final existingQuestions = await getAllQuestions();
        WriteBatch deleteBatch = _firestore.batch();
        
        for (var question in existingQuestions) {
          final docRef = _firestore.collection(_collection).doc(question.id);
          deleteBatch.delete(docRef);
        }
        
        await deleteBatch.commit();
      }

      // Import new questions
      WriteBatch importBatch = _firestore.batch();
      
      for (var questionData in questionsData) {
        final docRef = _firestore.collection(_collection).doc();
        // Remove the id field if it exists, as Firestore document IDs are not stored as fields
        questionData.remove('id');
        questionData['createdAt'] = DateTime.now();
        questionData['updatedAt'] = null;
        
        importBatch.set(docRef, questionData);
      }
      
      await importBatch.commit();
      print('Questions imported successfully.');
    } catch (e) {
      print('Error importing questions: $e');
      throw Exception('Failed to import questions');
    }
  }

  // Update college degree question to be a dropdown with course loading
  Future<void> updateCollegeDegreeQuestion() async {
    try {
      // Find the college_degree question
      final questions = await getAllQuestions();
      final collegeDegreeQuestion = questions.firstWhere(
        (q) => q.id == 'college_degree',
        orElse: () => throw Exception('College degree question not found'),
      );
      
      // Update it to be a dropdown with course loading configuration
      final updatedQuestion = collegeDegreeQuestion.copyWith(
        type: QuestionType.dropdown,
        configuration: {'loadFromDatabase': 'courses'},
        options: [], // Will be populated dynamically
        updatedAt: DateTime.now(),
      );
      
      await updateQuestion(updatedQuestion);
      print('College degree question updated to dropdown with course loading');
    } catch (e) {
      print('Error updating college degree question: $e');
    }
  }

  // Update the privacy section with the new detailed text
  Future<void> updatePrivacySection() async {
    try {
      // Find the section_privacy question
      final questions = await getAllQuestions();
      final privacySection = questions.firstWhere(
        (q) => q.id == 'section_privacy',
        orElse: () => throw Exception('Privacy section not found'),
      );
      
      // Update it with the new detailed description
      final updatedQuestion = privacySection.copyWith(
        description: 'PURPOSE:\nThe Eastern Samar State University System Alumni Tracer Survey collects feedback from alumni to assess the program\'s effectiveness in preparing graduates for their careers and post-graduation life. The survey aims to gather baseline data on ESSU graduates, helping the university identify areas for program improvement. By understanding alumni experiences and outcomes, the university strives to enhance its programs, better serve current and future students, and ensure graduates are well-equipped for success and informed decision-making about their future.\n\nDATA PRIVACY ACT\nIn compliance with RA 10173 or the Data Protection Act of 2012 (DPA of 2012) and its Implementing Rules and Regulations, we are detailing the processing of the data you will provide.\n\nStorage, Retention, Disposal:\nCollected personal data will be securely stored, using physical security for paper files and technical security for digital files. ESSU will retain both paper and digital files only as long as necessary. Once personal data is no longer needed, ESSU will take reasonable steps to securely dispose of the information, preventing further editing, processing, and unauthorized disclosure.',
        updatedAt: DateTime.now(),
      );
      
      await updateQuestion(updatedQuestion);
      print('Privacy section updated with detailed purpose and data privacy text');
    } catch (e) {
      print('Error updating privacy section: $e');
    }
  }


  
  /// Get dynamic options for a question based on its configuration
  Future<List<String>> getDynamicOptions(String dynamicType, {String? userCollege}) async {
    try {
      switch (dynamicType) {
        case 'batchYears':
          return BatchYearUtils.generateBatchYears();
          
        case 'courses':
          final courses = await _courseService.getAllCourses();
          // Filter courses by user's college if provided
          if (userCollege != null && userCollege.isNotEmpty) {
            final filteredCourses = courses.where((course) => course.college == userCollege).toList();
            print('DEBUG: Filtered courses for college "$userCollege": ${filteredCourses.length} out of ${courses.length} total courses');
            return filteredCourses.map((course) => course.name).toList()..sort();
          }
          return courses.map((course) => course.name).toList()..sort();
          
        case 'colleges':
          final courses = await _courseService.getAllCourses();
          final colleges = courses.map((course) => course.college).toSet().toList()..sort();
          return colleges;
          
        default:
          print('⚠️ Unknown dynamic option type: $dynamicType');
          return [];
      }
    } catch (e) {
      print('❌ Error getting dynamic options for $dynamicType: $e');
      return [];
    }
  }
  
  /// Get a question with its dynamic options populated
  Future<SurveyQuestionModel> getQuestionWithDynamicOptions(SurveyQuestionModel question, {String? userCollege}) async {
    if (question.configuration.containsKey('dynamicOptions')) {
      final dynamicType = question.configuration['dynamicOptions'] as String?;
      if (dynamicType != null) {
        final dynamicOptions = await getDynamicOptions(dynamicType, userCollege: userCollege);
        return question.copyWith(options: dynamicOptions);
      }
    }
    return question;
  }
  
  /// Get all active questions with their dynamic options populated
  Future<List<SurveyQuestionModel>> getActiveQuestionsWithDynamicOptions() async {
    final questions = await getActiveQuestions();
    final questionsWithOptions = <SurveyQuestionModel>[];
    
    for (final question in questions) {
      final questionWithOptions = await getQuestionWithDynamicOptions(question);
      questionsWithOptions.add(questionWithOptions);
    }
    
    return questionsWithOptions;
  }
} 