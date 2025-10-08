import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';

class CourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'courses';
  
  // Get all courses
  Future<List<Course>> getAllCourses() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }
  
  // Add a new course (admin only)
  Future<bool> addCourse(Course course) async {
    try {
      await _firestore.collection(_collection).doc().set(course.toMap());
      return true;
    } catch (e) {
      print('Error adding course: $e');
      return false;
    }
  }
  
  // Update a course (admin only)
  Future<bool> updateCourse(String id, Course course) async {
    try {
      await _firestore.collection(_collection).doc(id).update(course.toMap());
      return true;
    } catch (e) {
      print('Error updating course: $e');
      return false;
    }
  }
  
  // Delete a course (admin only)
  Future<bool> deleteCourse(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting course: $e');
      return false;
    }
  }
  
  // Add multiple courses in batch (for CSV import)
  Future<List<bool>> addMultipleCourses(List<Course> courses) async {
    final List<bool> results = [];
    
    try {
      // Use batch write for better performance
      final WriteBatch batch = _firestore.batch();
      
      for (Course course in courses) {
        DocumentReference docRef = _firestore.collection(_collection).doc();
        batch.set(docRef, course.toMap());
      }
      
      // Commit the batch
      await batch.commit();
      
      // All succeeded if we reach here
      results.addAll(List.filled(courses.length, true));
      
      print('Successfully added ${courses.length} courses in batch');
    } catch (e) {
      print('Error adding courses in batch: $e');
      // All failed if batch fails
      results.addAll(List.filled(courses.length, false));
    }
    
    return results;
  }
  
  // Delete multiple courses in batch
  Future<List<bool>> deleteMultipleCourses(List<String> courseIds) async {
    final List<bool> results = [];
    
    try {
      // Use batch write for better performance
      final WriteBatch batch = _firestore.batch();
      
      for (String courseId in courseIds) {
        DocumentReference docRef = _firestore.collection(_collection).doc(courseId);
        batch.delete(docRef);
      }
      
      // Commit the batch
      await batch.commit();
      
      // All succeeded if we reach here
      results.addAll(List.filled(courseIds.length, true));
      
      print('Successfully deleted ${courseIds.length} courses in batch');
    } catch (e) {
      print('Error deleting courses in batch: $e');
      // All failed if batch fails
      results.addAll(List.filled(courseIds.length, false));
    }
    
    return results;
  }
  
  // Get unique colleges/departments
  Future<List<String>> getUniqueColleges() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      final Set<String> colleges = {};
      
      for (final doc in snapshot.docs) {
        final course = Course.fromFirestore(doc);
        if (course.college.isNotEmpty) {
          colleges.add(course.college);
        }
      }
      
      final list = colleges.toList()..sort();
      return list;
    } catch (e) {
      print('Error fetching unique colleges: $e');
      return [];
    }
  }
  
  // Get course statistics
  Future<Map<String, int>> getCourseStatistics() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      final Map<String, int> stats = {
        'total': 0,
        'undergraduate': 0,
        'graduate': 0,
        'other': 0,
      };
      
      for (final doc in snapshot.docs) {
        final course = Course.fromFirestore(doc);
        stats['total'] = (stats['total'] ?? 0) + 1;
        
        switch (course.category.toLowerCase()) {
          case 'undergraduate':
            stats['undergraduate'] = (stats['undergraduate'] ?? 0) + 1;
            break;
          case 'graduate school':
            stats['graduate'] = (stats['graduate'] ?? 0) + 1;
            break;
          default:
            stats['other'] = (stats['other'] ?? 0) + 1;
            break;
        }
      }
      
      return stats;
    } catch (e) {
      print('Error fetching course statistics: $e');
      return {
        'total': 0,
        'undergraduate': 0,
        'graduate': 0,
        'other': 0,
      };
    }
  }

  // Add all default courses if the collection is empty
  Future<void> seedDefaultCoursesIfEmpty(Map<String, dynamic> defaultCoursesData) async {
    try {
      // Check if courses collection is empty
      final QuerySnapshot snapshot = await _firestore.collection(_collection).limit(1).get();
      
      if (snapshot.docs.isEmpty) {
        print('Courses collection is empty, seeding default courses...');
        
        // Flatten the nested structure and extract course names
        List<Course> defaultCourses = [];
        
        // Process undergraduate courses
        Map<String, List<String>> undergrad = defaultCoursesData["Undergraduate"] as Map<String, List<String>>;
        undergrad.forEach((college, courseList) {
          for (String courseName in courseList) {
            defaultCourses.add(Course(
              name: courseName,
              category: 'Undergraduate',
              college: college,
            ));
          }
        });
        
        // Process graduate school courses
        Map<String, List<String>> gradSchool = defaultCoursesData["Graduate School"] as Map<String, List<String>>;
        gradSchool.forEach((department, courseList) {
          for (String courseName in courseList) {
            defaultCourses.add(Course(
              name: courseName,
              category: 'Graduate School',
              college: department,
            ));
          }
        });
        
        // Create a batch write
        final WriteBatch batch = _firestore.batch();
        
        // Add each course to the batch
        for (Course course in defaultCourses) {
          DocumentReference docRef = _firestore.collection(_collection).doc();
          batch.set(docRef, course.toMap());
        }
        
        // Commit the batch
        await batch.commit();
        print('Successfully seeded ${defaultCourses.length} default courses');
      } else {
        print('Courses collection already has data, skipping seed');
      }
    } catch (e) {
      print('Error seeding default courses: $e');
    }
  }
} 