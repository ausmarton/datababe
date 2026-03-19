import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/sync/sync_engine_interface.dart';
import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  // -----------------------------------------------------------------------
  // Helper: find the sync dot by color
  // -----------------------------------------------------------------------
  Finder syncDot(Color color) => find.byWidgetPredicate((widget) =>
      widget is Container &&
      widget.decoration is BoxDecoration &&
      (widget.decoration as BoxDecoration).shape == BoxShape.circle &&
      (widget.decoration as BoxDecoration).color == color);

  group('Sync status indicators', () {
    testWidgets('idle shows green sync dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.idle));

      expect(syncDot(Colors.green), findsOneWidget);
    });

    testWidgets('syncing shows amber sync dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.syncing));

      expect(syncDot(Colors.amber), findsOneWidget);
    });

    testWidgets('error shows red sync dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.error));

      expect(syncDot(Colors.red), findsOneWidget);
    });

    testWidgets('offline shows grey sync dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.offline));

      expect(syncDot(Colors.grey), findsOneWidget);
    });

    testWidgets('status transitions: idle -> syncing -> idle updates dot color',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.idle));

      // Starts green (idle)
      expect(syncDot(Colors.green), findsOneWidget);

      // Transition to syncing — multiple pumps to flush stream delivery
      harness.setSyncStatus(SyncStatus.syncing);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(syncDot(Colors.amber), findsOneWidget);
      expect(syncDot(Colors.green), findsNothing);

      // Transition back to idle
      harness.setSyncStatus(SyncStatus.idle);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(syncDot(Colors.green), findsOneWidget);
      expect(syncDot(Colors.amber), findsNothing);
    });
  });

  group('Online/offline transitions', () {
    testWidgets('starting offline shows grey dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.offline,
              initialOnline: false));

      expect(syncDot(Colors.grey), findsOneWidget);
    });

    testWidgets('going offline updates dot to grey', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.idle,
              initialOnline: true));

      // Starts green
      expect(syncDot(Colors.green), findsOneWidget);

      // Go offline — update sync status to offline
      harness.setSyncStatus(SyncStatus.offline);
      harness.setOnline(false);
      await tester.pump();

      expect(syncDot(Colors.grey), findsOneWidget);
    });

    testWidgets('going back online restores dot', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialSyncStatus: SyncStatus.offline,
              initialOnline: false));

      // Starts grey (offline)
      expect(syncDot(Colors.grey), findsOneWidget);

      // Come back online
      harness.setSyncStatus(SyncStatus.idle);
      harness.setOnline(true);
      await tester.pump();

      expect(syncDot(Colors.green), findsOneWidget);
    });
  });

  group('Sync Now button', () {
    testWidgets('tapping Sync Now calls syncEngine.syncNow()', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to Sync Now
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(harness.syncEngine.syncNowCount, 0);

      // Tap Sync Now
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      expect(harness.syncEngine.syncNowCount, 1);
    });

    testWidgets('Sync Now shows result after completion', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      harness.syncEngine.nextSyncResult = const SyncResult(pushed: 3);
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to Sync Now
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      // Tap Sync Now
      await tester.tap(find.text('Sync Now'));
      await tester.pumpAndSettle();

      // Verify the result SnackBar appears
      expect(find.text('pushed 3'), findsOneWidget);
    });
  });

  group('Settings sync info', () {
    testWidgets('sync status shows "Synced" text when idle', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.idle));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to sync section
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.textContaining('Synced'), findsOneWidget);
    });

    testWidgets('sync status shows "Syncing..." when syncing', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.syncing));

      await tester.tap(find.text('Settings'));
      // Use pump() instead of pumpAndSettle() — the syncing indicator
      // has a continuous animation that prevents pumpAndSettle from settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Scroll to sync section
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.textContaining('Syncing...'), findsOneWidget);
    });

    testWidgets('sync status shows "error" when error', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(
          tester, harness.buildApp(initialSyncStatus: SyncStatus.error));

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to sync section
      await tester.scrollUntilVisible(
        find.text('Sync Now'),
        200,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.textContaining('Sync error'), findsOneWidget);
    });
  });

  group('Initial sync', () {
    testWidgets('initial sync incomplete shows loading spinner and text',
        (tester) async {
      await pumpApp(tester, harness.buildApp(initialSyncComplete: false));

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('Syncing your data...'), findsOneWidget);
    });

    testWidgets('initial sync complete shows home screen', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(
          tester, harness.buildApp(initialSyncComplete: true));

      // Home screen shows child name when sync is complete
      expect(find.text('Baby'), findsWidgets);
      // Loading text should not be present
      expect(find.text('Syncing your data...'), findsNothing);
    });
  });

  group('Sign out', () {
    testWidgets('sign out calls signOut on auth repository', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Tap Sign Out
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Sign out completes (no confirmation dialog when online with 0 pending)
      // The _signOut method calls syncNow() as a best-effort push, then
      // clearLocalData(), then authRepository.signOut().
      expect(harness.syncEngine.syncNowCount, greaterThanOrEqualTo(1));
      expect(harness.syncEngine.clearLocalDataCalled, isTrue);
      expect(harness.authRepository.signOutCalled, isTrue);
    });
  });
}
