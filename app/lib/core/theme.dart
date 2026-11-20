import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: const Color(0xFF6C4DFF),
      // Add Noto Sans Bengali under flutter: fonts: in pubspec when bundling the font file.
      fontFamilyFallback: const ['Noto Sans Bengali'],
    );
