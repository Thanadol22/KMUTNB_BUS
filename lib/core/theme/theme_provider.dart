import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeData get themeData {
    if (_isDarkMode) {
      return ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF4009),
          secondary: Color(0xFFFF4009),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF4009),
          foregroundColor: Colors.white,
        ),
      );
    } else {
      return ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFFF4009)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFF4009),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      );
    }
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }
}
