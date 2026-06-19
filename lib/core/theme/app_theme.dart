import 'package:flutter/material.dart';


// ======================================================
// App Colors
// ======================================================

abstract class AppColors {

  // =========================
  // Brand Colors
  // =========================

  static const primary = Color(0xFF84CC16);       // Lime Green
  static const primaryDark = Color(0xFF65A30D);
  static const primaryLight = Color(0xFFD9F99D);

  static const secondary = Color(0xFF22C55E);

  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);


  // =========================
  // Common Colors
  // =========================

  static const black = Color(0xFF030303);
  static const white = Color(0xFFFAFAFA);


  // ======================================================
  // Light Theme
  // ======================================================

  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);

  static const lightTextPrimary = Color(0xFF111827);
  static const lightTextSecondary = Color(0xFF6B7280);
  static const lightMuted = Color(0xFF9CA3AF);

  static const lightBorder = Color(0xFFE5E7EB);

  static const lightFieldFill = Color(0xFFFFFFFF);
  static const lightSegmentTrack = Color(0xFFF3F4F6);



  // ======================================================
  // Dark Theme
  // ======================================================

  static const darkBackground = Color(0xFF030303);
  static const darkSurface = Color(0xFF111111);
  static const darkCard = Color(0xFF1A1A1A);

  static const darkTextPrimary = Color(0xFFFAFAFA);
  static const darkTextSecondary = Color(0xFFA1A1AA);
  static const darkMuted = Color(0xFF71717A);

  static const darkBorder = Color(0xFF2A2A2A);

  static const darkFieldFill = Color(0xFF18181B);
  static const darkSegmentTrack = Color(0xFF27272A);



  // =========================
  // Button Text Colors
  // =========================

  static const onPrimary = Color(0xFF030303);
  static const onDark = Color(0xFFFAFAFA);
}



// ======================================================
// Spacing
// ======================================================

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}



// ======================================================
// Theme Configuration
// ======================================================

class AppTheme {


  // ======================================================
  // Light Theme
  // ======================================================

  static ThemeData get light => ThemeData(

    useMaterial3: true,

    brightness: Brightness.light,

    scaffoldBackgroundColor:
        AppColors.lightBackground,


    colorScheme: const ColorScheme.light(

      primary: AppColors.primary,
      secondary: AppColors.secondary,

      surface: AppColors.lightSurface,

      error: AppColors.error,

      onPrimary: AppColors.onPrimary,

      onSurface: AppColors.lightTextPrimary,

    ),


    appBarTheme: const AppBarTheme(

      backgroundColor: AppColors.lightSurface,

      foregroundColor:
          AppColors.lightTextPrimary,

      elevation: 0,

    ),



    elevatedButtonTheme: ElevatedButtonThemeData(

      style: ElevatedButton.styleFrom(

        backgroundColor:
            AppColors.primary,

        foregroundColor:
            AppColors.onPrimary,

        minimumSize:
            const Size(double.infinity, 56),

        elevation: 0,

        shape:
            RoundedRectangleBorder(

          borderRadius:
              BorderRadius.circular(16),

        ),

      ),

    ),



    inputDecorationTheme:
        _inputDecorationTheme(

      background:
          AppColors.lightFieldFill,

      text:
          AppColors.lightTextPrimary,

      border:
          AppColors.lightBorder,

    ),


  );





  // ======================================================
  // Dark Theme
  // ======================================================

  static ThemeData get dark => ThemeData(

    useMaterial3: true,

    brightness: Brightness.dark,


    scaffoldBackgroundColor:
        AppColors.darkBackground,


    colorScheme: const ColorScheme.dark(

      primary: AppColors.primary,

      secondary:
          AppColors.secondary,

      surface:
          AppColors.darkSurface,

      error:
          AppColors.error,

      onPrimary:
          AppColors.onPrimary,

      onSurface:
          AppColors.darkTextPrimary,

    ),



    appBarTheme: const AppBarTheme(

      backgroundColor:
          AppColors.darkBackground,

      foregroundColor:
          AppColors.darkTextPrimary,

      elevation: 0,

    ),



    cardColor:
        AppColors.darkCard,



    elevatedButtonTheme:
        ElevatedButtonThemeData(

      style:
          ElevatedButton.styleFrom(

        backgroundColor:
            AppColors.primary,

        foregroundColor:
            AppColors.onPrimary,

        minimumSize:
            const Size(double.infinity,56),

        elevation:
            0,

        shape:
            RoundedRectangleBorder(

          borderRadius:
              BorderRadius.circular(16),

        ),

      ),

    ),



    inputDecorationTheme:
        _inputDecorationTheme(

      background:
          AppColors.darkFieldFill,

      text:
          AppColors.darkTextPrimary,

      border:
          AppColors.darkBorder,

    ),


  );





  // ======================================================
  // Input Field Theme
  // ======================================================

  static InputDecorationTheme _inputDecorationTheme({

    required Color background,

    required Color text,

    required Color border,

  }) {


    return InputDecorationTheme(

      filled: true,

      fillColor:
          background,


      contentPadding:
          const EdgeInsets.symmetric(

            horizontal: 16,

            vertical: 16,

          ),


      labelStyle:
          TextStyle(

            color:
                text.withOpacity(.7),

          ),


      hintStyle:
          TextStyle(

            color:
                text.withOpacity(.5),

          ),



      enabledBorder:
          OutlineInputBorder(

        borderRadius:
            BorderRadius.circular(14),

        borderSide:
            BorderSide(

              color:
                  border,

            ),

      ),



      focusedBorder:
          OutlineInputBorder(

        borderRadius:
            BorderRadius.circular(14),

        borderSide:
            const BorderSide(

              color:
                  AppColors.primary,

              width:
                  1.5,

            ),

      ),



      errorBorder:
          OutlineInputBorder(

        borderRadius:
            BorderRadius.circular(14),

        borderSide:
            const BorderSide(

              color:
                  AppColors.error,

            ),

      ),

    );

  }

}