import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'services/persistence_service.dart';
import 'tv_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Auf einem Android-TV (z.B. waipu-Stick) startet die TV-Variante.
  if (await _isAndroidTv()) {
    runApp(const KaraokeTvApp());
    return;
  }

  final persistence = PersistenceService();
  await persistence.init();

  runApp(
    ProviderScope(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
      child: const KaraokePartyApp(),
    ),
  );
}

Future<bool> _isAndroidTv() async {
  if (!Platform.isAndroid) return false;
  try {
    final info = await DeviceInfoPlugin().androidInfo;
    final features = info.systemFeatures;
    return features.contains('android.software.leanback') ||
        features.contains('android.hardware.type.television');
  } catch (_) {
    return false;
  }
}
