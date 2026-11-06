import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF6366F1);

  static ThemeData light() => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed)
        .copyWith(surface: Colors.white),
    scaffoldBackgroundColor: const Color(0xFFF8FAFF),
    useMaterial3: true,
  );

  static ThemeData dark() => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF1E293B)),
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    useMaterial3: true,
  );
}
