import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/user_service.dart';

class ThemeProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = true;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isLoading => _isLoading;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Get current theme
  ThemeData get theme => isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;

  Future<void> _loadTheme() async {
    _isLoading = true;
    notifyListeners();

    try {
      final settings = await _userService.getUserSettings();
      if (settings != null) {
        _themeMode = settings.darkMode ? ThemeMode.dark : ThemeMode.light;
      } else {
        _themeMode = ThemeMode.light;
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
      _themeMode = ThemeMode.light;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // Set theme mode explicitly
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final settings = await _userService.getUserSettings();
      if (settings != null) {
        final updatedSettings = settings.copyWith(
          darkMode: mode == ThemeMode.dark,
        );
        await _userService.updateUserSettings(updatedSettings);
      }
    } catch (e) {
      debugPrint('Error saving theme setting: $e');
    }
  }

  // Set dark mode explicitly
  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
} 