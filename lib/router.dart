import 'package:go_router/go_router.dart';

import 'models/performance.dart';
import 'models/player.dart';
import 'models/song.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/players_screen.dart';
import 'screens/ranking_screen.dart';
import 'screens/result_screen.dart';
import 'screens/search_screen.dart';

/// Argumente für den Player-Screen (per GoRouter `extra` übergeben).
class PlayArgs {
  final Player singer;
  final Song song;
  const PlayArgs({required this.singer, required this.song});
}

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/players', builder: (context, state) => const PlayersScreen()),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(
      path: '/play',
      builder: (context, state) => PlayerScreen(args: state.extra as PlayArgs),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) =>
          ResultScreen(performance: state.extra as Performance),
    ),
    GoRoute(path: '/ranking', builder: (context, state) => const RankingScreen()),
  ],
);
