import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import '../../services/user_service.dart';
import '../../services/course_service.dart';
import '../../utils/responsive.dart';
import '../../widgets/responsive_screen_wrapper.dart';
import '../../models/user_role.dart';
import '../../utils/batch_year_utils.dart';

class AlumniDirectoryScreen extends StatefulWidget {
  const AlumniDirectoryScreen({Key? key}) : super(key: key);

  @override
  State<AlumniDirectoryScreen> createState() => _AlumniDirectoryScreenState();
}

class _AlumniDirectoryScreenState extends State<AlumniDirectoryScreen> {
  final UserService _userService = UserService();
  final CourseService _courseService = CourseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<UserModel> _alumni = [];
  List<Course> _courseObjects = [];
  bool _isLoading = false;
  bool _isLoadingCourses = false;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  String? _searchQuery;
  String? _selectedBatchYear;
  String? _selectedCourse;
  String? _selectedCollege;
  String? _selectedRole; // Add role filter
  String? _userCollege; // Store current user's college for restrictions
  String? _error;
  
  // Generate school year display format for UI
  final List<String> _schoolYearDisplay = BatchYearUtils.generateSchoolYearDisplay();
  
  // Role options for filtering
  final List<Map<String, String>> _roleOptions = [
    {'value': 'super_admin', 'label': 'Admin'},
    {'value': 'admin', 'label': 'College Admin'},
    {'value': 'alumni', 'label': 'Alumni'},
  ];
  
  // Default courses data - will be used as fallback and for seeding the database
  final Map<String, dynamic> _coursesData = {
    "Undergraduate": {
      "College of Agriculture": [
        "Bachelor Of Science In Agriculture"
      ],
      "College of Arts and Sciences": [
        "Bachelor Of Arts In Communication",
        "Bachelor Of Arts In Political Science",
        "Bachelor Of Science In Social Work"
      ],
      "College of Business Management and Accountancy": [
        "Bachelor Of Science In Accountancy",
        "Bachelor Of Science In Accounting Information System",
        "BS In Entrepreneurship",
        "Bachelor Of Science In Business Administration Major In Business Economics",
        "Bachelor Of Science In Business Administration Major In Financial Management",
        "Bachelor Of Science In Business Administration Major In Human Resource Management",
        "Bachelor Of Science In Business Administration Major In Marketing Management"
      ],
      "College of Computer Studies": [
        "Associate in Computer Technology",
        "Bachelor Of Science In Computer Science",
        "Bachelor Of Science In Entertainment And Multimedia Computing",
        "Bachelor Of Science In Information Technology"
      ],
      "College of Criminal Justice Education": [
        "Bachelor Of Science In Criminology"
      ],
      "College of Education": [
        "Bachelor Of Elementary Education",
        "Bachelor Of Secondary Education Major In English",
        "Bachelor Of Secondary Education Major In Filipino",
        "Bachelor Of Secondary Education Major In Mathematics",
        "Bachelor Of Secondary Education Major In Science",
        "Bachelor Of Secondary Education Major In Social Studies"
      ],
      "College of Engineering": [
        "Bachelor Of Science In Civil Engineering",
        "Bachelor Of Science In Computer Engineering",
        "Bachelor Of Science In Electrical Engineering"
      ],
      "College of Fisheries and Aquatic Sciences": [
        "Bachelor Of Science In Fisheries"
      ],
      "College of Hospitality Management": [
        "Bachelor Of Science In Hospitality Management",
        "Bachelor Of Science In Tourism Management"
      ],
      "College of Nursing and Allied Sciences": [
        "Bachelor Of Science In Midwifery",
        "Bachelor Of Science In Nursing",
        "Bachelor Of Science In Nutrition & Dietetics"
      ],
      "College of Science": [
        "Bachelor Of Science In Biology",
        "Bachelor Of Science In Environmental Science"
      ],
      "College of Technology": [
        "Bachelor In Industrial Technology"
      ]
    },
    "Graduate School": {
      "Law": [
        "Juris Doctor"
      ],
      "Doctoral": [
        "Doctor Of Philosophy In Animal Science",
        "Doctor Of Philosophy In Crop Science",
        "Doctor Of Philosophy In Education Major In Educational Management"
      ],
      "Masters": [
        "Master Of Arts In Education Major In Filipino Language Teaching",
        "Master In Agricultural Sciences Major In Animal Science",
        "Master In Agricultural Sciences Major In Crop Science",
        "Master Of Arts In Education In Biology",
        "Master Of Arts In Education Major In Educational Management",
        "Master Of Arts In Education Major In Elementary Education",
        "Master Of Arts In Education Major In English Language Teaching",
        "Master Of Arts In Education Major In Kindergarten Education",
        "Master Of Arts In Education Major In Science Teaching",
        "Master Of Arts In Education Major In Social Science",
        "Master Of Arts In Education Major In Teaching Mathematics",
        "Master Of Arts In Management",
        "Master Of Arts In Teaching Mathematics",
        "Master Of Arts In Teaching Vocational Education Major In Entrepreneurship",
        "Master Of Arts In Teaching Vocational Education Major In Home Economics Technology",
        "Master Of Arts In Teaching Vocational Education Major In Information And Communication Technology",
        "Master Of Science In Criminal Justice Education With Specialization In Criminology",
        "Master's In Engineering Major In Civil Engineering"
      ]
    }
  };
  
