import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SproutAppearance { light, dark, system }

class SproutPalette {
  const SproutPalette({
    required this.paper,
    required this.ink,
    required this.headline,
    required this.body,
    required this.field,
    required this.line,
    required this.background,
    required this.surface,
    required this.frame,
    required this.nav,
    required this.navIdle,
    required this.muted,
    required this.indicator,
  });

  final Color paper;
  final Color ink;
  final Color headline;
  final Color body;
  final Color field;
  final Color line;
  final Color background;
  final Color surface;
  final Color frame;
  final Color nav;
  final Color navIdle;
  final Color muted;
  final Color indicator;

  static const light = SproutPalette(
    paper: Color(0xFFF8FEF9),
    ink: Color(0xFF0B1F13),
    headline: Color(0xFF20342A),
    body: Color(0xFF4C7259),
    field: Color(0xFFE4F5E7),
    line: Color(0xFFC6E5CC),
    background: Color(0xFFF6F4EF),
    surface: Color(0xFFFFFFFF),
    frame: Color(0xFFD5DDD6),
    nav: Color(0xEBFFFFFF),
    navIdle: Color(0xFF7EA887),
    muted: Color(0xFF5E6F66),
    indicator: Color(0xFFD7E8DE),
  );

  static const dark = SproutPalette(
    paper: Color(0xFF102017),
    ink: Color(0xFFF4FBF6),
    headline: Color(0xFFF4FBF6),
    body: Color(0xFF9BB8A6),
    field: Color(0xFF1B3328),
    line: Color(0xFF2E4A3C),
    background: Color(0xFF0B1610),
    surface: Color(0xFF173024),
    frame: Color(0xFF070D0A),
    nav: Color(0xEB102017),
    navIdle: Color(0xFF8FB89A),
    muted: Color(0xFF8AA394),
    indicator: Color(0xFF1E3A2C),
  );
}

extension SproutAppearanceLabels on SproutAppearance {
  ThemeMode get themeMode => switch (this) {
    SproutAppearance.light => ThemeMode.light,
    SproutAppearance.dark => ThemeMode.dark,
    SproutAppearance.system => ThemeMode.system,
  };

  String get label => switch (this) {
    SproutAppearance.light => 'Light',
    SproutAppearance.dark => 'Dark',
    SproutAppearance.system => 'System',
  };
}

final themeControllerProvider =
    NotifierProvider<ThemeController, SproutAppearance>(ThemeController.new);

class ThemeController extends Notifier<SproutAppearance> {
  ThemeController([this._initial = SproutAppearance.light]);

  final SproutAppearance _initial;

  static const _key = 'sprout.appearance';

  @override
  SproutAppearance build() => _initial;

  /// Reads the stored appearance before the first frame, so launch does not
  /// flash the light theme.
  static Future<SproutAppearance> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'dark' => SproutAppearance.dark,
      'system' => SproutAppearance.system,
      _ => SproutAppearance.light,
    };
  }

  void select(String label) {
    final next = switch (label) {
      'Dark' => SproutAppearance.dark,
      'System' => SproutAppearance.system,
      _ => SproutAppearance.light,
    };
    if (next == state) return;
    state = next;
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_key, next.name));
  }
}
