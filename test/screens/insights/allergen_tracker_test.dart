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

// Minimal activity so InsightsScreen shows its body (not "Start logging...")
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

/// Build InsightsScreen with provider overrides for the allergen tracker.
Widget _buildApp({
  required AllergenCoverage? coverage,
  List<String> categories = const ['egg', 'dairy', 'peanut'],
  int period = 7,
}) {
  return ProviderScope(
    overrides: [
      selectedChildProvider.overrideWithValue(_dummyChild),
      activitiesProvider.overrideWith(
          (ref) => Stream.value([_dummyActivity])),
      allergenCategoriesProvider.overrideWithValue(categories),
      allergenCoverageProvider.overrideWithValue(coverage),
      allergenCoveragePeriodProvider.overrideWith((ref) => period),
      // Providers consumed by other sections — provide safe defaults
      todayProgressProvider.overrideWithValue([]),
      weeklyAllergenMatrixProvider.overrideWithValue(null),
      trendDataProvider.overrideWithValue([]),
      trendBaselineProvider.overrideWithValue(null),
      targetsProvider
          .overrideWith((ref) => Stream.value([])),
    ],
    child: const MaterialApp(home: InsightsScreen()),
  );
}

void main() {
  group('Allergen tracker section', () {
    testWidgets('shows summary progress bar with correct text',
        (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg', 'dairy'},
        missing: {'peanut'},
        exposureCounts: {'egg': 3, 'dairy': 2},
        lastExposed: {},
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      expect(find.text('2/3 covered'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows attention items for overdue/due allergens',
        (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg'},
        missing: {'dairy', 'peanut'},
        exposureCounts: {'egg': 3},
        lastExposed: {},
        urgencyInfo: {
          'dairy': const AllergenUrgencyInfo(
            daysSinceExposure: 10,
            expectedIntervalDays: 5,
            urgency: AllergenUrgency.overdue,
          ),
          'peanut': const AllergenUrgencyInfo(
            daysSinceExposure: 5,
            expectedIntervalDays: 5,
            urgency: AllergenUrgency.due,
          ),
        },
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      expect(find.text('Needs attention (2)'), findsOneWidget);
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('peanut'), findsOneWidget);
      // Overdue icon (warning) should appear
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      // Due icon (timelapse) should appear
      expect(find.byIcon(Icons.timelapse), findsOneWidget);
    });

    testWidgets('shows "All on track" when no attention items',
        (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg'},
        missing: {'dairy'},
        exposureCounts: {'egg': 3},
        lastExposed: {},
        urgencyInfo: {
          'dairy': const AllergenUrgencyInfo(
            daysSinceExposure: 2,
            expectedIntervalDays: 7,
            urgency: AllergenUrgency.onTrack,
          ),
        },
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      expect(find.text('All on track'), findsOneWidget);
      expect(find.text('Needs attention'), findsNothing);
    });

    testWidgets('footer shows covered and missing counts', (tester) async {
      final coverage = AllergenCoverage(
        covered: Set.from(List.generate(22, (i) => 'c$i')),
        missing: Set.from(List.generate(8, (i) => 'm$i')),
        exposureCounts: {},
        lastExposed: {},
        urgencyInfo: {
          'm0': const AllergenUrgencyInfo(
            daysSinceExposure: 10,
            expectedIntervalDays: 5,
            urgency: AllergenUrgency.overdue,
          ),
          'm1': const AllergenUrgencyInfo(
            daysSinceExposure: 6,
            expectedIntervalDays: 5,
            urgency: AllergenUrgency.due,
          ),
        },
      );
      await tester.pumpWidget(_buildApp(
        coverage: coverage,
        categories: [
          ...List.generate(22, (i) => 'c$i'),
          ...List.generate(8, (i) => 'm$i'),
        ],
      ));
      await tester.pumpAndSettle();

      // 2 are attention items, so 6 more missing (non-attention)
      expect(find.text('6 more missing \u00b7 22 covered'), findsOneWidget);
    });

    testWidgets('"All" link is visible', (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg'},
        missing: {},
        exposureCounts: {'egg': 3},
        lastExposed: {},
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      expect(find.text('All \u25b8'), findsOneWidget);
    });

    testWidgets('no covered chips render (old behavior removed)',
        (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg', 'dairy', 'peanut'},
        missing: {},
        exposureCounts: {'egg': 3, 'dairy': 2, 'peanut': 1},
        lastExposed: {},
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      // Old behavior had Chip widgets with check_circle icons — should be gone
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('period toggle renders', (tester) async {
      final coverage = AllergenCoverage(
        covered: {'egg'},
        missing: {},
        exposureCounts: {'egg': 3},
        lastExposed: {},
      );
      await tester.pumpWidget(_buildApp(coverage: coverage));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<int>), findsWidgets);
      expect(find.text('7d'), findsWidgets);
      expect(find.text('14d'), findsWidgets);
    });

    testWidgets('empty categories shows setup prompt', (tester) async {
      await tester.pumpWidget(_buildApp(
        coverage: null,
        categories: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Manage Allergens'), findsOneWidget);
    });

    testWidgets('null coverage shows logging prompt', (tester) async {
      await tester.pumpWidget(_buildApp(coverage: null));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Start logging solids with ingredients to track allergen exposure.'),
        findsOneWidget,
      );
    });
  });
}
