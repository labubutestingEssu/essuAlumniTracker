import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart' as excel;
import 'dart:convert';
import '../../models/survey_response_model.dart';
import '../../models/survey_question_model.dart';
import '../../models/course_model.dart';
import '../../services/survey_response_service.dart';
import '../../services/survey_question_service.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../utils/responsive.dart';
import '../../utils/batch_year_utils.dart';
import '../../utils/web_download_stub.dart' if (dart.library.html) '../../utils/web_download.dart';
import '../../services/export_filter_service.dart';

class SurveyDataViewerScreen extends StatefulWidget {
  const SurveyDataViewerScreen({Key? key}) : super(key: key);

  @override
  State<SurveyDataViewerScreen> createState() => _SurveyDataViewerScreenState();
}

class _SurveyDataViewerScreenState extends State<SurveyDataViewerScreen> {
  final SurveyResponseService _surveyResponseService = SurveyResponseService();
  final SurveyQuestionService _questionService = SurveyQuestionService();
  final UserService _userService = UserService();
  final CourseService _courseService = CourseService();
  final ExportFilterService _exportFilterService = ExportFilterService();
  final TextEditingController _searchController = TextEditingController();
  
  List<SurveyResponseModel> _surveyResponses = [];
  List<SurveyQuestionModel> _questions = [];
  
  bool _isLoading = false;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _searchQuery;
  String? _selectedCollege;
  String? _selectedBatchYear;
  String? _selectedCompletionStatus;
  String? _error;
  String? _userCollege; // Store current user's college for restrictions

  List<String> _colleges = [];

  // Generate school year display format for UI
  final List<String> _schoolYearDisplay = BatchYearUtils.generateSchoolYearDisplay();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadQuestions();
    _loadSurveyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _userService.isCurrentUserAdmin();
      final isSuperAdmin = await _userService.isCurrentUserSuperAdmin();
      
      // Get current user's college for filtering restrictions
      String? userCollege;
      if (!isSuperAdmin) {
        final currentUser = await _userService.getCurrentUser();
        userCollege = currentUser?.college;
        print("Non-super admin user college: '$userCollege'");
      }
      
      setState(() {
        _isAdmin = isAdmin;
        _isSuperAdmin = isSuperAdmin;
        _userCollege = userCollege;
        
        // Set initial college filter for non-super admins
        if (!_isSuperAdmin && userCollege != null && userCollege.isNotEmpty) {
          _selectedCollege = userCollege;
          print("Setting _selectedCollege to: '$_selectedCollege' for non-super admin");
        } else if (_isSuperAdmin) {
          _selectedCollege = null; // Super admins start with no college filter
          print("Super admin detected - no college restriction");
        }
      });
      
