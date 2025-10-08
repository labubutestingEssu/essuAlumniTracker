import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static bool useEmulator = false;
  
  // Set up emulators for Firebase services
  static Future<void> setupEmulators() async {
    if (!kIsWeb && kDebugMode && useEmulator) {
      try {
        // Android emulator hostname
        const String host = '10.0.2.2';
        
        // Auth emulator
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        
        // Firestore emulator
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        
        // Add other emulators as needed (Storage, Functions, etc.)
        
        if (kDebugMode) {
          print('✅ Connected to Firebase emulators');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Failed to connect to Firebase emulators: $e');
        }
      }
    }
  }
  
  // Initialize Firebase with offline persistence
  static void configureFirestore() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
} 