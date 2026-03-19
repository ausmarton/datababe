import 'package:datababe/widgets/data_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('DataErrorWidget', () {
    testWidgets('shows error icon and friendly message', (tester) async {
      await tester.pumpWidget(wrap(
        DataErrorWidget(error: Exception('test')),
      ));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(
        find.text('Please try again. If the problem persists, restart the app.'),
        findsOneWidget,
      );
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      bool retried = false;
      await tester.pumpWidget(wrap(
        DataErrorWidget(
          error: Exception('test'),
          onRetry: () => retried = true,
        ),
      ));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(wrap(
        DataErrorWidget(error: Exception('test')),
      ));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('database error shows specific message', (tester) async {
      await tester.pumpWidget(wrap(
        DataErrorWidget(error: Exception('DatabaseException: corrupt')),
      ));

      expect(
        find.text(
            'Could not read local data. Try closing and reopening the app.'),
        findsOneWidget,
      );
    });

    testWidgets('sembast error shows specific message', (tester) async {
      await tester.pumpWidget(wrap(
        DataErrorWidget(error: Exception('sembast store read failed')),
      ));

      expect(
        find.text(
            'Could not read local data. Try closing and reopening the app.'),
        findsOneWidget,
      );
    });

    testWidgets('permission error shows specific message', (tester) async {
      await tester.pumpWidget(wrap(
        DataErrorWidget(error: Exception('Permission denied')),
      ));

      expect(
        find.text('Permission denied. Check your account access.'),
        findsOneWidget,
      );
    });
  });
}
