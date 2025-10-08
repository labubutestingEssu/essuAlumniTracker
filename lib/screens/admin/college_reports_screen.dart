import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../services/survey_response_service.dart';
import '../../models/survey_response_model.dart';
import '../../utils/batch_year_utils.dart';
import '../../services/survey_question_mapping_service.dart';
import '../../services/export_filter_service.dart';
import 'package:excel/excel.dart' as excel;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/unified_user_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/web_download_stub.dart' if (dart.library.html) '../../utils/web_download.dart';

class CollegeReportsScreen extends StatefulWidget {
  const CollegeReportsScreen({Key? key}) : super(key: key);

  @override
  State<CollegeReportsScreen> createState() => _CollegeReportsScreenState();
}

class _CollegeReportsScreenState extends State<CollegeReportsScreen> {
  final SurveyResponseService _surveyResponseService = SurveyResponseService();
  final SurveyQuestionMappingService _questionMappingService = SurveyQuestionMappingService();
  final ExportFilterService _exportFilterService = ExportFilterService();
  String? _selectedCollege;
  String? _selectedBatchYear;
  bool _isLoading = true;
  Map<String, dynamic> _reportData = {};
  List<String> _colleges = [
    'College of Computing Studies',
    'College of Education',
    'College of Business Administration',
    'College of Engineering',
    'College of Arts and Sciences',
    'College of Technology',
    'College of Agriculture and Fisheries',
    'College of Nursing and Allied Sciences',
    'College of Hospitality Management',
    'College of Criminal Justice Education',
    'Student and Alumni Affairs',
    'External Programs Offerings',
  ];

  // Generate school year display format for UI
  final List<String> _schoolYearDisplay = BatchYearUtils.generateSchoolYearDisplay();

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all users from role-based tables using unified service
      final allUsers = await UnifiedUserService().getAllUsers();
      
      // Filter users based on selected criteria
      List<UserModel> filteredUsers = allUsers;
      
      // Apply college filter if selected
      if (_selectedCollege != null) {
        filteredUsers = filteredUsers.where((user) => user.college == _selectedCollege).toList();
      }
      
      // Apply batch year filter if selected
      if (_selectedBatchYear != null) {
        filteredUsers = filteredUsers.where((user) => user.batchYear == _selectedBatchYear).toList();
      }
      
      // Process users data directly
      final usersData = filteredUsers;
      print('Total user docs fetched: ${usersData.length} (College: ${_selectedCollege ?? "All"}, Batch Year: ${_selectedBatchYear ?? "All"})');

      // Fetch both old and new surveys
      final List<SurveyResponseModel> newSurveyResponses = await _surveyResponseService.getCompletedSurveyResponses();
      
      // Filter new survey responses by college and/or batch year if needed
      List<SurveyResponseModel> filteredNewResponses = newSurveyResponses;
      if (_selectedCollege != null || _selectedBatchYear != null) {
        filteredNewResponses = newSurveyResponses.where((r) {
          bool collegeMatch = _selectedCollege == null || r.college == _selectedCollege;
          bool batchYearMatch = _selectedBatchYear == null || r.batchYear == _selectedBatchYear;
          return collegeMatch && batchYearMatch;
        }).toList();
      }
      
      print('Total new survey responses fetched: ${newSurveyResponses.length}');
      print('Filtered new responses: ${filteredNewResponses.length}');
      
      // Debug: Show all survey response details
      if (newSurveyResponses.isNotEmpty) {
        print('\n=== ALL SURVEY RESPONSES DEBUG ===');
        for (int i = 0; i < newSurveyResponses.length; i++) {
          final response = newSurveyResponses[i];
          print('Response $i:');
          print('  userUid: ${response.userUid}');
          print('  fullName: ${response.fullName}');
          print('  college: ${response.college}');
          print('  batchYear: ${response.batchYear}');
          print('  isCompleted: ${response.isCompleted}');
          print('  responses count: ${response.responses.length}');
          print('  response keys: ${response.responses.keys.toList()}');
        }
      } else {
        print('\n=== NO SURVEY RESPONSES FOUND ===');
        print('This means no alumni have completed the survey yet.');
        print('To get accurate employment data, alumni need to complete the survey.');
      }
      
