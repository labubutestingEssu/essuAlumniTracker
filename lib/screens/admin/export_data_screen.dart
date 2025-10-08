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
      
      // Filter users based on selected criteria
      List<UserModel> users = allUsers;
      if (_selectedCollege != null) {
        users = users.where((user) => user.college == _selectedCollege).toList();
      }
      if (_selectedBatchYear != null) {
        users = users.where((user) => user.batchYear == _selectedBatchYear).toList();
      }
      if (_selectedCourse != null) {
        users = users.where((user) => user.course == _selectedCourse).toList();
      }
      // Get all completed survey responses to check completion status
      final List<SurveyResponseModel> completedSurveyResponses = await _surveyResponseService.getCompletedSurveyResponses();
      final Map<String, SurveyResponseModel> surveyByUserUid = { for (var r in completedSurveyResponses) r.userUid : r };
      debugPrint('[DEBUG] Users fetched: ${users.length}, Completed survey responses: ${completedSurveyResponses.length}');
      // Build headers and rows
      final headers = [
        'Full Name', 'Email', 'Student/Faculty ID', 'College', 'Course', 'Batch Year', 'Phone', 'Current Occupation', 'Company', 'Location', 'Facebook', 'Instagram', 'Role', 'Survey Completed', 'Survey Completed At'
      ];
      final List<List<String>> allRows = [headers];
      int userWithSurveyCount = 0;
      for (var user in users) {
        final survey = surveyByUserUid[user.uid];
        debugPrint('[DEBUG] User: uid=${user.uid}, fullName=${user.fullName}, surveyFound=${survey != null}');
        // Use facultyId for admins, studentId for alumni
        final idValue = (user.role == UserRole.admin || user.role == UserRole.super_admin)
          ? (user.facultyId ?? '')
          : user.studentId;
          
        final userRow = [
          user.fullName,
          user.email,
          idValue,
          user.college,
          user.course,
          user.batchYear,
          user.phone ?? '',
          user.currentOccupation ?? '',
          user.company ?? '',
          user.location ?? '',
          user.facebookUrl ?? '',
          user.instagramUrl ?? '',
          _getRoleDisplayText(user.role),
          (survey != null) ? 'Yes' : 'No',
          survey?.completedAt?.toIso8601String() ?? '',
        ];
        if (survey != null) {
          userWithSurveyCount++;
        }
        allRows.add(userRow);
      }
      debugPrint('[DEBUG] Users with survey: $userWithSurveyCount');
      if (allRows.length <= 1) {
        debugPrint('[WARNING] No data rows added to Excel!');
      } else {
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

  // Helper to convert role enum to display text
  String _getRoleDisplayText(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'College Admin';
      case UserRole.super_admin:
        return 'Admin';
      case UserRole.alumni:
        return 'Alumni';
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
                              '• Student/Faculty ID\n'
                              '• College\n'
                              '• Course\n'
                              '• Batch Year\n'
                              '• Phone\n'
                              '• Current Occupation\n'
                              '• Company\n'
                              '• Location\n'
                              '• Social Media Links\n'
                              '• Survey Completion Status',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Note: The data will be exported in CSV format and can be opened in any spreadsheet application.',
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