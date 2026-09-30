import 'package:flutter/material.dart';
import 'package:sprout/core/theme/theme_controller.dart';

class AppColors {
  const AppColors._();

  static SproutPalette _palette = SproutPalette.light;

  static void sync(Brightness brightness) {
    _palette = brightness == Brightness.dark ? SproutPalette.dark : SproutPalette.light;
  }

  static const primary = Color(0xFF006134);
  static const sproutGreen = Color(0xFF179C46);
  static const splashTop = Color(0xFF87DB6C);
  static const error = Color(0xFFB42318);

  static Color get onboardingPaper => _palette.paper;
  static Color get onboardingInk => _palette.headline;
  static Color get onboardingBody => _palette.body;
  static Color get dotIdle => _palette.line;
  static Color get ink => _palette.ink;
  static Color get muted => _palette.muted;
  static Color get background => _palette.background;
  static Color get surface => _palette.surface;
  static Color get frame => _palette.frame;
  static Color get line => _palette.line;
  static Color get indicator => _palette.indicator;
  static Color get field => _palette.field;
  static Color get nav => _palette.nav;
  static Color get navIdle => _palette.navIdle;
}
