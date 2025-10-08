import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:essu_alumni_tracker/screens/auth/login_screen.dart';
import 'package:essu_alumni_tracker/services/auth_service.dart';
import 'package:essu_alumni_tracker/services/app_initialization_service.dart';
import 'package:essu_alumni_tracker/utils/navigation_service.dart';
import 'package:essu_alumni_tracker/config/routes.dart';
import 'package:essu_alumni_tracker/providers/theme_provider.dart';
import 'package:essu_alumni_tracker/config/theme.dart';

// Global app initialization service for setting up default data
final appInitializationService = AppInitializationService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  try {
    print('Starting Firebase initialization...');
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase core initialized successfully');

    // Explicitly initialize Firebase Storage for debugging
    try {
      final storage = FirebaseStorage.instance;
      print('Firebase Storage instance created');
      
      // Verify storage bucket is correctly configured
      final storageBucket = storage.bucket;
      print('Storage bucket: $storageBucket');
      
      // Skip testing connectivity to avoid CORS issues
      print('Firebase Storage initialized');
    } catch (storageError) {
      print('Warning: Firebase Storage initialization issue: $storageError');
    }

    // For development purposes, we will skip App Check
    // This is to avoid the ReCAPTCHA errors
    if (kDebugMode) {
      // Only activate App Check on native platforms in debug mode
      if (!kIsWeb) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
          );
          print('Firebase App Check initialized for Android in debug mode');
        } catch (e) {
          print('Warning: Firebase App Check initialization failed: $e');
        }
      } else {
        print('Skipping App Check on web in debug mode to avoid ReCAPTCHA errors');
      }
    } else {
      // Production mode
      if (!kIsWeb) {
        try {
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.safetyNet,
          );
          print('Firebase App Check initialized for Android in production');
        } catch (e) {
          print('Warning: Firebase App Check initialization failed: $e');
        }
      } else {
        // In production, you would use your actual ReCAPTCHA site key
        // We're commenting this out for now to avoid errors
        /*
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('your-recaptcha-v3-site-key'),
        );
        */
        print('Firebase App Check for web disabled in production');
      }
    }
    
    // Set relaxed security settings for development
    if (kDebugMode) {
      // Enable debug mode for Firebase Auth
      try {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        print('Firebase Auth debug settings applied');
      } catch (e) {
        print('Warning: Could not set Firebase Auth debug settings: $e');
      }
    }

    print('Testing Firebase Auth connection...');
    final auth = FirebaseAuth.instance;
    // Try a simple Firebase operation
    await auth.fetchSignInMethodsForEmail('test@test.com');
    print('Firebase Auth connection successful');
    
    // Initialize notification service at app startup
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        // Initialize app with default data when user is authenticated
        try {
          await appInitializationService.initializeApp();
          print('App initialization completed');
        } catch (e) {
          print('Warning: App initialization failed: $e');
          // Don't crash the app, just log the error
        }
        
        
        // Check if user is admin and initialize survey questions if needed
        try {
          final authService = AuthService();
          final userData = await authService.getUserData(user.uid);
          if (userData != null) {
            final userRole = userData['role'] as String?;
            if (userRole == 'admin' || userRole == 'super_admin') {
              print('Admin user detected: ${user.uid}');
              await appInitializationService.initializeSurveyQuestionsForAdmin();
            }
          }
        } catch (e) {
          print('Error checking user role or initializing survey questions: $e');
          // Don't crash the app, just log the error
        }
      }
    });
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    print('Error during initialization: $e');
    print('Stack trace: $stackTrace');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Firebase Initialization Error', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('Error: $e'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => main(),
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'ESSU Alumni Tracker',
            debugShowCheckedModeBanner: false,
            navigatorKey: NavigationService.navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            routes: AppRoutes.getRoutes(),
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

// Wrap the AuthWrapper with an app usage check to prevent UI loading when app is disabled
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    // Continue with normal auth flow
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          // Route directly to Alumni Directory
          return AppRoutes.getRoutes()[AppRoutes.alumniDirectory]!(context);
        }

        return const LoginScreen();
      },
    );
  }
}
