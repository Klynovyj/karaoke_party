import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'router.dart';

class KaraokePartyApp extends StatelessWidget {
  const KaraokePartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Karaoke Party',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
