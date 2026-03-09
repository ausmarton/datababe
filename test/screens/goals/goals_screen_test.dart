import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/target_model.dart';
import 'package:datababe/providers/child_provider.dart';
import 'package:datababe/providers/target_provider.dart';
import 'package:datababe/screens/goals/goals_screen.dart';
import 'package:datababe/widgets/summary_card.dart';

TargetModel _target({
  required String id,
  required String metric,
  String activityType = 'solids',
  String period = 'weekly',
  double targetValue = 3.0,
  String? allergenName,
  String? ingredientName,
}) {
  final now = DateTime(2026, 3, 6);
  return TargetModel(
    id: id,
    childId: 'c1',
    activityType: activityType,
    metric: metric,
    period: period,
    targetValue: targetValue,
    createdBy: 'u1',
    createdAt: now,
    modifiedAt: now,
    allergenName: allergenName,
    ingredientName: ingredientName,
  );
}

Widget _buildApp({
  required List<TargetModel> targets,
  List<TargetProgress> progress = const [],
}) {
  return ProviderScope(
    overrides: [
      targetsProvider.overrideWith((ref) => Stream.value(targets)),
      targetProgressProvider.overrideWithValue(progress),
      selectedFamilyIdProvider.overrideWith((ref) => 'fam1'),
    ],
    child: MaterialApp(
      home: const GoalsScreen(),
      routes: {
        '/goals/add': (_) => const Scaffold(body: Text('add')),
        '/goals/bulk-allergens': (_) =>
            const Scaffold(body: Text('bulk')),
      },
    ),
  );
}

