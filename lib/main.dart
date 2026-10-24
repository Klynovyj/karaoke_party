import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers.dart';
import 'services/persistence_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final persistence = PersistenceService();
  await persistence.init();

  runApp(
    ProviderScope(
      overrides: [persistenceProvider.overrideWithValue(persistence)],
      child: const KaraokePartyApp(),
    ),
  );
}
