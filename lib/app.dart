import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home/home_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'screens/log_entry/log_entry_screen.dart';
import 'screens/charts/charts_screen.dart';
import 'screens/family/family_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'widgets/shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/timeline',
            builder: (context, state) => const TimelineScreen(),
          ),
          GoRoute(
            path: '/charts',
            builder: (context, state) => const ChartsScreen(),
          ),
          GoRoute(
            path: '/family',
            builder: (context, state) => const FamilyScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/log/:type',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final type = state.pathParameters['type']!;
          final activityId = state.uri.queryParameters['id'];
          return LogEntryScreen(activityType: type, activityId: activityId);
        },
      ),
    ],
  );
});

class FilhoApp extends ConsumerWidget {
  const FilhoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Filho',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routerConfig: router,
    );
  }
}
