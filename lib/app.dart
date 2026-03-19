import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/timeline/timeline_screen.dart';
import 'screens/log_entry/log_entry_screen.dart';
import 'screens/insights/insights_screen.dart';
import 'screens/family/family_screen.dart';
import 'screens/goals/goals_screen.dart';
import 'screens/goals/add_target_screen.dart';
import 'screens/goals/bulk_allergen_targets_screen.dart';
import 'screens/recipes/recipe_list_screen.dart';
import 'screens/recipes/add_recipe_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/manage_allergens_screen.dart';
import 'screens/insights/allergen_detail_screen.dart';
import 'screens/insights/growth_detail_screen.dart';
import 'screens/insights/metric_detail_screen.dart';
import 'screens/ingredients/ingredient_list_screen.dart';
import 'screens/ingredients/add_ingredient_screen.dart';
import 'screens/bulk_add/bulk_add_screen.dart';
import 'screens/import/import_preview_screen.dart';
import 'import/import_preview.dart';
import 'widgets/shell_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(currentUserProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = user != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
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
          final copyFromId = state.uri.queryParameters['copyFrom'];
          return LogEntryScreen(
            activityType: type,
            activityId: activityId,
            copyFromId: copyFromId,
          );
        },
      ),
      GoRoute(
        path: '/bulk-add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BulkAddScreen(),
      ),
      GoRoute(
        path: '/goals',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GoalsScreen(),
      ),
      GoRoute(
        path: '/goals/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AddTargetScreen(
          targetId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: '/goals/bulk-allergens',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const BulkAllergenTargetsScreen(),
      ),
      GoRoute(
        path: '/insights/metric/:key',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final key = state.pathParameters['key']!;
          return MetricDetailScreen(metricKey: key);
        },
      ),
      GoRoute(
        path: '/insights/growth',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GrowthDetailScreen(),
      ),
      GoRoute(
        path: '/insights/allergens',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AllergenDetailScreen(),
      ),
      GoRoute(
        path: '/settings/allergens',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ManageAllergensScreen(),
      ),
      GoRoute(
        path: '/ingredients',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const IngredientListScreen(),
      ),
      GoRoute(
        path: '/ingredients/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final ingredientId = state.uri.queryParameters['id'];
          return AddIngredientScreen(ingredientId: ingredientId);
        },
      ),
      GoRoute(
        path: '/recipes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecipeListScreen(),
      ),
      GoRoute(
        path: '/recipes/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final recipeId = state.uri.queryParameters['id'];
          return AddRecipeScreen(recipeId: recipeId);
        },
      ),
      GoRoute(
        path: '/import/preview',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final preview = state.extra as ImportPreview;
          return ImportPreviewScreen(preview: preview);
        },
      ),
    ],
  );
});

class DataBabeApp extends ConsumerWidget {
  const DataBabeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DataBabe',
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