      // Log sample survey response data for debugging
      if (filteredNewResponses.isNotEmpty) {
        print('\n=== SAMPLE SURVEY RESPONSE DATA ===');
        final sampleResponse = filteredNewResponses.first;
        print('Sample response userUid: ${sampleResponse.userUid}');
        print('Sample response college: ${sampleResponse.college}');
        print('Sample response batchYear: ${sampleResponse.batchYear}');
        print('Sample response responses: ${sampleResponse.responses}');
        
        // Show all available response keys
        final responseKeys = sampleResponse.responses.keys.toList();
        print('Available response keys: $responseKeys');
      }

      // Process the data
      Map<String, int> batchYearCounts = {};
      Map<String, int> courseCounts = {};
      int totalAlumni = 0;
      int completedSurveyCount = 0;
      int employedCount = 0;
      Map<String, int> employmentStatusCounts = {
        'Employed': 0,
        'Unemployed': 0,
        'Self-employed': 0,
        'Further Studies': 0,
      };

      // Build sets of alumni who completed surveys
      final Set<String> newSurveyUserUids = filteredNewResponses.map((r) => r.userUid).toSet();
      final Set<String> allSurveyUserUids = {...newSurveyUserUids};
      
      final Map<String, SurveyResponseModel> newSurveyByUserUid = { for (var r in filteredNewResponses) r.userUid : r };

      print('=== DETAILED USER ANALYSIS ===');
      print('Total users fetched: ${usersData.length}');
      print('New survey user UIDs: $newSurveyUserUids');
      print('All survey user UIDs: $allSurveyUserUids');
      
      for (var user in usersData) {
        print('\n--- User Analysis: ${user.fullName} (${user.uid}) ---');
        print('  Role: ${user.role}');
        print('  College: ${user.college}');
        print('  Course: ${user.course}');
        print('  Batch Year: ${user.batchYear}');
        print('  Current Occupation: ${user.currentOccupation}');
        print('  Company: ${user.company}');
        
        // Only count actual alumni (not admins or super admins)
        if (user.role == UserRole.alumni) {
          print('  -> COUNTED AS ALUMNI (role is alumni)');
          totalAlumni++;
          
          // Count by batch year
          final batchYear = user.batchYear;
          if (batchYear.isNotEmpty) {
            batchYearCounts[batchYear] = (batchYearCounts[batchYear] ?? 0) + 1;
            print('  -> Added to batch year: $batchYear');
          } else {
            print('  -> No batch year found');
          }
          
          // Count by course
          final course = user.course;
          if (course.isNotEmpty) {
            courseCounts[course] = (courseCounts[course] ?? 0) + 1;
            print('  -> Added to course: $course');
          } else {
            print('  -> No course found');
          }
          
          // Count survey completion (check both old and new surveys)
          if (allSurveyUserUids.contains(user.uid)) {
            print('  -> HAS COMPLETED A SURVEY!');
            completedSurveyCount++;

            if (newSurveyUserUids.contains(user.uid)) {
              print('  -> Found in NEW survey data');
            }
          } else {
            print('  -> NO SURVEY COMPLETED');
          }
          
          // Employment status analysis
          final newSurvey = newSurveyByUserUid[user.uid];
          
          print('  -> Employment Analysis:');
          if (newSurvey != null) {
            print('    Using NEW survey data');
            final isEmployed = await _isEmployedFromNewSurvey(newSurvey);
            print('    Employment status from new survey: $isEmployed');
            
            if (isEmployed == true) {
              employedCount++;
              employmentStatusCounts['Employed'] = (employmentStatusCounts['Employed'] ?? 0) + 1;
              print('    -> Counted as EMPLOYED');
            } else if (isEmployed == false) {
              employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
              print('    -> Counted as UNEMPLOYED');
            } else {
              print('    -> Employment status UNKNOWN from new survey');
            }
          } else {
            print('    No survey data found, checking profile data');
            if (user.currentOccupation != null && user.currentOccupation!.isNotEmpty) {
              print('    Profile occupation: ${user.currentOccupation}');
              
              if (user.currentOccupation!.toLowerCase().contains('student')) {
                employmentStatusCounts['Further Studies'] = (employmentStatusCounts['Further Studies'] ?? 0) + 1;
                print('    -> Counted as FURTHER STUDIES (from profile)');
              } else if (user.company != null && user.company!.isNotEmpty) {
                employmentStatusCounts['Employed'] = (employmentStatusCounts['Employed'] ?? 0) + 1;
                print('    -> Counted as EMPLOYED (from profile - has company)');
              } else if (user.currentOccupation!.toLowerCase().contains('self-employed') ||
                        user.currentOccupation!.toLowerCase().contains('freelance')) {
                employmentStatusCounts['Self-employed'] = (employmentStatusCounts['Self-employed'] ?? 0) + 1;
                print('    -> Counted as SELF-EMPLOYED (from profile)');
              } else {
                employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
                print('    -> Counted as UNEMPLOYED (from profile)');
              }
            } else {
              print('    -> No employment data available');
              // Count as unemployed if no data is available
              employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
              print('    -> Counted as UNEMPLOYED (no data available)');
            }
          }
        } else {
          print('  -> SKIPPED (not an alumni - role is ${user.role})');
        }
      }
      
