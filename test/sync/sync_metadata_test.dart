import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/sync/sync_metadata.dart';

void main() {
  late Database db;
  late SyncMetadata metadata;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    metadata = SyncMetadata(db);
  });

  group('getLastPull / setLastPull', () {
    test('returns null when no pull recorded', () async {
      final result = await metadata.getLastPull('fam-1', 'activities');
      expect(result, isNull);
    });

    test('returns timestamp after setLastPull', () async {
      final ts = DateTime(2026, 3, 6, 10, 30);
      await metadata.setLastPull('fam-1', 'activities', ts);

      final result = await metadata.getLastPull('fam-1', 'activities');
      expect(result, ts);
    });

    test('different family+collection combos are independent', () async {
      final ts1 = DateTime(2026, 3, 6, 10, 0);
      final ts2 = DateTime(2026, 3, 6, 12, 0);

      await metadata.setLastPull('fam-1', 'activities', ts1);
      await metadata.setLastPull('fam-1', 'ingredients', ts2);

      expect(await metadata.getLastPull('fam-1', 'activities'), ts1);
      expect(await metadata.getLastPull('fam-1', 'ingredients'), ts2);
    });

    test('different families are independent', () async {
      final ts1 = DateTime(2026, 3, 6, 10, 0);
      final ts2 = DateTime(2026, 3, 6, 12, 0);

      await metadata.setLastPull('fam-1', 'activities', ts1);
      await metadata.setLastPull('fam-2', 'activities', ts2);

      expect(await metadata.getLastPull('fam-1', 'activities'), ts1);
      expect(await metadata.getLastPull('fam-2', 'activities'), ts2);
    });

    test('setLastPull overwrites previous value', () async {
      final ts1 = DateTime(2026, 3, 6, 10, 0);
      final ts2 = DateTime(2026, 3, 6, 14, 0);

      await metadata.setLastPull('fam-1', 'activities', ts1);
      await metadata.setLastPull('fam-1', 'activities', ts2);

      expect(await metadata.getLastPull('fam-1', 'activities'), ts2);
    });
  });

  group('getLastReconcile / setLastReconcile', () {
    test('returns null when no reconcile recorded', () async {
      final result = await metadata.getLastReconcile('fam-1', 'activities');
      expect(result, isNull);
    });

    test('returns timestamp after setLastReconcile', () async {
      final ts = DateTime(2026, 3, 7, 9, 0);
      await metadata.setLastReconcile('fam-1', 'activities', ts);

      final result = await metadata.getLastReconcile('fam-1', 'activities');
      expect(result, ts);
    });

    test('different family+collection combos are independent', () async {
      final ts1 = DateTime(2026, 3, 7, 9, 0);
      final ts2 = DateTime(2026, 3, 7, 11, 0);

      await metadata.setLastReconcile('fam-1', 'activities', ts1);
      await metadata.setLastReconcile('fam-1', 'ingredients', ts2);

      expect(await metadata.getLastReconcile('fam-1', 'activities'), ts1);
      expect(await metadata.getLastReconcile('fam-1', 'ingredients'), ts2);
    });

    test('reconcile keys do not collide with pull keys', () async {
      final pullTs = DateTime(2026, 3, 7, 8, 0);
      final reconcileTs = DateTime(2026, 3, 7, 10, 0);

      await metadata.setLastPull('fam-1', 'activities', pullTs);
      await metadata.setLastReconcile('fam-1', 'activities', reconcileTs);

      expect(await metadata.getLastPull('fam-1', 'activities'), pullTs);
      expect(
          await metadata.getLastReconcile('fam-1', 'activities'), reconcileTs);
    });

    test('setLastReconcile overwrites previous value', () async {
      final ts1 = DateTime(2026, 3, 7, 9, 0);
      final ts2 = DateTime(2026, 3, 7, 15, 0);

      await metadata.setLastReconcile('fam-1', 'activities', ts1);
      await metadata.setLastReconcile('fam-1', 'activities', ts2);

      expect(await metadata.getLastReconcile('fam-1', 'activities'), ts2);
    });
  });

  group('pull failure tracking', () {
    test('getPullFailureCount returns 0 when no failures recorded', () async {
      final count =
          await metadata.getPullFailureCount('fam-1', 'activities');
      expect(count, 0);
    });

    test('incrementPullFailure increments count', () async {
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'network error');
      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 1);

      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'timeout');
      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 2);
    });

    test('resetPullFailure clears count and error', () async {
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'network error');
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'timeout');

      await metadata.resetPullFailure('fam-1', 'activities');

      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 0);
      expect(
          await metadata.getLastPullError('fam-1', 'activities'), isNull);
    });

    test('getLastPullError returns null when no failures', () async {
      final error =
          await metadata.getLastPullError('fam-1', 'activities');
      expect(error, isNull);
    });

    test('getLastPullError returns most recent error', () async {
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'network error');
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'permission denied');

      final error =
          await metadata.getLastPullError('fam-1', 'activities');
      expect(error, 'permission denied');
    });

    test('different family+collection failures are independent', () async {
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'error A');
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'error A2');
      await metadata.incrementPullFailure(
          'fam-1', 'ingredients', 'error B');

      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 2);
      expect(
          await metadata.getPullFailureCount('fam-1', 'ingredients'), 1);
      expect(
          await metadata.getPullFailureCount('fam-2', 'activities'), 0);
    });

    test('failure keys do not collide with pull or reconcile keys',
        () async {
      final pullTs = DateTime(2026, 3, 19, 10, 0);
      final reconcileTs = DateTime(2026, 3, 19, 12, 0);

      await metadata.setLastPull('fam-1', 'activities', pullTs);
      await metadata.setLastReconcile('fam-1', 'activities', reconcileTs);
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'some error');

      // All three should be independent.
      expect(await metadata.getLastPull('fam-1', 'activities'), pullTs);
      expect(await metadata.getLastReconcile('fam-1', 'activities'),
          reconcileTs);
      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 1);
      expect(
          await metadata.getLastPullError('fam-1', 'activities'),
          'some error');
    });

    test('resetPullFailure does not affect pull or reconcile data',
        () async {
      final pullTs = DateTime(2026, 3, 19, 10, 0);
      await metadata.setLastPull('fam-1', 'activities', pullTs);
      await metadata.incrementPullFailure(
          'fam-1', 'activities', 'error');

      await metadata.resetPullFailure('fam-1', 'activities');

      expect(await metadata.getLastPull('fam-1', 'activities'), pullTs);
      expect(
          await metadata.getPullFailureCount('fam-1', 'activities'), 0);
    });
  });

  group('getWorstPullFailure', () {
    test('returns null when no failures', () async {
      final result = await metadata.getWorstPullFailure();
      expect(result, isNull);
    });

    test('returns worst failure across all combos', () async {
      await metadata.incrementPullFailure('fam-1', 'activities', 'err1');
      await metadata.incrementPullFailure('fam-1', 'activities', 'err1b');
      await metadata.incrementPullFailure('fam-1', 'activities', 'err1c');
      await metadata.incrementPullFailure('fam-2', 'recipes', 'err2');

      final result = await metadata.getWorstPullFailure();
      expect(result, isNotNull);
      expect(result!.count, 3);
      expect(result.error, 'err1c');
    });

    test('returns null after all failures are reset', () async {
      await metadata.incrementPullFailure('fam-1', 'activities', 'err');
      await metadata.resetPullFailure('fam-1', 'activities');

      final result = await metadata.getWorstPullFailure();
      expect(result, isNull);
    });
  });

  group('getLastSyncTime', () {
    test('returns null when no pulls recorded', () async {
      final result = await metadata.getLastSyncTime();
      expect(result, isNull);
    });

    test('returns most recent pull across all families and collections',
        () async {
      final early = DateTime(2026, 3, 6, 8, 0);
      final middle = DateTime(2026, 3, 6, 12, 0);
      final latest = DateTime(2026, 3, 6, 16, 0);

      await metadata.setLastPull('fam-1', 'activities', early);
      await metadata.setLastPull('fam-1', 'ingredients', latest);
      await metadata.setLastPull('fam-2', 'activities', middle);

      final result = await metadata.getLastSyncTime();
      expect(result, latest);
    });

    test('returns the only recorded pull time', () async {
      final ts = DateTime(2026, 3, 6, 10, 0);
      await metadata.setLastPull('fam-1', 'activities', ts);

      final result = await metadata.getLastSyncTime();
      expect(result, ts);
    });
  });
}
