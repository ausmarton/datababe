import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  // ---------------------------------------------------------------------------
  // Multi-user — parent role
  // ---------------------------------------------------------------------------

  group('Multi-user — parent role', () {
    testWidgets('parent sees both carer cards (Test User + Partner)',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
    });

    testWidgets('parent sees PopupMenuButton on Partner card', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Parent (test-uid-123) is also the creator of familyA, so only
      // Partner's card gets a PopupMenuButton (not self, not creator).
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('parent sees role chips (parent + carer)', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(Chip, 'parent'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'carer'), findsOneWidget);
    });

    testWidgets('parent sees invite button in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });

    testWidgets('parent sees FAB to add child', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-user — carer role
  // ---------------------------------------------------------------------------

  group('Multi-user — carer role', () {
    // Use seedMultiCarer but build app with userId: 'user-b-uid' (Partner),
    // who has 'carer' role. This means the current user is NOT a parent and
    // should not see management controls on any member card.

    testWidgets('carer sees both member cards', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp(userId: 'user-b-uid'));

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
    });

    testWidgets('carer does NOT see PopupMenuButton on any card',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp(userId: 'user-b-uid'));

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Carer role cannot manage any member — no PopupMenuButton at all.
      expect(find.byType(PopupMenuButton<String>), findsNothing);
    });

    testWidgets('carer still sees Children section', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp(userId: 'user-b-uid'));

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Baby'), findsOneWidget);
    });

    testWidgets('carer sees invite button in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp(userId: 'user-b-uid'));

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // The invite button is always shown in the AppBar regardless of role.
      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-family — data isolation
  // ---------------------------------------------------------------------------

  group('Multi-family — data isolation', () {
    testWidgets('home screen shows child from family A', (tester) async {
      await tester.runAsync(() => harness.seedMultiFamily());
      await pumpApp(tester, harness.buildApp());

      // Auto-selection picks family A (first), child 'Baby' appears in AppBar.
      expect(find.text('Baby'), findsWidgets);
    });

    testWidgets('family screen shows family A members', (tester) async {
      await tester.runAsync(() => harness.seedMultiFamily());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Members'), findsOneWidget);
      // Family A's carer (Test User) is displayed.
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('ingredients from family A are visible (5 ingredients)',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiFamily());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Ingredients'));
      await tester.pumpAndSettle();

      // 5 ingredients seeded in family A.
      expect(find.text('Ingredients (5)'), findsOneWidget);
    });

    testWidgets('activities from family A are visible on home screen',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiFamily());
      await pumpApp(tester, harness.buildApp());

      // Today's activities from family A include a bottle feed with 120ml.
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.textContaining('120ml'),
        200,
        scrollable: scrollable,
      );
      expect(find.textContaining('120ml'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-family — family structure
  // ---------------------------------------------------------------------------

  group('Multi-family — family structure', () {
    testWidgets('family screen shows family A as active family context',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiFamily());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Family A is auto-selected (first family). Verify its carer (parent
      // role) is displayed, confirming family A is the active context.
      expect(find.text('Test User'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'parent'), findsOneWidget);

      // Child from family A is shown in the Children section.
      expect(find.text('Baby'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
