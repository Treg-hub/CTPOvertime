import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryOrange = Colors.orange; // Main orange
  static const Color accentGreen = Color(0xFF4CAF50); // Badenia
  static const Color accentYellow = Color(0xFFFF9800); // Wifag
  static const Color accentBlue = Color(0xFF2196F3);  // Aurora

  static ThemeData lightTheme = ThemeData.light().copyWith(
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryOrange,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryOrange,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    cardColor: Colors.black12,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFF6D00),
      foregroundColor: Colors.black, // Black text in dark mode
      elevation: 2,
    ),
  );
}