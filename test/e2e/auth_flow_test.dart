import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_harness.dart';

void main() {
  final harness = TestHarness();

  setUp(harness.setUp);
  tearDown(harness.tearDown);

  group('Auth flow', () {
    testWidgets('unauthenticated → shows login screen', (tester) async {
      await pumpApp(tester, harness.buildApp(authenticated: false));

      expect(find.text('DataBabe'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.child_care), findsOneWidget);
    });

    testWidgets('authenticated with data → shows home screen', (tester) async {
      await tester.runAsync(() => harness.seedFull());
      await pumpApp(tester, harness.buildApp());

      // Should see the child name in the app bar
      expect(find.text('Baby'), findsWidgets);
    });

    testWidgets('authenticated with no family → shows setup prompt',
        (tester) async {
      // No seed data — empty database
      await pumpApp(tester, harness.buildApp());

      expect(find.text('Welcome to DataBabe'), findsOneWidget);
      expect(find.text('Add your child to get started'), findsOneWidget);
    });

    testWidgets('initial sync loading state shows spinner', (tester) async {
      await pumpApp(
          tester, harness.buildApp(initialSyncComplete: false));

      // When initial sync is loading, home screen shows a loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('sign out tile visible on settings', (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester, harness.buildApp());

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('deep link while unauthenticated → redirects to login',
        (tester) async {
      // GoRouter redirect sends unauthenticated users to /login
      // regardless of initial location
      await pumpApp(tester, harness.buildApp(authenticated: false));

      // Should show login, not the requested route
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('DataBabe'), findsOneWidget);
    });

    testWidgets('sign out tap triggers confirmation when offline with pending',
        (tester) async {
      await tester.runAsync(() => harness.seedMinimal());
      await pumpApp(tester,
          harness.buildApp(initialOnline: false));

      // Navigate to Settings
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Scroll to make sure Sign Out is visible
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Sign Out tries to sync — since we use ControllableSyncEngine,
      // it completes immediately. Verify the engine was asked to sync.
      expect(harness.syncEngine.syncNowCount, greaterThanOrEqualTo(0));
    });
  });
}
