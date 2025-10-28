import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/survey_question_model.dart';
import '../utils/batch_year_utils.dart';
import 'course_service.dart';

class SurveyQuestionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'survey_questions';
  final String _settingsDocId = '_settings'; // Special doc in same collection for settings
  final CourseService _courseService = CourseService();

  // Get all active survey questions ordered by order (from active question set)
  Future<List<SurveyQuestionModel>> getActiveQuestions({String? setId}) async {
    try {
      // If no setId provided, use 'set_1' as default
      final targetSetId = setId ?? 'set_1';
      
      QuerySnapshot querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('setId', isEqualTo: targetSetId)
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
          final targetSetId = setId ?? 'set_1';
          QuerySnapshot fallbackSnapshot = await _firestore
              .collection(_collection)
              .where('isActive', isEqualTo: true)
              .where('setId', isEqualTo: targetSetId)
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
  Future<List<SurveyQuestionModel>> getAllQuestions({String? setId}) async {
    try {
      Query query = _firestore.collection(_collection);
      
      // Filter by setId if provided
      if (setId != null) {
        query = query.where('setId', isEqualTo: setId);
      }
      
      QuerySnapshot querySnapshot = await query.orderBy('order').get();

      return querySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting all questions: $e');
      
      // Fallback: If index is not built yet, fetch without orderBy and sort manually
      if (e.toString().contains('index') || e.toString().contains('requires an index')) {
        print('📋 Index not ready, using fallback query...');
        try {
          Query fallbackQuery = _firestore.collection(_collection);
          
          if (setId != null) {
            fallbackQuery = fallbackQuery.where('setId', isEqualTo: setId);
          }
          
          QuerySnapshot fallbackSnapshot = await fallbackQuery.get();
          
          final questions = fallbackSnapshot.docs
              .map((doc) => SurveyQuestionModel.fromFirestore(doc))
              .toList();
          
          // Sort manually by order
          questions.sort((a, b) => a.order.compareTo(b.order));
          
          print('✅ Fallback query successful, got ${questions.length} questions');
          return questions;
        } catch (fallbackError) {
          print('❌ Fallback query also failed: $fallbackError');
        }
      }
      
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
      print('🎯 Creating new question in section: ${question.sectionId}');
      
      // Get the next order number based on section
      int nextOrder;
      if (question.sectionId != null && question.sectionId!.isNotEmpty) {
        nextOrder = await _getNextOrderInSection(question.sectionId);
        print('📌 Assigned order $nextOrder to new question in section ${question.sectionId}');
      } else {
        nextOrder = await _getNextOrder();
        print('📌 Assigned order $nextOrder to new question (no section)');
      }
      
      final questionToCreate = question.copyWith(
        order: nextOrder,
        createdAt: DateTime.now(),
      );

      DocumentReference docRef = await _firestore
          .collection(_collection)
          .add(questionToCreate.toMap());
      
      print('✅ Question created with ID: ${docRef.id}, order: $nextOrder');
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
      // Check if questions already exist in set_1
      final existingQuestions = await getAllQuestions(setId: 'set_1');
      
      if (existingQuestions.isNotEmpty) {
        print('Survey questions already exist in set_1 (${existingQuestions.length} questions). Skipping initialization.');
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
        // Ensure the question has setId = 'set_1'
        final questionData = question.toMap();
        questionData['setId'] = 'set_1'; // Explicitly set to 'set_1'
        batch.set(docRef, questionData);
      }
      
      await batch.commit();
      print('Default survey questions initialized successfully (${defaultQuestions.length} questions created in set_1).');
      
      // Update the question count for set_1
      try {
        await _firestore.collection('question_sets').doc('set_1').update({
          'questionCount': defaultQuestions.length,
          'updatedAt': DateTime.now(),
        });
        print('Updated question count for set_1: ${defaultQuestions.length}');
      } catch (e) {
        print('Warning: Could not update question count for set_1: $e');
        // Don't throw - questions were created successfully
      }
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
      if (sectionId == null || sectionId.isEmpty) {
        return await _getNextOrder();
      }
      
      print('🔍 Getting next order for section: $sectionId');
      
      // Query questions in the specific section, ordered by order
      // IMPORTANT: We need to fetch all questions in the section to calculate the correct next order
      QuerySnapshot sectionQuerySnapshot = await _firestore
          .collection(_collection)
          .where('sectionId', isEqualTo: sectionId)
          .get();
      
      print('📊 Found ${sectionQuerySnapshot.docs.length} total questions in section $sectionId');
      
      // Convert to SurveyQuestionModel and get all orders
      List<SurveyQuestionModel> sectionQuestions = sectionQuerySnapshot.docs
          .map((doc) => SurveyQuestionModel.fromFirestore(doc))
          .toList();
      
      // Sort by order
      sectionQuestions.sort((a, b) => a.order.compareTo(b.order));
      
      // Log all orders in this section
      print('📋 All questions in section $sectionId:');
      for (var q in sectionQuestions) {
        print('   - Order ${q.order}: ${q.title}');
      }
      
      if (sectionQuestions.isEmpty) {
        // No questions in this section, return 1
        print('📝 No existing questions in $sectionId, starting with order 1');
        return 1;
      }

      // Get the highest order in this section
      final highestOrder = sectionQuestions.last.order;
      final nextOrder = highestOrder + 1;
      print('📝 Highest order in $sectionId is $highestOrder, next will be: $nextOrder');
      
      return nextOrder;
    } catch (e) {
      print('❌ Error getting next order in section: $e');
      return await _getNextOrder(); // Fallback to global order
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
  Future<List<SurveyQuestionModel>> getActiveQuestionsWithDynamicOptions({String? setId}) async {
    final questions = await getActiveQuestions(setId: setId);
    final questionsWithOptions = <SurveyQuestionModel>[];
    
    for (final question in questions) {
      final questionWithOptions = await getQuestionWithDynamicOptions(question);
      questionsWithOptions.add(questionWithOptions);
    }
    
    return questionsWithOptions;
  }

  /// Duplicate all questions from one set to another
  Future<void> duplicateQuestionsToSet(String sourceSetId, String targetSetId) async {
    try {
      print('🔄 Duplicating questions from $sourceSetId to $targetSetId');
      
      // Get all questions from source set
      final sourceQuestions = await getAllQuestions(setId: sourceSetId);
      
      if (sourceQuestions.isEmpty) {
        print('⚠️ No questions found in source set $sourceSetId');
        return;
      }
      
      print('📝 Found ${sourceQuestions.length} questions to duplicate');
      
      WriteBatch batch = _firestore.batch();
      int count = 0;
      
      for (var question in sourceQuestions) {
        final docRef = _firestore.collection(_collection).doc();
        final duplicatedQuestion = question.copyWith(
          id: docRef.id, // This won't be used in toMap but good for reference
          setId: targetSetId,
          createdAt: DateTime.now(),
          updatedAt: null,
        );
        
        batch.set(docRef, duplicatedQuestion.toMap());
        count++;
        
        // Firestore batch has a limit of 500 operations
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
      
      // Commit remaining operations
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Successfully duplicated $count questions to $targetSetId');
    } catch (e) {
      print('❌ Error duplicating questions to set: $e');
      throw Exception('Failed to duplicate questions: $e');
    }
  }

  /// Get question count for a specific set
  Future<int> getQuestionCountForSet(String setId) async {
    try {
      final questions = await getAllQuestions(setId: setId);
      return questions.length;
    } catch (e) {
      print('Error getting question count for set: $e');
      return 0;
    }
  }

  /// Delete all questions in a set
  Future<void> deleteAllQuestionsInSet(String setId) async {
    try {
      print('🗑️ Deleting all questions in set $setId');
      
      final questions = await getAllQuestions(setId: setId);
      
      if (questions.isEmpty) {
        print('⚠️ No questions found in set $setId');
        return;
      }
      
      WriteBatch batch = _firestore.batch();
      int count = 0;
      
      for (var question in questions) {
        final docRef = _firestore.collection(_collection).doc(question.id);
        batch.delete(docRef);
        count++;
        
        // Firestore batch has a limit of 500 operations
        if (count % 500 == 0) {
          await batch.commit();
          batch = _firestore.batch();
        }
      }
      
      // Commit remaining operations
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Successfully deleted $count questions from $setId');
    } catch (e) {
      print('❌ Error deleting questions in set: $e');
      throw Exception('Failed to delete questions: $e');
    }
  }

  // ==================== SET MANAGEMENT (NO SEPARATE COLLECTION) ====================
  
  /// Get all available set IDs from questions
  Future<List<String>> getAvailableSets() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      // Extract unique setIds
      final setIds = <String>{};
      for (var doc in querySnapshot.docs) {
        // Skip the settings document
        if (doc.id == _settingsDocId) continue;
        
        final data = doc.data();
        final setId = data['setId'] as String?;
        if (setId != null && setId.isNotEmpty) {
          setIds.add(setId);
        }
      }
      
      // Sort with set_1 first
      final sortedSetIds = setIds.toList()..sort((a, b) {
        if (a == 'set_1') return -1;
        if (b == 'set_1') return 1;
        return a.compareTo(b);
      });
      
      print('📋 Found ${sortedSetIds.length} sets: $sortedSetIds');
      return sortedSetIds;
    } catch (e) {
      print('❌ Error getting available sets: $e');
      return ['set_1']; // Always return at least set_1
    }
  }
  
  /// Get the active set ID (from settings)
  Future<String> getActiveSetId() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final activeSetId = data?['activeSetId'] as String?;
        if (activeSetId != null && activeSetId.isNotEmpty) {
          print('✅ Active set ID: $activeSetId');
          return activeSetId;
        }
      }
      
      // Default to set_1
      print('📝 No active set found, defaulting to set_1');
      return 'set_1';
    } catch (e) {
      print('❌ Error getting active set: $e');
      return 'set_1';
    }
  }
  
  /// Set the active set ID
  Future<void> setActiveSetId(String setId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .set({
        'activeSetId': setId,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
      
      print('✅ Active set changed to: $setId');
    } catch (e) {
      print('❌ Error setting active set: $e');
      rethrow;
    }
  }
  
  /// Get question count for each set
  Future<Map<String, int>> getQuestionCountPerSet() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      final counts = <String, int>{};
      for (var doc in querySnapshot.docs) {
        // Skip the settings document
        if (doc.id == _settingsDocId) continue;
        
        final data = doc.data();
        final setId = data['setId'] as String?;
        if (setId != null && setId.isNotEmpty) {
          counts[setId] = (counts[setId] ?? 0) + 1;
        }
      }
      
      print('📊 Question counts: $counts');
      return counts;
    } catch (e) {
      print('❌ Error getting question counts: $e');
      return {};
    }
  }
  
  /// Get or create display name for a set
  Future<String> getSetDisplayName(String setId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final setNames = data?['setNames'] as Map<String, dynamic>?;
        if (setNames != null && setNames.containsKey(setId)) {
          return setNames[setId] as String;
        }
      }
      
      // Default names
      if (setId == 'set_1') return 'Set 1 (Default)';
      return 'Set ${setId.replaceAll('set_', '')}';
    } catch (e) {
      print('❌ Error getting set name: $e');
      return setId;
    }
  }
  
  /// Update display name for a set
  Future<void> updateSetDisplayName(String setId, String displayName) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .get();
      
      Map<String, dynamic> setNames = {};
      if (doc.exists) {
        final data = doc.data();
        setNames = Map<String, dynamic>.from(data?['setNames'] ?? {});
      }
      
      setNames[setId] = displayName;
      
      await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .set({
        'setNames': setNames,
        'updatedAt': DateTime.now(),
      }, SetOptions(merge: true));
      
      print('✅ Set name updated: $setId -> $displayName');
    } catch (e) {
      print('❌ Error updating set name: $e');
      rethrow;
    }
  }
  
  /// Check if a set can be deleted (not set_1 and not active)
  Future<bool> canDeleteSet(String setId) async {
    if (setId == 'set_1') return false;
    
    final activeSetId = await getActiveSetId();
    return setId != activeSetId;
  }
  
  /// Initialize default survey settings
  Future<void> initializeSurveySettings() async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(_settingsDocId)
          .get();
      
      if (!doc.exists) {
        await _firestore
            .collection(_collection)
            .doc(_settingsDocId)
            .set({
          'activeSetId': 'set_1',
          'setNames': {
            'set_1': 'Set 1 (Default)',
          },
          'createdAt': DateTime.now(),
          'updatedAt': DateTime.now(),
        });
        
        print('✅ Survey settings initialized in survey_questions/_settings');
      }
    } catch (e) {
      print('❌ Error initializing survey settings: $e');
    }
  }
} 