  // Flatten the nested structure into a simple list for the dropdown
  late List<String> _courses;
  
  @override
  void initState() {
    super.initState();
    _initializeCoursesList();
    _fetchCoursesFromFirebase();
    _checkAdminStatus().then((_) {
      // After checking admin status, fetch alumni with proper restrictions
      _fetchAlumni();
    });
  }
  
  // Initialize the flattened courses list from the default data
  void _initializeCoursesList() {
    _courses = [];
    
    // Process undergraduate courses
    Map<String, List<String>> undergrad = _coursesData["Undergraduate"] as Map<String, List<String>>;
    undergrad.forEach((college, courseList) {
      _courses.addAll(courseList);
    });
    
    // Process graduate school courses
    Map<String, List<String>> gradSchool = _coursesData["Graduate School"] as Map<String, List<String>>;
    gradSchool.forEach((department, courseList) {
      _courses.addAll(courseList);
    });
    
    // Sort alphabetically
    _courses.sort();
  }
  
  
  // Fetch courses from Firebase and seed if empty
  Future<void> _fetchCoursesFromFirebase() async {
    try {
      setState(() {
        _isLoadingCourses = true;
      });
      
      // First seed default courses if the collection is empty
      await _courseService.seedDefaultCoursesIfEmpty(_coursesData);
      
      // Then fetch all courses
      final courses = await _courseService.getAllCourses();
      
      if (mounted) {
        setState(() {
          _courseObjects = courses;
          
          // Replace the courses list with Firebase data (don't append to existing)
          if (courses.isNotEmpty) {
            _courses = courses.map((course) => course.name).toList();
            _courses.sort(); // Sort alphabetically
          }
          // If no courses from Firebase, keep the default courses list as fallback
          
          _isLoadingCourses = false;
        });
      }
    } catch (e) {
      print('Error fetching courses from Firebase: $e');
      // We still have the default courses list as a fallback
      if (mounted) {
        setState(() {
          _isLoadingCourses = false;
        });
      }
    }
  }
  
