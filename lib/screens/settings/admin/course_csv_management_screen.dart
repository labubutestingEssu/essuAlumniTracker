import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../../models/course_model.dart';
import '../../../services/course_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/web_download_stub.dart' if (dart.library.html) '../../../utils/web_download.dart';

class CourseCsvManagementScreen extends StatefulWidget {
  const CourseCsvManagementScreen({Key? key}) : super(key: key);

  @override
  State<CourseCsvManagementScreen> createState() => _CourseCsvManagementScreenState();
}

class _CourseCsvManagementScreenState extends State<CourseCsvManagementScreen> {
  final CourseService _courseService = CourseService();
  final UserService _userService = UserService();
  
  List<Course> _courses = [];
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  bool _isExporting = false;
  bool _isImporting = false;
  
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
            content: Text('Super Admin access required for this page'),
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
      
      // Sort courses by category, then college, then name
      courses.sort((a, b) {
        // First by category
        int categoryComparison = a.category.compareTo(b.category);
        if (categoryComparison != 0) return categoryComparison;
        
        // Then by college
        int collegeComparison = a.college.compareTo(b.college);
        if (collegeComparison != 0) return collegeComparison;
        
        // Finally by name
        return a.name.compareTo(b.name);
      });
      
      setState(() {
        _courses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading courses: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _exportCoursesToCsv() async {
    setState(() {
      _isExporting = true;
    });
    
    try {
      // Prepare CSV data
      final headers = ['Course Name', 'Category', 'College/Department'];
      final List<List<String>> csvRows = [headers];
      
      for (final course in _courses) {
        csvRows.add([
          course.name,
          course.category,
          course.college,
        ]);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final csvString = _listToCsv(csvRows);
      final csvFileName = 'courses_export_$timestamp.csv';
      
      if (kIsWeb) {
        // Web download
        final csvBytes = utf8.encode(csvString);
        downloadFileWeb(csvBytes, csvFileName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV file downloaded: $csvFileName'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Mobile/Desktop download
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
          throw Exception('Could not access file system');
        }
        
        final file = File('${targetDir.path}/$csvFileName');
        await file.writeAsString(csvString);
        
        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'ESSU Courses Export',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV exported: ${file.path}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }
  
  Future<void> _showImportDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Courses from CSV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CSV Format Requirements:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('• First row must be headers'),
                const Text('• Required columns: Course Name, Category, College/Department'),
                const Text('• Categories: Undergraduate, Graduate School, Other'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Example CSV Content:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text(
                        'Course Name,Category,College/Department\n'
                        'Bachelor of Science in Computer Science,Undergraduate,College of Computer Studies\n'
                        'Bachelor of Science in Information Technology,Undergraduate,College of Computer Studies\n'
                        'Master of Arts in Education,Graduate School,Graduate School\n'
                        'Doctor of Philosophy in Education,Graduate School,Graduate School',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _downloadSampleCsv(),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download Sample CSV'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
                          'This will add new courses. Existing courses will not be modified.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Select CSV File'),
              onPressed: () {
                Navigator.of(context).pop();
                _selectAndImportCsv();
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _selectAndImportCsv() async {
    setState(() {
      _isImporting = true;
    });
    
    try {
      // For web, we'll show a text input dialog
      if (kIsWeb) {
        await _showWebCsvImportDialog();
      } else {
        // For mobile/desktop, we'd use file_picker package
        // Since it's not in pubspec, we'll show an alternative method
        await _showMobileCsvImportDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
  
  Future<void> _showWebCsvImportDialog() async {
    final csvController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Paste CSV Data'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: Column(
              children: [
                const Text('Paste your CSV data below:'),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: csvController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Course Name,Category,College/Department\n...',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Import'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _processCsvData(csvController.text);
              },
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _showMobileCsvImportDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('File Import Not Available'),
          content: const Text(
            'File picker is not configured for this platform. '
            'Please use the web version for CSV import, or manually add courses one by one.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _processCsvData(String csvData) async {
    try {
      final lines = csvData.trim().split('\n');
      
      if (lines.length < 2) {
        throw Exception('CSV must have at least a header row and one data row');
      }
      
      // Parse header
      final headers = lines[0].split(',').map((h) => h.trim().replaceAll('"', '')).toList();
      
      // Find required column indices
      int nameIndex = -1;
      int categoryIndex = -1;
      int collegeIndex = -1;
      
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i].toLowerCase();
        if (header.contains('course') && header.contains('name')) {
          nameIndex = i;
        } else if (header.contains('category')) {
          categoryIndex = i;
        } else if (header.contains('college') || header.contains('department')) {
          collegeIndex = i;
        }
      }
      
      if (nameIndex == -1 || categoryIndex == -1 || collegeIndex == -1) {
        throw Exception(
          'CSV must contain columns: Course Name, Category, College/Department\n'
          'Found headers: ${headers.join(', ')}'
        );
      }
      
      // Parse data rows
      final List<Course> coursesToAdd = [];
      final List<String> errors = [];
      
      for (int i = 1; i < lines.length; i++) {
        try {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          final values = _parseCsvLine(line);
          
          if (values.length <= nameIndex || 
              values.length <= categoryIndex || 
              values.length <= collegeIndex) {
            errors.add('Row ${i + 1}: Not enough columns');
            continue;
          }
          
          final name = values[nameIndex].trim();
          final category = values[categoryIndex].trim();
          final college = values[collegeIndex].trim();
          
          // Validate data
          if (name.isEmpty) {
            errors.add('Row ${i + 1}: Course name is required');
            continue;
          }
          
          if (category.isEmpty) {
            errors.add('Row ${i + 1}: Category is required');
            continue;
          }
          
          if (college.isEmpty) {
            errors.add('Row ${i + 1}: College/Department is required');
            continue;
          }
          
          // Validate category
          if (!['Undergraduate', 'Graduate School', 'Other'].contains(category)) {
            errors.add('Row ${i + 1}: Invalid category "$category". Must be: Undergraduate, Graduate School, or Other');
            continue;
          }
          
          // Check for duplicates
          final duplicate = _courses.any((c) => 
            c.name.toLowerCase() == name.toLowerCase() && 
            c.category == category && 
            c.college.toLowerCase() == college.toLowerCase()
          );
          
          if (duplicate) {
            errors.add('Row ${i + 1}: Course "$name" already exists in $category - $college');
            continue;
          }
          
          coursesToAdd.add(Course(
            name: name,
            category: category,
            college: college,
          ));
        } catch (e) {
          errors.add('Row ${i + 1}: Error parsing - $e');
        }
      }
      
      // Show preview dialog
      await _showImportPreviewDialog(coursesToAdd, errors);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV parsing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _showImportPreviewDialog(List<Course> coursesToAdd, List<String> errors) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Preview'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses to Import: ${coursesToAdd.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  if (coursesToAdd.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: coursesToAdd.length,
                        itemBuilder: (context, index) {
                          final course = coursesToAdd[index];
                          return ListTile(
                            dense: true,
                            title: Text(course.name, style: const TextStyle(fontSize: 12)),
                            subtitle: Text('${course.category} • ${course.college}', 
                                         style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ],
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Errors: ${errors.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: errors.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              errors[index],
                              style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (coursesToAdd.isNotEmpty)
              ElevatedButton(
                child: const Text('Import Courses'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _importCourses(coursesToAdd);
                },
              ),
          ],
        );
      },
    );
  }
  
  Future<void> _importCourses(List<Course> courses) async {
    try {
      // Use batch import for better performance
      final results = await _courseService.addMultipleCourses(courses);
      
      final successCount = results.where((r) => r).length;
      final errorCount = results.where((r) => !r).length;
      
      await _loadCourses(); // Reload the list
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import completed: $successCount successful, $errorCount failed'
            ),
            backgroundColor: successCount > 0 ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Helper to parse CSV line handling quoted values
  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    String current = '';
    bool inQuotes = false;
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Escaped quote
          current += '"';
          i++; // Skip next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // Field separator
        result.add(current.trim());
        current = '';
      } else {
        current += char;
      }
    }
    
    result.add(current.trim());
    return result;
  }
  
  // Download sample CSV file
  Future<void> _downloadSampleCsv() async {
    try {
      final sampleData = [
        ['Course Name', 'Category', 'College/Department'],
        ['Bachelor of Science in Computer Science', 'Undergraduate', 'College of Computer Studies'],
        ['Bachelor of Science in Information Technology', 'Undergraduate', 'College of Computer Studies'],
        ['Bachelor of Science in Education', 'Undergraduate', 'College of Education'],
        ['Bachelor of Science in Business Administration', 'Undergraduate', 'College of Business'],
        ['Master of Arts in Education', 'Graduate School', 'Graduate School'],
        ['Master of Science in Computer Science', 'Graduate School', 'Graduate School'],
        ['Doctor of Philosophy in Education', 'Graduate School', 'Graduate School'],
      ];
      
      final csvString = _listToCsv(sampleData);
      final fileName = 'sample_courses_template.csv';
      
      if (kIsWeb) {
        final csvBytes = utf8.encode(csvString);
        downloadFileWeb(csvBytes, fileName);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample CSV template downloaded'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Mobile/Desktop
        Directory? targetDir;
        
        if (Platform.isAndroid || Platform.isIOS) {
          targetDir = await getApplicationDocumentsDirectory();
        } else {
          try {
            targetDir = await getDownloadsDirectory();
          } catch (e) {
            targetDir = await getApplicationDocumentsDirectory();
          }
        }
        
        if (targetDir != null) {
          final file = File('${targetDir.path}/$fileName');
          await file.writeAsString(csvString);
          
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'Sample CSV Template for Course Import',
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sample CSV template saved: ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download sample: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
  
  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Courses'),
        content: const Text(
          'Are you sure you want to delete ALL courses? This action cannot be undone.\n\n'
          'This will remove all course data from the system.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _clearAllCourses();
    }
  }
  
  Future<void> _clearAllCourses() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Use batch delete for better performance
      final courseIds = _courses.where((c) => c.id != null).map((c) => c.id!).toList();
      
      if (courseIds.isNotEmpty) {
        final results = await _courseService.deleteMultipleCourses(courseIds);
        
        final successCount = results.where((r) => r).length;
        final errorCount = results.where((r) => !r).length;
        
        await _loadCourses(); // Reload the list
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted $successCount courses. $errorCount errors.'
              ),
              backgroundColor: successCount > 0 ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing courses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course CSV Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: !_isSuperAdmin
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isExporting ? null : _exportCoursesToCsv,
                              icon: _isExporting 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download),
                              label: Text(_isExporting ? 'Exporting...' : 'Export CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isImporting ? null : _showImportDialog,
                              icon: _isImporting 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload),
                              label: Text(_isImporting ? 'Importing...' : 'Import CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _courses.isEmpty ? null : _showClearAllDialog,
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('Clear All Courses'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Statistics
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '${_courses.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Text('Total Courses'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_courses.where((c) => c.category == 'Undergraduate').length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Text('Undergraduate'),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '${_courses.where((c) => c.category == 'Graduate School').length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Text('Graduate'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Course List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _courses.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No courses found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Import courses from CSV to get started',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _courses.length,
                              itemBuilder: (context, index) {
                                final course = _courses[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(course.name),
                                    subtitle: Text('${course.category} • ${course.college}'),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: course.category == 'Undergraduate' 
                                            ? Colors.green.shade100
                                            : course.category == 'Graduate School'
                                                ? Colors.orange.shade100
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        course.category,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: course.category == 'Undergraduate' 
                                              ? Colors.green.shade700
                                              : course.category == 'Graduate School'
                                                  ? Colors.orange.shade700
                                                  : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
