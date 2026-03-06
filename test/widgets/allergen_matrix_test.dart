import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/providers/insights_provider.dart';
import 'package:datababe/widgets/allergen_matrix.dart';

void main() {
  group('AllergenMatrix widget', () {
    // Reference week: Mon Mar 2 – Sun Mar 8, 2026
    final days = List.generate(
        7, (i) => DateTime(2026, 3, 2).add(Duration(days: i)));

    Widget buildWidget({
      required WeeklyAllergenMatrix matrix,
      void Function(int, String)? onDotTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AllergenMatrix(
            matrix: matrix,
            onDotTap: onDotTap,
          ),
        ),
      );
    }

    testWidgets('renders day headers', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: days,
        allergens: ['dairy'],
        matrix: {'dairy': {}},
      );
      await tester.pumpWidget(buildWidget(matrix: matrix));
      // Day headers are single letters: M T W T F S S
      expect(find.text('M'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('renders allergen labels', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: days,
        allergens: ['dairy', 'egg'],
        matrix: {'dairy': {}, 'egg': {}},
      );
      await tester.pumpWidget(buildWidget(matrix: matrix));
      expect(find.text('dairy'), findsOneWidget);
      expect(find.text('egg'), findsOneWidget);
    });

    testWidgets('renders correct number of dot containers', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: days,
        allergens: ['dairy', 'egg'],
        matrix: {'dairy': {0, 2}, 'egg': {1}},
      );
      await tester.pumpWidget(buildWidget(matrix: matrix));
      // 2 allergens × 7 days = 14 dot containers
      // Each dot is a Container with BoxDecoration circle
      final containers = tester.widgetList<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );
      expect(containers.length, 14);
    });

    testWidgets('dot tap callback fires for exposed dots', (tester) async {
      int? tappedDay;
      String? tappedAllergen;
      final matrix = WeeklyAllergenMatrix(
        days: days,
        allergens: ['dairy'],
        matrix: {'dairy': {0}}, // Monday exposed
      );
      await tester.pumpWidget(buildWidget(
        matrix: matrix,
        onDotTap: (day, allergen) {
          tappedDay = day;
          tappedAllergen = allergen;
        },
      ));
      // Find the GestureDetector wrapping the first dot (Monday, dairy)
      final gestureDetectors = find.byType(GestureDetector);
      // Tap the first GestureDetector in the allergen row area
      // The row structure: allergen label + 7 GestureDetectors
      // We look for the one that fires the callback
      for (final gd in gestureDetectors.evaluate()) {
        final widget = gd.widget as GestureDetector;
        if (widget.onTap != null) {
          widget.onTap!();
          break;
        }
      }
      expect(tappedDay, 0);
      expect(tappedAllergen, 'dairy');
    });

    testWidgets('renders empty when no allergens', (tester) async {
      final matrix = WeeklyAllergenMatrix(
        days: days,
        allergens: [],
        matrix: {},
      );
      await tester.pumpWidget(buildWidget(matrix: matrix));
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
