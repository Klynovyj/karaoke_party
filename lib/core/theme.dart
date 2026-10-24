import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFAB47BC),
          brightness: Brightness.dark,
        ),
      );
}
