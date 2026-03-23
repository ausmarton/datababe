import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  /// Scroll the main scrollable until [finder] is visible, then tap it.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Tap the copy button from edit mode and wait for the copy screen to load.
  Future<void> tapCopyAndSettle(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pumpAndSettle();
    // Allow async DB load (runs outside FakeAsync zone)
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  group('Copy activity — AppBar', () {
    testWidgets('shows copy button when editing existing activity',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await scrollAndTap(tester, find.text('formula - 120ml'));

      expect(find.text('Edit Bottle Feed'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('does NOT show copy button when creating new activity',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.widgetWithText(ActionChip, 'Medication'));
      await tester.pumpAndSettle();

      expect(find.text('Log Medication'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
    });

    testWidgets('copy navigates to form with "Copy" in title',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await scrollAndTap(tester, find.text('formula - 120ml'));
      expect(find.text('Edit Bottle Feed'), findsOneWidget);

      await tapCopyAndSettle(tester);

      expect(find.text('Copy Bottle Feed'), findsOneWidget);
      expect(find.text('Edit Bottle Feed'), findsNothing);
    });

    testWidgets('copied bottle feed form pre-fills fields', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await scrollAndTap(tester, find.text('formula - 120ml'));

      await tapCopyAndSettle(tester);

      expect(find.text('Copy Bottle Feed'), findsOneWidget);
      // Seed a1: formula, 120.0ml
      expect(find.text('Formula'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, '120.0'),
        findsOneWidget,
      );
    });

    testWidgets('copied form has end time "Not set"', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // a2: feedBreast with R:10, L:8 (duration-based)
      await scrollAndTap(tester, find.text('R: 10min, L: 8min'));
      expect(find.text('Edit Breast Feed'), findsOneWidget);

      await tapCopyAndSettle(tester);

      expect(find.text('Copy Breast Feed'), findsOneWidget);
      // endTime is cleared in copy mode, so "Not set" should appear
      expect(find.text('Not set'), findsWidgets);
    });

    testWidgets('copy does not show delete or copy buttons', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());
      await scrollAndTap(tester, find.text('formula - 120ml'));

      await tapCopyAndSettle(tester);

      expect(find.text('Copy Bottle Feed'), findsOneWidget);
      // In copy mode: isEdit is false, so neither delete nor copy should show
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.copy), findsNothing);
    });
  });

  group('Copy activity — long press', () {
    testWidgets('long-press on ActivityTile shows "Copy as new" option',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      final finder = find.text('formula - 120ml');
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.longPress(finder);
      await tester.pumpAndSettle();

      expect(find.text('Copy as new'), findsOneWidget);
    });

    testWidgets('tapping "Copy as new" navigates to copy form',
        (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      final finder = find.text('formula - 120ml');
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.longPress(finder);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy as new'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Copy Bottle Feed'), findsOneWidget);
    });
  });
}
