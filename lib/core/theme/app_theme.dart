import 'package:flutter/material.dart';

/// UniRide palette — "Deep Green".
///
/// One brand accent carries every primary action; semantic colours (success /
/// warning / danger) are held separate so a green button is never confused with
/// a success state. Neutrals carry a faint green bias rather than being pure
/// grey, so they read as chosen alongside the accent.
///
/// Every value below is checked against its intended background at WCAG AA
/// (4.5:1 for text). The ratios in the comments are measured, not estimated —
/// the previous sage primary sat at 2.92:1 against white, which is what made
/// the UI look washed out.
abstract class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF0B7A4B); // white on it: 5.39:1
  static const primaryDark = Color(0xFF096239); // pressed / gradient end
  static const primaryWash = Color(0xFFE8F4EE); // tinted fill; primary on it: 4.77:1

  /// Auth header ground — near-black carrying the same green bias.
  static const dark = Color(0xFF121917);

  // ── Semantic ───────────────────────────────────────────────────────────────
  // Deliberately not Apple's systemGreen/systemRed literals: those are tuned as
  // fills and fail as text (#34C759 is 2.22:1 on white, #FF3B30 is 3.55:1).
  // These are the darker equivalents, legible as both fill and label.
  static const success = Color(0xFF18874A); // 4.56:1 either direction
  static const warning = Color(0xFFB45309); // 5.02:1 on white
  static const error = Color(0xFFD92B20); // 4.86:1 either direction

  /// Female-only ride marker. A signal colour, not part of the brand ramp.
  static const genderFemale = Color(0xFFBE185D); // 6.04:1 on white
  static const genderFemaleWash = Color(0xFFFCE7F3); // marker on it: 5.14:1

  // ── Neutrals — faint green bias ────────────────────────────────────────────
  static const background = Color(0xFFF3F5F4);
  static const surface = Color(0xFFFFFFFF);
  static const onPrimary = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF14181A); // 16.32:1 on background
  static const textSecondary = Color(0xFF667070); // 4.66:1 on background
  static const muted = Color(0xFF9BA3A3);

  /// Translucent hairline rather than a solid grey — it picks up whatever sits
  /// beneath it, which is what keeps Apple-style lists feeling light.
  static const border = Color(0x1F14181A);

  static const fieldFill = Color(0xFFFFFFFF);
  static const segmentTrack = Color(0xFFEDF0EF);

  /// Shimmer base for loading placeholders. Deliberately opaque: skeletons
  /// animate their alpha, and animating the alpha of a translucent token like
  /// [border] overrides its transparency and renders near-solid.
  static const skeleton = Color(0xFFDCE3E0);
}

abstract class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          // Without these, fromSeed derives its own error hue and Material's
          // built-in error text drifts away from AppColors.error.
          error: AppColors.error,
          onError: AppColors.onPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            disabledForegroundColor: AppColors.onPrimary,
            minimumSize: const Size(double.infinity, 56),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(double.infinity, 52),
            side: const BorderSide(color: AppColors.border),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.fieldFill,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIconColor: AppColors.primary,
          suffixIconColor: AppColors.muted,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          hintStyle: const TextStyle(color: AppColors.muted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        ),
      );
}
