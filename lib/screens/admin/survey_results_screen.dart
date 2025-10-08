import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/survey_response_service.dart';
import '../../models/survey_response_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../services/survey_question_mapping_service.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../services/unified_user_service.dart';

class SurveyResultsScreen extends StatefulWidget {
  const SurveyResultsScreen({Key? key}) : super(key: key);

  @override
  _SurveyResultsScreenState createState() => _SurveyResultsScreenState();
}

class _SurveyResultsScreenState extends State<SurveyResultsScreen> {
  final _surveyResponseService = SurveyResponseService();
  final _questionMappingService = SurveyQuestionMappingService();
  bool _isLoading = true;
  String? _selectedCollege;
  Map<String, dynamic> _employmentStats = {};
  Map<String, dynamic> _organizationTypesAnalysis = {};
  Map<String, dynamic> _incomeAnalysis = {};
  Map<String, dynamic> _jobRelevanceAnalysis = {};
  double _completionRate = 0.0;
  bool _hasLoadingError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadingError) {
      // Schedule the snackbar to be shown after the current frame
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading data.')),
        );
      });
      _hasLoadingError = false; // Reset the flag immediately
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      print("=== LOADING SURVEY RESULTS WITH ENHANCED ACCURACY ===");

      // Get all users from role-based tables for accurate analysis
      final allUsers = await UnifiedUserService().getAllUsers();
      
      print('Total users in database: ${allUsers.length}');

      // Load new survey responses
      final newSurveyResponses = await _surveyResponseService.getCompletedSurveyResponses();
      final newStats = await _surveyResponseService.getSurveyStatistics();
      
      print('New survey responses: ${newSurveyResponses.length}');
      print('New survey stats: $newStats');

      // Analyze user data for accurate employment statistics
      final userAnalysis = await _analyzeUserData(allUsers, newSurveyResponses);
      
      print('User analysis completed:');
      print('  Total Alumni: ${userAnalysis['totalAlumni']}');
      print('  Survey Completion: ${userAnalysis['completedSurveyCount']}');
      print('  Employment Status: ${userAnalysis['employmentStatusCounts']}');

      // Generate new analytics based on actual survey data
      final combinedEmploymentStats = await _combineEmploymentStatsWithUserData(
        <String, dynamic>{}, // Empty old stats
        newSurveyResponses,
        userAnalysis,
      );
      
      final organizationTypesAnalysis = await _analyzeOrganizationTypes(newSurveyResponses);
      final incomeAnalysis = await _analyzeIncomeRanges(newSurveyResponses);
      final jobRelevanceAnalysis = await _analyzeJobRelevance(newSurveyResponses);
      
      // Calculate accurate completion rate based on actual alumni count
      final totalAlumni = userAnalysis['totalAlumni'] as int;
      final completedSurveyCount = userAnalysis['completedSurveyCount'] as int;
      final accurateCompletionRate = totalAlumni > 0 ? completedSurveyCount / totalAlumni : 0.0;

      setState(() {
        _employmentStats = combinedEmploymentStats;
        _organizationTypesAnalysis = organizationTypesAnalysis;
        _incomeAnalysis = incomeAnalysis;
        _jobRelevanceAnalysis = jobRelevanceAnalysis;
        _completionRate = accurateCompletionRate;
        _selectedCollege = "All Colleges"; // Indicate global results
      });

      print("=== SURVEY RESULTS LOADED SUCCESSFULLY ===");
      print("Accurate completion rate: ${(accurateCompletionRate * 100).toStringAsFixed(1)}%");
      print("Employment stats: $combinedEmploymentStats");

    } catch (e) {
      print('Error loading survey results: $e');
      if (mounted) {
        _hasLoadingError = true;
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1200;

    return WillPopScope(
      onWillPop: () async {
        // Navigate to Alumni Directory and replace the current route
        NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
        // Prevent the default back button behavior
        return false;
      },
      child: ResponsiveScreenWrapper(
        title: 'Survey Results',
        customAppBar: const CustomAppBar(title: 'Survey Results'),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_employmentStats['employed'] == null && _employmentStats['unemployed'] == null)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No survey data available yet.',
                        style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Survey Results for $_selectedCollege',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDebugInfo(),
                        const SizedBox(height: 24),
                        _buildCompletionRateCard(),
                        const SizedBox(height: 24),
                        _buildEmploymentSection(isDesktop),
                        const SizedBox(height: 24),
                        _buildOrganizationTypesSection(isDesktop),
                        const SizedBox(height: 24),
                        _buildIncomeAnalysisSection(isDesktop),
                        const SizedBox(height: 24),
                        _buildJobRelevanceSection(isDesktop),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildDebugInfo() {
    final totalAlumni = _employmentStats['totalAlumni'] as int? ?? 0;
    final completedSurveyCount = (_completionRate * totalAlumni).round();
    
    if (totalAlumni > 0 && completedSurveyCount == 0) {
      return Card(
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Survey Data Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'No alumni have completed the survey yet.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.amber.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Total Alumni: $totalAlumni',
                style: TextStyle(fontSize: 14, color: Colors.amber.shade700),
              ),
              Text(
                '• Survey Completion: $completedSurveyCount',
                style: TextStyle(fontSize: 14, color: Colors.amber.shade700),
              ),
              Text(
                '• Employment data is based on profile information',
                style: TextStyle(fontSize: 14, color: Colors.amber.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 To get accurate employment data, alumni need to complete the survey.',
                style: TextStyle(fontSize: 14, color: Colors.amber.shade700, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildCompletionRateCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Survey Completion Rate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _completionRate,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _completionRate >= 0.7
                    ? Theme.of(context).primaryColor
                    : _completionRate >= 0.4
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_completionRate * 100).toStringAsFixed(1)}% of alumni have completed the survey',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentSection(bool isDesktop) {
    final employed = _employmentStats['employed'] as int? ?? 0;
    final unemployed = _employmentStats['unemployed'] as int? ?? 0;
    final selfEmployed = _employmentStats['selfEmployed'] as int? ?? 0;
    final furtherStudies = _employmentStats['furtherStudies'] as int? ?? 0;
    final employmentRate = _employmentStats['employmentRate'] as double? ?? 0.0;
    final totalAlumni = _employmentStats['totalAlumni'] as int? ?? 0;
    final industries = _safeIntMap(_employmentStats['industries']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Employment Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (totalAlumni > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Based on $totalAlumni alumni',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildEmploymentPieChart(employed, unemployed, selfEmployed, furtherStudies),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEmploymentRateCard(employmentRate),
                        const SizedBox(height: 16),
                        _buildEmploymentStatusBreakdown(employed, unemployed, selfEmployed, furtherStudies),
                        const SizedBox(height: 16),
                        _buildIndustriesList(industries),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildEmploymentPieChart(employed, unemployed, selfEmployed, furtherStudies),
                  const SizedBox(height: 24),
                  _buildEmploymentRateCard(employmentRate),
                  const SizedBox(height: 24),
                  _buildEmploymentStatusBreakdown(employed, unemployed, selfEmployed, furtherStudies),
                  const SizedBox(height: 24),
                  _buildIndustriesList(industries),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmploymentPieChart(int employed, int unemployed, int selfEmployed, int furtherStudies) {
    final total = employed + unemployed + selfEmployed + furtherStudies;
    if (total == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No employment data available',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    final sections = <PieChartSectionData>[];
    
    if (employed > 0) {
      sections.add(PieChartSectionData(
        value: employed.toDouble(),
        title: '${((employed / total) * 100).toStringAsFixed(1)}%',
        color: Theme.of(context).primaryColor,
        radius: 80,
      ));
    }
    
    if (unemployed > 0) {
      sections.add(PieChartSectionData(
        value: unemployed.toDouble(),
        title: '${((unemployed / total) * 100).toStringAsFixed(1)}%',
        color: Colors.red,
        radius: 80,
      ));
    }
    
    if (selfEmployed > 0) {
      sections.add(PieChartSectionData(
        value: selfEmployed.toDouble(),
        title: '${((selfEmployed / total) * 100).toStringAsFixed(1)}%',
        color: Colors.orange,
        radius: 80,
      ));
    }
    
    if (furtherStudies > 0) {
      sections.add(PieChartSectionData(
        value: furtherStudies.toDouble(),
        title: '${((furtherStudies / total) * 100).toStringAsFixed(1)}%',
        color: Colors.blue,
        radius: 80,
      ));
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }

  Widget _buildEmploymentStatusBreakdown(int employed, int unemployed, int selfEmployed, int furtherStudies) {
    final total = employed + unemployed + selfEmployed + furtherStudies;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employment Status Breakdown',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (employed > 0)
          _buildStatusRow('Employed', employed, total, Theme.of(context).primaryColor),
        if (selfEmployed > 0)
          _buildStatusRow('Self-employed', selfEmployed, total, Colors.orange),
        if (furtherStudies > 0)
          _buildStatusRow('Further Studies', furtherStudies, total, Colors.blue),
        if (unemployed > 0)
          _buildStatusRow('Unemployed', unemployed, total, Colors.red),
      ],
    );
  }

  Widget _buildStatusRow(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            '$count (${percentage.toStringAsFixed(1)}%)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentRateCard(double rate) {
    return Card(
      color: rate >= 0.7
          ? Theme.of(context).primaryColor.withOpacity(0.1)
          : rate >= 0.4
              ? Colors.orange[100]
              : Colors.red[100],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Employment Rate',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(rate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndustriesList(Map<String, int> industries) {
    final sortedIndustries = industries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Industries',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedIndustries.take(5).map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(entry.key),
                ),
                Text(
                  '${entry.value} alumni',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }





  // Helper to safely extract Map<String, int> from dynamic
  Map<String, int> _safeIntMap(dynamic value) {
    if (value is Map<String, int>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0));
    }
    return {};
  }


  // Analyze user data for accurate employment statistics
  Future<Map<String, dynamic>> _analyzeUserData(
    List<UserModel> users,
    List<SurveyResponseModel> newSurveyResponses,
  ) async {
    print('=== ANALYZING USER DATA FOR ACCURATE STATISTICS ===');
    
    int totalAlumni = 0;
    int completedSurveyCount = 0;
    Map<String, int> employmentStatusCounts = {
      'Employed': 0,
      'Unemployed': 0,
      'Self-employed': 0,
      'Further Studies': 0,
    };

    // Build sets of alumni who completed surveys
    final Set<String> newSurveyUserUids = newSurveyResponses.map((r) => r.userUid).toSet();
    final Map<String, SurveyResponseModel> newSurveyByUserUid = { 
      for (var r in newSurveyResponses) r.userUid : r 
    };

    print('New survey user UIDs: $newSurveyUserUids');
    print('Total new survey responses: ${newSurveyResponses.length}');

    for (var user in users) {
      
      // Only count actual alumni (not admins or super admins)
      if (user.role == UserRole.alumni) {
        totalAlumni++;
        
        // Count survey completion
        if (newSurveyUserUids.contains(user.uid)) {
          completedSurveyCount++;
        }
        
        // Employment status analysis
        final newSurvey = newSurveyByUserUid[user.uid];
        
        if (newSurvey != null) {
          print('  -> Employment Analysis for ${user.fullName}:');
          final isEmployed = await _isEmployedFromNewSurvey(newSurvey);
          print('    Employment status from new survey: $isEmployed');
          
          if (isEmployed == true) {
            employmentStatusCounts['Employed'] = (employmentStatusCounts['Employed'] ?? 0) + 1;
            print('    -> Counted as EMPLOYED');
          } else if (isEmployed == false) {
            employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
            print('    -> Counted as UNEMPLOYED');
          } else {
            print('    -> Employment status UNKNOWN from new survey');
          }
        } else {
          // No survey data, check profile data
          if (user.currentOccupation != null && user.currentOccupation!.isNotEmpty) {
            if (user.currentOccupation!.toLowerCase().contains('student')) {
              employmentStatusCounts['Further Studies'] = (employmentStatusCounts['Further Studies'] ?? 0) + 1;
            } else if (user.company != null && user.company!.isNotEmpty) {
              employmentStatusCounts['Employed'] = (employmentStatusCounts['Employed'] ?? 0) + 1;
            } else if (user.currentOccupation!.toLowerCase().contains('self-employed') ||
                      user.currentOccupation!.toLowerCase().contains('freelance')) {
              employmentStatusCounts['Self-employed'] = (employmentStatusCounts['Self-employed'] ?? 0) + 1;
            } else {
              employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
            }
          } else {
            // No employment data available, count as unemployed
            employmentStatusCounts['Unemployed'] = (employmentStatusCounts['Unemployed'] ?? 0) + 1;
          }
        }
      }
    }

    print('=== USER ANALYSIS RESULTS ===');
    print('Total Alumni: $totalAlumni');
    print('Completed Survey Count: $completedSurveyCount');
    print('Employment Status Counts: $employmentStatusCounts');

    return {
      'totalAlumni': totalAlumni,
      'completedSurveyCount': completedSurveyCount,
      'employmentStatusCounts': employmentStatusCounts,
    };
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

  // Combine employment stats with enhanced accuracy using user data
  Future<Map<String, dynamic>> _combineEmploymentStatsWithUserData(
    Map<String, dynamic> oldStats, 
    List<SurveyResponseModel> newResponses,
    Map<String, dynamic> userAnalysis,
  ) async {
    print('=== COMBINING EMPLOYMENT STATS WITH USER DATA ===');
    
    final employmentStatusCounts = userAnalysis['employmentStatusCounts'] as Map<String, int>;
    final totalAlumni = userAnalysis['totalAlumni'] as int;
    
    // Calculate accurate employment rates
    final employed = employmentStatusCounts['Employed'] ?? 0;
    final unemployed = employmentStatusCounts['Unemployed'] ?? 0;
    final selfEmployed = employmentStatusCounts['Self-employed'] ?? 0;
    final furtherStudies = employmentStatusCounts['Further Studies'] ?? 0;
    
    final totalWithEmploymentData = employed + unemployed + selfEmployed + furtherStudies;
    final employmentRate = totalWithEmploymentData > 0 ? (employed + selfEmployed) / totalWithEmploymentData : 0.0;
    
    // Build industries and job levels from new survey responses
    Map<String, int> industries = Map<String, int>.from(oldStats['industries'] as Map? ?? {});
    Map<String, int> jobLevels = Map<String, int>.from(oldStats['jobLevels'] as Map? ?? {});

    // Get question mappings for industries and job levels
    final questionMappings = await _questionMappingService.getEmploymentQuestionIds();
    final currentlyEmployedId = questionMappings['currently_employed'];
    final orgTypeId = questionMappings['organization_type'];
    final jobLevelId = questionMappings['employment_status'];

    for (var response in newResponses) {
      final isEmployed = currentlyEmployedId != null ? response.getResponse<String>(currentlyEmployedId) : null;
      if (isEmployed?.toLowerCase() == 'yes') {
        // Count industries
        final orgType = orgTypeId != null ? response.getResponse<String>(orgTypeId) : null;
        if (orgType != null) {
          industries[orgType] = (industries[orgType] ?? 0) + 1;
        }
        
        // Count job levels
        final jobLevel = jobLevelId != null ? response.getResponse<String>(jobLevelId) : null;
        if (jobLevel != null) {
          jobLevels[jobLevel] = (jobLevels[jobLevel] ?? 0) + 1;
        }
      }
    }

    print('Employment stats calculated:');
    print('  Employed: $employed');
    print('  Unemployed: $unemployed');
    print('  Self-employed: $selfEmployed');
    print('  Further Studies: $furtherStudies');
    print('  Employment Rate: ${(employmentRate * 100).toStringAsFixed(1)}%');

    return {
      'employed': employed,
      'unemployed': unemployed,
      'selfEmployed': selfEmployed,
      'furtherStudies': furtherStudies,
      'employmentRate': employmentRate,
      'industries': industries,
      'jobLevels': jobLevels,
      'totalAlumni': totalAlumni,
    };
  }


  // Analyze organization types from survey responses
  Future<Map<String, dynamic>> _analyzeOrganizationTypes(List<SurveyResponseModel> responses) async {
    final questionMappings = await _questionMappingService.getEmploymentQuestionIds();
    final organizationTypeId = questionMappings['organization_type'];
    
    Map<String, int> organizationTypes = {};
    
    for (var response in responses) {
      final isEmployed = questionMappings['currently_employed'] != null 
          ? response.getResponse<String>(questionMappings['currently_employed']!) 
          : null;
      
      if (isEmployed?.toLowerCase() == 'yes' && organizationTypeId != null) {
        final orgType = response.getResponse<String>(organizationTypeId);
        if (orgType != null && orgType.isNotEmpty) {
          organizationTypes[orgType] = (organizationTypes[orgType] ?? 0) + 1;
        }
      }
    }
    
    return {
      'organizationTypes': organizationTypes,
      'totalEmployed': organizationTypes.values.fold(0, (sum, count) => sum + count),
    };
  }

  // Analyze income ranges from survey responses
  Future<Map<String, dynamic>> _analyzeIncomeRanges(List<SurveyResponseModel> responses) async {
    final questionMappings = await _questionMappingService.getEmploymentQuestionIds();
    final monthlyIncomeId = questionMappings['monthly_income'];
    final selfEmploymentIncomeId = questionMappings['self_employment_income'];
    
    Map<String, int> incomeRanges = {};
    
    for (var response in responses) {
      final isEmployed = questionMappings['currently_employed'] != null 
          ? response.getResponse<String>(questionMappings['currently_employed']!) 
          : null;
      
      if (isEmployed?.toLowerCase() == 'yes') {
        // Check regular employment income
        if (monthlyIncomeId != null) {
          final income = response.getResponse<String>(monthlyIncomeId);
          if (income != null && income.isNotEmpty && income != 'N/A') {
            incomeRanges[income] = (incomeRanges[income] ?? 0) + 1;
          }
        }
        
        // Check self-employment income
        if (selfEmploymentIncomeId != null) {
          final selfIncome = response.getResponse<String>(selfEmploymentIncomeId);
          if (selfIncome != null && selfIncome.isNotEmpty && selfIncome != 'N/A') {
            incomeRanges[selfIncome] = (incomeRanges[selfIncome] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'incomeRanges': incomeRanges,
      'totalWithIncomeData': incomeRanges.values.fold(0, (sum, count) => sum + count),
    };
  }

  // Analyze job relevance to degree from survey responses
  Future<Map<String, dynamic>> _analyzeJobRelevance(List<SurveyResponseModel> responses) async {
    final questionMappings = await _questionMappingService.getEmploymentQuestionIds();
    final jobRelatedId = questionMappings['job_related_to_degree'];
    final firstJobId = questionMappings['first_job_after_college'];
    
    Map<String, int> jobRelevance = {};
    Map<String, int> firstJobStatus = {};
    
    for (var response in responses) {
      final isEmployed = questionMappings['currently_employed'] != null 
          ? response.getResponse<String>(questionMappings['currently_employed']!) 
          : null;
      
      if (isEmployed?.toLowerCase() == 'yes') {
        // Check job relevance to degree
        if (jobRelatedId != null) {
          final related = response.getResponse<String>(jobRelatedId);
          if (related != null && related.isNotEmpty) {
            jobRelevance[related] = (jobRelevance[related] ?? 0) + 1;
          }
        }
        
        // Check if first job after college
        if (firstJobId != null) {
          final firstJob = response.getResponse<String>(firstJobId);
          if (firstJob != null && firstJob.isNotEmpty) {
            firstJobStatus[firstJob] = (firstJobStatus[firstJob] ?? 0) + 1;
          }
        }
      }
    }
    
    return {
      'jobRelevance': jobRelevance,
      'firstJobStatus': firstJobStatus,
      'totalEmployed': jobRelevance.values.fold(0, (sum, count) => sum + count),
    };
  }

  Widget _buildOrganizationTypesSection(bool isDesktop) {
    final organizationTypes = _safeIntMap(_organizationTypesAnalysis['organizationTypes']);
    final totalEmployed = _organizationTypesAnalysis['totalEmployed'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Organization Types',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (totalEmployed > 0)
              _buildOrganizationTypesChart(organizationTypes, totalEmployed)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No organization type data available yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationTypesChart(Map<String, int> organizationTypes, int total) {
    final sortedTypes = organizationTypes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: sortedTypes.isEmpty ? 10 : sortedTypes.first.value.toDouble() * 1.2,
              barGroups: sortedTypes.map((entry) {
                return BarChartGroupData(
                  x: sortedTypes.indexOf(entry),
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      color: Colors.blue,
                      width: 20,
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= sortedTypes.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text(
                            sortedTypes[value.toInt()].key,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sortedTypes.map((entry) {
          final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Expanded(child: Text(entry.key)),
                Text(
                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildIncomeAnalysisSection(bool isDesktop) {
    final incomeRanges = _safeIntMap(_incomeAnalysis['incomeRanges']);
    final totalWithIncomeData = _incomeAnalysis['totalWithIncomeData'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (totalWithIncomeData > 0)
              _buildIncomeRangesChart(incomeRanges, totalWithIncomeData)
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No income data available yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeRangesChart(Map<String, int> incomeRanges, int total) {
    final sortedRanges = incomeRanges.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: sortedRanges.isEmpty ? 10 : sortedRanges.first.value.toDouble() * 1.2,
              barGroups: sortedRanges.map((entry) {
                return BarChartGroupData(
                  x: sortedRanges.indexOf(entry),
                  barRods: [
                    BarChartRodData(
                      toY: entry.value.toDouble(),
                      color: Theme.of(context).primaryColor,
                      width: 20,
                    ),
                  ],
                );
              }).toList(),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= sortedRanges.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Text(
                            sortedRanges[value.toInt()].key,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...sortedRanges.map((entry) {
          final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Expanded(child: Text(entry.key)),
                Text(
                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildJobRelevanceSection(bool isDesktop) {
    final jobRelevance = _safeIntMap(_jobRelevanceAnalysis['jobRelevance']);
    final firstJobStatus = _safeIntMap(_jobRelevanceAnalysis['firstJobStatus']);
    final totalEmployed = _jobRelevanceAnalysis['totalEmployed'] as int? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Job Relevance Analysis',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildJobRelevanceChart(jobRelevance, totalEmployed),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildFirstJobChart(firstJobStatus, totalEmployed),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildJobRelevanceChart(jobRelevance, totalEmployed),
                  const SizedBox(height: 24),
                  _buildFirstJobChart(firstJobStatus, totalEmployed),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobRelevanceChart(Map<String, int> jobRelevance, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job Related to Degree',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (total > 0)
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sections: jobRelevance.entries.map((entry) {
                  final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: '${percentage.toStringAsFixed(1)}%',
                    color: entry.key.toLowerCase() == 'yes' ? Theme.of(context).primaryColor : Colors.orange,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 20,
              ),
            ),
          )
        else
          Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        const SizedBox(height: 16),
        ...jobRelevance.entries.map((entry) {
          final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: entry.key.toLowerCase() == 'yes' ? Theme.of(context).primaryColor : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text(
                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFirstJobChart(Map<String, int> firstJobStatus, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'First Job After College',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (total > 0)
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sections: firstJobStatus.entries.map((entry) {
                  final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: entry.value.toDouble(),
                    title: '${percentage.toStringAsFixed(1)}%',
                    color: entry.key.toLowerCase() == 'yes' ? Colors.blue : Colors.purple,
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 20,
              ),
            ),
          )
        else
          Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        const SizedBox(height: 16),
        ...firstJobStatus.entries.map((entry) {
          final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: entry.key.toLowerCase() == 'yes' ? Colors.blue : Colors.purple,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(entry.key)),
                Text(
                  '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
} 