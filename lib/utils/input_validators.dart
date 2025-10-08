import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputValidators {
  // Philippine phone number validation (11 digits starting with 09)
  static String? validatePhilippinePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    // Remove all non-digit characters
    String cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if it's exactly 11 digits
    if (cleanValue.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    
    // Check if it starts with 09 (Philippine mobile format)
    if (!cleanValue.startsWith('09')) {
      return 'Phone number must start with 09 (Philippine mobile format)';
    }
    
    return null;
  }

  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter email';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  // Name validation (letters, spaces, hyphens, apostrophes only)
  static String? validateName(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    
    final nameRegex = RegExp(r"^[a-zA-Z\s\-'\.]+$");
    if (!nameRegex.hasMatch(value.trim())) {
      return '$fieldName can only contain letters, spaces, hyphens, apostrophes, and periods';
    }
    
    // Check minimum length
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters long';
    }
    
    return null;
  }

  // Student/Faculty ID validation (alphanumeric, 3-20 characters)
  static String? validateId(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    
    final idRegex = RegExp(r'^[a-zA-Z0-9\-_]+$');
    if (!idRegex.hasMatch(value.trim())) {
      return '$fieldName can only contain letters, numbers, hyphens, and underscores';
    }
    
    if (value.trim().length < 3) {
      return '$fieldName must be at least 3 characters long';
    }
    
    if (value.trim().length > 20) {
      return '$fieldName must be no more than 20 characters long';
    }
    
    return null;
  }

  // URL validation (for social media links)
  static String? validateUrl(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$'
    );
    
    if (!urlRegex.hasMatch(value.trim())) {
      return 'Please enter a valid URL (e.g., https://example.com)';
    }
    
    return null;
  }

  // Facebook URL validation
  static String? validateFacebookUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final facebookRegex = RegExp(
      r'^https?:\/\/(www\.)?facebook\.com\/[a-zA-Z0-9._-]+\/?$'
    );
    
    if (!facebookRegex.hasMatch(value.trim())) {
      return 'Please enter a valid Facebook URL (e.g., https://facebook.com/username)';
    }
    
    return null;
  }

  // Instagram URL validation
  static String? validateInstagramUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final instagramRegex = RegExp(
      r'^https?:\/\/(www\.)?instagram\.com\/[a-zA-Z0-9._-]+\/?$'
    );
    
    if (!instagramRegex.hasMatch(value.trim())) {
      return 'Please enter a valid Instagram URL (e.g., https://instagram.com/username)';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    if (value.length > 128) {
      return 'Password must be no more than 128 characters long';
    }
    
    return null;
  }

  // Bio validation (max 500 characters)
  static String? validateBio(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    
    if (value.length > 500) {
      return 'Bio must be no more than 500 characters long';
    }
    
    return null;
  }

  // Company/Occupation validation
  static String? validateCompany(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters long';
    }
    
    if (value.trim().length > 100) {
      return '$fieldName must be no more than 100 characters long';
    }
    
    return null;
  }

  // Location validation
  static String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    if (value.trim().length < 2) {
      return 'Location must be at least 2 characters long';
    }
    
    if (value.trim().length > 200) {
      return 'Location must be no more than 200 characters long';
    }
    
    return null;
  }

  // Suffix validation (Jr., Sr., III, etc.)
  static String? validateSuffix(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }
    
    final suffixRegex = RegExp(r'^[a-zA-Z]+\.?$');
    if (!suffixRegex.hasMatch(value.trim())) {
      return 'Suffix can only contain letters and optional period (e.g., Jr., Sr., III)';
    }
    
    if (value.trim().length > 10) {
      return 'Suffix must be no more than 10 characters long';
    }
    
    return null;
  }

  // Helper method to format phone number as user types
  static String formatPhilippinePhone(String value) {
    // Remove all non-digit characters
    String cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');
    
    // Limit to 11 digits
    if (cleanValue.length > 11) {
      cleanValue = cleanValue.substring(0, 11);
    }
    
    // Format as 09XX XXX XXXX
    if (cleanValue.length >= 4) {
      if (cleanValue.length >= 7) {
        return '${cleanValue.substring(0, 4)} ${cleanValue.substring(4, 7)} ${cleanValue.substring(7)}';
      } else {
        return '${cleanValue.substring(0, 4)} ${cleanValue.substring(4)}';
      }
    }
    
    return cleanValue;
  }

  // Helper method to get phone number input formatter
  static List<TextInputFormatter> getPhoneInputFormatters() {
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(11),
      TextInputFormatter.withFunction((oldValue, newValue) {
        // Ensure it starts with 09
        if (newValue.text.isNotEmpty && !newValue.text.startsWith('09')) {
          if (newValue.text.startsWith('9')) {
            return TextEditingValue(
              text: '0${newValue.text}',
              selection: TextSelection.collapsed(offset: '0${newValue.text}'.length),
            );
          }
          return oldValue;
        }
        return newValue;
      }),
    ];
  }
}