      print('\n=== FINAL COUNTS ===');
      print('Total Alumni: $totalAlumni');
      print('Completed Survey Count: $completedSurveyCount');
      print('Employed Count: $employedCount');
      print('Batch Year Counts: $batchYearCounts');
      print('Course Counts: $courseCounts');
      print('Employment Status Counts: $employmentStatusCounts');
      
      print('\n=== REPORT SUMMARY ===');
      print('✅ Accurate: Alumni count (only UserRole.alumni)');
      print('✅ Accurate: Batch year distribution');
      print('✅ Accurate: Course distribution');
      print('❌ Incomplete: Survey completion (0/${totalAlumni}) - no surveys completed yet');
      print('❌ Incomplete: Employment data - no survey responses available');
      print('💡 To improve accuracy: Alumni need to complete the survey');

      setState(() {
        _reportData = {
          'totalAlumni': totalAlumni,
          'completedSurveyCount': completedSurveyCount,
          'batchYearCounts': batchYearCounts,
          'courseCounts': courseCounts,
          'employmentStatusCounts': employmentStatusCounts,
          'employedCount': employedCount,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: Responsive.isDesktop(context) ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(
          'Total Alumni',
          _reportData['totalAlumni']?.toString() ?? '0',
          Icons.people_outline,
          Colors.blue,
        ),
        _buildSummaryCard(
          'Survey Completion',
          '${_reportData['completedSurveyCount'] ?? 0}/${_reportData['totalAlumni'] ?? 0}',
          Icons.assignment_turned_in_outlined,
          Theme.of(context).primaryColor,
        ),
        _buildSummaryCard(
          'Survey Rate',
          '${_reportData['totalAlumni'] != null && _reportData['totalAlumni']! > 0 ? ((_reportData['completedSurveyCount'] ?? 0) / _reportData['totalAlumni']! * 100).toStringAsFixed(1) : '0'}%',
          Icons.analytics_outlined,
          Colors.orange,
        ),
        _buildSummaryCard(
          'Employment Rate',
          '${_reportData['totalAlumni'] != null && _reportData['totalAlumni']! > 0 ? ((_reportData['employmentStatusCounts']?['Employed'] ?? 0) / _reportData['totalAlumni']! * 100).toStringAsFixed(1) : '0'}%',
          Icons.work_outline,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchYearChart() {
    final batchYearData = _reportData['batchYearCounts'] as Map<String, int>? ?? {};
    final sortedYears = batchYearData.keys.toList()..sort();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alumni by Batch Year',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: batchYearData.values.fold(0, (max, value) => value > max ? value : max).toDouble(),
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value >= 0 && value < sortedYears.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                sortedYears[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: false),
                  barGroups: List.generate(
                    sortedYears.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: batchYearData[sortedYears[index]]?.toDouble() ?? 0,
                          color: Colors.blue,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentStatusChart() {
    final employmentData = _reportData['employmentStatusCounts'] as Map<String, int>? ?? {};
    final total = employmentData.values.fold(0, (sum, value) => sum + value);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employment Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: employmentData.entries.map((entry) {
                    final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      color: _getEmploymentStatusColor(entry.key),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: employmentData.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: _getEmploymentStatusColor(entry.key),
                    ),
                    const SizedBox(width: 4),
                    Text(entry.key),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurveyDebugInfo() {
    final totalAlumni = _reportData['totalAlumni'] ?? 0;
    final completedSurveyCount = _reportData['completedSurveyCount'] ?? 0;
    if (totalAlumni > 0 && completedSurveyCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          'No alumni have completed a survey yet.',
          style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Color _getEmploymentStatusColor(String status) {
    switch (status) {
      case 'Employed':
        return Theme.of(context).primaryColor;
      case 'Unemployed':
        return Colors.red;
      case 'Self-employed':
        return Colors.orange;
      case 'Further Studies':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Helper method to determine employment status from new dynamic survey
  Future<bool?> _isEmployedFromNewSurvey(SurveyResponseModel surveyResponse) async {
    print('    Analyzing new survey responses for employment status...');
    
    // Get question mappings
    final questionMappings = await _questionMappingService.getEmploymentQuestionIds();
    
    // Check multiple possible employment-related questions using proper question IDs
    final currentlyEmployedId = questionMappings['currently_employed'];
    final employmentStatusId = questionMappings['employment_status'];
    final currentOccupationId = questionMappings['current_occupation'];
    final companyId = questionMappings['company'];
    
    final currentlyEmployed = currentlyEmployedId != null ? surveyResponse.getResponse<String>(currentlyEmployedId) : null;
    final employmentStatus = employmentStatusId != null ? surveyResponse.getResponse<String>(employmentStatusId) : null;
    final currentOccupation = currentOccupationId != null ? surveyResponse.getResponse<String>(currentOccupationId) : null;
    final company = companyId != null ? surveyResponse.getResponse<String>(companyId) : null;
    
    print('      currently_employed (ID: $currentlyEmployedId): $currentlyEmployed');
    print('      employment_status (ID: $employmentStatusId): $employmentStatus');
    print('      current_occupation (ID: $currentOccupationId): $currentOccupation');
    print('      company (ID: $companyId): $company');
    
    // Check currently_employed question first
    if (currentlyEmployed != null) {
      if (currentlyEmployed.toLowerCase() == 'yes') {
        print('      -> Determined EMPLOYED from currently_employed: yes');
        return true;
      }
      if (currentlyEmployed.toLowerCase() == 'no' || currentlyEmployed.toLowerCase() == 'never employed') {
        print('      -> Determined UNEMPLOYED from currently_employed: no/never employed');
        return false;
      }
    }
    
    // Check employment_status question
    if (employmentStatus != null) {
      final status = employmentStatus.toLowerCase();
      if (status.contains('employed') && !status.contains('unemployed')) {
        print('      -> Determined EMPLOYED from employment_status: $employmentStatus');
        return true;
      }
      if (status.contains('unemployed') || status.contains('not employed')) {
        print('      -> Determined UNEMPLOYED from employment_status: $employmentStatus');
        return false;
      }
    }
    
    // Check if they have a company name
    if (company != null && company.isNotEmpty) {
      print('      -> Determined EMPLOYED from company: $company');
      return true;
    }
    
    // Check current occupation for employment indicators
    if (currentOccupation != null) {
      final occupation = currentOccupation.toLowerCase();
      if (occupation.contains('student') || occupation.contains('studying')) {
        print('      -> Determined FURTHER STUDIES from occupation: $currentOccupation');
        return null; // Special case for further studies
      }
      if (occupation.contains('self-employed') || occupation.contains('freelance') || occupation.contains('business')) {
        print('      -> Determined SELF-EMPLOYED from occupation: $currentOccupation');
        return true;
      }
      if (occupation.contains('unemployed') || occupation.contains('jobless') || occupation.contains('not working')) {
        print('      -> Determined UNEMPLOYED from occupation: $currentOccupation');
        return false;
      }
    }
    
    print('      -> Could not determine employment status from survey data');
    return null; // Unknown status
  }

  Future<void> _exportReportData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user's filter info
      final filterInfo = await _exportFilterService.getCurrentUserFilterInfo();
      final userCollege = filterInfo['college'] as String?;
      final canExportAll = filterInfo['canExportAll'] as bool;
      
      print('Export filter info: college=$userCollege, canExportAll=$canExportAll');
      
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
      
      // If no college is selected and user is college admin, use their college
      String? exportCollege = _selectedCollege;
      if (!canExportAll && exportCollege == null) {
        exportCollege = userCollege;
      }
      
      // Build export data
      final headers = [
        'Metric',
        'Value',
        'College',
        'Batch Year',
        'Export Date',
      ];
      
      final List<List<String>> allRows = [headers];
      final now = DateTime.now();
      final exportDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // Add summary data
      allRows.add(['Total Alumni', '${_reportData['totalAlumni'] ?? 0}', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      allRows.add(['Completed Surveys', '${_reportData['completedSurveyCount'] ?? 0}', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      allRows.add(['Survey Completion Rate', '${_reportData['totalAlumni'] != null && _reportData['totalAlumni']! > 0 ? ((_reportData['completedSurveyCount'] ?? 0) / _reportData['totalAlumni']! * 100).toStringAsFixed(1) : '0'}%', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      allRows.add(['Employed Count', '${_reportData['employedCount'] ?? 0}', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      allRows.add(['Employment Rate', '${_reportData['totalAlumni'] != null && _reportData['totalAlumni']! > 0 ? ((_reportData['employmentStatusCounts']?['Employed'] ?? 0) / _reportData['totalAlumni']! * 100).toStringAsFixed(1) : '0'}%', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      
      // Add batch year data
      final batchYearCounts = _reportData['batchYearCounts'] as Map<String, int>? ?? {};
      for (final entry in batchYearCounts.entries) {
        allRows.add(['Batch Year: ${entry.key}', '${entry.value}', exportCollege ?? 'All', entry.key, exportDate]);
      }
      
      // Add course data
      final courseCounts = _reportData['courseCounts'] as Map<String, int>? ?? {};
      for (final entry in courseCounts.entries) {
        allRows.add(['Program: ${entry.key}', '${entry.value}', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      }
      
      // Add employment status data
      final employmentStatusCounts = _reportData['employmentStatusCounts'] as Map<String, int>? ?? {};
      for (final entry in employmentStatusCounts.entries) {
        allRows.add(['Employment Status: ${entry.key}', '${entry.value}', exportCollege ?? 'All', _selectedBatchYear ?? 'All', exportDate]);
      }
      
      // Create Excel workbook
      final excelWorkbook = excel.Excel.createExcel();
      final sheet = excelWorkbook['College Report Data'];
      
      for (final row in allRows) {
        sheet.appendRow(row);
      }
      
      // Save to file
      final excelBytes = excelWorkbook.encode();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'college_report_${exportCollege ?? 'all'}_${timestamp}.xlsx';
      
      if (kIsWeb) {
        final csvString = _listToCsv(allRows);
        final csvBytes = utf8.encode(csvString);
        final csvFileName = 'college_report_${exportCollege ?? 'all'}_${timestamp}.csv';
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
        text: 'ESSU College Report Data Export',
      );
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report exported successfully for ${exportCollege ?? 'all colleges'}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error exporting report data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting report data: $e'),
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
  String _listToCsv(List<List<String>> rows) {
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
        title: 'College Reports',
        customAppBar: CustomAppBar(
          title: 'College Reports',
          showBackButton: false, // Hide default back button
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportReportData,
              tooltip: 'Export Report Data',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 24.0 : 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter selectors
                    if (isDesktop)
                      Row(
                        children: [
                          // College selector
                          Expanded(
                            child: DropdownSearch<String>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: const TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Search college...',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                                menuProps: MenuProps(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: ['All Colleges', ..._colleges],
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Select College',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.account_balance),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCollege = value == 'All Colleges' ? null : value;
                                });
                                _loadReportData();
                              },
                              selectedItem: _selectedCollege ?? 'All Colleges',
                              dropdownBuilder: (context, selectedItem) {
                                return Text(
                                  selectedItem ?? 'All Colleges',
                                  style: const TextStyle(fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                              filterFn: (item, filter) {
                                return item.toLowerCase().contains(filter.toLowerCase());
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Batch year selector
                          Expanded(
                            child: DropdownSearch<String>(
                              popupProps: PopupProps.menu(
                                showSearchBox: true,
                                searchFieldProps: const TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Search school year...',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                ),
                                menuProps: MenuProps(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items: ['All School Years', ..._schoolYearDisplay.reversed],
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Select School Year',
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                  prefixIcon: Icon(Icons.calendar_today),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _selectedBatchYear = value == 'All School Years' ? null : BatchYearUtils.schoolYearToBatchYear(value ?? '');
                                });
                                _loadReportData();
                              },
                              selectedItem: _selectedBatchYear != null ? BatchYearUtils.batchYearToSchoolYear(_selectedBatchYear!) : 'All School Years',
                              dropdownBuilder: (context, selectedItem) {
                                return Text(
                                  selectedItem ?? 'All School Years',
                                  style: const TextStyle(fontSize: 16),
                                );
                              },
                              filterFn: (item, filter) {
                                return item.toLowerCase().contains(filter.toLowerCase());
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          // College selector
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Search college...',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              menuProps: MenuProps(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: ['All Colleges', ..._colleges],
                            dropdownDecoratorProps: const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Select College',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.account_balance),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedCollege = value == 'All Colleges' ? null : value;
                              });
                              _loadReportData();
                            },
                            selectedItem: _selectedCollege ?? 'All Colleges',
                            dropdownBuilder: (context, selectedItem) {
                              return Text(
                                selectedItem ?? 'All Colleges',
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                            filterFn: (item, filter) {
                              return item.toLowerCase().contains(filter.toLowerCase());
                            },
                          ),
                          const SizedBox(height: 16),
                          // Batch year selector
                          DropdownSearch<String>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: const TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Search school year...',
                                  prefixIcon: Icon(Icons.search),
                                ),
                              ),
                              menuProps: MenuProps(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: ['All School Years', ..._schoolYearDisplay.reversed],
                            dropdownDecoratorProps: const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                labelText: 'Select School Year',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                                prefixIcon: Icon(Icons.calendar_today),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedBatchYear = value == 'All School Years' ? null : BatchYearUtils.schoolYearToBatchYear(value ?? '');
                              });
                              _loadReportData();
                            },
                              selectedItem: _selectedBatchYear != null ? BatchYearUtils.batchYearToSchoolYear(_selectedBatchYear!) : 'All School Years',
                              dropdownBuilder: (context, selectedItem) {
                                return Text(
                                  selectedItem ?? 'All School Years',
                                style: const TextStyle(fontSize: 16),
                              );
                            },
                            filterFn: (item, filter) {
                              return item.toLowerCase().contains(filter.toLowerCase());
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    
                    // Debug warning/info
                    _buildSurveyDebugInfo(),
                    
                    // Summary cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    
                    // Charts
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildBatchYearChart()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildEmploymentStatusChart()),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildBatchYearChart(),
                          const SizedBox(height: 24),
                          _buildEmploymentStatusChart(),
                        ],
                      ),
                  ],
                ),
              ),
      ),
    );
  }
} 