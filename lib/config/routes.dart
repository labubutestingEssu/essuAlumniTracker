import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/alumni/alumni_directory_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/admin/course_management_screen.dart';
import '../screens/admin/create_alumni_account_screen.dart';
import '../screens/admin/college_reports_screen.dart';
import '../screens/admin/export_data_screen.dart';
import '../screens/admin/survey_results_screen.dart';
import '../screens/alumni/dynamic_survey_form_screen.dart';
import '../screens/admin/system_initialization_screen.dart';
import '../screens/admin/survey_question_management_screen.dart';
import '../screens/survey/survey_data_viewer_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/alumni-directory';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String alumniDirectory = '/alumni-directory';
  static const String settings = '/settings';
  static const String courseManagement = '/admin/courses';
  
  // Admin routes
  static const String createAlumniAccount = '/admin/create-alumni';
  static const String collegeReports = '/admin/college-reports';
  static const String exportData = '/admin/export-data';

  // Survey routes
  static const String surveyForm = '/survey-form';
  static const String surveyResults = '/survey-results';
  
  // System routes
  static const String systemInitialization = '/admin/system-initialization';
  static const String surveyQuestionManagement = '/admin/survey-questions';
  static const String surveyDataViewer = '/admin/survey-data-viewer';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == splash) {
      return MaterialPageRoute(builder: (_) => const SplashScreen());
    } else if (settings.name == login) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    } else if (settings.name == register) {
      return MaterialPageRoute(builder: (_) => const RegisterScreen());
    } else if (settings.name == home) {
      return MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen());
    } else if (settings.name == profile) {
      return MaterialPageRoute(builder: (_) => const ProfileScreen());
    } else if (settings.name == editProfile) {
      // Handle the edit profile route with arguments
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => ProfileScreen(
          userId: args?['userId'],
          isAdminEdit: args?['isAdminEdit'] ?? false,
        ),
      );
    } else if (settings.name == courseManagement) {
      return MaterialPageRoute(builder: (_) => const CourseManagementScreen());
    } else if (settings.name == alumniDirectory) {
      return MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen());
    } else if (settings.name == settings) {
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    } else if (settings.name == createAlumniAccount) {
      return MaterialPageRoute(builder: (_) => const CreateAlumniAccountScreen());
    } else if (settings.name == collegeReports) {
      return MaterialPageRoute(builder: (_) => const CollegeReportsScreen());
    } else if (settings.name == exportData) {
      return MaterialPageRoute(builder: (_) => const ExportDataScreen());
    } else if (settings.name == surveyForm) {
      return MaterialPageRoute(builder: (_) => const DynamicSurveyFormScreen());
    } else if (settings.name == surveyResults) {
      return MaterialPageRoute(builder: (_) => const SurveyResultsScreen());
    } else if (settings.name == systemInitialization) {
      return MaterialPageRoute(builder: (_) => const SystemInitializationScreen());
    } else if (settings.name == surveyQuestionManagement) {
      return MaterialPageRoute(builder: (_) => const SurveyQuestionManagementScreen());
    } else if (settings.name == surveyDataViewer) {
      return MaterialPageRoute(builder: (_) => const SurveyDataViewerScreen());
    }
    
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(
          child: Text('No route defined for ${settings.name}'),
        ),
      ),
    );
  }

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      home: (context) => const AlumniDirectoryScreen(),
      profile: (context) => const ProfileScreen(),
      settings: (context) => const SettingsScreen(),
      courseManagement: (context) => const CourseManagementScreen(),
      createAlumniAccount: (context) => const CreateAlumniAccountScreen(),
      collegeReports: (context) => const CollegeReportsScreen(),
      exportData: (context) => const ExportDataScreen(),
      surveyForm: (context) => const DynamicSurveyFormScreen(),
      surveyResults: (context) => const SurveyResultsScreen(),
      systemInitialization: (context) => const SystemInitializationScreen(),
      surveyQuestionManagement: (context) => const SurveyQuestionManagementScreen(),
      // Note: routes requiring arguments are handled in onGenerateRoute
    };
  }
}

