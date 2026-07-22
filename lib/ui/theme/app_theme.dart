import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color stingerRed = Color(0xFFFF3B5C);
  static const Color stingerGreen = Color(0xFF00E676);
  static const Color accentGold = Color(0xFFFFC107);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF111218),
      colorScheme: const ColorScheme.dark(
        primary: stingerRed,
        secondary: stingerGreen,
        surface: Color(0xFF1A1B23),
      ),
      cardColor: const Color(0xFF1E202A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111218),
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E202A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF6F8FC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE53935),
        secondary: Color(0xFF2E7D32),
        surface: Colors.white,
      ),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F8FC),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          letterSpacing: 0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        hintStyle: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }
}
