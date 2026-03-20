import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:datababe/providers/sync_provider.dart';
import 'package:datababe/sync/sync_engine.dart';
import 'package:datababe/widgets/shell_scaffold.dart';

Widget _buildApp({
  String initialPath = '/',
  SyncStatus status = SyncStatus.idle,
}) {
  final router = GoRouter(
    initialLocation: initialPath,
    routes: [
      ShellRoute(
        builder: (_, __, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Center(child: Text('Home Page')),
          ),
          GoRoute(
            path: '/timeline',
            builder: (_, __) => const Center(child: Text('Timeline Page')),
          ),
          GoRoute(
            path: '/insights',
            builder: (_, __) => const Center(child: Text('Insights Page')),
          ),
          GoRoute(
            path: '/family',
            builder: (_, __) => const Center(child: Text('Family Page')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const Center(child: Text('Settings Page')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      syncStatusProvider.overrideWith((_) => Stream.value(status)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('ShellScaffold', () {
    testWidgets('shows 5 navigation destinations', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows NavigationBar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Home tab shows home content', (tester) async {
      await tester.pumpWidget(_buildApp(initialPath: '/'));
      await tester.pumpAndSettle();

      expect(find.text('Home Page'), findsOneWidget);
    });

    testWidgets('tapping Timeline navigates to timeline', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      expect(find.text('Timeline Page'), findsOneWidget);
    });

    testWidgets('tapping Insights navigates to insights', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.text('Insights Page'), findsOneWidget);
    });

    testWidgets('tapping Family navigates to family', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Family Page'), findsOneWidget);
    });

    testWidgets('tapping Settings navigates to settings', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Page'), findsOneWidget);
    });

    testWidgets('sync dot is rendered', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Sync dot is a Container with BoxDecoration circle
      final dots = tester.widgetList<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 10),
      );
      expect(dots.length, 1);
    });

    testWidgets('sync dot shows green for idle', (tester) async {
      await tester.pumpWidget(_buildApp(status: SyncStatus.idle));
      await tester.pumpAndSettle();

      final dot = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            w.constraints?.maxWidth == 10),
      );
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, Colors.green);
    });
  });
}
