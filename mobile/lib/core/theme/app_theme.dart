import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens mirrored from `frontend/app/globals.css`.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF6200); // --color-primary
  static const Color pending = Color(0xFFFF0000); // --color-pending
  static const Color dispatched = Color(0xFF096700); // --color-dispatched
  static const Color border = Color(0xFFD9D9D9); // --color-border
  static const Color heading = Color(0xFF000000); // --color-heading
  static const Color textMuted = Color(0xFF919191); // --color-text

  // StatusBadge.tsx colours.
  static const Color pendingBg = Color(0xFFFFFBEB);
  static const Color pendingFg = Color(0xFFD97706);
  static const Color packedBg = Color(0xFFFFF7ED);
  static const Color packedFg = Color(0xFFEA580C);
  static const Color dispatchedBg = Color(0xFFF0FDF4);
  static const Color dispatchedFg = Color(0xFF15803D);
  static const Color grayBg = Color(0xFFF9FAFB);
  static const Color grayFg = Color(0xFF4B5563);

  static const Color scaffold = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEBEBEB);

  // Unread-order indicator (green). One token pair used by the dashboard's
  // unread dot, card tint/border and the "Unread" filter chip.
  static const Color unread = Color(0xFF16A34A);
  static const Color unreadTint = Color(0xFFF0FDF4);
}

/// Flutter ThemeData replicating the web app's visual language.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.scaffold,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: Colors.white,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        headlineLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.1,
          color: AppColors.heading,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.heading,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.heading,
        ),
        titleSmall: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: const TextStyle(fontSize: 13, color: AppColors.heading),
        bodySmall: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        labelLarge: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.heading,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}