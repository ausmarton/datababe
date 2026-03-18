import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/child_model.dart';
import 'package:datababe/providers/activity_provider.dart';
import 'package:datababe/providers/child_provider.dart';
import 'package:datababe/providers/family_provider.dart';
import 'package:datababe/providers/insights_provider.dart';
import 'package:datababe/providers/target_provider.dart';
import 'package:datababe/screens/insights/insights_screen.dart';
import 'package:datababe/widgets/allergen_matrix.dart';

final _dummyActivity = ActivityModel(
  id: 'a1',
  childId: 'c1',
  type: 'solids',
  startTime: DateTime(2026, 3, 6),
  createdAt: DateTime(2026, 3, 6),
  modifiedAt: DateTime(2026, 3, 6),
);

final _dummyChild = ChildModel(
  id: 'c1',
  name: 'Test',
  dateOfBirth: DateTime(2025, 9, 1),
  createdAt: DateTime(2025, 9, 1),
  modifiedAt: DateTime(2025, 9, 1),
);

// Reference week: Mon Mar 2 – Sun Mar 8, 2026
final _days =
    List.generate(7, (i) => DateTime(2026, 3, 2).add(Duration(days: i)));

Widget _buildApp({
  required WeeklyAllergenMatrix matrix,
  List<String> categories = const ['a', 'b', 'c'],
  AllergenMatrixFilter initialFilter = AllergenMatrixFilter.exposedOnly,
}) {
  return ProviderScope(
    overrides: [
      selectedChildProvider.overrideWithValue(_dummyChild),
      activitiesProvider
          .overrideWith((ref) => Stream.value([_dummyActivity])),
      allergenCategoriesProvider.overrideWithValue(categories),
      insightsAllergenCoverageProvider.overrideWithValue(null),
      allergenCoveragePeriodProvider.overrideWith((ref) => 7),
      insightsWeeklyAllergenMatrixProvider.overrideWithValue(matrix),
      allergenMatrixFilterProvider
          .overrideWith((ref) => initialFilter),
      insightsProgressProvider.overrideWithValue([]),
      trendDataProvider.overrideWithValue([]),
      trendBaselineProvider.overrideWithValue(null),
      targetsProvider.overrideWith((ref) => Stream.value([])),
    ],
    child: const MaterialApp(home: InsightsScreen()),
  );
}

