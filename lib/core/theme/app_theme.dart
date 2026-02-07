import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryColor = Color(0xFFE50914); // Netflix red
  static const backgroundColor = Color(0xFF000000);
  static const surfaceColor = Color(0xFF121212);

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      surface: surfaceColor,
      background: backgroundColor,
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      titleLarge: GoogleFonts.outfit(
        fontWeight: FontWeight.bold,
        fontSize: 24,
      ),
      titleMedium: GoogleFonts.outfit(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
    ),
  );
}
