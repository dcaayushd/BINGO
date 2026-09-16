import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF102A43);
  static const deepOcean = Color(0xFF163A5F);
  static const teal = Color(0xFF087E8B);
  static const mint = Color(0xFFB8E3D0);
  static const sky = Color(0xFFEAF4F8);
  static const panel = Color(0xFFF8FBFC);
  static const danger = Color(0xFFC94C4C);
  static const classicTargetLines = 5;

  static const darkScreenGradient = LinearGradient(
    colors: [deepOcean, teal],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const lightScreenGradient = LinearGradient(
    colors: [Color(0xFF367E8B), Color(0xFF50A5A0)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient screenGradientFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkScreenGradient : lightScreenGradient;

  static Color screenBottomColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? teal : const Color(0xFF50A5A0);
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: brightness,
    primary: isDark ? AppColors.mint : AppColors.teal,
    secondary: isDark ? const Color(0xFF6BCFC8) : AppColors.mint,
    surface: isDark ? const Color(0xFF183B4E) : AppColors.panel,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Poppins',
    visualDensity: VisualDensity.adaptivePlatformDensity,
    scaffoldBackgroundColor: AppColors.screenBottomColorFor(brightness),
    cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
      brightness: brightness,
      primaryColor: scheme.primary,
      barBackgroundColor: scheme.surface,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
