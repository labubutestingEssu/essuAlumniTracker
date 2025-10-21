import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../models/user_role.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../services/course_service.dart';
import '../../models/course_model.dart';
import '../../utils/admin_session_password.dart';
import '../../utils/batch_year_utils.dart';
import '../../utils/input_validators.dart';

class CreateAlumniAccountScreen extends StatefulWidget {
  const CreateAlumniAccountScreen({Key? key}) : super(key: key);

  @override
  State<CreateAlumniAccountScreen> createState() => _CreateAlumniAccountScreenState();
}

class _CreateAlumniAccountScreenState extends State<CreateAlumniAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facebookUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  
  String? _selectedBatch;
  String? _selectedCourse;
  String? _selectedCollege;
  UserRole _selectedRole = UserRole.alumni;
  bool _isLoading = false;
  String? _errorMessage;
  
  final AuthService _authService = AuthService();
  final CourseService _courseService = CourseService();
  List<Course> _courses = [];
  bool _coursesLoading = true;

  // Generate school year display format for UI
  final List<String> _schoolYearDisplay = BatchYearUtils.generateSchoolYearDisplay();

  List<String> _colleges = [];
  List<String> _allowedColleges = [];
  bool _isCollegeDropdownDisabled = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _initializeDefaultRole();
    _autoFillDefaults(); // Initialize smart defaults
  }

  Future<void> _initializeDefaultRole() async {
    final currentUserRole = await _getCurrentUserRole();
    if (currentUserRole?.isSuperAdmin == true) {
      setState(() {
        _selectedRole = UserRole.admin; // Default to admin for super admin users
      });
    }
  }

  Future<UserRole?> _getCurrentUserRole() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return null;
    
    try {
      final userData = await _authService.getUserData(currentUser.uid);
      final userRole = UserRole.fromString(userData?['role'] ?? 'alumni');
      return userRole;
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchCourses() async {
    try {
      // Fetch all courses from database
      final courses = await _courseService.getAllCourses();
      
      // Extract unique colleges from courses
      final collegeSet = <String>{};
      for (final course in courses) {
        if (course.college.isNotEmpty) {
          collegeSet.add(course.college);
        }
      }
      
      if (mounted) {
        setState(() {
          _courses = courses;
          _colleges = collegeSet.toList()..sort();
          _coursesLoading = false;
        });
        await _filterCollegesForAdmin();
        debugPrint('[DEBUG] All colleges: _colleges=$_colleges');
        debugPrint('[DEBUG] All courses: ' + _courses.map((c) => '${c.name} (${c.college})').join(', '));
      }
    } catch (e) {
      print('Error fetching courses: $e');
      if (mounted) {
        setState(() {
          _coursesLoading = false;
        });
      }
    }
  }

  Future<void> _filterCollegesForAdmin() async {
    final currentUser = await _authService.currentUser;
    if (currentUser == null) return;
    final userData = await _authService.getUserData(currentUser.uid);
    final userRole = UserRole.fromString(userData?['role'] ?? 'alumni');
    
    // For super admin, allow all colleges and enable the dropdown
    if (userRole.isSuperAdmin) {
      setState(() {
        _allowedColleges = List<String>.from(_colleges);
        _isCollegeDropdownDisabled = false; // Enable dropdown for super admin
        // Don't preselect any college - let super admin choose
        _selectedCollege = null;
      });
      debugPrint('[DEBUG] Super admin: allowedColleges=$_allowedColleges, selectedCollege=$_selectedCollege, dropdownEnabled=true');
      return;
    }
    
    // For admin, only allow their assigned college and disable the dropdown
    final adminCollege = userData?['college'] ?? '';
    if (adminCollege.isNotEmpty && _colleges.contains(adminCollege)) {
      setState(() {
        _allowedColleges = [adminCollege];
        _selectedCollege = adminCollege;
        _isCollegeDropdownDisabled = true; // Disable dropdown for admin
      });
      debugPrint('[DEBUG] Admin: allowedColleges=$_allowedColleges, selectedCollege=$_selectedCollege, dropdownEnabled=false');
    } else {
      setState(() {
        _allowedColleges = [];
        _isCollegeDropdownDisabled = false;
        _selectedCollege = null;
      });
      debugPrint('[DEBUG] Admin: No allowed college found!');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _facebookUrlController.dispose();
    _instagramUrlController.dispose();
    super.dispose();
  }

  // Helper method to auto-fill smart defaults based on user input
  void _autoFillDefaults() {
    // Auto-format phone number as user types
    _phoneController.addListener(() {
      final text = _phoneController.text;
      final formatted = InputValidators.formatPhilippinePhone(text);
      if (formatted != text) {
        _phoneController.value = _phoneController.value.copyWith(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });
  }

  void _updateCourses(String? college) {
    setState(() {
      _selectedCollege = college;
      // Filter courses for the selected college and deduplicate by name
      final filteredCourses = _courses.where((c) => c.college == college).toList();
      final uniqueCourseNames = <String>{};
      final uniqueCourses = <Course>[];
      for (final course in filteredCourses) {
        if (!uniqueCourseNames.contains(course.name)) {
          uniqueCourseNames.add(course.name);
          uniqueCourses.add(course);
        }
      }
      debugPrint('[DEBUG] updateCourses: selectedCollege=$_selectedCollege, uniqueCourses=' + uniqueCourses.map((c) => c.name).join(', '));
      // If the selected course is not in the filtered list, reset it
      if (uniqueCourses.every((c) => c.name != _selectedCourse)) {
        _selectedCourse = null;
        debugPrint('[DEBUG] updateCourses: Resetting selectedCourse to null');
      }
    });
  }

  // Helper method to check if ID field should be shown (both alumni and admin need IDs)
  bool _shouldShowIdField() {
    return _selectedRole == UserRole.alumni || _selectedRole == UserRole.admin;
  }

  // Helper method to check if selected role should show Faculty ID instead of Student ID
  bool _shouldShowFacultyId() {
    return _selectedRole == UserRole.admin;
  }

  // Helper method to get the appropriate ID field label
  String _getIdFieldLabel() {
    return _shouldShowFacultyId() ? 'Faculty ID' : 'Student ID';
  }

  // Helper method to check if selected role should show college/course fields
  bool _shouldShowCollegeCourseFields() {
    return _selectedRole != UserRole.super_admin;
  }
  
  // Helper method to check if Program field should be shown (alumni only, not admin)
  bool _shouldShowProgramField() {
    return _selectedRole == UserRole.alumni;
  }
  
  // Helper method to check if Academic Year field should be shown (alumni only, not admin)
  bool _shouldShowAcademicYearField() {
    return _selectedRole == UserRole.alumni;
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      // First, get admin password to sign back in later
      final adminEmail = _authService.currentUser?.email;
      String? adminPassword = await AdminSessionPassword.getPassword();
      if (adminPassword == null) {
        adminPassword = await _showAdminPasswordDialog(adminEmail!);
        if (adminPassword == null) {
          // User cancelled
          return;
        }
        await AdminSessionPassword.setPassword(adminPassword);
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Create the new user account (this will automatically sign in the new user)
        await _authService.createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          middleName: _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          suffix: _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim(),
          studentId: (_selectedRole == UserRole.alumni) ? _studentIdController.text.trim() : '',
          facultyId: (_selectedRole == UserRole.admin || _selectedRole == UserRole.super_admin) ? _studentIdController.text.trim() : null,
          course: _selectedRole == UserRole.super_admin 
              ? 'SUPERADMIN' 
              : (_selectedRole == UserRole.admin 
                  ? 'ADMIN' 
                  : (_selectedCourse ?? '')),
          batchYear: _selectedRole == UserRole.alumni ? (_selectedBatch ?? '') : '',
          college: _selectedRole == UserRole.super_admin ? 'SUPERADMIN' : (_selectedCollege ?? ''),
          phone: _phoneController.text.trim(),
          facebookUrl: _facebookUrlController.text.trim(),
          instagramUrl: _instagramUrlController.text.trim(),
          role: _selectedRole,
        );
        
        // Sign out the newly created user
        await _authService.signOut();
        
        // Sign the admin back in
        await _authService.signIn(
          email: adminEmail!,
          password: adminPassword,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedRole.toDisplayString()} account created successfully!'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          );
          // After re-login, refetch college/admin data to ensure college is set
          await _fetchCourses();
          await _filterCollegesForAdmin();
        }
        // Do not call _clearForm() since we are refetching
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<String?> _showAdminPasswordDialog(String adminEmail) async {
    String? password;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final passwordController = TextEditingController();
        final formKey = GlobalKey<FormState>();
        
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.blue),
              SizedBox(width: 8),
              Text('College Admin Authentication'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('To create a new user account, please confirm your college admin password:'),
                const SizedBox(height: 16),
                Text('College Admin Email: $adminEmail', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Your Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState!.validate()) {
                      password = passwordController.text;
                      Navigator.of(context).pop(password);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  password = passwordController.text;
                  Navigator.of(context).pop(password);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    
    return result;
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
        title: 'Create User Account',
        customAppBar: const CustomAppBar(
          title: 'Create User Account',
          showBackButton: false, // Hide default back button
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => InputValidators.validateName(value, 'first name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _middleNameController,
                      decoration: const InputDecoration(
                        labelText: 'Middle Name (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.trim().isEmpty == true 
                          ? null 
                          : InputValidators.validateName(value, 'middle name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => InputValidators.validateName(value, 'last name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _suffixController,
                      decoration: const InputDecoration(
                        labelText: 'Suffix (Optional) - e.g., Jr., Sr., III',
                        border: OutlineInputBorder(),
                      ),
                      validator: InputValidators.validateSuffix,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: InputValidators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: InputValidators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    if (_shouldShowIdField())
                      TextFormField(
                        controller: _studentIdController,
                        decoration: InputDecoration(
                          labelText: _getIdFieldLabel(),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) => InputValidators.validateId(value, _getIdFieldLabel().toLowerCase()),
                      ),
                    if (_shouldShowIdField())
                      const SizedBox(height: 16),
                    FutureBuilder<UserRole?>(
                      future: _getCurrentUserRole(),
                      builder: (context, snapshot) {
                        final userRole = snapshot.data;
                        
                        if (userRole == null) {
                          return const SizedBox.shrink();
                        }
                        
                        // Only show role selector for admins and super admins
                        if (!userRole.isAdmin) {
                          return const SizedBox.shrink();
                        }
                        
                        return Column(
                          children: [
                            DropdownButtonFormField<UserRole>(
                              value: _selectedRole,
                              decoration: const InputDecoration(
                                labelText: 'Account Type',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                // Super admins can only create admin or super admin accounts
                                if (userRole.isSuperAdmin) ...[
                                  DropdownMenuItem(
                                    value: UserRole.admin,
                                    child: Text(UserRole.admin.toDisplayString()),
                                  ),
                                  DropdownMenuItem(
                                    value: UserRole.super_admin,
                                    child: Text(UserRole.super_admin.toDisplayString()),
                                  ),
                                ] else ...[
                                  // Regular admins can create alumni accounts
                                  DropdownMenuItem(
                                    value: UserRole.alumni,
                                    child: Text(UserRole.alumni.toDisplayString()),
                                  ),
                                ],
                              ],
                              // Disable dropdown for regular admins since they can only create alumni
                              onChanged: userRole.isSuperAdmin ? (value) {
                                setState(() {
                                  _selectedRole = value ?? UserRole.admin;
                                  // Reset course and batch year when switching to admin role
                                  if (_selectedRole == UserRole.admin) {
                                    _selectedCourse = null;
                                    _selectedBatch = null;
                                  }
                                });
                              } : null,
                              disabledHint: Text(UserRole.alumni.toDisplayString()),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    if (_shouldShowCollegeCourseFields()) ...[
                      DropdownButtonFormField<String>(
                        value: _selectedCollege,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                        ),
                        items: _allowedColleges.toSet().map((college) {
                          return DropdownMenuItem(
                            value: college,
                            child: Text(college),
                          );
                        }).toList(),
                        onChanged: _isCollegeDropdownDisabled ? null : _updateCourses,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select college';
                          }
                          return null;
                        },
                        disabledHint: _allowedColleges.isNotEmpty
                            ? Text(_allowedColleges.first)
                            : const Text('No college assigned'),
                      ),
                      const SizedBox(height: 16),
                      if (_shouldShowProgramField())
                        DropdownButtonFormField<String>(
                          value: _selectedCourse,
                          decoration: const InputDecoration(
                            labelText: 'Program',
                            border: OutlineInputBorder(),
                          ),
                          items: _coursesLoading
                              ? [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Loading programs...'),
                                  ),
                                ]
                              : (() {
                                  final filteredCourses = _courses.where((course) => _selectedCollege == null || course.college == _selectedCollege).toList();
                                  final uniqueCourseNames = <String>{};
                                  final uniqueCourses = <Course>[];
                                  for (final course in filteredCourses) {
                                    if (!uniqueCourseNames.contains(course.name)) {
                                      uniqueCourseNames.add(course.name);
                                      uniqueCourses.add(course);
                                    }
                                  }
                                  debugPrint('[DEBUG] Program dropdown: uniqueCourses=' + uniqueCourses.map((c) => c.name).join(', '));
                                  return uniqueCourses
                                      .map((course) => DropdownMenuItem<String>(
                                            value: course.name,
                                            child: Text(course.name),
                                          ))
                                      .toList();
                                })(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCourse = value;
                              debugPrint('[DEBUG] Course changed: selectedCourse=$_selectedCourse');
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select course';
                            }
                            return null;
                          },
                          isExpanded: true,
                        ),
                      if (_shouldShowProgramField())
                        const SizedBox(height: 16),
                    ],
                    if (_shouldShowAcademicYearField())
                      DropdownButtonFormField<String>(
                        value: _selectedBatch,
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                        ),
                        items: _schoolYearDisplay.map((schoolYear) {
                          return DropdownMenuItem(
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
                            return 'Please select academic year';
                          }
                          return null;
                        },
                      ),
                    if (_shouldShowAcademicYearField())
                      const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        hintText: '09XX XXX XXXX',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: InputValidators.getPhoneInputFormatters(),
                      validator: InputValidators.validatePhilippinePhone,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Social Media Links (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _facebookUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Facebook URL',
                        hintText: 'https://facebook.com/username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.facebook),
                      ),
                      validator: InputValidators.validateFacebookUrl,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _instagramUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram URL',
                        hintText: 'https://instagram.com/username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: InputValidators.validateInstagramUrl,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createAccount,
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
                          : const Text('Create Account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 