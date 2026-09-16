import 'package:bingo/models/app_theme_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme preferences restore valid values and safely default to system',
      () {
    expect(AppThemeMode.fromStorage('light'), AppThemeMode.light);
    expect(AppThemeMode.fromStorage('dark'), AppThemeMode.dark);
    expect(AppThemeMode.fromStorage('system'), AppThemeMode.system);
    expect(AppThemeMode.fromStorage('invalid'), AppThemeMode.system);
    expect(AppThemeMode.fromStorage(null).materialThemeMode, ThemeMode.system);
  });
}
