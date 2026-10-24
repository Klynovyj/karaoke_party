import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/tv_stage_screen.dart';

/// Variante der App, die auf einem Android-TV (waipu-Stick) startet.
class KaraokeTvApp extends StatelessWidget {
  const KaraokeTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karaoke Party TV',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: const TvStageScreen(),
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
