import 'package:flutter/material.dart';
import '../../../models/course_model.dart';
import '../../../services/course_service.dart';
import '../../../services/user_service.dart';
import 'course_csv_management_screen.dart';

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({Key? key}) : super(key: key);

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  final CourseService _courseService = CourseService();
  final UserService _userService = UserService();
  
  List<Course> _courses = [];
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  
  @override
  void initState() {
    super.initState();
    _checkSuperAdminStatus();
    _loadCourses();
  }
  
  Future<void> _checkSuperAdminStatus() async {
    final isSuperAdmin = await _userService.isCurrentUserSuperAdmin();
    
    setState(() {
      _isSuperAdmin = isSuperAdmin;
    });
    
    if (!isSuperAdmin) {
      Future.microtask(() {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('College Admin access required for this page'),
            backgroundColor: Colors.red,
          )
        );
        Navigator.of(context).pop();
      });
    }
  }
  
  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final courses = await _courseService.getAllCourses();
      
      // Group courses by category and college
      final groupedCourses = <String, Map<String, List<Course>>>{};
      
      for (final course in courses) {
        if (!groupedCourses.containsKey(course.category)) {
          groupedCourses[course.category] = {};
        }
        
        if (!groupedCourses[course.category]!.containsKey(course.college)) {
          groupedCourses[course.category]![course.college] = [];
        }
        
        groupedCourses[course.category]![course.college]!.add(course);
      }
      
      // Flatten the grouped courses back to a list, but keep them ordered
      final orderedCourses = <Course>[];
      
      // Add undergraduate courses first
      if (groupedCourses.containsKey('Undergraduate')) {
        final colleges = groupedCourses['Undergraduate']!.keys.toList()..sort();
        
        for (final college in colleges) {
          final coursesList = groupedCourses['Undergraduate']![college]!;
          coursesList.sort((a, b) => a.name.compareTo(b.name));
          orderedCourses.addAll(coursesList);
        }
      }
      
      // Add graduate school courses next
      if (groupedCourses.containsKey('Graduate School')) {
        final departments = groupedCourses['Graduate School']!.keys.toList()..sort();
        
        for (final department in departments) {
          final coursesList = groupedCourses['Graduate School']![department]!;
          coursesList.sort((a, b) => a.name.compareTo(b.name));
          orderedCourses.addAll(coursesList);
        }
      }
      
      // Add any remaining categories
      for (final category in groupedCourses.keys.where((c) => 
          c != 'Undergraduate' && c != 'Graduate School')) {
        final institutions = groupedCourses[category]!.keys.toList()..sort();
        
        for (final institution in institutions) {
          final coursesList = groupedCourses[category]![institution]!;
          coursesList.sort((a, b) => a.name.compareTo(b.name));
          orderedCourses.addAll(coursesList);
        }
      }
      
      setState(() {
        _courses = orderedCourses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading programs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _showAddCourseDialog() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController(text: 'Undergraduate');
    final collegeController = TextEditingController();
    
    final formKey = GlobalKey<FormState>();
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Program'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: 'Undergraduate',
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Undergraduate',
                        child: Text('Undergraduate'),
                      ),
                      DropdownMenuItem(
                        value: 'Graduate School',
                        child: Text('Graduate School'),
                      ),
                      DropdownMenuItem(
                        value: 'Other',
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        categoryController.text = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select a category';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: collegeController,
                    decoration: const InputDecoration(
                      labelText: 'College/Department',
                      hintText: 'e.g., College of Computer Studies',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a college or department';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Program Name',
                      hintText: 'e.g., Bachelor Of Science In Computer Science',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a course name';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newCourse = Course(
                    name: nameController.text.trim(),
                    category: categoryController.text,
                    college: collegeController.text.trim(),
                  );
                  
                  final success = await _courseService.addCourse(newCourse);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Program added successfully'),
                      ),
                    );
                    
                    _loadCourses(); // Refresh the list
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to add program'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _deleteCourse(Course course) async {
    if (course.id == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Are you sure you want to delete "${course.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await _courseService.deleteCourse(course.id!);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Program deleted successfully'),
          ),
        );
        
        _loadCourses(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete program'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.import_export),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CourseCsvManagementScreen(),
                ),
              ).then((_) => _loadCourses()); // Refresh when returning
            },
            tooltip: 'CSV Import/Export',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: !_isSuperAdmin
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _courses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No courses found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddCourseDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Program'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _courses.length,
                      itemBuilder: (context, index) {
                        final course = _courses[index];
                        return ListTile(
                          title: Text(course.name),
                          subtitle: Text('${course.category} • ${course.college}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteCourse(course),
                            color: Colors.red,
                          ),
                        );
                      },
                    ),
      floatingActionButton: _isSuperAdmin
          ? FloatingActionButton(
              onPressed: _showAddCourseDialog,
              child: const Icon(Icons.add),
              tooltip: 'Add Course',
            )
          : null,
    );
  }
} 