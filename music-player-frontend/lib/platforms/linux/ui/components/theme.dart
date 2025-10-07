import 'package:flutter/material.dart';

class MusicPlayerTheme {
  // Define the color palette
  static const Color primaryPurple = Color(0xFF3D2A78);
  static const Color secondaryPurple = Color(0xFF4B3A91);
  static const Color accentPurple = Color(0xFF5A4BA3);
  static const Color darkPurple = Color(0xFF2A1B55);
  static const Color deepBlack = Color(0xFF000000);
  static const Color backgroundDark = Color(0xFF0B0B0B);
  static const Color backgroundLight = Color(0xFF1A1A1A);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);

  // Gradient backgrounds
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A1B55),
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0xFF000000),
      Color(0xFF2A1B55),
    ],
    stops: [0.0, 0.35, 0.5, 0.65, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A1B55), Color(0xFF3D2A78), Color(0xFF4B3A91)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF1E1E1E)],
    stops: [0.0, 1.0],
  );

  // Create the ThemeData
  static ThemeData getTheme(BuildContext context) {
    var height = MediaQuery.of(context).size.height;

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Inter',

      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: secondaryPurple,
        surface: surfaceDark,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        tertiary: accentPurple,
      ),

      // Scaffold theme
      scaffoldBackgroundColor: backgroundDark,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.025,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: surfaceDark,
        elevation: 8,
        shadowColor: primaryPurple.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.height * 0.015,
          ),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: textPrimary,
          elevation: 8,
          shadowColor: primaryPurple.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: height * 0.02,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: accentPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      // Slider theme for music controls
      sliderTheme: SliderThemeData(
        activeTrackColor: accentPurple,
        inactiveTrackColor: textSecondary.withOpacity(0.2),
        thumbColor: primaryPurple,
        overlayColor: primaryPurple.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundLight,
        selectedItemColor: accentPurple,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.04,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.03,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.025,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.02,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.018,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.018,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.016,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.014,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.016,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.014,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: height * 0.012,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(fontFamily: 'Inter', color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      // List tile theme
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        subtitleTextStyle: TextStyle(fontFamily: 'Inter', color: textSecondary),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentPurple,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
      ),
    );
  }
}