      if (!_isAdmin && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied. College Admin privileges required.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      print("User is admin: $_isAdmin, Super Admin: $_isSuperAdmin, User College: '$userCollege', Selected College: '$_selectedCollege'");
    } catch (e) {
      print("Error checking admin status: $e");
    }
  }

  Future<void> _loadQuestions() async {
    try {
      // Load ALL questions from ALL sets to match old responses
      // This is important because responses may contain question IDs from previous sets
      final futures = await Future.wait([
        _questionService.getAllQuestions(), // Gets questions from all sets
        _courseService.getAllCourses(),
      ]);
      
      final questions = futures[0] as List<SurveyQuestionModel>;
      final courses = futures[1] as List<Course>;
      
      print('=== SURVEY DATA VIEWER: LOADING QUESTIONS ===');
      print('Loaded ${questions.length} questions from all sets');
      
      if (questions.isEmpty) {
        print('⚠️ WARNING: No questions loaded! This will cause all responses to show "not found"');
      } else {
        // Print first 5 question IDs for debugging
        print('Sample question IDs (first 5):');
        for (int i = 0; i < questions.length && i < 5; i++) {
          print('  ${i + 1}. ${questions[i].id} - "${questions[i].title}" (set: ${questions[i].setId})');
        }
        
        // Show unique set IDs
        final setIds = questions.map((q) => q.setId).toSet();
        print('Questions from sets: $setIds');
      }
      
      // Extract unique colleges from courses
      final collegeSet = <String>{};
      for (final course in courses) {
        if (course.college.isNotEmpty) {
          collegeSet.add(course.college);
        }
      }
      
      setState(() {
        _questions = questions;
        _colleges = collegeSet.toList()..sort();
      });
    } catch (e) {
      print('❌ ERROR loading questions: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _loadSurveyData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // For non-super admins, enforce their college restriction
      String? effectiveCollegeFilter = _selectedCollege;
      if (!_isSuperAdmin && _userCollege != null && _userCollege!.isNotEmpty) {
        effectiveCollegeFilter = _userCollege; // Force to user's college regardless of UI selection
        print("Non-super admin: Forcing college filter to '$effectiveCollegeFilter' (user's college: '$_userCollege')");
      } else if (_isSuperAdmin) {
        print("Super admin: Using selected college filter '$effectiveCollegeFilter'");
      } else {
        print("Warning: Non-super admin with no college assigned - this shouldn't happen");
      }
      
      final responses = await _surveyResponseService.getAllSurveyResponses();

      setState(() {
        _surveyResponses = _filterSurveyResponses(responses);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load survey data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<SurveyResponseModel> _filterSurveyResponses(List<SurveyResponseModel> responses) {
    return responses.where((response) {
      // For non-super admins, ALWAYS enforce their college restriction
      if (!_isSuperAdmin && _userCollege != null && _userCollege!.isNotEmpty) {
        if (response.college != _userCollege) {
          return false;
        }
      }
      
      if (_searchQuery != null && _searchQuery!.isNotEmpty) {
        final query = _searchQuery!.toLowerCase();
        if (!response.fullName.toLowerCase().contains(query) &&
            !response.college.toLowerCase().contains(query) &&
            !response.course.toLowerCase().contains(query)) {
          return false;
        }
      }

      if (_selectedCollege != null && response.college != _selectedCollege) {
        return false;
      }

      if (_selectedBatchYear != null && response.batchYear != _selectedBatchYear) {
        return false;
      }

      if (_selectedCompletionStatus != null) {
        if (_selectedCompletionStatus == 'completed' && !response.isCompleted) {
          return false;
        }
        if (_selectedCompletionStatus == 'partial' && response.isCompleted) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = null;
      _selectedBatchYear = null;
      _selectedCompletionStatus = null;
      
      // Only reset college filter for super admins
      if (_isSuperAdmin) {
        _selectedCollege = null;
      } else {
        // For non-super admins, reset to their own college
        _selectedCollege = _userCollege;
      }
    });
    _loadSurveyData();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ResponsiveScreenWrapper(
      title: 'Survey Data Viewer',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadSurveyData,
          tooltip: 'Refresh Data',
        ),
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: _exportData,
          tooltip: 'Export Data',
        ),
      ],
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildSurveyList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, college, or program...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = null;
                        });
                        _loadSurveyData();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (value) {
              setState(() {
                _searchQuery = value.isEmpty ? null : value;
              });
              _loadSurveyData();
            },
          ),
          const SizedBox(height: 16),
          
          // Add status indicator for admin access level
          if (_isAdmin) 
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FutureBuilder<bool>(
                future: _userService.isCurrentUserSuperAdmin(),
                builder: (context, snapshot) {
                  final isSuperAdmin = snapshot.data == true;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSuperAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSuperAdmin ? Colors.purple.shade200 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuperAdmin ? Icons.security : Icons.admin_panel_settings,
                          size: 16,
                          color: isSuperAdmin ? Colors.purple : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSuperAdmin 
                              ? 'Admin View: Full access to all college data'
                              : 'College Admin View: Limited to ${_userCollege ?? "your college"} - You can only see survey data from your assigned college',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          
          Responsive.isDesktop(context)
              ? Row(
                  children: [
                    Expanded(child: _buildCollegeDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildBatchYearDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildCompletionStatusDropdown()),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Reset'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildCollegeDropdown(),
                    const SizedBox(height: 12),
                    _buildBatchYearDropdown(),
                    const SizedBox(height: 12),
                    _buildCompletionStatusDropdown(),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Reset Filters'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildCollegeDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'College',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        // Add lock icon for non-super admins to indicate it's restricted
        suffixIcon: !_isSuperAdmin ? const Icon(Icons.lock, size: 20, color: Colors.grey) : null,
      ),
      value: _selectedCollege,
      items: _isSuperAdmin 
          ? [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Colleges'),
              ),
              ..._colleges.map((college) => DropdownMenuItem<String>(
                value: college,
                child: Text(college),
              )),
            ]
          : _colleges.map((college) => DropdownMenuItem<String>(
              value: college,
              child: Text(college),
            )).toList(),
      onChanged: _isSuperAdmin ? (value) {
        setState(() {
          _selectedCollege = value;
        });
        _loadSurveyData();
      } : null,
    );
  }

  Widget _buildBatchYearDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Academic Year',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      value: _selectedBatchYear,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Academic Years'),
        ),
        ..._schoolYearDisplay.map((schoolYear) => DropdownMenuItem<String>(
          value: BatchYearUtils.schoolYearToBatchYear(schoolYear),
          child: Text(schoolYear),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedBatchYear = value;
        });
        _loadSurveyData();
      },
    );
  }

  Widget _buildCompletionStatusDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      value: _selectedCompletionStatus,
      items: const [
        DropdownMenuItem<String>(
          value: null,
          child: Text('All Responses'),
        ),
        DropdownMenuItem<String>(
          value: 'completed',
          child: Text('Completed Only'),
        ),
        DropdownMenuItem<String>(
          value: 'partial',
          child: Text('Partial Only'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCompletionStatus = value;
        });
        _loadSurveyData();
      },
    );
  }

  Widget _buildSurveyList() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading survey data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSurveyData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_surveyResponses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No survey responses found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text('Try adjusting your search criteria'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Survey Responses (${_surveyResponses.length})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        // Survey list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _surveyResponses.length,
            itemBuilder: (context, index) {
              final response = _surveyResponses[index];
              return _buildSurveyResponseCard(response);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSurveyResponseCard(SurveyResponseModel response) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: response.isCompleted ? Theme.of(context).primaryColor : Colors.orange,
          child: Icon(
            response.isCompleted ? Icons.check : Icons.hourglass_empty,
            color: Colors.white,
          ),
        ),
        title: Text(
          response.fullName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${response.course} - Academic Year ${BatchYearUtils.batchYearToSchoolYear(response.batchYear)}'),
            Text(response.college),
            Text(
              response.isCompleted 
                  ? 'Completed: ${DateFormat('MMM dd, yyyy').format(response.completedAt!)}'
                  : 'Partial - Updated: ${DateFormat('MMM dd, yyyy').format(response.updatedAt ?? response.createdAt)}',
              style: TextStyle(
                color: response.isCompleted ? Theme.of(context).primaryColor : Colors.orange,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${response.responses.length} answers',
              style: const TextStyle(fontSize: 12),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildSurveyResponseDetails(response),
          ),
        ],
      ),
    );
  }



  Widget _buildSurveyResponseDetails(SurveyResponseModel response) {
    // Debug: Print response question IDs
    print('\n=== DISPLAYING RESPONSE: ${response.fullName} ===');
    print('Response has ${response.responses.length} answers');
    print('Available questions in memory: ${_questions.length}');
    print('Sample response question IDs (first 5):');
    int idx = 0;
    for (var entry in response.responses.entries) {
      if (idx >= 5) break;
      print('  ${idx + 1}. ${entry.key} -> ${entry.value.toString().substring(0, entry.value.toString().length > 50 ? 50 : entry.value.toString().length)}...');
      idx++;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Response Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow('Response ID', response.id),
              _buildInfoRow('User ID', response.userId),
              _buildInfoRow('Status', response.isCompleted ? 'Completed' : 'Partial'),
              _buildInfoRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(response.createdAt)),
              if (response.updatedAt != null)
                _buildInfoRow('Updated', DateFormat('MMM dd, yyyy HH:mm').format(response.updatedAt!)),
              if (response.completedAt != null)
                _buildInfoRow('Completed', DateFormat('MMM dd, yyyy HH:mm').format(response.completedAt!)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          'Survey Responses (${response.responses.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        
        if (response.responses.isEmpty)
          const Text('No responses recorded')
        else
          ...response.responses.entries.map((entry) {
            final questionId = entry.key;
            final answer = entry.value;
            
            // Debug: Try to find question
            final foundQuestion = _questions.where((q) => q.id == questionId).toList();
            if (foundQuestion.isEmpty) {
              print('⚠️ Question not found: $questionId');
            }
            
            final question = _questions.firstWhere(
              (q) => q.id == questionId,
              orElse: () => SurveyQuestionModel(
                id: questionId,
                title: 'Question ID: $questionId (not found in current questions)',
                type: QuestionType.textInput,
                isRequired: false,
                order: 0,
                configuration: {},
                options: [],
                validation: {},
                createdAt: DateTime.now(),
                isActive: true,
              ),
            );
            
            // Format answer properly based on type
            String displayAnswer = '';
            if (answer != null) {
              // Handle Map structure (bypass fields, other_specify, etc.)
              if (answer is Map) {
                // Check for bypass structure with 'value' key
                if (answer.containsKey('value')) {
                  final value = answer['value'];
                  if (value != null && value.toString().isNotEmpty) {
                    displayAnswer = value.toString();
                  } else {
                    displayAnswer = '(empty)';
                  }
                }
                // Check for 'other_specify' structure
                else if (answer.containsKey('other_specify')) {
                  final mainValue = answer['value'] ?? '';
                  final otherValue = answer['other_specify'];
                  if (otherValue != null && otherValue.toString().isNotEmpty) {
                    displayAnswer = '$mainValue: ${otherValue.toString()}';
                  } else {
                    displayAnswer = mainValue.toString();
                  }
                }
                // Generic map handling
                else {
                  final nonEmptyValues = answer.values.where((v) => v != null && v.toString().isNotEmpty);
                  displayAnswer = nonEmptyValues.isNotEmpty ? nonEmptyValues.join(', ') : answer.toString();
                }
              }
              // Handle List
              else if (answer is List) {
                displayAnswer = answer.isNotEmpty ? answer.join(', ') : '(empty list)';
              }
              // Handle DateTime
              else if (answer is DateTime) {
                displayAnswer = DateFormat('MMM dd, yyyy').format(answer);
              }
              // Handle simple types
              else {
                displayAnswer = answer.toString();
              }
            }
            
            if (displayAnswer.isEmpty) {
              displayAnswer = '(no answer)';
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type: ${question.type.toString().split('.').last}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayAnswer,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }



  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user's filter info
      final filterInfo = await _exportFilterService.getCurrentUserFilterInfo();
      final userCollege = filterInfo['college'] as String?;
      final canExportAll = filterInfo['canExportAll'] as bool;
      
      print('Export filter info: college=$userCollege, canExportAll=$canExportAll');
      
      // Filter survey responses based on user's college access
      List<SurveyResponseModel> filteredResponses = _surveyResponses;
      if (!canExportAll && userCollege != null) {
        filteredResponses = _surveyResponses.where((response) => response.college == userCollege).toList();
        print('Filtered responses for college $userCollege: ${filteredResponses.length} out of ${_surveyResponses.length}');
      }
      
      // Check if user can export the selected college data
      if (!canExportAll && _selectedCollege != null && _selectedCollege != userCollege) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can only export data from your assigned college: $userCollege'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Build headers and rows for survey data export
      final headers = [
        'Response ID',
        'User ID',
        'Full Name',
        'College',
        'Program',
        'Academic Year',
        'Status',
        'Created At',
        'Updated At',
        'Completed At',
        'Total Responses',
      ];
      
      // Add question titles as headers
      for (final question in _questions) {
        if (question.type != QuestionType.section) {
          headers.add(question.title);
        }
      }
      
      final List<List<String>> allRows = [headers];
      
      // Add data rows using filtered responses
      for (final response in filteredResponses) {
        final row = [
          response.id,
          response.userId,
          response.fullName,
          response.college,
          response.course,
          BatchYearUtils.batchYearToSchoolYear(response.batchYear),
          response.isCompleted ? 'Completed' : 'Partial',
          response.createdAt.toIso8601String(),
          response.updatedAt?.toIso8601String() ?? '',
          response.completedAt?.toIso8601String() ?? '',
          response.responses.length.toString(),
        ];
        
        // Add question responses
        for (final question in _questions) {
          if (question.type != QuestionType.section) {
            final answer = response.responses[question.id];
            String displayAnswer = '';
            
            if (answer != null) {
              // Handle Map structure (bypass fields, other_specify, etc.)
              if (answer is Map) {
                // Check for bypass structure with 'value' key
                if (answer.containsKey('value')) {
                  final value = answer['value'];
                  if (value != null && value.toString().isNotEmpty) {
                    displayAnswer = value.toString();
                  }
                }
                // Check for 'other_specify' structure
                else if (answer.containsKey('other_specify')) {
                  final mainValue = answer['value'] ?? '';
                  final otherValue = answer['other_specify'];
                  if (otherValue != null && otherValue.toString().isNotEmpty) {
                    displayAnswer = '$mainValue: ${otherValue.toString()}';
                  } else {
                    displayAnswer = mainValue.toString();
                  }
                }
                // Generic map handling
                else {
                  final nonEmptyValues = answer.values.where((v) => v != null && v.toString().isNotEmpty);
                  displayAnswer = nonEmptyValues.isNotEmpty ? nonEmptyValues.join(', ') : '';
                }
              }
              // Handle List
              else if (answer is List) {
                displayAnswer = answer.join(', ');
              }
              // Handle DateTime
              else if (answer is DateTime) {
                displayAnswer = DateFormat('MMM dd, yyyy').format(answer);
              }
              // Handle simple types
              else {
                displayAnswer = answer.toString();
              }
            }
            
            row.add(displayAnswer);
          }
        }
        
        allRows.add(row);
      }
      
      debugPrint('[DEBUG] Survey responses to export: ${filteredResponses.length} (filtered from ${_surveyResponses.length} total)');
      if (allRows.length <= 1) {
        debugPrint('[WARNING] No data rows added to Excel!');
      } else {
        for (int i = 0; i < allRows.length && i < 4; i++) {
          debugPrint('[DEBUG] Excel row $i: ${allRows[i]}');
        }
      }
      
      // Create Excel workbook
      final excelWorkbook = excel.Excel.createExcel();
      final sheet = excelWorkbook['Survey Data'];
      
      for (final row in allRows) {
        sheet.appendRow(row);
      }
      
      // Save to file
      final excelBytes = excelWorkbook.encode();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final collegeSuffix = userCollege != null ? '_${userCollege.replaceAll(' ', '_').toLowerCase()}' : '_all_colleges';
      final fileName = 'survey_data${collegeSuffix}_${timestamp}.xlsx';
      
      if (kIsWeb) {
        debugPrint('[DEBUG] kIsWeb branch entered');
        final csvString = listToCsv(allRows);
        final csvBytes = utf8.encode(csvString);
        final csvFileName = 'survey_data${collegeSuffix}_${timestamp}.csv';
        debugPrint('[DEBUG] Calling downloadFileWeb with fileName: $csvFileName and bytes length: ${csvBytes.length}');
        downloadFileWeb(csvBytes, csvFileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV file downloaded for ${userCollege ?? 'all colleges'}.'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
        return;
      }
      
      Directory? targetDir;
      if (Platform.isAndroid || Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        try {
          targetDir = await getDownloadsDirectory();
        } catch (e) {
          targetDir = await getApplicationDocumentsDirectory();
        }
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }
      
      if (targetDir == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to get a directory to save the file.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final file = File('${targetDir.path}/$fileName');
      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes, flush: true);
      }
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ESSU Survey Data Export',
      );
      
      // Show dialog/snackbar with file path
      if (mounted) {
        if (Theme.of(context).platform == TargetPlatform.windows ||
            Theme.of(context).platform == TargetPlatform.macOS ||
            Theme.of(context).platform == TargetPlatform.linux) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Excel Exported'),
              content: Text('File saved to:\n${file.path}'),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      if (targetDir != null) {
                        await Process.run('explorer', [targetDir.path]);
                      }
                    } catch (e) {
                      // Ignore if not supported
                    }
                  },
                  child: const Text('Open Folder'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel saved for ${userCollege ?? 'all colleges'}: ${file.path}'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      print('Error exporting survey data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting survey data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper to convert rows to CSV
  String listToCsv(List<List<String>> rows) {
    return rows.map((row) => row.map((cell) {
      final escaped = cell.replaceAll('"', '""');
      if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
        return '"$escaped"';
      }
      return escaped;
    }).join(',')).join('\r\n');
  }
} 