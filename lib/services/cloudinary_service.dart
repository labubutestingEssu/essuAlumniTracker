import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;

class CloudinaryService {
  final cloudinary = CloudinaryPublic(
    'du5iwvnxz',      // Cloud name
    'essu_default',   // Upload preset name
    cache: false,
  );

  // Upload an image file and return the URL
  Future<String?> uploadImage(File imageFile, {String? folder}) async {
    try {
      if (kIsWeb) {
        debugPrint('Web platform detected, cannot use File directly');
        return null; // Web platform will use uploadWebImage instead
      }
      
      debugPrint('Starting Cloudinary upload. File path: ${imageFile.path}');
      debugPrint('File exists: ${await imageFile.exists()}');
      debugPrint('File size: ${await imageFile.length()} bytes');
      
      // Create response object for the upload
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder ?? 'essu_alumni',  // Default folder name
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      debugPrint('Cloudinary upload successful. URL: ${response.secureUrl}');
      // Return the secure URL of the uploaded image
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }
  
  // Upload PDF file and return the URL
  Future<String?> uploadPdf(File pdfFile, {String? folder}) async {
    try {
      if (kIsWeb) {
        debugPrint('Web platform detected, cannot use File directly for PDF');
        return null; // Web platform will use uploadPdfBytes instead
      }
      
      debugPrint('Starting Cloudinary PDF upload. File path: ${pdfFile.path}');
      debugPrint('File exists: ${await pdfFile.exists()}');
      debugPrint('File size: ${await pdfFile.length()} bytes');
      
      // Create response object for the upload
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          pdfFile.path,
          folder: folder ?? 'resumes',  // Default folder for resumes
          resourceType: CloudinaryResourceType.Raw, // Use Raw for PDFs
        ),
      );

      debugPrint('Cloudinary PDF upload successful. URL: ${response.secureUrl}');
      // Return the secure URL of the uploaded PDF
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading PDF to Cloudinary: $e');
      return null;
    }
  }
  
  // Upload PDF from XFile (works on both web and mobile)
  Future<String?> uploadPdfXFile(XFile pdfFile, {String? folder}) async {
    try {
      debugPrint('Starting Cloudinary PDF upload from XFile. Path: ${pdfFile.path}');
      
      if (kIsWeb) {
        // For web, we need to read the bytes
        final bytes = await pdfFile.readAsBytes();
        return uploadPdfBytes(bytes, pdfFile.name, folder: folder);
      } else {
        // For mobile, we can use the file path
        return uploadPdf(File(pdfFile.path), folder: folder);
      }
    } catch (e) {
      debugPrint('Error uploading PDF XFile to Cloudinary: $e');
      return null;
    }
  }
  
  // Upload PDF from bytes (for web)
  Future<String?> uploadPdfBytes(Uint8List bytes, String fileName, {String? folder}) async {
    try {
      debugPrint('Starting Cloudinary PDF upload from bytes. Size: ${bytes.length} bytes');
      
      // Create response object for the upload
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          folder: folder ?? 'resumes',
          resourceType: CloudinaryResourceType.Raw, // Use Raw for PDFs
        ),
      );

      debugPrint('Cloudinary PDF upload successful. URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading PDF bytes to Cloudinary: $e');
      return null;
    }
  }
  
  // Upload image from XFile (works on both web and mobile)
  Future<String?> uploadXFile(XFile pickedFile, {String? folder}) async {
    try {
      debugPrint('Starting Cloudinary upload from XFile. Path: ${pickedFile.path}');
      
      if (kIsWeb) {
        // For web, we need to read the bytes
        final bytes = await pickedFile.readAsBytes();
        return uploadBytes(bytes, pickedFile.name, folder: folder);
      } else {
        // For mobile, we can use the file path
        return uploadImage(File(pickedFile.path), folder: folder);
      }
    } catch (e) {
      debugPrint('Error uploading XFile to Cloudinary: $e');
      return null;
    }
  }
  
  // Upload image from bytes (for web)
  Future<String?> uploadBytes(Uint8List bytes, String fileName, {String? folder}) async {
    try {
      debugPrint('Starting Cloudinary upload from bytes. Size: ${bytes.length} bytes');
      
      // Create response object for the upload
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          folder: folder ?? 'essu_alumni',
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      debugPrint('Cloudinary upload successful. URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading bytes to Cloudinary: $e');
      return null;
    }
  }

  // Generate a Cloudinary URL for a placeholder if upload fails
  String getPlaceholderUrl(String seed) {
    // Create a proper URL-encoded seed (limit length to avoid URL issues)
    final shortenedSeed = seed.length > 30 ? seed.substring(0, 30) + '...' : seed;
    final encodedSeed = Uri.encodeComponent(shortenedSeed);
    
    // Use a simpler transformation that's guaranteed to work
    // Use a solid color background with text overlay
    return 'https://res.cloudinary.com/du5iwvnxz/image/upload/'
           'w_800,h_400,c_fill,b_rgb:0047AB/'  // Changed color to a more visible blue
           'l_text:Arial_40_bold:${encodedSeed},co_white,g_center/'
           'sample';  // Use Cloudinary's built-in 'sample' image
  }

  // Test connection to Cloudinary
  Future<bool> testConnection() async {
    try {
      // Attempt to fetch Cloudinary info (doesn't consume any upload quota)
      final response = await http.get(Uri.parse(
        'https://res.cloudinary.com/du5iwvnxz/image/upload/sample'
      ));
      
      // Check if the response is successful (200 OK)
      final success = response.statusCode == 200;
      
      debugPrint('Cloudinary connection test: ${success ? 'SUCCESS' : 'FAILED'} (status: ${response.statusCode})');
      if (!success) {
        debugPrint('Response body: ${response.body}');
      }
      
      return success;
    } catch (e) {
      debugPrint('Cloudinary connection test error: $e');
      return false;
    }
  }
  
  // Get Cloudinary configuration details for debugging
  Map<String, String> getDebugInfo() {
    return {
      'cloudName': 'du5iwvnxz',
      'uploadPreset': 'essu_default',
      'apiUrl': 'https://api.cloudinary.com/v1_1/du5iwvnxz/image/upload',
      'sampleImageUrl': 'https://res.cloudinary.com/du5iwvnxz/image/upload/sample',
    };
  }
} 