import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../services/survey_response_service.dart';
import '../../models/survey_response_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'dart:convert';
import '../../utils/web_download_stub.dart' if (dart.library.html) '../../utils/web_download.dart';
import '../../services/unified_user_service.dart';
import '../../services/survey_question_service.dart';
import '../../models/survey_question_model.dart';

class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({Key? key}) : super(key: key);

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  bool _isLoading = false;
  String? _selectedCollege;
  String? _selectedBatchYear;
  String? _selectedCourse;
  final SurveyResponseService _surveyResponseService = SurveyResponseService();
  List<String> _colleges = [];
  List<String> _batchYears = [];
  Map<String, List<String>> _coursesByCollege = {};

  @override
  void initState() {
    super.initState();
    _loadCollegesAndCourses();
  }

  Future<void> _loadCollegesAndCourses() async {
    // Fetch all courses from Firestore
    final firestore = FirebaseFirestore.instance;
    final coursesSnapshot = await firestore.collection('courses').get();
    final Set<String> collegesSet = {};
    final Map<String, Set<String>> coursesByCollegeSet = {};
    for (final doc in coursesSnapshot.docs) {
      final data = doc.data();
      final college = data['college'] ?? '';
      final course = data['name'] ?? '';
      if (college.isNotEmpty) {
        collegesSet.add(college);
        coursesByCollegeSet.putIfAbsent(college, () => {});
        if (course.isNotEmpty) {
          coursesByCollegeSet[college]!.add(course);
        }
      }
    }
    // Fetch all batch years from role-based tables
    final allUsers = await UnifiedUserService().getAllUsers();
    final Set<String> batchYearsSet = {};
    for (final user in allUsers) {
      final batchYear = user.batchYear;
      if (batchYear.isNotEmpty) batchYearsSet.add(batchYear);
    }
    setState(() {
      _colleges = collegesSet.toList()..sort();
      _coursesByCollege = { for (var c in coursesByCollegeSet.keys) c: coursesByCollegeSet[c]!.toList()..sort() };
      _batchYears = batchYearsSet.toList()..sort();
    });
  }

  Future<void> _exportData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Get all users from role-based tables
      final allUsers = await UnifiedUserService().getAllUsers();
      
      // Filter out ADMIN and SUPER_ADMIN roles - only export alumni
      List<UserModel> users = allUsers.where((user) => user.role == UserRole.alumni).toList();
      
      // Filter users based on selected criteria
      if (_selectedCollege != null) {
        users = users.where((user) => user.college == _selectedCollege).toList();
      }
      if (_selectedBatchYear != null) {
        users = users.where((user) => user.batchYear == _selectedBatchYear).toList();
      }
      if (_selectedCourse != null) {
        users = users.where((user) => user.course == _selectedCourse).toList();
      }
      
      // Get survey questions from active set
      final surveyQuestionService = SurveyQuestionService();
      final activeSetId = await surveyQuestionService.getActiveSetId();
      final surveyQuestions = await surveyQuestionService.getActiveQuestions(setId: activeSetId);
      
      // Filter out section headers, keep only actual questions
      final actualQuestions = surveyQuestions.where((q) => q.type != QuestionType.section).toList();
      
      // Get all completed survey responses
      final List<SurveyResponseModel> completedSurveyResponses = await _surveyResponseService.getCompletedSurveyResponses();
      final Map<String, SurveyResponseModel> surveyByUserUid = { for (var r in completedSurveyResponses) r.userUid : r };
      
      debugPrint('[DEBUG] Alumni users fetched: ${users.length}, Survey questions: ${actualQuestions.length}, Completed survey responses: ${completedSurveyResponses.length}');
      
      // Build headers - basic info + survey questions
      final headers = [
        'Full Name', 'Email', 'Student ID', 'College', 'Course', 'Batch Year', 
        'Phone', 'Current Occupation', 'Company', 'Location', 'Facebook', 'Instagram', 
        'Survey Completed', 'Survey Completed At',
      ];
      
      // Add survey question titles as headers
      for (var question in actualQuestions) {
        headers.add(question.title);
      }
      
      final List<List<String>> allRows = [headers];
      int userWithSurveyCount = 0;
      
      for (var user in users) {
        final survey = surveyByUserUid[user.uid];
        debugPrint('[DEBUG] User: uid=${user.uid}, fullName=${user.fullName}, surveyFound=${survey != null}');
          
        final userRow = [
          user.fullName,
          user.email,
          user.studentId,
          user.college,
          user.course,
          user.batchYear,
          user.phone ?? '',
          user.currentOccupation ?? '',
          user.company ?? '',
          user.location ?? '',
          user.facebookUrl ?? '',
          user.instagramUrl ?? '',
          (survey != null) ? 'Yes' : 'No',
          survey?.completedAt?.toIso8601String() ?? '',
        ];
        
        // Add survey answers for each question
        if (survey != null) {
          userWithSurveyCount++;
          for (var question in actualQuestions) {
            // Use getResponse method to properly retrieve the answer
            final answer = survey.getResponse<dynamic>(question.id);
            // Format answer based on type
            String answerStr = '';
            if (answer != null) {
              // Handle Map structure (bypass fields, other_specify, etc.)
              if (answer is Map) {
                // Check for bypass structure with 'value' key
                if (answer.containsKey('value')) {
                  final value = answer['value'];
                  if (value != null && value.toString().isNotEmpty) {
                    answerStr = value.toString();
                  }
                }
                // Check for 'other_specify' structure
                else if (answer.containsKey('other_specify')) {
                  final otherValue = answer['other_specify'];
                  if (otherValue != null && otherValue.toString().isNotEmpty) {
                    answerStr = 'Other: ${otherValue.toString()}';
                  }
                }
                // Generic map handling
                else {
                  answerStr = answer.values.where((v) => v != null && v.toString().isNotEmpty).join(', ');
                }
              }
              // Handle List
              else if (answer is List) {
                answerStr = answer.join(', ');
              }
              // Handle DateTime
              else if (answer is DateTime) {
                answerStr = '${answer.day}/${answer.month}/${answer.year}';
              }
              // Handle simple types
              else {
                answerStr = answer.toString();
              }
            }
            userRow.add(answerStr);
          }
        } else {
          // No survey - add empty cells for all questions
          for (var _ in actualQuestions) {
            userRow.add('');
          }
        }
        
        allRows.add(userRow);
      }
      debugPrint('[DEBUG] Users with survey: $userWithSurveyCount');
      debugPrint('[DEBUG] Total rows in export: ${allRows.length} (including header)');
      debugPrint('[DEBUG] Total question columns: ${actualQuestions.length}');
      
      if (allRows.length <= 1) {
        debugPrint('[WARNING] No data rows added to Excel!');
      } else {
        // Debug: Show sample of first user's data
        if (allRows.length > 1) {
          debugPrint('[DEBUG] Sample user row (first user):');
          final sampleRow = allRows[1];
          debugPrint('  - Name: ${sampleRow[0]}');
          debugPrint('  - Email: ${sampleRow[1]}');
          debugPrint('  - Survey Completed: ${sampleRow[12]}');
          debugPrint('  - First 3 survey answers:');
          final startIdx = 14; // After basic info
          for (int i = 0; i < 3 && (startIdx + i) < sampleRow.length; i++) {
            final questionIdx = i;
            final questionTitle = questionIdx < actualQuestions.length ? actualQuestions[questionIdx].title : 'Unknown';
            debugPrint('    Q${i + 1} ($questionTitle): ${sampleRow[startIdx + i]}');
          }
        }
        
        for (int i = 0; i < allRows.length && i < 4; i++) {
          debugPrint('[DEBUG] Excel row $i: ${allRows[i]}');
        }
      }
      // Create Excel workbook
      final excel = Excel.createExcel();

      final sheet = excel['Alumni Data'];
      for (final row in allRows) {
        sheet.appendRow(row);
      }
      // Save to file
      final excelBytes = excel.encode();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'alumni_data_${timestamp}.xlsx';
      if (kIsWeb) {
        debugPrint('[DEBUG] kIsWeb branch entered');
        final csvString = listToCsv(allRows);
        final csvBytes = utf8.encode(csvString);
        final csvFileName = 'alumni_data_${timestamp}.csv';
        debugPrint('[DEBUG] Calling downloadFileWeb with fileName: $csvFileName and bytes length: ${csvBytes.length}');
        downloadFileWeb(csvBytes, csvFileName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV file downloaded.'),
              duration: Duration(seconds: 6),
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
        text: 'ESSU Alumni Data Export',
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
              content: Text('Excel saved to: ${file.path}'),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } catch (e) {
      print('Error exporting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    
    return WillPopScope(
      onWillPop: () async {
        // Navigate to Alumni Directory and replace the current route
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        // Prevent the default back button behavior
        return false;
      },
      child: ResponsiveScreenWrapper(
        title: 'Export Alumni Data',
        customAppBar: const CustomAppBar(
          title: 'Export Alumni Data',
          showBackButton: false, // Hide default back button
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Export Filters',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCollege,
                              decoration: const InputDecoration(
                                labelText: 'College',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Colleges'),
                                ),
                                ..._colleges.map((college) {
                                  return DropdownMenuItem<String>(
                                    value: college,
                                    child: Text(college),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCollege = value;
                                  _selectedCourse = null; // Reset course when college changes
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            if (_selectedCollege != null) ...[
                              DropdownButtonFormField<String>(
                                value: _selectedCourse,
                                decoration: const InputDecoration(
                                  labelText: 'Program',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('All Programs'),
                                  ),
                                  ...(_coursesByCollege[_selectedCollege] ?? []).map((course) {
                                    return DropdownMenuItem<String>(
                                      value: course,
                                      child: Text(course),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCourse = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                            DropdownButtonFormField<String>(
                              value: _selectedBatchYear,
                              decoration: const InputDecoration(
                                labelText: 'Batch Year',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Years'),
                                ),
                                ..._batchYears.map((year) {
                                  return DropdownMenuItem<String>(
                                    value: year,
                                    child: Text(year),
                                  );
                                }).toList(),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedBatchYear = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _exportData,
                                icon: const Icon(Icons.download),
                                label: const Text('Export Data'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Export Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'The exported data will include the following information for each alumnus:',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Full Name\n'
                              '• Email\n'
                              '• Student ID\n'
                              '• College\n'
                              '• Course\n'
                              '• Batch Year\n'
                              '• Phone\n'
                              '• Current Occupation\n'
                              '• Company\n'
                              '• Location\n'
                              '• Social Media Links\n'
                              '• Survey Completion Status\n'
                              '• All Survey Questions & Answers (from active question set)',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Note: The data will be exported in CSV format and can be opened in any spreadsheet application. '
                              'Each survey question will appear as a separate column with the alumnus\'s answer. '
                              'Only alumni accounts will be exported (admin accounts are excluded).',
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
} 