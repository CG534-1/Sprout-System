import 'package:flutter/material.dart';
import 'package:sprout/core/theme/theme_controller.dart';

class AppTextStyles {
  const AppTextStyles._();

  static TextTheme forPalette(SproutPalette palette) {
    return TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: palette.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: palette.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: palette.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: palette.muted),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: palette.ink,
      ),
    );
  }
}
