import 'package:flutter/material.dart';
import '../../models/survey_question_model.dart';
import '../../models/survey_response_model.dart';
import '../../models/user_role.dart';
import '../../services/survey_question_service.dart';
import '../../services/survey_response_service.dart';
import '../../services/auth_service.dart';
import '../../services/course_service.dart';
import '../../models/course_model.dart';
import '../../widgets/dynamic_question_widget.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/navigation_service.dart' as nav_service;
import '../../config/routes.dart';
import '../../utils/responsive.dart';
import '../../utils/input_validators.dart';

class DynamicSurveyFormScreen extends StatefulWidget {
  const DynamicSurveyFormScreen({Key? key}) : super(key: key);

  @override
  State<DynamicSurveyFormScreen> createState() => _DynamicSurveyFormScreenState();
}

class _DynamicSurveyFormScreenState extends State<DynamicSurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _surveyQuestionService = SurveyQuestionService();
  final _surveyResponseService = SurveyResponseService();
  final _authService = AuthService();
  final _courseService = CourseService();
  
  List<SurveyQuestionModel> _questions = [];
  SurveyResponseModel? _existingResponse;
  Map<String, dynamic> _responses = {};
  Map<String, String?> _validationErrors = {};
  
  bool _isLoading = false;
  bool _isSaving = false;
  int _currentSectionIndex = 0;
  
  // Section-based pagination settings
  List<String> _sections = [];
  Map<String, List<SurveyQuestionModel>> _questionsBySection = {};
  
  @override
  void initState() {
    super.initState();
    _loadSurveyData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSurveyData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load active questions, courses, and user profile in parallel
      final currentUser = _authService.currentUser;
      final futures = await Future.wait([
        _surveyQuestionService.getActiveQuestions(),
        _courseService.getAllCourses(),
        if (currentUser != null) _authService.getUserData(currentUser.uid) else Future.value(null),
      ]);
      
      final questions = futures[0] as List<SurveyQuestionModel>;
      final courses = futures[1] as List<Course>;
      final userProfile = futures[2] as Map<String, dynamic>?;
      
      print('DEBUG: Loaded ${questions.length} questions and ${courses.length} courses');
      
      // Debug: Print all loaded questions with their sections
      for (var question in questions) {
        final sectionId = question.sectionId ?? question.getSectionIdFromQuestionId();
        print('DEBUG: Question ${question.id} (${question.type}) - section: $sectionId, order: ${question.order}');
      }
      
      // Update questions that need dynamic options from database
      final updatedQuestions = <SurveyQuestionModel>[];
      
      for (final question in questions) {
        print('DEBUG: Checking question ${question.id} - type: ${question.type}, config: ${question.configuration}');
        
        // Use the new dynamic options service
        if (question.configuration.containsKey('dynamicOptions')) {
          final dynamicType = question.configuration['dynamicOptions'] as String?;
          if (dynamicType != null) {
            print('DEBUG: Question ${question.id} has dynamic options: $dynamicType');
            // Pass user's college for course filtering
            final userCollege = userProfile?['college']?.toString();
            final questionWithOptions = await _surveyQuestionService.getQuestionWithDynamicOptions(question, userCollege: userCollege);
            updatedQuestions.add(questionWithOptions);
            continue;
          }
        }
        
        // Legacy support for loadFromDatabase
        if (question.configuration['loadFromDatabase'] == 'courses') {
          print('DEBUG: Updating question ${question.id} with ${courses.length} course options (legacy)');
          
          // Filter courses by user's college if available
          List<Course> filteredCourses = courses;
          if (userProfile != null && userProfile['college'] != null && userProfile['college'].toString().isNotEmpty) {
            final userCollege = userProfile['college'].toString();
            filteredCourses = courses.where((course) => course.college == userCollege).toList();
            print('DEBUG: Filtered courses for college "$userCollege": ${filteredCourses.length} out of ${courses.length} total courses (legacy)');
          } else {
            print('DEBUG: No college found in user profile, showing all courses (legacy)');
          }
          
          // Ensure unique course names to prevent dropdown assertion errors
          final courseNames = filteredCourses.map((course) => course.name).toSet().toList()..sort();
          print('DEBUG: Course names: ${courseNames.take(5).join(", ")}... (showing first 5)');
          print('DEBUG: Total unique course names: ${courseNames.length}');
          updatedQuestions.add(question.copyWith(
            options: courseNames,
          ));
          continue;
        }
        
        // Also check if this is the college_degree question and force update it
        if (question.id == 'college_degree' && question.type == QuestionType.dropdown) {
          print('DEBUG: Force updating college_degree question with courses');
          
          // Filter courses by user's college if available
          List<Course> filteredCourses = courses;
          if (userProfile != null && userProfile['college'] != null && userProfile['college'].toString().isNotEmpty) {
            final userCollege = userProfile['college'].toString();
            filteredCourses = courses.where((course) => course.college == userCollege).toList();
            print('DEBUG: Filtered courses for college "$userCollege": ${filteredCourses.length} out of ${courses.length} total courses');
          } else {
            print('DEBUG: No college found in user profile, showing all courses');
          }
          
          // Ensure unique course names to prevent dropdown assertion errors
          final courseNames = filteredCourses.map((course) => course.name).toSet().toList()..sort();
          updatedQuestions.add(question.copyWith(
            options: courseNames,
            configuration: {...question.configuration, 'dynamicOptions': 'courses', 'searchable': true},
          ));
          continue;
        }
        
        updatedQuestions.add(question);
      }
      
      // Debug conditional logic
      for (var question in updatedQuestions) {
        if (question.conditionalLogic.isNotEmpty) {
          print('DEBUG: Question ${question.id} has conditional logic: ${question.conditionalLogic}');
        }
      }
      
             // Load existing response if any
       if (currentUser != null) {
        final existingResponse = await _surveyResponseService.getSurveyResponseByUserId(currentUser.uid);
        // Organize questions by sections
        _organizeQuestionsBySection(updatedQuestions);
        // Log user profile data for debugging
        if (userProfile != null) {
          print('DEBUG: User profile data available for auto-fill:');
          print('  firstName: ${userProfile['firstName']}');
          print('  middleName: ${userProfile['middleName']}');
          print('  lastName: ${userProfile['lastName']}');
          print('  suffix: ${userProfile['suffix']}');
          print('  email: ${userProfile['email']}');
          print('  phone: ${userProfile['phone']}');
          print('  studentId: ${userProfile['studentId']}');
          print('  college: ${userProfile['college']}');
          print('  course: ${userProfile['course']}');
          print('  batchYear: ${userProfile['batchYear']}');
          print('  company: ${userProfile['company']}');
          print('  currentOccupation: ${userProfile['currentOccupation']}');
          print('  location: ${userProfile['location']}');
          print('  bio: ${userProfile['bio']}');
        }
        setState(() {
          _questions = updatedQuestions;
          _existingResponse = existingResponse;
          // Start with existing responses
          _responses = Map<String, dynamic>.from(existingResponse?.responses ?? {});
          
          // Force override user profile fields with user profile data, regardless of existing responses
          if (userProfile != null) {
            // Find user profile field questions by their titles and map user data to them
            for (final question in updatedQuestions) {
              final title = question.title.toUpperCase();
              String? userValue;
              
              // Name fields (text input)
              if (question.type == QuestionType.textInput) {
                if (title.contains('FIRST NAME')) {
                  userValue = userProfile['firstName'];
                } else if (title.contains('MIDDLE NAME')) {
                  userValue = userProfile['middleName'];
                } else if (title.contains('LAST NAME')) {
                  userValue = userProfile['lastName'];
                } else if (title.contains('SUFFIX')) {
                  userValue = userProfile['suffix'];
                } else if (title.contains('EMAIL')) {
                  userValue = userProfile['email'];
                } else if (title.contains('PHONE') || title.contains('MOBILE') || title.contains('CONTACT NUMBER')) {
                  final phone = userProfile['phone'];
                  if (phone != null && phone.toString().isNotEmpty) {
                    // Format phone number for display
                    userValue = InputValidators.formatPhilippinePhone(phone.toString());
                  }
                } else if (title.contains('STUDENT ID') || title.contains('ID NUMBER') || title.contains('FACULTY ID')) {
                  // Use facultyId for admins, studentId for alumni
                  final userRole = UserRole.fromString(userProfile['role'] ?? 'alumni');
                  if (userRole == UserRole.admin || userRole == UserRole.super_admin) {
                    userValue = userProfile['facultyId'] ?? '';
                  } else {
                    userValue = userProfile['studentId'];
                  }
                } else if (title.contains('COMPANY') || title.contains('EMPLOYER')) {
                  userValue = userProfile['company'];
                } else if (title.contains('POSITION') || title.contains('JOB TITLE') || title.contains('OCCUPATION')) {
                  userValue = userProfile['currentOccupation'];
                } else if (title.contains('LOCATION') || title.contains('ADDRESS')) {
                  userValue = userProfile['location'];
                } else if (title.contains('BIO') || title.contains('ABOUT')) {
                  userValue = userProfile['bio'];
                }
              }
              
              // College field (dropdown)
              else if (question.type == QuestionType.dropdown) {
                if (title.contains('COLLEGE') && !title.contains('DEGREE')) {
                  userValue = userProfile['college'];
                } else if (title.contains('COURSE') || title.contains('PROGRAM') || (title.contains('DEGREE') && title.contains('COLLEGE'))) {
                  userValue = userProfile['course'];
                } else if (title.contains('BATCH') || title.contains('YEAR') || title.contains('GRADUATION')) {
                  userValue = userProfile['batchYear'];
                }
              }
              
              // Set the value if we found a match
              if (userValue != null && userValue.toString().isNotEmpty) {
                _responses[question.id] = userValue;
                print('DEBUG: Auto-fill setting ${question.id} (${question.title}) to: $userValue');
              }
            }
          }
        });
        print('DEBUG: Final responses after auto-fill:');
        // Show all auto-filled responses by finding questions with auto-filled data
        for (final question in updatedQuestions) {
          final title = question.title.toUpperCase();
          final response = _responses[question.id];
          if (response != null && response.toString().isNotEmpty) {
            // Check if this might be an auto-filled field
            if (title.contains('FIRST NAME') || title.contains('MIDDLE NAME') || title.contains('LAST NAME') ||
                title.contains('SUFFIX') || title.contains('EMAIL') || title.contains('PHONE') ||
                title.contains('STUDENT ID') || title.contains('COMPANY') || title.contains('POSITION') ||
                title.contains('LOCATION') || title.contains('BIO') || title.contains('COLLEGE') ||
                title.contains('COURSE') || title.contains('BATCH') || title.contains('YEAR')) {
              print('  ${question.id} (${question.title}): $response');
            }
          }
        }
        print('DEBUG: All responses: $_responses');
        print('DEBUG: Organized into ${_sections.length} sections: $_sections');
      }
    } catch (e) {
      print('ERROR loading survey: $e');
      _showErrorMessage('Error loading survey: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _organizeQuestionsBySection(List<SurveyQuestionModel> questions) {
    _questionsBySection.clear();
    _sections.clear();
    
    // Sort questions by order first
    final sortedQuestions = List<SurveyQuestionModel>.from(questions)
      ..sort((a, b) => a.order.compareTo(b.order));
    
    String currentSectionId = '';
    List<SurveyQuestionModel> currentSectionQuestions = [];
    
    for (var question in sortedQuestions) {
      print('DEBUG: Processing question ${question.id} (${question.type}) - order: ${question.order}');
      
      // If this is a section divider, start a new section
      if (question.type == QuestionType.section) {
        // Save the previous section if it has questions
        if (currentSectionId.isNotEmpty && currentSectionQuestions.isNotEmpty) {
          _questionsBySection[currentSectionId] = List.from(currentSectionQuestions);
          _sections.add(currentSectionId);
          print('DEBUG: Completed section $currentSectionId with ${currentSectionQuestions.length} questions');
        }
        
        // Start new section
        currentSectionId = question.id;
        currentSectionQuestions = [question]; // Include the section header
        print('DEBUG: Started new section: $currentSectionId');
      } else {
        // Add question to current section
        if (currentSectionId.isEmpty) {
          // If no section started yet, create a default first section
          currentSectionId = 'section_personal';
          print('DEBUG: Creating default first section: $currentSectionId');
        }
        currentSectionQuestions.add(question);
        print('DEBUG: Added question ${question.id} to section $currentSectionId');
      }
    }
    
    // Don't forget the last section
    if (currentSectionId.isNotEmpty && currentSectionQuestions.isNotEmpty) {
      _questionsBySection[currentSectionId] = currentSectionQuestions;
      _sections.add(currentSectionId);
      print('DEBUG: Completed final section $currentSectionId with ${currentSectionQuestions.length} questions');
    }
    
    print('DEBUG: Questions organized by sections:');
    for (var section in _sections) {
      final questionCount = _questionsBySection[section]?.length ?? 0;
      final questionIds = _questionsBySection[section]?.map((q) => q.id).join(', ') ?? '';
      print('  $section: $questionCount questions [$questionIds]');
    }
  }

  List<SurveyQuestionModel> get _currentPageQuestions {
    if (_sections.isEmpty || _currentSectionIndex >= _sections.length) {
      return [];
    }
    
    final currentSectionId = _sections[_currentSectionIndex];
    final sectionQuestions = _questionsBySection[currentSectionId] ?? [];
    
    // Check if this is an employment-related section by looking at the section title
    final sectionHeader = sectionQuestions.firstWhere(
      (q) => q.type == QuestionType.section, 
      orElse: () => SurveyQuestionModel(
        id: '', 
        title: '', 
        type: QuestionType.textInput, 
        isRequired: false, 
        order: 0, 
        sectionId: '', 
        configuration: {}, 
        options: [], 
        validation: {}, 
        createdAt: DateTime.now(), 
        isActive: true
      )
    );
    
    // Hide only the self-employment section if currently_employed is not "Yes"
    if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
      // Find the employment status by looking for the question with the right title
      String? currentlyEmployed;
      for (var question in _questions) {
        if (question.title.contains('Are you presently employed')) {
          currentlyEmployed = _responses[question.id]?.toString();
          break;
        }
      }
      
      if (currentlyEmployed != 'Yes') {
        return []; // Return empty list to hide the entire section
      }
    }
    
    // Filter questions based on conditional logic (include sections as they are important content)
    final visibleQuestions = sectionQuestions.where((q) {
      // Always show sections (they're not questions but important content like disclaimers)
      if (q.type == QuestionType.section) return true;
      
      // For self-employment section, ignore individual question conditional logic
      // since we're already handling section-level visibility
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        return true; // Show all questions in self-employment section if section is visible
      }
      
      // For actual questions in other sections, check conditional logic
      return q.shouldShow(_responses);
    }).toList();
    
    print('DEBUG: Section $currentSectionId has ${visibleQuestions.length} visible questions');
    
    return visibleQuestions;
  }

  int get _totalPages {
    // Count only visible sections based on section titles
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toList();
    return visibleSections.length;
  }

  bool get _isLastPage => _currentSectionIndex >= _totalPages - 1;
  bool get _isFirstPage => _currentSectionIndex == 0;
  
  String get _currentSectionTitle {
    if (_sections.isEmpty || _currentSectionIndex >= _sections.length) {
      return 'Survey';
    }
    
    final currentSectionId = _sections[_currentSectionIndex];
    final sectionQuestions = _questionsBySection[currentSectionId] ?? [];
    
    // Find the section header question (should be the first one)
    SurveyQuestionModel? sectionHeader;
    try {
      sectionHeader = sectionQuestions.firstWhere((q) => q.type == QuestionType.section);
    } catch (e) {
      sectionHeader = sectionQuestions.isNotEmpty ? sectionQuestions.first : null;
    }
    
    if (sectionHeader != null && sectionHeader.type == QuestionType.section) {
      return sectionHeader.title;
    }
    
    // Fallback to a descriptive name based on section ID
    switch (currentSectionId) {
      case 'section_personal':
        return 'Personal Information';
      case 'section_education':
        return 'Educational Background';
      case 'section_employment':
        return 'Employment Information';
      case 'section_self_employment':
        return 'Self Employment';
      case 'section_privacy':
        return 'Privacy & Consent';
      default:
        return 'Section ${_currentSectionIndex + 1}';
    }
  }

  double get _completionPercentage {
    // Get all visible sections first
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toSet();
    
    // Only check required questions from visible sections
    final requiredQuestionIds = _questions
        .where((q) => q.isRequired && q.type != QuestionType.section && visibleSections.contains(q.sectionId) && q.shouldShow(_responses))
        .map((q) => q.id)
        .toList();
    
    if (requiredQuestionIds.isEmpty) return 1.0;
    
    int answeredCount = 0;
    for (String questionId in requiredQuestionIds) {
      if (_isQuestionAnswered(questionId)) {
        answeredCount++;
      }
    }
    
    return answeredCount / requiredQuestionIds.length;
  }

  bool _isQuestionAnswered(String questionId) {
    final value = _responses[questionId];
    if (value == null) return false;
    
    // Handle bypass structure for name fields
    if (value is Map) {
      final actualValue = value['value']?.toString() ?? '';
      return actualValue.isNotEmpty;
    }
    
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  // Helper method to extract actual value from response (handles bypass structure)


  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return WillPopScope(
      onWillPop: () async {
        if (_hasUnsavedChanges()) {
          final shouldSave = await _showUnsavedChangesDialog();
          if (shouldSave == true) {
            await _savePartialResponse();
          }
        }
        nav_service.NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        return false;
      },
      child: ResponsiveScreenWrapper(
        title: 'Alumni Survey',
        customAppBar: CustomAppBar(
          title: 'Alumni Survey',
          showBackButton: false,
          actions: [
            if (_hasUnsavedChanges())
              IconButton(
                onPressed: _savePartialResponse,
                icon: const Icon(Icons.save),
                tooltip: 'Save Progress',
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? _buildNoQuestionsMessage()
                : _buildSurveyContent(isDesktop),
      ),
    );
  }

  Widget _buildNoQuestionsMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Survey Not Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The survey questions are currently being set up by the administrators. Please check back later.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadSurveyData,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyContent(bool isDesktop) {
    return Column(
      children: [
        // Progress indicator
        _buildProgressIndicator(),
        
        // Survey content
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
            child: Container(
              key: ValueKey('survey_form_section_$_currentSectionIndex'),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page title and section navigation
                    _buildPageTitle(),
                    const SizedBox(height: 16),
                    _buildSectionNavigation(),
                    const SizedBox(height: 24),
                    
                    // Questions for current page
                    ..._buildCurrentPageQuestions(),
                    
                    const SizedBox(height: 32),
                    
                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _completionPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(_completionPercentage * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
                      Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Section ${_currentSectionIndex + 1} of $_totalPages'),
                Text('${_getAnsweredQuestionsCount()} of ${_getRequiredQuestionsCount()} required questions answered'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPageTitle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ESSU Alumni Tracer Survey',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentSectionTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete this survey accurately. Your responses will be used to improve our programs and services.',
              style: TextStyle(fontSize: 14),
            ),
            if (_existingResponse != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _existingResponse!.isCompleted ? Icons.check_circle : Icons.pending,
                    color: _existingResponse!.isCompleted ? Theme.of(context).primaryColor : Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _existingResponse!.isCompleted 
                        ? 'Survey completed on ${_formatDate(_existingResponse!.completedAt)}'
                        : 'Survey in progress - last saved ${_formatDate(_existingResponse!.updatedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionNavigation() {
    // Filter out employment sections if currently_employed is not "Yes" based on section titles
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toList();
    
    if (visibleSections.length <= 1) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Survey Sections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: visibleSections.asMap().entries.map((entry) {
                final index = entry.key;
                final sectionId = entry.value;
                final isCurrentSection = index == _currentSectionIndex;
                final isCompleted = _isSectionCompleted(sectionId);
                final isAccessible = _isSectionAccessible(index);
                
                return GestureDetector(
                  onTap: isAccessible ? () {
                    setState(() => _currentSectionIndex = index);
                    _scrollToTop();
                  } : () {
                    // Show message for inaccessible sections
                    _showErrorMessage('Please complete the previous sections before accessing this section.');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrentSection 
                          ? Colors.blue
                          : isCompleted 
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : isAccessible
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentSection 
                            ? Colors.blue.shade700
                            : isCompleted
                                ? Theme.of(context).primaryColor
                                : isAccessible
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade400,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCompleted)
                          Icon(Icons.check_circle, size: 16, color: Theme.of(context).primaryColor)
                        else if (!isAccessible)
                          Icon(Icons.lock, size: 16, color: Colors.grey.shade500)
                        else
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrentSection 
                                  ? Colors.white 
                                  : isAccessible 
                                      ? Colors.grey.shade700 
                                      : Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _getSectionDisplayName(sectionId),
                          style: TextStyle(
                            color: isCurrentSection 
                                ? Colors.white 
                                : isAccessible 
                                    ? Colors.grey.shade700 
                                    : Colors.grey.shade500,
                            fontWeight: isCurrentSection ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionDisplayName(String sectionId) {
    final sectionQuestions = _questionsBySection[sectionId] ?? [];
    
    // Find the section header question
    SurveyQuestionModel? sectionHeader;
    try {
      sectionHeader = sectionQuestions.firstWhere((q) => q.type == QuestionType.section);
    } catch (e) {
      sectionHeader = null;
    }
    
    if (sectionHeader != null) {
      // Use the actual section title but make it shorter for navigation
      final title = sectionHeader.title;
      if (title.length > 25) {
        // For longer titles, use a smarter truncation
        if (title.contains('PURPOSE & DATA PRIVACY ACT')) {
          return 'Privacy & Data Act';
        } else if (title.contains('PERSONAL INFORMATION')) {
          return 'Personal Information';
        } else if (title.contains('EDUCATIONAL BACKGROUND')) {
          return 'Educational Background';
        } else if (title.contains('EMPLOYMENT INFORMATION')) {
          return 'Employment Information';
        } else if (title.contains('EMPLOYMENT DETAILS')) {
          return 'Self Employment';
        } else {
          // For other long titles, take first 3 words
          return title.split(' ').take(3).join(' ');
        }
      }
      return title;
    }
    
    // Fallback to predefined names
    switch (sectionId) {
      case 'section_privacy':
        return 'Privacy & Data Act';
      case 'section_personal':
        return 'Personal Information';
      case 'section_education':
        return 'Educational Background';
      case 'section_employment':
        return 'Employment Information';
      case 'section_self_employment':
        return 'Self Employment';
      default:
        return sectionId.replaceAll('section_', '').replaceAll('_', ' ');
    }
  }

  bool _isSectionCompleted(String sectionId) {
    final sectionQuestions = _questionsBySection[sectionId] ?? [];
    final requiredQuestions = sectionQuestions.where((q) => 
      q.isRequired && q.type != QuestionType.section && q.shouldShow(_responses)
    );
    
    for (var question in requiredQuestions) {
      if (!_isQuestionAnswered(question.id)) {
        return false;
      }
    }
    
    return requiredQuestions.isNotEmpty;
  }

  bool _isSectionAccessible(int sectionIndex) {
    // First section is always accessible
    if (sectionIndex == 0) return true;
    
    // Check if all previous sections are completed
    for (int i = 0; i < sectionIndex; i++) {
      if (i < _sections.length) {
        final sectionId = _sections[i];
        if (!_isSectionCompleted(sectionId)) {
          return false;
        }
      }
    }
    
    return true;
  }

  List<Widget> _buildCurrentPageQuestions() {
    final currentQuestions = _currentPageQuestions;
    final widgets = <Widget>[];
    
    for (int i = 0; i < currentQuestions.length; i++) {
      final question = currentQuestions[i];
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: DynamicQuestionWidget(
            question: question,
            currentValue: _responses[question.id],
            onChanged: (value) async {
              setState(() {
                _responses[question.id] = value;
                _validationErrors.remove(question.id);
                
                // Clear responses for questions that are no longer visible due to conditional logic
                _clearHiddenQuestionResponses();
              });
              
              // Handle consent question - if user selects "No", show confirmation and exit
              if (question.title.contains('Do you want to continue with the survey') && value == 'No') {
                print('DEBUG: Consent declined for question: ${question.title}');
                await _handleConsentDeclined();
              }
              
              // Handle employment status change - trigger UI update for section visibility
              if (question.title.contains('Are you presently employed')) {
                print('DEBUG: Employment status changed to: $value');
                setState(() {
                  // Force UI rebuild to update section visibility
                });
              }
            },
            errorText: _validationErrors[question.id],
          ),
        ),
      );
    }
    
    return widgets;
  }

  Widget _buildNavigationButtons() {
    final canProceed = _canProceedToNext();
    final currentSectionCompleted = _isSectionCompleted(_sections.isNotEmpty ? _sections[_currentSectionIndex] : '');
    
    return Column(
      children: [
        // Section completion status
        if (!currentSectionCompleted && !_isLastPage)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please complete all required fields in this section before proceeding.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        // Navigation buttons
        Row(
          children: [
            if (!_isFirstPage)
              ElevatedButton(
                onPressed: _previousPage,
                child: const Text('Previous'),
              ),
            const Spacer(),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!_isLastPage) ...[
              ElevatedButton(
                onPressed: canProceed ? _nextPage : null,
                style: canProceed ? null : ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.grey.shade600,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Next'),
                    if (!canProceed) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.lock, size: 16),
                    ],
                  ],
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _canSubmitSurvey() ? _submitSurvey : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: const Text('Submit Survey'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _previousPage() {
    if (!_isFirstPage) {
      setState(() => _currentSectionIndex--);
      _scrollToTop();
    }
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      if (!_isLastPage) {
        setState(() => _currentSectionIndex++);
        _scrollToTop();
      }
      // Auto-save progress
      _savePartialResponse();
    } else {
      // Show validation error message
      _showErrorMessage('Please complete all required fields in this section before proceeding.');
    }
  }

  void _scrollToTop() {
    // Add a small delay to ensure the UI has updated before scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  bool _validateCurrentPage() {
    final currentQuestions = _currentPageQuestions;
    bool isValid = true;
    
    setState(() => _validationErrors.clear());
    
    for (var question in currentQuestions) {
      if (question.isRequired) {
        final value = _responses[question.id];
        if (value == null || 
            (value is String && value.isEmpty) ||
            (value is List && value.isEmpty)) {
          setState(() {
            _validationErrors[question.id] = question.validation['required'] ?? 'This field is required';
          });
          isValid = false;
        }
      }
    }
    
    return isValid;
  }

  bool _canProceedToNext() {
    // Check if current section is completed
    if (_sections.isEmpty || _currentSectionIndex >= _sections.length) {
      return false;
    }
    
    final currentSectionId = _sections[_currentSectionIndex];
    return _isSectionCompleted(currentSectionId);
  }

  bool _canSubmitSurvey() {
    // Get all visible sections first
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toSet();
    
    // Only check required questions from visible sections
    final requiredQuestions = _questions.where((q) => 
      q.isRequired && 
      q.type != QuestionType.section && 
      visibleSections.contains(q.sectionId) &&
      q.shouldShow(_responses)
    );
    
    for (var question in requiredQuestions) {
      if (!_isQuestionAnswered(question.id)) {
        return false;
      }
    }
    
    return true;
  }

  Future<void> _savePartialResponse() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      
      final currentUserModel = await _authService.getUserData(currentUser.uid);
      if (currentUserModel == null) throw Exception('User data not found');
      
      final response = SurveyResponseModel(
        id: _existingResponse?.id ?? '',
        userId: currentUser.uid,
        userUid: currentUser.uid,
        fullName: currentUserModel['fullName'] ?? '',
        college: currentUserModel['college'] ?? '',
        course: currentUserModel['course'] ?? '',
        batchYear: currentUserModel['batchYear'] ?? '',
        responses: _responses,
        isCompleted: false,
        createdAt: _existingResponse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _surveyResponseService.savePartialResponse(response);
      
      // Update existing response reference
      if (_existingResponse == null) {
        final savedResponse = await _surveyResponseService.getSurveyResponseByUserId(currentUser.uid);
        setState(() => _existingResponse = savedResponse);
      }
      
      _showSuccessMessage('Progress saved successfully');
    } catch (e) {
      _showErrorMessage('Error saving progress: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate() || !_canSubmitSurvey()) {
      _showErrorMessage('Please complete all required fields');
      return;
    }

    // Show review dialog before submitting
    final shouldSubmit = await _showReviewDialog();
    if (shouldSubmit != true) return;
    setState(() => _isSaving = true);
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) throw Exception('User not logged in');
      final currentUserModel = await _authService.getUserData(currentUser.uid);
      if (currentUserModel == null) throw Exception('User data not found');
      final response = SurveyResponseModel(
        id: _existingResponse?.id ?? '',
        userId: currentUser.uid,
        userUid: currentUser.uid,
        fullName: currentUserModel['fullName'] ?? '',
        college: currentUserModel['college'] ?? '',
        course: currentUserModel['course'] ?? '',
        batchYear: currentUserModel['batchYear'] ?? '',
        responses: _responses,
        isCompleted: true,
        createdAt: _existingResponse?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        completedAt: DateTime.now(),
      );
      await _surveyResponseService.submitSurveyResponse(response);
      _showSuccessDialog();
    } catch (e) {
      _showErrorMessage('Error submitting survey: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<bool?> _showReviewDialog() async {
    // Build a list of all visible, answered questions
    final List<Map<String, String>> reviewList = [];
    for (final q in _questions) {
      if (q.type == QuestionType.section) continue;
      if (!q.shouldShow(_responses)) continue;
      final answer = _responses[q.id];
      if (answer == null || (answer is String && answer.isEmpty) || (answer is List && answer.isEmpty)) continue;
      String displayAnswer;
      if (answer is List) {
        displayAnswer = answer.join(', ');
      } else if (answer is DateTime) {
        displayAnswer = _formatDate(answer);
      } else if (answer is Map) {
        // Handle bypass structure for name fields
        final actualValue = answer['value']?.toString() ?? '';
        if (actualValue.isNotEmpty) {
          displayAnswer = actualValue;
        } else {
          displayAnswer = answer.values.join(', ');
        }
      } else {
        displayAnswer = answer.toString();
      }
      reviewList.add({'question': q.title, 'answer': displayAnswer});
    }
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Your Answers'),
        content: SizedBox(
          width: double.maxFinite,
          child: reviewList.isEmpty
              ? const Text('No answers to review.')
              : Scrollbar(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: reviewList.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final item = reviewList[i];
                      return ListTile(
                        title: Text(item['question'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['answer'] ?? ''),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _clearHiddenQuestionResponses() {
    // Remove responses for questions that are no longer visible due to conditional logic
    final visibleQuestionIds = _questions
        .where((q) => q.shouldShow(_responses))
        .map((q) => q.id)
        .toSet();
    
    final keysToRemove = _responses.keys
        .where((key) => !visibleQuestionIds.contains(key))
        .toList();
    
    for (final key in keysToRemove) {
      _responses.remove(key);
    }
  }

  Future<void> _handleConsentDeclined() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Exit Survey'),
            ],
          ),
          content: const Text(
            'You have chosen not to continue with the survey. '
            'Are you sure you want to exit? Your progress will not be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Exit Survey'),
            ),
          ],
        );
      },
    );

    if (shouldExit == true) {
      // Clear any saved responses and exit
      try {
        final currentUser = _authService.currentUser;
        if (currentUser != null && _existingResponse != null) {
          await _surveyResponseService.deleteSurveyResponse(_existingResponse!.id, currentUser.uid);
        }
      } catch (e) {
        print('Error clearing survey data: $e');
      }
      
      // Navigate back to alumni directory
      if (mounted) {
        nav_service.NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
      }
    } else {
      // User cancelled, reset the consent question to null
      setState(() {
        // Find and remove the consent question response
        final consentQuestion = _questions.firstWhere(
          (q) => q.title.contains('Do you want to continue with the survey'),
          orElse: () => _questions.first,
        );
        _responses.remove(consentQuestion.id);
      });
    }
  }

  bool _hasUnsavedChanges() {
    return _responses.isNotEmpty && 
           (_existingResponse == null || 
            _existingResponse!.updatedAt == null ||
            _existingResponse!.updatedAt!.isBefore(DateTime.now().subtract(const Duration(minutes: 5))));
  }

  int _getAnsweredQuestionsCount() {
    // Get all visible sections first
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toSet();
    
    return _questions
        .where((q) => q.isRequired && q.type != QuestionType.section && visibleSections.contains(q.sectionId) && q.shouldShow(_responses) && _isQuestionAnswered(q.id))
        .length;
  }

  int _getRequiredQuestionsCount() {
    // Get all visible sections first
    final visibleSections = _sections.where((sectionId) {
      final sectionQuestions = _questionsBySection[sectionId] ?? [];
      final sectionHeader = sectionQuestions.firstWhere(
        (q) => q.type == QuestionType.section, 
        orElse: () => SurveyQuestionModel(
          id: '', 
          title: '', 
          type: QuestionType.textInput, 
          isRequired: false, 
          order: 0, 
          sectionId: '', 
          configuration: {}, 
          options: [], 
          validation: {}, 
          createdAt: DateTime.now(), 
          isActive: true
        )
      );
      
      // Hide only the self-employment section if currently_employed is not "Yes"
      if (sectionHeader.title.contains('EMPLOYMENT DETAILS')) {
        // Find the employment status by looking for the question with the right title
        String? currentlyEmployed;
        for (var question in _questions) {
          if (question.title.contains('Are you presently employed')) {
            currentlyEmployed = _responses[question.id]?.toString();
            break;
          }
        }
        return currentlyEmployed == 'Yes';
      }
      return true;
    }).toSet();
    
    return _questions
        .where((q) => q.isRequired && q.type != QuestionType.section && visibleSections.contains(q.sectionId) && q.shouldShow(_responses))
        .length;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('You have unsaved changes. Would you like to save your progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Survey Submitted'),
        content: const Text('Thank you for completing the alumni survey! Your responses have been submitted successfully.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              nav_service.NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).primaryColor),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
} 