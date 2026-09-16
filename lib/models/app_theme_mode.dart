import 'package:flutter/material.dart';

enum AppThemeMode {
  system('System default', Icons.brightness_auto_outlined),
  light('Light', Icons.light_mode_outlined),
  dark('Dark', Icons.dark_mode_outlined);

  const AppThemeMode(this.label, this.icon);

  final String label;
  final IconData icon;

  ThemeMode get materialThemeMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode fromStorage(String? value) => switch (value) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };
}