  Future<void> _checkAdminStatus() async {
    try {
      final isAdmin = await _userService.isCurrentUserAdmin();
      final isSuperAdmin = await _userService.isCurrentUserSuperAdmin();
      
      // Get current user's college for filtering restrictions
      String? userCollege;
      if (!isSuperAdmin) {
        final currentUser = await _userService.getCurrentUser();
        userCollege = currentUser?.college;
        print("Non-super admin user college: '$userCollege'");
      }
      
      setState(() {
        _isAdmin = isAdmin; // This now includes super admin check
        _isSuperAdmin = isSuperAdmin;
        _userCollege = userCollege;
        
        // FORCE set initial college filter for non-super admins - this was the bug
        if (!_isSuperAdmin && userCollege != null && userCollege.isNotEmpty) {
          _selectedCollege = userCollege;
          print("Setting _selectedCollege to: '$_selectedCollege' for non-super admin");
        } else if (_isSuperAdmin) {
          _selectedCollege = null; // Super admins start with no college filter
          print("Super admin detected - no college restriction");
        }
      });
      
      print("User is admin: $_isAdmin, Admin: $_isSuperAdmin, User College: '$userCollege', Selected College: '$_selectedCollege'");
    } catch (e) {
      print("Error checking admin status: $e");
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  String _getRoleDisplayText(UserRole role) {
    switch (role) {
      case UserRole.super_admin:
        return 'Admin';
      case UserRole.admin:
        return 'College Admin';
      case UserRole.alumni:
        return 'Alumni';
    }
  }

  // Helper method to check if user should show Faculty ID instead of Student ID
  bool _shouldShowFacultyId(UserRole role) {
    return role == UserRole.admin;
  }

  // Helper method to get the appropriate ID field label
  String _getIdFieldLabel(UserRole role) {
    return _shouldShowFacultyId(role) ? 'Faculty ID' : 'Student ID';
  }
  
  // Method to sort alumni by role (Admin -> College Admin -> Alumni)
  List<UserModel> _sortAlumniByRole(List<UserModel> alumni) {
    return List<UserModel>.from(alumni)..sort((a, b) {
      // Define role priority: Admin (0) -> College Admin (1) -> Alumni (2)
      int getRolePriority(UserRole role) {
        switch (role) {
          case UserRole.super_admin:
            return 0;
          case UserRole.admin:
            return 1;
          case UserRole.alumni:
            return 2;
        }
      }
      
      final aPriority = getRolePriority(a.role);
      final bPriority = getRolePriority(b.role);
      
      // First sort by role priority
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      
      // Then sort by name within the same role
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
  }
  
  // Method to check if current user can edit another user's profile
  bool _canEditUserProfile(UserModel targetUser) {
    // Super admins can edit anyone's profile
    if (_isSuperAdmin) {
      return true;
    }
    
    // Regular admins can only edit alumni profiles (not other admins or super admins)
    if (_isAdmin && !_isSuperAdmin) {
      return targetUser.role == UserRole.alumni;
    }
    
    // Non-admin users cannot edit other profiles
    return false;
  }
  
  Future<void> _fetchAlumni() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // For non-super admins, ALWAYS enforce their college restriction
      String? effectiveCollegeFilter = _selectedCollege;
      if (!_isSuperAdmin && _userCollege != null && _userCollege!.isNotEmpty) {
        effectiveCollegeFilter = _userCollege; // Force to user's college regardless of UI selection
        print("Non-super admin: Forcing college filter to '$effectiveCollegeFilter' (user's college: '$_userCollege')");
      } else if (_isSuperAdmin) {
        print("Super admin: Using selected college filter '$effectiveCollegeFilter'");
      } else {
        print("Warning: Non-super admin with no college assigned - this shouldn't happen");
      }
      
      print("Final query parameters - batchYear: '$_selectedBatchYear', course: '$_selectedCourse', college: '$effectiveCollegeFilter', role: '$_selectedRole', isAdmin: $_isAdmin, isSuperAdmin: $_isSuperAdmin");
      final alumni = await _userService.searchAlumni(
        query: _searchQuery,
        batchYear: _selectedBatchYear,
        course: _selectedCourse,
        college: effectiveCollegeFilter, // Use enforced college filter
        isAdmin: _isAdmin,
      );
      
      // Apply role filtering if selected (client-side filter since backend doesn't support role filtering yet)
      List<UserModel> filteredAlumni = alumni;
      if (_selectedRole != null && _selectedRole!.isNotEmpty) {
        filteredAlumni = alumni.where((user) {
          return user.role.toString().split('.').last == _selectedRole;
        }).toList();
      }
      
      setState(() {
        _alumni = _sortAlumniByRole(filteredAlumni);
        print("Found ${_alumni.length} alumni (filtered and sorted by role)");
        
        // Debug the first few results to verify filtering and sorting
        for (int i = 0; i < (_alumni.length < 3 ? _alumni.length : 3); i++) {
          var user = _alumni[i];
          print("Result $i: ${user.fullName}, College: '${user.college}', Role: ${user.role}");
        }
      });
    } catch (e) {
      print('Error fetching alumni: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load alumni: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching alumni: $e')),
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
  
  void _resetFilters() {
    if (mounted) {
      setState(() {
        _searchController.clear();
        _searchQuery = null;
        _selectedBatchYear = null;
        _selectedCourse = null;
        _selectedRole = null; // Reset role filter
        
        // Only reset college filter for super admins
        if (_isSuperAdmin) {
          _selectedCollege = null;
        } else {
          // For non-super admins, reset to their own college
          _selectedCollege = _userCollege;
        }
      });
      
      _fetchAlumni();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenWrapper(
      title: 'Alumni Directory',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _fetchAlumni,
        ),
      ],
      body: _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return Column(
        children: [
        _buildSearchAndFilters(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  const Text(
                    'Error',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_error ?? 'Unknown error'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _fetchAlumni,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _alumni.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No alumni found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try changing your search criteria',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _resetFilters,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset Filters'),
          ),
        ],
      ),
                    )
                  : _buildAlumniList(),
            ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated loading icon with pulse effect
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.9 + (0.1 * (1 + 0.3 * (value * 2 - 1).abs())),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1 + 0.05 * value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.2 * value),
                        spreadRadius: 2 * value,
                        blurRadius: 8 * value,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.people,
                    size: 40,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Loading indicator
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Loading text
          Text(
            'Loading Alumni Directory...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we fetch the latest data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          
          // Optional: Add skeleton loading cards
          const SizedBox(height: 40),
          _buildSkeletonCards(),
        ],
      ),
    );
  }

  Widget _buildSkeletonCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(3, (index) => 
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            builder: (context, opacity, child) {
              return AnimatedOpacity(
                opacity: opacity,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar skeleton with shimmer
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.5, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        builder: (context, value, child) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200.withOpacity(value),
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      
                      // Text skeleton with shimmer
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.5, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              builder: (context, value, child) {
                                return Container(
                                  height: 16,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200.withOpacity(value),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.5, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              builder: (context, value, child) {
                                return Container(
                                  height: 12,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200.withOpacity(value),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search alumni by name',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        if (mounted) {
                          setState(() {
                            _searchQuery = null;
                          });
                          _fetchAlumni();
                        }
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (value) {
              if (mounted) {
                setState(() {
                  _searchQuery = value;
                });
                _fetchAlumni();
              }
            },
          ),
          const SizedBox(height: 16),
          Responsive.isDesktop(context)
              ? Row(
                  children: [
                    Expanded(child: _buildBatchYearDropdown()),
                    const SizedBox(width: 16),
                    if (_isSuperAdmin) ...[
                      Expanded(child: _buildCollegeDropdown()),
                      const SizedBox(width: 16),
                    ],
                    Expanded(child: _buildProgramDropdown()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRoleDropdown()),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Reset Filters'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBatchYearDropdown(),
                    const SizedBox(height: 12),
                    if (_isSuperAdmin) ...[
                      _buildCollegeDropdown(),
                      const SizedBox(height: 12),
                    ],
                    _buildProgramDropdown(),
                    const SizedBox(height: 12),
                    _buildRoleDropdown(),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Reset Filters'),
                    ),
                  ],
                ),
          if (_isAdmin) 
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: FutureBuilder<bool>(
                future: _userService.isCurrentUserSuperAdmin(),
                builder: (context, snapshot) {
                  final isSuperAdmin = snapshot.data == true;
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSuperAdmin ? Colors.purple.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSuperAdmin ? Colors.purple.shade200 : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuperAdmin ? Icons.security : Icons.admin_panel_settings,
                          size: 16,
                          color: isSuperAdmin ? Colors.purple : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSuperAdmin 
                              ? 'Admin View: Full access + user management'
                              : 'College Admin View: Limited to ${_userCollege ?? "your college"} - You can see all user information within your college',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            ],
          ),
        );
  }
  
  Widget _buildBatchYearDropdown() {
    return DropdownSearch<String>(
      popupProps: const PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search academic year...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      items: ['All Academic Years', ..._schoolYearDisplay],
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Academic Year',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.calendar_today),
        ),
      ),
      onChanged: (value) {
        setState(() {
          _selectedBatchYear = value == 'All Academic Years' ? null : BatchYearUtils.schoolYearToBatchYear(value ?? '');
        });
        _fetchAlumni();
      },
      selectedItem: _selectedBatchYear != null ? BatchYearUtils.batchYearToSchoolYear(_selectedBatchYear!) : 'All Academic Years',
      dropdownBuilder: (context, selectedItem) {
        return Text(
          selectedItem ?? 'All Academic Years',
          style: const TextStyle(fontSize: 16),
        );
      },
      filterFn: (item, filter) {
        return item.toLowerCase().contains(filter.toLowerCase());
      },
    );
  }

  Widget _buildProgramDropdown() {
    // Filter courses by selected college, just like in create account screen
    List<Course> filteredCourses = _selectedCollege == null 
        ? _courseObjects 
        : _courseObjects.where((course) => course.college == _selectedCollege).toList();
    
    // Remove duplicates by course name and sort
    List<String> uniqueCourseNames = filteredCourses
        .map((course) => course.name)
        .toSet()
        .toList()
      ..sort();
    
    List<String> courseNames = ['All Programs', ...uniqueCourseNames];
    
    return DropdownSearch<String>(
      popupProps: PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: const TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search program...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        menuProps: MenuProps(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: _isLoadingCourses ? ['Loading programs...'] : courseNames,
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Program',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.school),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      onChanged: _isLoadingCourses
          ? null
          : (value) {
              setState(() {
                _selectedCourse = value == 'All Programs' ? null : value;
              });
              _fetchAlumni();
            },
      selectedItem: _selectedCourse ?? 'All Programs',
      dropdownBuilder: (context, selectedItem) {
        return Text(
          selectedItem ?? 'All Programs',
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        );
      },
      filterFn: (item, filter) {
        return item.toLowerCase().contains(filter.toLowerCase());
      },
      enabled: !_isLoadingCourses,
    );
  }

  Widget _buildCollegeDropdown() {
    // Extract unique colleges from course objects
    List<String> availableColleges = _courseObjects
        .map((course) => course.college)
        .where((college) => college.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    List<String> collegeOptions = _isSuperAdmin 
        ? ['All Colleges', ...availableColleges]
        : availableColleges;

    return DropdownSearch<String>(
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
      items: _isLoadingCourses ? ['Loading colleges...'] : collegeOptions,
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'College',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(Icons.account_balance),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          // Add lock icon for non-super admins to indicate it's restricted
          suffixIcon: !_isSuperAdmin ? const Icon(Icons.lock, size: 20, color: Colors.grey) : null,
        ),
      ),
      onChanged: (_isLoadingCourses || !_isSuperAdmin)
          ? null
          : (value) {
              setState(() {
                _selectedCollege = value == 'All Colleges' ? null : value;
                _selectedCourse = null; // Reset course when college changes
              });
              _fetchAlumni();
            },
      selectedItem: _isSuperAdmin 
          ? (_selectedCollege ?? 'All Colleges')
          : (_selectedCollege ?? availableColleges.first),
      dropdownBuilder: (context, selectedItem) {
        return Text(
          selectedItem ?? (_isSuperAdmin ? 'All Colleges' : 'Select College'),
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        );
      },
      filterFn: (item, filter) {
        return item.toLowerCase().contains(filter.toLowerCase());
      },
      enabled: !_isLoadingCourses && _isSuperAdmin,
    );
  }

  Widget _buildRoleDropdown() {
    List<String> roleLabels = ['All Roles', ..._roleOptions.map((role) => role['label']!).toList()];
    
    return DropdownSearch<String>(
      popupProps: const PopupProps.menu(
        showSearchBox: true,
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search role...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      items: roleLabels,
      dropdownDecoratorProps: const DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: 'Role',
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(Icons.admin_panel_settings),
        ),
      ),
      onChanged: (value) {
        setState(() {
          if (value == 'All Roles') {
            _selectedRole = null;
          } else {
            // Find the corresponding role value from the label
            final selectedRoleData = _roleOptions.firstWhere(
              (role) => role['label'] == value,
              orElse: () => {'value': '', 'label': value ?? ''},
            );
            _selectedRole = selectedRoleData['value']?.isEmpty == true ? null : selectedRoleData['value'];
          }
        });
        _fetchAlumni();
      },
      selectedItem: _selectedRole == null 
          ? 'All Roles' 
          : _roleOptions.firstWhere(
              (role) => role['value'] == _selectedRole,
              orElse: () => {'label': 'All Roles'},
            )['label']!,
      dropdownBuilder: (context, selectedItem) {
        return Text(
          selectedItem ?? 'All Roles',
          style: const TextStyle(fontSize: 16),
        );
      },
      filterFn: (item, filter) {
        return item.toLowerCase().contains(filter.toLowerCase());
      },
    );
  }

  Widget _buildAlumniCard(UserModel alumni) {
    // Always show the name and profile image
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _showAlumniDetail(alumni),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile image with edit button for admins
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: alumni.profileImageUrl != null && alumni.profileImageUrl!.isNotEmpty
                            ? NetworkImage(alumni.profileImageUrl!)
                            : null,
                        child: alumni.profileImageUrl == null || alumni.profileImageUrl!.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      // Add edit capability for admins (with role restrictions)
                      if (_canEditUserProfile(alumni))
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: () => _navigateToEditProfile(alumni),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Alumni information
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'First Name: ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        alumni.firstName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (alumni.middleName != null && alumni.middleName!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Middle Name: ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          alumni.middleName!,
                                          style: const TextStyle(
                                            fontSize: 16,
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
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        alumni.lastName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (alumni.suffix != null && alumni.suffix!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Suffix: ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          alumni.suffix!,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_isAdmin && (alumni.role == UserRole.admin || alumni.role == UserRole.super_admin))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: alumni.role == UserRole.super_admin ? 'Admin' : 'College Admin',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: alumni.role == UserRole.super_admin ? Colors.purple : Colors.blue,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        alumni.role == UserRole.super_admin ? 'ADMIN' : 'COLLEGE ADMIN',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Show lock icon for profiles that regular admins cannot edit
                                  if (!_canEditUserProfile(alumni) && _isAdmin && !_isSuperAdmin) ...[
                                    const SizedBox(width: 4),
                                    Tooltip(
                                      message: 'Cannot edit ${alumni.role == UserRole.super_admin ? 'Admin' : 'College Admin'} profile',
                                      child: Icon(
                                        Icons.lock,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            if (!_isAdmin && alumni.uid != _userService.currentUserId)
                              Tooltip(
                                message: 'Privacy Applied',
                                child: Icon(
                                  Icons.visibility_off,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Display role and college (prominent but subtle)
                        // Hide college info for super admins since they are all-encompassing
                        if (alumni.college.isNotEmpty && alumni.role != UserRole.super_admin)
                          Text(
                            '${_getRoleDisplayText(alumni.role)} of ${alumni.college}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        // Display batch year
                        if (alumni.batchYear.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Academic Year ${BatchYearUtils.batchYearToSchoolYear(alumni.batchYear)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        // Only show occupation if visible
                        if (alumni.currentOccupation != null && alumni.currentOccupation!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(alumni.currentOccupation!),
                        ],
                        // Only show company if visible
                        if (alumni.company != null && alumni.company!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(alumni.company!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // View Profile Button
                  OutlinedButton.icon(
                    onPressed: () => _showAlumniDetail(alumni),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('View Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Profile Button (with role restrictions)
                  if (_canEditUserProfile(alumni))
                    ElevatedButton.icon(
                      onPressed: () => _navigateToEditProfile(alumni),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  const SizedBox(width: 8),
                  // Delete User Button (Admin only)
                  if (_isSuperAdmin && alumni.uid != _userService.currentUserId)
                    ElevatedButton.icon(
                      onPressed: () => _showDeleteUserDialog(alumni),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showAlumniDetail(UserModel alumni) {
    // Prepare fields to display with appropriate privacy handling
    final bool isCurrentUser = alumni.uid == _userService.currentUserId;
    
    // If admin is viewing, get the full user data without privacy filters
    if (_isAdmin && !isCurrentUser) {
      // Get full unfiltered user data for admin view
      _userService.getUserById(alumni.uid, isAdmin: true).then((fullUserData) {
        if (fullUserData != null) {
          _showAlumniDetailDialog(fullUserData, isCurrentUser: isCurrentUser);
        } else {
          _showAlumniDetailDialog(alumni, isCurrentUser: isCurrentUser);
        }
      });
    } else {
      // Show the filtered user data for non-admins
      _showAlumniDetailDialog(alumni, isCurrentUser: isCurrentUser);
    }
  }
  
  void _showAlumniDetailDialog(UserModel alumni, {required bool isCurrentUser}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: alumni.profileImageUrl != null && alumni.profileImageUrl!.isNotEmpty
                  ? NetworkImage(alumni.profileImageUrl!)
                  : null,
              child: alumni.profileImageUrl == null || alumni.profileImageUrl!.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                                  Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'First Name: ',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          alumni.firstName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (alumni.middleName != null && alumni.middleName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Middle Name: ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            alumni.middleName!,
                            style: const TextStyle(
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
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          alumni.lastName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (alumni.suffix != null && alumni.suffix!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Suffix: ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            alumni.suffix!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                  if (alumni.role == UserRole.admin || alumni.role == UserRole.super_admin)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: alumni.role == UserRole.super_admin ? Colors.purple : Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        alumni.role == UserRole.super_admin ? 'ADMIN' : 'COLLEGE ADMIN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              // Display privacy notice for non-admin viewing other profiles
              if (!_isAdmin && !isCurrentUser)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
      children: [
                      Icon(Icons.visibility_off, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Some information may be hidden by privacy settings',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // For admins, always show all fields
              // Hide college/course info for super admins since they are all-encompassing
              if ((_isAdmin || isCurrentUser || alumni.college.isNotEmpty) && alumni.role != UserRole.super_admin)
                _buildDetailItem('College', alumni.college),
              if ((_isAdmin || isCurrentUser || alumni.course.isNotEmpty) && alumni.role != UserRole.super_admin)
                _buildDetailItem('Course', alumni.course),
              if (_isAdmin || isCurrentUser || alumni.batchYear.isNotEmpty)
                _buildDetailItem('Academic Year', BatchYearUtils.batchYearToSchoolYear(alumni.batchYear)),
              if (_isAdmin || isCurrentUser)
                _buildDetailItem(
                  _getIdFieldLabel(alumni.role), 
                  alumni.role == UserRole.admin || alumni.role == UserRole.super_admin 
                    ? (alumni.facultyId ?? '') 
                    : alumni.studentId
                ),
              if (_isAdmin || isCurrentUser)
                _buildDetailItem('Email', alumni.email),
              if ((_isAdmin || isCurrentUser) && alumni.phone != null)
                _buildDetailItem('Phone', alumni.phone!),
              if ((_isAdmin || isCurrentUser) || (alumni.currentOccupation != null && alumni.currentOccupation!.isNotEmpty))
                _buildDetailItem('Occupation', alumni.currentOccupation ?? ''),
              if ((_isAdmin || isCurrentUser) || (alumni.company != null && alumni.company!.isNotEmpty))
                _buildDetailItem('Company', alumni.company ?? ''),
              if ((_isAdmin || isCurrentUser) || (alumni.location != null && alumni.location!.isNotEmpty))
                _buildDetailItem('Location', alumni.location ?? ''),
              if ((_isAdmin || isCurrentUser) || (alumni.bio != null && alumni.bio!.isNotEmpty))
                _buildDetailItem('Bio', alumni.bio ?? ''),
              
              // Social Media Links (only visible if data exists and privacy allows)
              if ((alumni.facebookUrl != null && alumni.facebookUrl!.isNotEmpty) ||
                  (alumni.instagramUrl != null && alumni.instagramUrl!.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Social Media',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16.0,
                        runSpacing: 8.0,
                        children: [
                          if (alumni.facebookUrl != null && alumni.facebookUrl!.isNotEmpty)
                            _buildSocialMediaButton(Icons.facebook, 'Facebook', alumni.facebookUrl!),
                          if (alumni.instagramUrl != null && alumni.instagramUrl!.isNotEmpty)
                            _buildSocialMediaButton(Icons.link, 'Instagram', alumni.instagramUrl!), // Using link icon
                        ],
                      ),
                    ],
                  ),
                ),

              // Survey Completion Status (only for alumni)
              if (alumni.role == UserRole.alumni) // Make sure UserRole is imported
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Survey Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alumni.hasCompletedSurvey ? 'Completed' : 'Not Completed',
                        style: TextStyle(
                          fontSize: 16,
                          color: alumni.hasCompletedSurvey ? Theme.of(context).primaryColor : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              if (_isAdmin)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 16),
                      SizedBox(width: 8),
        Expanded(
          child: Text(
                          'Admin view: You can see all information regardless of privacy settings',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (_canEditUserProfile(alumni) && !isCurrentUser)
            TextButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToEditProfile(alumni);
              },
            ),
          // Add role editing for super admins
          FutureBuilder<bool>(
            future: _userService.isCurrentUserSuperAdmin(),
            builder: (context, snapshot) {
              if (snapshot.data == true && !isCurrentUser) {
                return TextButton.icon(
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Edit Role'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showRoleEditDialog(alumni);
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Add delete button for super admins (not for current user)
          if (_isSuperAdmin && !isCurrentUser && alumni.uid != _userService.currentUserId)
            TextButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete User', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteUserDialog(alumni);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _navigateToEditProfile(UserModel alumni) {
    // Navigate to the ProfileScreen with edit mode enabled
    Navigator.pushNamed(
      context,
      '/edit-profile',
      arguments: {
        'userId': alumni.uid,
        'isAdminEdit': true,
      },
    ).then((_) {
      // Refresh the alumni list when returning from edit
      _fetchAlumni();
    });
  }

  void _showRoleEditDialog(UserModel alumni) {
    UserRole selectedRole = alumni.role;
    
    // Only super admins can edit roles
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only College Admins can edit user roles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings),
              const SizedBox(width: 8),
              Text('Edit Role: ${alumni.fullName}'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select the new role for this user:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              
              // Role selection radio buttons
              RadioListTile<UserRole>(
                title: const Text('Alumni'),
                subtitle: const Text('Regular alumni user with basic access'),
                value: UserRole.alumni,
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              RadioListTile<UserRole>(
                title: const Text('College Admin'),
                subtitle: const Text('College admin with management privileges'),
                value: UserRole.admin,
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              RadioListTile<UserRole>(
                title: const Text('Admin'),
                subtitle: const Text('Full system access and user management'),
                value: UserRole.super_admin,
                groupValue: selectedRole,
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              
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
                        'Changing user roles affects their access permissions. This action cannot be undone.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRole != alumni.role
                  ? () => _updateUserRole(alumni, selectedRole)
                  : null,
              child: const Text('Update Role'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserRole(UserModel alumni, UserRole newRole) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating user role...'),
            ],
          ),
        ),
      );

      // Update the role in Firestore
      await _userService.updateUserRole(alumni.uid, newRole);

      // Close loading dialog
      Navigator.of(context).pop();
      
      // Close role edit dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully updated ${alumni.fullName}\'s role to ${_getRoleDisplayName(newRole)}',
          ),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      // Refresh the alumni list
      _fetchAlumni();
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update role: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.alumni:
        return 'Alumni';
      case UserRole.admin:
        return 'College Admin';
      case UserRole.super_admin:
        return 'Admin';
    }
  }

  
  Widget _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAlumniList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alumni.length,
      itemBuilder: (context, index) {
        return _buildAlumniCard(_alumni[index]);
      },
    );
  }


  Widget _buildSocialMediaButton(IconData icon, String label, String url) {
    return InkWell(
      onTap: () {
        // TODO: Implement URL launching here using url_launcher
        print('Attempting to open $label URL: $url');
        // Example: launchUrl(Uri.parse(url));
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).primaryColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteUserDialog(UserModel alumni) {
    // Double-check super admin status
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only College Admins can delete users'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prevent self-deletion
    if (alumni.uid == _userService.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete your own account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete this user?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text('Name: ${alumni.fullName}'),
                  Text('Email: ${alumni.email}'),
                  Text('Role: ${_getRoleDisplayText(alumni.role)}'),
                  if (alumni.college.isNotEmpty) Text('College: ${alumni.college}'),
                  if (alumni.course.isNotEmpty) Text('Program: ${alumni.course}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'This action will:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('• Delete all user data from the database', style: TextStyle(fontSize: 13)),
                  Text('• Delete all survey responses', style: TextStyle(fontSize: 13)),
                  Text('• Remove user from the alumni directory', style: TextStyle(fontSize: 13)),
                  Text('• This action cannot be undone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteUser(alumni),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel alumni) async {
    try {
      // Close the dialog first
      Navigator.of(context).pop();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('Deleting user: ${alumni.fullName}...'),
            ],
          ),
        ),
      );

      // Perform the deletion
      await _userService.deleteUser(alumni.uid);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted user: ${alumni.fullName}'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );

      // Refresh the alumni list
      _fetchAlumni();
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 