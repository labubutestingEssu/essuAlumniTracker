import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../../utils/responsive.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import '../../utils/navigation_service.dart';
import '../../config/routes.dart';
import '../../utils/input_validators.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import 'package:flutter/services.dart';

import '../../models/user_role.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If provided, edit this user instead of current user
  final bool isAdminEdit; // Whether this is an admin editing someone else's profile
  
  const ProfileScreen({
    Key? key, 
    this.userId,
    this.isAdminEdit = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  final CourseService _courseService = CourseService();
  
  UserModel? _userData;
  UserModel? _userSettings;
  bool _isEditing = false;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _profileImageUrl;
  File? _selectedImage;
  UserRole? _selectedRole; // Track selected role for super admin editing
  
  // Course and College management
  List<Course> _courses = [];
  List<String> _colleges = [];
  bool _coursesLoading = true;
  String? _selectedCourse;
  String? _selectedCollege;
  
  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _suffixController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _batchYearController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    print("ProfileScreen initialized - userId: ${widget.userId}, isAdminEdit: ${widget.isAdminEdit}");
    _checkAdminStatus();
    _initializeData();
  }
  
  Future<void> _checkAdminStatus() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    final isSuperAdmin = await _userService.isCurrentUserSuperAdmin();
    print("Admin status check: $isAdmin, Admin: $isSuperAdmin");
    setState(() {
      _isAdmin = isAdmin;
      _isSuperAdmin = isSuperAdmin;
    });
  }
  
  @override
  void dispose() {
    // Dispose of all controllers
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _batchYearController.dispose();
    _companyController.dispose();
    _positionController.dispose();
    _locationController.dispose();
    _studentIdController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    // Load courses first, then user data
    await _fetchCourses();
    await _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // First check admin status just to be sure we have the latest
      final isAdmin = await _userService.isCurrentUserAdmin();
      final isSuperAdmin = await _userService.isCurrentUserSuperAdmin();
      setState(() {
        _isAdmin = isAdmin;
        _isSuperAdmin = isSuperAdmin;
      });
      
      // Determine if we're editing someone else's profile or viewing our own
      String? targetUserId = widget.userId;
      bool isEditingOtherUser = widget.isAdminEdit && targetUserId != null;
      
      if (isEditingOtherUser && _isAdmin) {
        // Admin is editing another user's profile
        print("Loading data for user ID: $targetUserId (Admin edit mode)");
        final userData = await _userService.getUserById(targetUserId, isAdmin: true);
        
        if (userData != null) {
          setState(() {
            _userData = userData;
            _profileImageUrl = userData.profileImageUrl;
            _selectedRole = userData.role; // Initialize selected role for super admin editing
            
            // Initialize selected college and course with better error handling
            _selectedCollege = (userData.college.isNotEmpty && _colleges.contains(userData.college)) 
                ? userData.college 
                : null;
            _selectedCourse = (userData.course.isNotEmpty) 
                ? userData.course 
                : null;
            
            // Debug logging
            print("Initializing profile data:");
            print("User college: '${userData.college}', Available colleges: $_colleges");
            print("Selected college: $_selectedCollege");
            print("User course: '${userData.course}'");
            print("Available courses: ${_courses.map((c) => c.name).toList()}");
            print("Selected course: $_selectedCourse");
            
            // Auto-fill all form controllers with user data
            _autoFillControllers(userData);
            
            // Set editing mode to true since we're in admin edit mode
            _isEditing = true;
          });
          
          // Load this user's settings
          final settings = await _userService.getUserSettings(targetUserId);
          if (settings != null) {
            setState(() {
              _userSettings = settings;
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load user data'),
              backgroundColor: Colors.red,
            ),
          );
          // Navigate back if we can't load the user data
          Navigator.of(context).pop();
        }
      } else {
        // Loading own profile
        print("Loading current user's own profile data");
        final userData = await _userService.getCurrentUser();
        
        if (userData != null) {
          setState(() {
            _userData = userData;
            _profileImageUrl = userData.profileImageUrl;
            _selectedRole = userData.role; // Initialize selected role for super admin editing
            
            // Initialize selected college and course with better error handling
            _selectedCollege = (userData.college.isNotEmpty && _colleges.contains(userData.college)) 
                ? userData.college 
                : null;
            _selectedCourse = (userData.course.isNotEmpty) 
                ? userData.course 
                : null;
            
            // Debug logging
            print("Initializing profile data:");
            print("User college: '${userData.college}', Available colleges: $_colleges");
            print("Selected college: $_selectedCollege");
            print("User course: '${userData.course}'");
            print("Available courses: ${_courses.map((c) => c.name).toList()}");
            print("Selected course: $_selectedCourse");
            
            // Auto-fill all form controllers with user data
            _autoFillControllers(userData);
          });
          
          // Load current user's settings
          final settings = await _userService.getUserSettings();
          if (settings != null) {
            setState(() {
              _userSettings = settings;
            });
          }
        } else {
          print("Current user data could not be loaded");
        }
      }
    } catch (e) {
      print('Error loading profile data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    
    if (image != null) {
      setState(() {
        if (kIsWeb) {
          // For web, we'll set a dummy file path
          _selectedImage = File("dummy_path_for_web");
          // Clear existing URL to avoid showing both
          _profileImageUrl = null;
        } else {
          _selectedImage = File(image.path);
          // Clear existing URL to avoid showing both
          _profileImageUrl = null;
        }
      });
      
      // Upload image immediately
      _uploadProfileImage(image);
    }
  }
  
  Future<String?> _uploadAdminProfileImage(XFile pickedImage, String userId) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // For admin editing, use a direct method to store the image
      String? imageUrl;
      
      if (kIsWeb) {
        // Use the XFile method for web
        imageUrl = await _userService.uploadProfileXFile(pickedImage, userId: userId);
      } else {
        // Use the File method for mobile
        imageUrl = await _userService.uploadProfileImage(_selectedImage!, userId: userId);
      }
      
      // Update the target user's profile with this image URL
      if (imageUrl != null) {
        final success = await _userService.updateUserProfileImage(userId, imageUrl);
        if (!success) {
          throw Exception('Failed to update user image');
        }
      }
      
      return imageUrl;
    } catch (e) {
      print('Error during admin profile image upload: $e');
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _uploadProfileImage(XFile pickedImage) async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      String? imageUrl;
      
      // Check if admin is editing someone else's profile
      if (widget.isAdminEdit && widget.userId != null) {
        // Use admin-specific upload method
        imageUrl = await _uploadAdminProfileImage(pickedImage, widget.userId!);
      } else {
        // Regular user editing their own profile
        if (kIsWeb) {
          // For web, use the XFile upload method
          imageUrl = await _userService.uploadProfileXFile(pickedImage);
        } else {
          // For mobile, use the File upload method
          imageUrl = await _userService.uploadProfileImage(_selectedImage!);
        }
      }
      
      if (imageUrl != null && mounted) {
        setState(() {
          _profileImageUrl = imageUrl;
          
          // If this is the current user's profile, also update it in the user model
          if (_userData != null && !widget.isAdminEdit) {
            _userData = _userData!.copyWith(profileImageUrl: imageUrl);
          } else if (_userData != null && widget.isAdminEdit) {
            // If admin editing someone else, just update the displayed data
            _userData = _userData!.copyWith(profileImageUrl: imageUrl);
          }
        });
        
        // Update role if super admin is editing and role has changed
        if (_isSuperAdmin && _selectedRole != null && _selectedRole != _userData!.role) {
          await _userService.updateUserRole(widget.userId!, _selectedRole!);
        }
        
        // Save the user settings if we have them
        if (_userSettings != null) {
          await _userService.updateUserSettings(_userSettings!);
        }
        
        String successMessage = 'User profile updated successfully';
        if (_isSuperAdmin && _selectedRole != null && _selectedRole != _userData!.role) {
          successMessage += ' and role changed to ${_selectedRole!.toDisplayString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedImage = null;
        });
      }
    }
  }
  
  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                _changePassword(newPasswordController.text);
              }
            },
            child: const Text('CHANGE'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _changePassword(String newPassword) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await _userService.changePassword(newPassword);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to change password. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error changing password: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  String _getRoleDisplayText() {
    switch (_userData!.role) {
      case UserRole.super_admin:
        return 'Admin';
      case UserRole.admin:
        return 'College Admin';
      case UserRole.alumni:
        return 'Alumni';
    }
  }
  
  String _buildEducationText() {
    if (_userData == null) {
      return '';
    }
    
    List<String> educationParts = [];
    
    // Add role first
    educationParts.add(_getRoleDisplayText());
    
    // Add college if available (changed from course to college)
    // For super admin, don't show college since they are all-encompassing
    if (_userData!.college.isNotEmpty && _userData!.role != UserRole.super_admin) {
      educationParts.add('of ${_userData!.college}');
    }
    
    return educationParts.join(' ');
  }

  // Helper method to check if education section should be shown
  bool _shouldShowEducationSection() {
    return _userData?.role != UserRole.super_admin;
  }

  
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get name fields directly from controllers
      String firstName = _firstNameController.text.trim();
      String lastName = _lastNameController.text.trim();
      String? middleName = _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim();
      String? suffix = _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim();
      
      // Check if this is an admin editing another user's profile
      bool isAdminEditingOtherUser = widget.isAdminEdit && widget.userId != null && _isAdmin;
      
      if (isAdminEditingOtherUser) {
        // Admin is updating someone else's profile
        print("Admin updating profile for user ID: ${widget.userId}");
        
        // Update the user data directly
        await _userService.updateUser(widget.userId!, {
          'firstName': firstName,
          'lastName': lastName,
          'middleName': middleName,
          'suffix': suffix,
          'phone': _phoneController.text,
          'bio': _bioController.text,
          'course': _selectedCourse ?? '',
          'college': _selectedCollege ?? '',
          'batchYear': _shouldShowStudentFields() ? _batchYearController.text : '',
          'company': _companyController.text,
          'currentOccupation': _positionController.text,
          'location': _locationController.text,
          'studentId': _shouldShowStudentFields() ? _studentIdController.text : '',
          'facebookUrl': _facebookController.text.trim(),
          'instagramUrl': _instagramController.text.trim(),
        });
        
        // Update role if super admin is editing and role has changed
        if (_isSuperAdmin && _selectedRole != null && _selectedRole != _userData!.role) {
          await _userService.updateUserRole(widget.userId!, _selectedRole!);
        }
        
        // Save the user settings if we have them
        if (_userSettings != null) {
          await _userService.updateUserSettings(_userSettings!);
        }
        
        String successMessage = 'User profile updated successfully';
        if (_isSuperAdmin && _selectedRole != null && _selectedRole != _userData!.role) {
          successMessage += ' and role changed to ${_selectedRole!.toDisplayString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      } else {
        // Regular user updating their own profile
        print("User updating their own profile");
        
        bool success = await _userService.updateUserProfile(
          firstName: firstName,
          lastName: lastName,
          middleName: middleName,
          suffix: suffix,
          batchYear: _shouldShowStudentFields() ? _batchYearController.text : '',
          course: _selectedCourse ?? '',
          currentOccupation: _positionController.text,
          company: _companyController.text,
          location: _locationController.text,
          bio: _bioController.text,
          phone: _phoneController.text,
          studentId: _shouldShowStudentFields() ? _studentIdController.text.trim() : '',
          facebookUrl: _facebookController.text.trim(),
          instagramUrl: _instagramController.text.trim(),
        );
        
        // Update college separately using updateUser since updateUserProfile doesn't support it yet
        if (_selectedCollege != null) {
          await _userService.updateUser(_userService.currentUserId!, {
            'college': _selectedCollege!,
          });
        }
        
        // Save the user settings if we have them
        if (_userSettings != null) {
          await _userService.updateUserSettings(_userSettings!);
        }
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
      
      // Reload the data to reflect changes
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return ResponsiveScreenWrapper(
      title: widget.isAdminEdit ? 'Edit Alumni Profile' : 'My Profile',
      // Remove customAppBar and let ResponsiveScreenWrapper handle the default AppBar
      // customAppBar: CustomAppBar(
      //   title: widget.isAdminEdit ? 'Edit Alumni Profile' : 'My Profile',
      //   showBackButton: false,
      //   leading: (!widget.isAdminEdit && !isDesktop) ? Builder(
      //     builder: (context) => IconButton(
      //       icon: const Icon(Icons.menu),
      //       onPressed: () => Scaffold.of(context).openDrawer(),
      //     ),
      //   ) : null,
      // ),
      // Remove drawer parameter as ResponsiveScreenWrapper handles it
      // drawer: isDesktop ? null : const AppDrawer(),
      actions: _userData != null && !widget.isAdminEdit // Only show actions for own profile
          ? [ // Actions for own profile
              if (_isLoading) // Show loading indicator when saving
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_isEditing)
                // Show Save button when in editing mode
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveProfile,
                  tooltip: 'Save Profile',
                )
              else
                // Show Edit button when not in editing mode
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  tooltip: 'Edit Profile',
                ),
            ]
          : [], // No actions for admin editing or if user data is null
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData == null
              ? const Center(
                  child: Text('Could not load profile data.'),
                )
              : WillPopScope(
                  onWillPop: () async {
                    // Navigate to Alumni Directory and replace the current route
                    NavigationService.navigateToWithReplacement(AppRoutes.alumniDirectory);
                    // Prevent the default back button behavior
                    return false;
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                    child: _buildProfileContent(),
                  ),
                ),
    );
  }

  Widget _buildProfileContent() {
    if (_userData == null) {
      return const Center(
        child: Text('No profile data available'),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 32),
              _buildProfileForm(),
              // Survey Section - Only show for alumni users or when admin is editing an alumni's profile
              if (_shouldShowSurveySection()) ...[
                const SizedBox(height: 24),
                _buildSurveySection(_userData?.hasCompletedSurvey ?? false),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _isEditing ? _pickImage : null,
          child: Stack(
            children: [
              if (_isLoading && _selectedImage != null)
                // Loading state during image upload
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  child: const CircularProgressIndicator(),
                )
              else if (_selectedImage != null && kIsWeb)
                // Selected image on web (placeholder)
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        size: 30,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Uploading...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Regular profile image or default icon
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.white,
                        )
                      : null,
                ),
              
              // Edit badge in corner when in edit mode
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display name fields separately when not editing, combined when editing for simplicity
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'First Name: ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _userData!.firstName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_userData!.middleName != null && _userData!.middleName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Middle Name: ',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _userData!.middleName!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Last Name: ',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _userData!.lastName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (_userData!.suffix != null && _userData!.suffix!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Suffix: ',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _userData!.suffix!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _buildEducationText(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              if (_userData!.email.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.email, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _userData!.email,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              // Add more user information as needed
              if (_userData!.role == UserRole.admin || _userData!.role == UserRole.super_admin)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _userData!.role == UserRole.super_admin ? Colors.purple : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _userData!.role == UserRole.super_admin ? 'Admin' : 'College Admin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTextField(
                    label: 'First Name',
                    controller: _firstNameController,
                    enabled: _isEditing,
                    validator: (value) => InputValidators.validateName(value, 'first name'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Middle Name (Optional)',
                    controller: _middleNameController,
                    enabled: _isEditing,
                    validator: (value) => value?.trim().isEmpty == true 
                        ? null 
                        : InputValidators.validateName(value, 'middle name'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    enabled: _isEditing,
                    validator: (value) => InputValidators.validateName(value, 'last name'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Suffix (Optional) - e.g., Jr., Sr., III',
                    controller: _suffixController,
                    enabled: _isEditing,
                    validator: InputValidators.validateSuffix,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email',
                    initialValue: _userData!.email,
                    enabled: false, // Email cannot be edited
                  ),
                  const SizedBox(height: 16),
                  if (_shouldShowStudentFields())
                    _buildTextField(
                      label: _getIdFieldLabel(),
                      controller: _studentIdController,
                      enabled: _isEditing,
                      validator: (value) => InputValidators.validateId(value, _getIdFieldLabel().toLowerCase()),
                    ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                    inputFormatters: InputValidators.getPhoneInputFormatters(),
                    validator: InputValidators.validatePhilippinePhone,
                    hintText: '09XX XXX XXXX',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Bio',
                    controller: _bioController,
                    enabled: _isEditing,
                    maxLines: 3,
                    validator: InputValidators.validateBio,
                    hintText: 'Tell us about yourself (max 500 characters)',
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showChangePasswordDialog,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('CHANGE PASSWORD'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Role Management Section - Only visible to super admins editing other users
          if (_isSuperAdmin && widget.isAdminEdit && widget.userId != null && _selectedRole != null) ...[
            Text(
              'Account Management',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Role',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'As an Admin, you can change this user\'s role and permissions.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Account Type',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.admin_panel_settings),
                      ),
                      isExpanded: true,
                      itemHeight: 48,
                      onChanged: _isEditing ? (UserRole? value) {
                        setState(() {
                          _selectedRole = value ?? UserRole.alumni;
                        });
                      } : null,
                      items: [
                        DropdownMenuItem(
                          value: UserRole.alumni,
                          child: Row(
                            children: [
                              Icon(Icons.school, size: 18, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              Text(
                                '${UserRole.alumni.toDisplayString()} - Standard user access',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.admin,
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings, size: 18, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                '${UserRole.admin.toDisplayString()} - Management privileges',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: UserRole.super_admin,
                          child: Row(
                            children: [
                              const Icon(Icons.security, size: 18, color: Colors.purple),
                              const SizedBox(width: 8),
                              Text(
                                '${UserRole.super_admin.toDisplayString()} - Full system access',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                    ),
                    if (_selectedRole != _userData!.role) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Role will be updated when you save the profile. This change affects the user\'s access permissions.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Education Section - Only show if not super admin
          if (_shouldShowEducationSection()) ...[
            Text(
              'Education',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // College Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCollege,
                      decoration: InputDecoration(
                        labelText: 'College',
                        border: const OutlineInputBorder(),
                        // Show lock icon for alumni users
                        suffixIcon: (!_isAdmin && !widget.isAdminEdit) ? const Icon(Icons.lock, size: 20, color: Colors.grey) : null,
                      ),
                      items: _coursesLoading
                          ? [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Loading colleges...'),
                              ),
                            ]
                          : [
                              // Add empty option for users without college
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Select College (Optional)'),
                              ),
                              // Create a Set to ensure unique college names, then convert to list
                              ...{
                                ..._colleges,
                                // Always include the current user's college if it exists and isn't already in the list
                                if (_selectedCollege != null && _selectedCollege!.isNotEmpty) _selectedCollege!,
                              }.map((college) => DropdownMenuItem(
                                    value: college,
                                    child: Text(college),
                                  )).toList(),
                            ],
                      // Only allow editing if admin is editing OR user is admin/super admin editing their own profile
                      onChanged: (_isEditing && (_isAdmin || widget.isAdminEdit)) ? _updateCourses : null,
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                    // Program Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCourse,
                      decoration: InputDecoration(
                        labelText: 'Program',
                        border: const OutlineInputBorder(),
                        // Show lock icon for alumni users
                        suffixIcon: (!_isAdmin && !widget.isAdminEdit) ? const Icon(Icons.lock, size: 20, color: Colors.grey) : null,
                      ),
                      items: _coursesLoading
                          ? [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Loading programs...'),
                              ),
                            ]
                          : [
                              // Add empty option for users without course
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Select Program (Optional)'),
                              ),
                              // Create a Set to ensure unique course names, then convert to list
                              ...{
                                ..._courses
                                    .where((course) => _selectedCollege == null || course.college == _selectedCollege)
                                    .map((course) => course.name),
                                // Always include the current user's course if it exists and isn't already in the list
                                if (_selectedCourse != null && _selectedCourse!.isNotEmpty) _selectedCourse!,
                              }.map((courseName) => DropdownMenuItem<String>(
                                    value: courseName,
                                    child: Text(courseName),
                                  )).toList(),
                            ],
                      // Only allow editing if admin is editing OR user is admin/super admin editing their own profile
                      onChanged: (_isEditing && (_isAdmin || widget.isAdminEdit)) ? (value) {
                        setState(() {
                          _selectedCourse = value;
                        });
                      } : null,
                      isExpanded: true,
                    ),
                    // Add warning message for alumni users
                    if (_isEditing && !_isAdmin && !widget.isAdminEdit) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'College and Program information can only be modified by administrators for security reasons.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_shouldShowStudentFields())
                      _buildTextField(
                        label: 'School Year',
                        controller: _batchYearController,
                        enabled: _isEditing,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your school year';
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Employment',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTextField(
                    label: 'Current Company',
                    controller: _companyController,
                    enabled: _isEditing,
                    validator: (value) => InputValidators.validateCompany(value, 'company name'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Position',
                    controller: _positionController,
                    enabled: _isEditing,
                    validator: (value) => InputValidators.validateCompany(value, 'position'),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Location',
                    controller: _locationController,
                    enabled: _isEditing,
                    validator: InputValidators.validateLocation,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Social Media Links',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _facebookController,
                    decoration: const InputDecoration(
                      labelText: 'Facebook URL (Optional)',
                      hintText: 'https://facebook.com/username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.facebook),
                    ),
                    readOnly: !_isEditing,
                    validator: InputValidators.validateFacebookUrl,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _instagramController,
                    decoration: const InputDecoration(
                      labelText: 'Instagram URL (Optional)',
                      hintText: 'https://instagram.com/username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    readOnly: !_isEditing,
                    validator: InputValidators.validateInstagramUrl,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          
          if (_isEditing)
            _buildFieldVisibilitySection(),
          
          SizedBox(height: 20),
          if (_isEditing) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('SAVE CHANGES'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldVisibilitySection() {
    // Use the default settings if none are loaded
    if (_userSettings == null) {
      _userSettings = _userData;
    }
    
    // Create a map to track field visibility for the UI
    Map<String, bool> fieldVisibility = Map.from(_userSettings!.fieldVisibility);
    
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Field Visibility',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Control which information is visible to other alumni',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Email Address'),
              subtitle: const Text('Email address is visible to other alumni'),
              value: fieldVisibility['email'] ?? false,
              onChanged: (bool value) async {
                await _userService.updateFieldVisibility('email', value);
                setState(() {
                  fieldVisibility['email'] = value;
                  // Update the settings object
                  _userSettings = _userSettings!.updateFieldVisibility('email', value);
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Phone Number'),
              subtitle: const Text('Phone number is visible to other alumni'),
              value: fieldVisibility['phone'] ?? false,
              onChanged: (bool value) async {
                await _userService.updateFieldVisibility('phone', value);
                setState(() {
                  fieldVisibility['phone'] = value;
                  _userSettings = _userSettings!.updateFieldVisibility('phone', value);
                });
              },
            ),
            const Divider(),
            if (_shouldShowStudentFields())
              SwitchListTile(
                title: Text(_getIdFieldLabel()),
                subtitle: Text('${_getIdFieldLabel()} is visible to other alumni'),
                value: fieldVisibility['studentId'] ?? false,
                onChanged: (bool value) async {
                  await _userService.updateFieldVisibility('studentId', value);
                  setState(() {
                    fieldVisibility['studentId'] = value;
                    _userSettings = _userSettings!.updateFieldVisibility('studentId', value);
                  });
                },
              ),
            const Divider(),
            if (_shouldShowEducationSection())
              SwitchListTile(
                title: const Text('Program Information'),
                subtitle: const Text('Program details are visible to other alumni'),
                value: fieldVisibility['course'] ?? true,
                onChanged: (bool value) async {
                  await _userService.updateFieldVisibility('course', value);
                  setState(() {
                    fieldVisibility['course'] = value;
                    _userSettings = _userSettings!.updateFieldVisibility('course', value);
                  });
                },
              ),
            const Divider(),
            if (_shouldShowStudentFields() && _shouldShowEducationSection())
              SwitchListTile(
                title: const Text('School Year'),
                subtitle: const Text('Graduation year is visible to other alumni'),
                value: fieldVisibility['batchYear'] ?? true,
                onChanged: (bool value) async {
                  await _userService.updateFieldVisibility('batchYear', value);
                  setState(() {
                    fieldVisibility['batchYear'] = value;
                    _userSettings = _userSettings!.updateFieldVisibility('batchYear', value);
                  });
                },
              ),
            const Divider(),
            SwitchListTile(
              title: const Text('Employment Information'),
              subtitle: const Text('Current job and company are visible'),
              value: (fieldVisibility['currentOccupation'] ?? true) && 
                     (fieldVisibility['company'] ?? true),
              onChanged: (bool value) async {
                // Update both employment-related fields
                await _userService.updateFieldVisibility('currentOccupation', value);
                await _userService.updateFieldVisibility('company', value);
                setState(() {
                  fieldVisibility['currentOccupation'] = value;
                  fieldVisibility['company'] = value;
                  _userSettings = _userSettings!
                    .updateFieldVisibility('currentOccupation', value)
                    .updateFieldVisibility('company', value);
                });
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Location Information'),
              subtitle: const Text('Location is visible to other alumni'),
              value: fieldVisibility['location'] ?? true,
              onChanged: (bool value) async {
                await _userService.updateFieldVisibility('location', value);
                setState(() {
                  fieldVisibility['location'] = value;
                  _userSettings = _userSettings!.updateFieldVisibility('location', value);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  // New method to build the survey section
  Widget _buildSurveySection(bool hasCompletedSurvey) {
    return Card(
      elevation: 2, // Add elevation for consistency
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alumni Survey',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (hasCompletedSurvey) // Show completion message if answered
              Text(
                'You have completed the alumni survey. Thank you for your contribution!',
                style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor), // Optional: add color
              ) else // Show prompt if not answered
                const Text(
                  'Please help us improve our programs by completing the alumni survey.',
                  style: TextStyle(fontSize: 16),
                ),
            const SizedBox(height: 16), // Add spacing before the button
            Center( // Center the button
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to the Survey Form screen
                  NavigationService.navigateTo(AppRoutes.surveyForm);
                },
                child: Text(hasCompletedSurvey ? 'Re-answer Survey' : 'Answer Survey'), // Change button text based on status
              ),
            ),
          ],
        ),
      ),
    );
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
  
  void _updateCourses(String? college) {
    setState(() {
      _selectedCollege = college;
      _selectedCourse = null; // Reset course when college changes
    });
  }

  // Helper method to check if student fields should be shown
  bool _shouldShowStudentFields() {
    return _userData?.role == UserRole.alumni || _userData?.role == UserRole.admin;
  }

  // Helper method to check if selected role should show Faculty ID instead of Student ID
  bool _shouldShowFacultyId() {
    return _userData?.role == UserRole.admin;
  }

  // Helper method to get the appropriate ID field label
  String _getIdFieldLabel() {
    return _shouldShowFacultyId() ? 'Faculty ID' : 'Student ID';
  }

  // Helper method to check if survey section should be shown
  bool _shouldShowSurveySection() {
    // Don't show survey section for admin/super admin users viewing their own profile
    if (!widget.isAdminEdit && (_isAdmin || _isSuperAdmin)) {
      return false;
    }
    
    // Show survey section for alumni users or when admin is editing an alumni's profile
    return _userData?.role == UserRole.alumni;
  }

  // Helper method to auto-fill all form controllers with user data
  void _autoFillControllers(UserModel userData) {
    try {
      // Personal Information
      _firstNameController.text = userData.firstName.trim();
      _lastNameController.text = userData.lastName.trim();
      _middleNameController.text = (userData.middleName ?? '').trim();
      _suffixController.text = (userData.suffix ?? '').trim();
      
      // Phone number with formatting
      final rawPhone = userData.phone ?? '';
      if (rawPhone.isNotEmpty) {
        // Apply Philippine phone formatting if valid
        if (InputValidators.validatePhilippinePhone(rawPhone) == null) {
          _phoneController.text = InputValidators.formatPhilippinePhone(rawPhone);
        } else {
          // Keep original format if not valid Philippine format
          _phoneController.text = rawPhone;
        }
      } else {
        _phoneController.text = '';
      }
      
      // Other Personal Information
      _bioController.text = (userData.bio ?? '').trim();
      
      // Education Information
      _studentIdController.text = userData.studentId.trim();
      _batchYearController.text = userData.batchYear.trim();
      
      // Employment Information
      _companyController.text = (userData.company ?? '').trim();
      _positionController.text = (userData.currentOccupation ?? '').trim();
      _locationController.text = (userData.location ?? '').trim();
      
      // Social Media Information
      _facebookController.text = (userData.facebookUrl ?? '').trim();
      _instagramController.text = (userData.instagramUrl ?? '').trim();
      
      print('Profile auto-fill completed successfully for user: ${userData.firstName} ${userData.lastName}');
      print('  firstName: ${_firstNameController.text}');
      print('  middleName: ${_middleNameController.text}');  
      print('  lastName: ${_lastNameController.text}');
      print('  phone: ${_phoneController.text}');
      print('  email: ${userData.email}');
      print('  studentId: ${_studentIdController.text}');
      print('  college: $_selectedCollege');
      print('  course: $_selectedCourse');
    } catch (e) {
      print('Error during auto-fill: $e');
      // Fallback to basic auto-fill without formatting
      _firstNameController.text = userData.firstName;
      _lastNameController.text = userData.lastName;
      _middleNameController.text = userData.middleName ?? '';
      _suffixController.text = userData.suffix ?? '';
      _phoneController.text = userData.phone ?? '';
      _bioController.text = userData.bio ?? '';
      _batchYearController.text = userData.batchYear;
      _companyController.text = userData.company ?? '';
      _positionController.text = userData.currentOccupation ?? '';
      _locationController.text = userData.location ?? '';
      _studentIdController.text = userData.studentId;
      _facebookController.text = userData.facebookUrl ?? '';
      _instagramController.text = userData.instagramUrl ?? '';
    }
  }
  

}