void main() {
  group('GoalsScreen grouping', () {
    // =====================================================================
    // Unit-style: partitioning and counting logic
    // =====================================================================

    test('partitions allergen vs other targets correctly', () {
      final targets = [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
        _target(id: '2', metric: 'allergenExposureDays', allergenName: 'dairy'),
        _target(id: '3', metric: 'count', activityType: 'diaper'),
        _target(id: '4', metric: 'totalVolumeMl', activityType: 'feedBottle'),
      ];
      final allergen = targets.where((t) =>
          t.metric == 'allergenExposures' ||
          t.metric == 'allergenExposureDays');
      final other = targets.where((t) =>
          t.metric != 'allergenExposures' &&
          t.metric != 'allergenExposureDays');
      expect(allergen.length, 2);
      expect(other.length, 2);
    });

    test('groups allergen targets by period', () {
      final targets = [
        _target(id: '1', metric: 'allergenExposures', period: 'weekly', allergenName: 'egg'),
        _target(id: '2', metric: 'allergenExposures', period: 'daily', allergenName: 'dairy'),
        _target(id: '3', metric: 'allergenExposures', period: 'weekly', allergenName: 'peanut'),
      ];
      final byPeriod = <String, List<TargetModel>>{};
      for (final t in targets.where((t) => t.metric == 'allergenExposures')) {
        byPeriod.putIfAbsent(t.period, () => []).add(t);
      }
      expect(byPeriod.keys, containsAll(['weekly', 'daily']));
      expect(byPeriod['weekly']!.length, 2);
      expect(byPeriod['daily']!.length, 1);
    });

    test('on-track count: 22 met out of 30', () {
      final targets = List.generate(
          30, (i) => _target(id: 'a$i', metric: 'allergenExposures', allergenName: 'a$i'));
      final progress = [
        for (int i = 0; i < 22; i++)
          TargetProgress(target: targets[i], actual: 3, fraction: 1.0),
        for (int i = 22; i < 30; i++)
          TargetProgress(target: targets[i], actual: 1, fraction: 0.33),
      ];
      int onTrack = 0;
      for (final t in targets) {
        final tp = progress.where((p) => p.target.id == t.id).firstOrNull;
        if (tp != null && tp.fraction >= 1.0) onTrack++;
      }
      expect(onTrack, 22);
    });

    test('all on track: 30/30', () {
      final targets = List.generate(
          30, (i) => _target(id: 'a$i', metric: 'allergenExposures', allergenName: 'a$i'));
      final progress = [
        for (final t in targets)
          TargetProgress(target: t, actual: 3, fraction: 1.0),
      ];
      int onTrack = 0;
      for (final t in targets) {
        final tp = progress.where((p) => p.target.id == t.id).firstOrNull;
        if (tp != null && tp.fraction >= 1.0) onTrack++;
      }
      expect(onTrack, 30);
    });

    test('none on track: 0/30', () {
      final targets = List.generate(
          30, (i) => _target(id: 'a$i', metric: 'allergenExposures', allergenName: 'a$i'));
      final progress = [
        for (final t in targets)
          TargetProgress(target: t, actual: 0, fraction: 0.0),
      ];
      int onTrack = 0;
      for (final t in targets) {
        final tp = progress.where((p) => p.target.id == t.id).firstOrNull;
        if (tp != null && tp.fraction >= 1.0) onTrack++;
      }
      expect(onTrack, 0);
    });

    test('mixed metrics grouped under allergen section', () {
      final targets = [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
        _target(id: '2', metric: 'allergenExposureDays', allergenName: 'dairy'),
      ];
      final allergen = targets.where((t) =>
          t.metric == 'allergenExposures' ||
          t.metric == 'allergenExposureDays');
      expect(allergen.length, 2);
    });

    // =====================================================================
    // Widget tests
    // =====================================================================

    testWidgets('shows section headers for allergen and other goals',
        (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
        _target(id: '2', metric: 'count', activityType: 'diaper'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Allergen Goals (weekly)'), findsOneWidget);
      expect(find.text('Other Goals'), findsOneWidget);
    });

    testWidgets('shows aggregate progress bar and summary text',
        (tester) async {
      final targets = [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
        _target(id: '2', metric: 'allergenExposures', allergenName: 'dairy'),
      ];
      await tester.pumpWidget(_buildApp(
        targets: targets,
        progress: [
          TargetProgress(target: targets[0], actual: 3, fraction: 1.0),
          TargetProgress(target: targets[1], actual: 1, fraction: 0.33),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1/2 on track'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('expand/collapse allergen goals', (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
        _target(id: '2', metric: 'allergenExposures', allergenName: 'dairy'),
      ]));
      await tester.pumpAndSettle();

      // Initially collapsed — allergen names not visible
      expect(find.text('egg'), findsNothing);
      expect(find.text('Show all'), findsOneWidget);

      // Expand
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      expect(find.text('egg'), findsOneWidget);
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('egg'), findsNothing);
    });

    testWidgets('other goals render as cards', (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'count', activityType: 'diaper'),
      ]));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsWidgets);
      expect(find.text('Count: 0 / 3'), findsOneWidget);
    });

    testWidgets('no allergen targets: no allergen section header',
        (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'count', activityType: 'diaper'),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Allergen Goals'), findsNothing);
    });

    testWidgets('no other targets: no "Other Goals" header',
        (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Other Goals'), findsNothing);
    });

    testWidgets('empty state shows message', (tester) async {
      await tester.pumpWidget(_buildApp(targets: []));
      await tester.pumpAndSettle();

      expect(find.text('No goals set yet.\nTap + to add one.'), findsOneWidget);
    });

    testWidgets('delete icon in expanded list triggers dialog',
        (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
      ]));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      // Tap delete (the small 16px one in the expanded row)
      final deleteIcons = find.byIcon(Icons.delete_outline);
      expect(deleteIcons, findsWidgets);
      await tester.tap(deleteIcons.first);
      await tester.pumpAndSettle();

      expect(find.text('Delete goal?'), findsOneWidget);
    });

    testWidgets('Edit button is visible', (tester) async {
      await tester.pumpWidget(_buildApp(targets: [
        _target(id: '1', metric: 'allergenExposures', allergenName: 'egg'),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
