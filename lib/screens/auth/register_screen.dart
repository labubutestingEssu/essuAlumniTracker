import 'package:flutter/material.dart';
import '../../config/routes.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_layout.dart';
import '../../services/auth_service.dart';
import '../../utils/navigation_service.dart';
import '../../utils/batch_year_utils.dart';
import '../../utils/input_validators.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _studentIdController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedBatch;
  String? _selectedCourse;
  bool _isLoading = false;
  String? _errorMessage;
  
  final AuthService _authService = AuthService();

  // Generate school year display format for UI
  final List<String> _schoolYearDisplay = BatchYearUtils.generateSchoolYearDisplay();

  final List<String> _courses = [
    'BS Information Technology',
    'BS Computer Science',
    'BS Education',
    'BS Business Administration',
    'BS Accountancy',
    'BS Engineering',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _autoFillDefaults(); // Initialize smart defaults
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _studentIdController.dispose();
    super.dispose();
  }

  // Helper method to auto-fill smart defaults for new registrations
  void _autoFillDefaults() {
    // Auto-generate student ID prefix based on current year
    final currentYear = DateTime.now().year;
    _studentIdController.text = '$currentYear-';
    
    // Set default batch year to current academic year
    final currentAcademicYear = '$currentYear-${currentYear + 1}';
    if (_schoolYearDisplay.contains(currentAcademicYear)) {
      _selectedBatch = currentAcademicYear;
    }
    
    // Add real-time phone formatting listener
    _firstNameController.addListener(() {
      // Auto-capitalize first letter of first name
      final text = _firstNameController.text;
      if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
        final capitalized = text[0].toUpperCase() + text.substring(1);
        _firstNameController.value = _firstNameController.value.copyWith(
          text: capitalized,
          selection: TextSelection.collapsed(offset: capitalized.length),
        );
      }
    });
    
    _lastNameController.addListener(() {
      // Auto-capitalize first letter of last name
      final text = _lastNameController.text;
      if (text.isNotEmpty && text[0] != text[0].toUpperCase()) {
        final capitalized = text[0].toUpperCase() + text.substring(1);
        _lastNameController.value = _lastNameController.value.copyWith(
          text: capitalized,
          selection: TextSelection.collapsed(offset: capitalized.length),
        );
      }
    });
  }

  Future<void> _register() async {
    // Check connectivity before attempting registration
    bool isConnected = await _checkConnectivity();
    if (!isConnected) {
      setState(() {
        _errorMessage = 'Network error: Check your internet connection';
      });
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Use AuthService's createAccount method which properly sets up the user with role
        await _authService.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          middleName: _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          suffix: _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim(),
          studentId: _studentIdController.text.trim(),
          course: _selectedCourse ?? '',
          batchYear: _selectedBatch ?? '',
          college: 'College of Computing Studies', // Default college for self-registration
        );
        
        if (mounted) {
          // Show success message and navigate to login
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Registration successful! Please log in.'),
              backgroundColor: Theme.of(context).primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Wait for the snackbar to be visible before navigation
          Future.delayed(const Duration(seconds: 1), () {
            NavigationService.navigateToWithReplacement(AppRoutes.login);
          });
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('FirebaseAuthException: ', '');
          
          // Handle network errors with a more user-friendly message
          if (errorMsg.toLowerCase().contains('network') || 
              errorMsg.toLowerCase().contains('connection') ||
              errorMsg.toLowerCase().contains('timeout') ||
              errorMsg.toLowerCase().contains('unreachable')) {
            errorMsg = 'Network error: Please check your internet connection and try again.';
          }
          
          setState(() {
            _errorMessage = errorMsg;
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to check connectivity: $e');
      }
      return true; // Assume connected if we can't check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: Theme.of(context).primaryColor,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Theme.of(context).primaryColor,
          secondary: Theme.of(context).primaryColor,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).primaryColor,
          ),
        ),
      ),
      child: Scaffold(
        appBar: Responsive.isMobile(context)
            ? AppBar(
                title: const Text('Register'),
                backgroundColor: Theme.of(context).primaryColor,
              )
            : null,
        body: ResponsiveLayout(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildRegisterForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create an Account',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildRegisterForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left side with background image or color
        Expanded(
          child: Container(
            color: Theme.of(context).primaryColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 24),
                  Text(
                    'ESSU Alumni Tracker',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Join your university community',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Right side with register form
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Create an Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 32),
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo.png',
      width: Responsive.isDesktop(context) ? 120 : 100,
      height: Responsive.isDesktop(context) ? 120 : 100,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to a simple icon if image fails to load
        return Icon(
          Icons.school,
          size: Responsive.isDesktop(context) ? 120 : 100,
          color: Theme.of(context).primaryColor,
        );
      },
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create an Account',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join the ESSU Alumni community',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[800]),
              ),
            ),
          
          // First Name field
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) => InputValidators.validateName(value, 'first name'),
          ),
          const SizedBox(height: 16),
          
          // Middle Name field (optional)
          TextFormField(
            controller: _middleNameController,
            decoration: const InputDecoration(
              labelText: 'Middle Name (Optional)',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Last Name field
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) => InputValidators.validateName(value, 'last name'),
          ),
          const SizedBox(height: 16),
          
          // Suffix field (optional)
          TextFormField(
            controller: _suffixController,
            decoration: const InputDecoration(
              labelText: 'Suffix (Optional) - e.g., Jr., Sr., III',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: InputValidators.validateEmail,
          ),
          const SizedBox(height: 16),
          
          // Student ID field (optional)
          TextFormField(
            controller: _studentIdController,
            decoration: const InputDecoration(
              labelText: 'Student ID (Optional)',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.trim().isEmpty == true 
                ? null 
                : InputValidators.validateId(value, 'student ID'),
          ),
          const SizedBox(height: 16),
          
          // Batch Year dropdown
          DropdownButtonFormField<String>(
            value: _selectedBatch,
            decoration: const InputDecoration(
              labelText: 'School Year',
              prefixIcon: Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(),
            ),
            items: _schoolYearDisplay.map((schoolYear) {
              return DropdownMenuItem<String>(
                value: BatchYearUtils.schoolYearToBatchYear(schoolYear),
                child: Text(schoolYear),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBatch = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your school year';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Program dropdown
          DropdownButtonFormField<String>(
            value: _selectedCourse,
            decoration: const InputDecoration(
              labelText: 'Program',
              prefixIcon: Icon(Icons.school_outlined),
              border: OutlineInputBorder(),
            ),
            items: _courses.map((course) {
              return DropdownMenuItem<String>(
                value: course,
                child: Text(course),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCourse = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your course';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            validator: InputValidators.validatePassword,
          ),
          const SizedBox(height: 16),
          
          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // Register button
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Register'),
          ),
          const SizedBox(height: 16),
          
          // Login link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account?'),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

