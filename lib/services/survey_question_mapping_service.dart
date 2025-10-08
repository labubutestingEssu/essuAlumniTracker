import '../models/survey_question_model.dart';
import 'survey_question_service.dart';

class SurveyQuestionMappingService {
  final SurveyQuestionService _questionService = SurveyQuestionService();
  
  // Cache for question mappings to avoid repeated database calls
  Map<String, String>? _questionIdCache;
  Map<String, SurveyQuestionModel>? _questionCache;
  
  // Get question ID by field name (e.g., 'currently_employed' -> 'eAK92PntsacSSwXiU1pk')
  Future<String?> getQuestionIdByFieldName(String fieldName) async {
    await _ensureCacheLoaded();
    return _questionIdCache?[fieldName];
  }
  
  // Get question model by field name
  Future<SurveyQuestionModel?> getQuestionByFieldName(String fieldName) async {
    await _ensureCacheLoaded();
    final questionId = _questionIdCache?[fieldName];
    if (questionId != null) {
      return _questionCache?[questionId];
    }
    return null;
  }
  
  // Get all question mappings
  Future<Map<String, String>> getAllQuestionMappings() async {
    await _ensureCacheLoaded();
    return Map<String, String>.from(_questionIdCache ?? {});
  }
  
  // Load and cache question mappings
  Future<void> _ensureCacheLoaded() async {
    if (_questionIdCache != null && _questionCache != null) {
      return; // Cache already loaded
    }
    
    try {
      final questions = await _questionService.getAllQuestions();
      
      _questionIdCache = {};
      _questionCache = {};
      
      for (final question in questions) {
        if (question.type != QuestionType.section) {
          _questionIdCache![question.id] = question.id;
          _questionCache![question.id] = question;
          
          // Map by field name based on question title and content
          // This is more reliable than checking question IDs
          final title = question.title.toLowerCase();
          
          if (title.contains('are you presently employed') || title.contains('currently employed')) {
            _questionIdCache!['currently_employed'] = question.id;
            print('Mapped currently_employed to: ${question.id}');
          } else if (title.contains('name of organization') || title.contains('organization name')) {
            _questionIdCache!['organization_name'] = question.id;
            print('Mapped organization_name to: ${question.id}');
          } else if (title.contains('type of organization') || title.contains('organization type')) {
            _questionIdCache!['organization_type'] = question.id;
            print('Mapped organization_type to: ${question.id}');
          } else if (title.contains('employment status')) {
            _questionIdCache!['employment_status'] = question.id;
            print('Mapped employment_status to: ${question.id}');
          } else if (title.contains('employment type')) {
            _questionIdCache!['employment_type'] = question.id;
            print('Mapped employment_type to: ${question.id}');
          } else if (title.contains('job position')) {
            _questionIdCache!['job_position'] = question.id;
            print('Mapped job_position to: ${question.id}');
          } else if (title.contains('monthly income')) {
            _questionIdCache!['monthly_income'] = question.id;
            print('Mapped monthly_income to: ${question.id}');
          } else if (title.contains('job related to degree')) {
            _questionIdCache!['job_related_to_degree'] = question.id;
            print('Mapped job_related_to_degree to: ${question.id}');
          } else if (title.contains('first job after college')) {
            _questionIdCache!['first_job_after_college'] = question.id;
            print('Mapped first_job_after_college to: ${question.id}');
          } else if (title.contains('nature of employment')) {
            _questionIdCache!['nature_of_employment'] = question.id;
            print('Mapped nature_of_employment to: ${question.id}');
          } else if (title.contains('self employment years')) {
            _questionIdCache!['self_employment_years'] = question.id;
            print('Mapped self_employment_years to: ${question.id}');
          } else if (title.contains('self employment income')) {
            _questionIdCache!['self_employment_income'] = question.id;
            print('Mapped self_employment_income to: ${question.id}');
          } else if (title.contains('current occupation')) {
            _questionIdCache!['current_occupation'] = question.id;
            print('Mapped current_occupation to: ${question.id}');
          } else if (title.contains('company')) {
            _questionIdCache!['company'] = question.id;
            print('Mapped company to: ${question.id}');
          }
        }
      }
      
      print('Question mapping cache loaded: $_questionIdCache');
    } catch (e) {
      print('Error loading question mappings: $e');
      _questionIdCache = {};
      _questionCache = {};
    }
  }
  
  // Clear cache (useful for testing or when questions are updated)
  void clearCache() {
    _questionIdCache = null;
    _questionCache = null;
  }
  
  // Get employment-related question IDs
  Future<Map<String, String>> getEmploymentQuestionIds() async {
    await _ensureCacheLoaded();
    
    return {
      'currently_employed': _questionIdCache?['currently_employed'] ?? '',
      'organization_name': _questionIdCache?['organization_name'] ?? '',
      'organization_type': _questionIdCache?['organization_type'] ?? '',
      'employment_status': _questionIdCache?['employment_status'] ?? '',
      'employment_type': _questionIdCache?['employment_type'] ?? '',
      'job_position': _questionIdCache?['job_position'] ?? '',
      'monthly_income': _questionIdCache?['monthly_income'] ?? '',
      'job_related_to_degree': _questionIdCache?['job_related_to_degree'] ?? '',
      'first_job_after_college': _questionIdCache?['first_job_after_college'] ?? '',
      'nature_of_employment': _questionIdCache?['nature_of_employment'] ?? '',
      'self_employment_years': _questionIdCache?['self_employment_years'] ?? '',
      'self_employment_income': _questionIdCache?['self_employment_income'] ?? '',
      'current_occupation': _questionIdCache?['current_occupation'] ?? '',
      'company': _questionIdCache?['company'] ?? '',
    };
  }
}
