import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeMode _themeMode;

  ThemeProvider({ThemeMode? initialMode}) : _themeMode = initialMode ?? ThemeMode.dark {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, isDark ? 1 : 0);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkVal = prefs.getInt(_themeKey);
    if (isDarkVal != null) {
      final loadedMode = isDarkVal == 1 ? ThemeMode.dark : ThemeMode.light;
      if (_themeMode != loadedMode) {
        _themeMode = loadedMode;
        notifyListeners();
      }
    }
  }
}
