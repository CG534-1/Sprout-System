import 'package:flutter/material.dart';
import 'package:sprout/core/theme/app_colors.dart';
import 'package:sprout/core/theme/app_text_styles.dart';
import 'package:sprout/core/theme/theme_controller.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light => _theme(SproutPalette.light, Brightness.light);

  static ThemeData get dark => _theme(SproutPalette.dark, Brightness.dark);

  static ThemeData _theme(SproutPalette palette, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.sproutGreen,
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.paper,
      textTheme: AppTextStyles.forPalette(palette),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.paper,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.indicator,
        height: 72,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.forPalette(palette).labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
