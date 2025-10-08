import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String? id;
  final String name;
  final String category; // 'Undergraduate' or 'Graduate School'
  final String college;  // College or department name
  
  Course({
    this.id,
    required this.name,
    required this.category,
    required this.college,
  });
  
  // Create a Course object from a Firestore document snapshot
  factory Course.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Course(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      college: data['college'] ?? '',
    );
  }
  
  // Convert a Course object to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'college': college,
    };
  }
  
  @override
  String toString() {
    return name;
  }
} 