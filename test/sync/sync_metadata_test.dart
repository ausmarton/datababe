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
