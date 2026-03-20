import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/providers/insights_provider.dart';
import 'package:datababe/widgets/trend_chart.dart';

void main() {
  group('TrendChart', () {
    Widget buildWidget({
      required List<TrendPoint> data,
      double? baselineValue,
      Color barColor = Colors.blue,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: TrendChart(
            data: data,
            baselineValue: baselineValue,
            barColor: barColor,
          ),
        ),
      );
    }

    testWidgets('shows "No data" when data is empty', (tester) async {
      await tester.pumpWidget(buildWidget(data: []));
      expect(find.text('No data'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
    });

    testWidgets('renders BarChart with data', (tester) async {
      await tester.pumpWidget(buildWidget(data: [
        TrendPoint(date: DateTime(2026, 3, 1), value: 100),
        TrendPoint(date: DateTime(2026, 3, 2), value: 200),
      ]));
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('No data'), findsNothing);
    });

    testWidgets('renders with single data point', (tester) async {
      await tester.pumpWidget(buildWidget(data: [
        TrendPoint(date: DateTime(2026, 3, 1), value: 50),
      ]));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders with 7 data points (week view)', (tester) async {
      final data = List.generate(
        7,
        (i) => TrendPoint(
          date: DateTime(2026, 3, 1 + i),
          value: (i + 1) * 10.0,
        ),
      );
      await tester.pumpWidget(buildWidget(data: data));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders with 30 data points (month view)', (tester) async {
      final data = List.generate(
        30,
        (i) => TrendPoint(
          date: DateTime(2026, 3, 1 + i),
          value: (i + 1) * 5.0,
        ),
      );
      await tester.pumpWidget(buildWidget(data: data));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders baseline line when provided', (tester) async {
      await tester.pumpWidget(buildWidget(
        data: [
          TrendPoint(date: DateTime(2026, 3, 1), value: 100),
          TrendPoint(date: DateTime(2026, 3, 2), value: 200),
        ],
        baselineValue: 150,
      ));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders without baseline when null', (tester) async {
      await tester.pumpWidget(buildWidget(
        data: [
          TrendPoint(date: DateTime(2026, 3, 1), value: 100),
        ],
        baselineValue: null,
      ));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('handles all-zero data without crash', (tester) async {
      final data = List.generate(
        7,
        (i) =>
            TrendPoint(date: DateTime(2026, 3, 1 + i), value: 0),
      );
      await tester.pumpWidget(buildWidget(data: data));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders with custom barColor', (tester) async {
      await tester.pumpWidget(buildWidget(
        data: [
          TrendPoint(date: DateTime(2026, 3, 1), value: 100),
        ],
        barColor: Colors.red,
      ));
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('has fixed height of 200', (tester) async {
      await tester.pumpWidget(buildWidget(data: [
        TrendPoint(date: DateTime(2026, 3, 1), value: 100),
      ]));
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 200);
    });
  });
}