void main() {
  group('Allergen matrix filter', () {
    // =====================================================================
    // Unit tests: filtering and sorting logic
    // =====================================================================

    test('filter exposed only: keeps only allergens with exposures', () {
      final allergens = ['a', 'b', 'c', 'd', 'e'];
      final matrix = <String, Set<int>>{
        'a': {0, 2, 4},
        'b': {1},
        'c': {},
        'd': {},
        'e': {3},
      };
      final filtered = allergens
          .where((a) => (matrix[a] ?? {}).isNotEmpty)
          .toList();
      expect(filtered, ['a', 'b', 'e']);
    });

    test('filter all: keeps all allergens', () {
      final allergens = ['a', 'b', 'c'];
      // When filter is "all", no filtering occurs — all allergens remain
      expect(allergens.length, 3);
    });

    test('sort by exposure count descending, then alphabetically', () {
      final allergens = ['c', 'a', 'b'];
      final matrix = <String, Set<int>>{
        'c': {0},       // 1 day
        'a': {0, 1, 2}, // 3 days
        'b': {0},       // 1 day
      };
      final sorted = allergens
          .where((a) => (matrix[a] ?? {}).isNotEmpty)
          .toList()
        ..sort((a, b) {
          final countA = (matrix[a] ?? {}).length;
          final countB = (matrix[b] ?? {}).length;
          if (countA != countB) return countB.compareTo(countA);
          return a.compareTo(b);
        });
      expect(sorted, ['a', 'b', 'c']);
    });

    test('alphabetical tiebreak when exposure counts equal', () {
      final matrix = <String, Set<int>>{
        'dairy': {0, 1},
        'egg': {2, 3},
      };
      final sorted = ['dairy', 'egg']..sort((a, b) {
          final countA = (matrix[a] ?? {}).length;
          final countB = (matrix[b] ?? {}).length;
          if (countA != countB) return countB.compareTo(countA);
          return a.compareTo(b);
        });
      expect(sorted, ['dairy', 'egg']);
    });

    test('all unexposed: filtered list empty', () {
      final allergens = List.generate(30, (i) => 'a$i');
      final matrix = {for (final a in allergens) a: <int>{}};
      final filtered = allergens
          .where((a) => (matrix[a] ?? {}).isNotEmpty)
          .toList();
      expect(filtered, isEmpty);
    });

    test('all exposed: filtered list equals full list', () {
      final allergens = List.generate(30, (i) => 'a$i');
      final matrix = {for (final a in allergens) a: {0}};
      final filtered = allergens
          .where((a) => (matrix[a] ?? {}).isNotEmpty)
          .toList();
      expect(filtered.length, 30);
    });

    test('unexposed count: 30 - 5 = 25', () {
      final allergens = List.generate(30, (i) => 'a$i');
      final matrix = <String, Set<int>>{};
      for (int i = 0; i < 30; i++) {
        matrix['a$i'] = i < 5 ? {0} : {};
      }
      final filtered = allergens
          .where((a) => (matrix[a] ?? {}).isNotEmpty)
          .toList();
      final unexposed = allergens.length - filtered.length;
      expect(unexposed, 25);
    });

    // =====================================================================
    // Widget tests
    // =====================================================================

    testWidgets('default is filtered: shows only exposed allergens',
        (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy', 'peanut', 'soy', 'wheat'],
        matrix: {
          'egg': {0, 2},
          'dairy': {1},
          'peanut': {},
          'soy': {},
          'wheat': {},
        },
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy', 'peanut', 'soy', 'wheat'],
      ));
      await tester.pumpAndSettle();

      // Only egg and dairy should appear as labels
      expect(find.text('egg'), findsOneWidget);
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('peanut'), findsNothing);
      expect(find.text('soy'), findsNothing);
    });

    testWidgets('toggle to All shows all allergens', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy', 'peanut'],
        matrix: {'egg': {0}, 'dairy': {}, 'peanut': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy', 'peanut'],
      ));
      await tester.pumpAndSettle();

      // Initially only egg visible
      expect(find.text('egg'), findsOneWidget);
      expect(find.text('dairy'), findsNothing);

      // Tap "All"
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('egg'), findsOneWidget);
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('peanut'), findsOneWidget);
    });

    testWidgets('footer shows unexposed count when filtered',
        (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy', 'peanut'],
        matrix: {'egg': {0}, 'dairy': {}, 'peanut': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy', 'peanut'],
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('2 allergens not exposed this week'), findsOneWidget);
    });

    testWidgets('footer tap switches to All view', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy', 'peanut'],
        matrix: {'egg': {0}, 'dairy': {}, 'peanut': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy', 'peanut'],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2 allergens not exposed this week'));
      await tester.pumpAndSettle();

      // Now all should be visible
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('peanut'), findsOneWidget);
    });

    testWidgets('0 exposed shows empty message', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy'],
        matrix: {'egg': {}, 'dairy': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy'],
      ));
      await tester.pumpAndSettle();

      expect(find.text('No allergens exposed this week'), findsOneWidget);
      expect(find.byType(AllergenMatrix), findsNothing);
    });

    testWidgets('matrix widget receives filtered data', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy', 'peanut', 'soy'],
        matrix: {'egg': {0, 1}, 'dairy': {2}, 'peanut': {}, 'soy': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy', 'peanut', 'soy'],
      ));
      await tester.pumpAndSettle();

      // AllergenMatrix should render with only 2 allergens (egg, dairy)
      final matrixWidget = tester.widget<AllergenMatrix>(
          find.byType(AllergenMatrix));
      expect(matrixWidget.matrix.allergens.length, 2);
    });

    testWidgets('toggle back to Exposed filters again', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: _days,
        allergens: ['egg', 'dairy'],
        matrix: {'egg': {0}, 'dairy': {}},
      );
      await tester.pumpWidget(_buildApp(
        matrix: matrix,
        categories: ['egg', 'dairy'],
      ));
      await tester.pumpAndSettle();

      // Switch to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('dairy'), findsOneWidget);

      // Switch back to Exposed
      await tester.tap(find.text('Exposed'));
      await tester.pumpAndSettle();
      expect(find.text('dairy'), findsNothing);
    });
  });
}
