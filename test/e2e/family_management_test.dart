import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('Family screen — Members section', () {
    testWidgets('shows both carer cards with multi-carer seed',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Partner'), findsOneWidget);
    });

    testWidgets('displays parent and carer role chips', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Role chips show the role text inside Chip widgets
      final parentChip = find.widgetWithText(Chip, 'parent');
      final carerChip = find.widgetWithText(Chip, 'carer');
      expect(parentChip, findsOneWidget);
      expect(carerChip, findsOneWidget);
    });

    testWidgets('parent sees PopupMenuButton on other carer but not on self',
        (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Only one PopupMenuButton should exist (on Partner's card, not on
      // the current user's card).
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('carer cards show first-letter CircleAvatars', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Test User → "T", Partner → "P"
      expect(find.widgetWithText(CircleAvatar, 'T'), findsOneWidget);
      expect(find.widgetWithText(CircleAvatar, 'P'), findsOneWidget);
    });
  });

  group('Family screen — Children section', () {
    testWidgets('shows child card with name and DOB', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Baby'), findsOneWidget);
      // DOB: 1/9/2025 (day/month/year format from the source)
      expect(find.text('Born: 1/9/2025'), findsOneWidget);
    });

    testWidgets('selected child shows check_circle icon', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // The selected child has a green check_circle icon
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('Family screen — Section headers', () {
    testWidgets('Members and Children headers visible', (tester) async {
      await tester.runAsync(() => harness.seedMultiCarer());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
    });
  });

  group('Family screen — FAB and AppBar actions', () {
    testWidgets('FAB with person_add icon is visible', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('invite carer button visible in AppBar', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
    });
  });

  group('Family screen — Add child dialog', () {
    testWidgets('tapping FAB opens Add Child dialog with Name field',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Tap the FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('Add Child'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Date of birth'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });

  group('Family screen — Invite carer dialog', () {
    testWidgets('tapping invite button opens Invite Carer dialog',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      await tester.tap(find.text('Family'));
      await tester.pumpAndSettle();

      // Tap the invite icon in the AppBar
      await tester.tap(find.byIcon(Icons.person_add_alt_1));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('Invite Carer'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Send Invite'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
