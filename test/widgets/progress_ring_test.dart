import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/widgets/progress_ring.dart';

void main() {
  group('ProgressRing', () {
    Widget buildWidget({
      double fraction = 0.5,
      String label = 'Test',
      bool isInferred = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ProgressRing(
            fraction: fraction,
            icon: Icons.baby_changing_station,
            color: Colors.blue,
            actual: '3',
            target: '6',
            label: label,
            isInferred: isInferred,
          ),
        ),
      );
    }

    testWidgets('renders actual/target text', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.text('3 / 6'), findsOneWidget);
    });

    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(buildWidget(label: 'Feeds'));
      expect(find.text('Feeds'), findsOneWidget);
    });

    testWidgets('shows (avg) suffix when inferred', (tester) async {
      await tester.pumpWidget(buildWidget(label: 'Feeds', isInferred: true));
      expect(find.text('Feeds (avg)'), findsOneWidget);
    });

    testWidgets('does not show (avg) when explicit', (tester) async {
      await tester.pumpWidget(buildWidget(label: 'Feeds', isInferred: false));
      expect(find.text('Feeds (avg)'), findsNothing);
      expect(find.text('Feeds'), findsOneWidget);
    });

    testWidgets('renders icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byIcon(Icons.baby_changing_station), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ProgressRing(
            fraction: 0.5,
            icon: Icons.baby_changing_station,
            color: Colors.blue,
            actual: '3',
            target: '6',
            label: 'Test',
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.tap(find.byType(ProgressRing));
      expect(tapped, isTrue);
    });

    testWidgets('renders CustomPaint for ring', (tester) async {
      await tester.pumpWidget(buildWidget());
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
