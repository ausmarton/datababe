import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/local/store_refs.dart';
import 'package:datababe/providers/settings_provider.dart';

void main() {
  group('setStartOfDayHour', () {
    late Database db;

    setUp(() async {
      db = await newDatabaseFactoryMemory().openDatabase('test.db');
    });

    tearDown(() async {
      await db.close();
    });

    test('writes and reads back hour', () async {
      await setStartOfDayHour(db, 6);
      final snap = await StoreRefs.settings.record('startOfDayHour').get(db);
      expect(snap?['value'], 6);
    });

    test('clamps to 0-23 range', () async {
      await setStartOfDayHour(db, 25);
      final snap = await StoreRefs.settings.record('startOfDayHour').get(db);
      expect(snap?['value'], 23);

      await setStartOfDayHour(db, -1);
      final snap2 = await StoreRefs.settings.record('startOfDayHour').get(db);
      expect(snap2?['value'], 0);
    });

    test('overwrites previous value', () async {
      await setStartOfDayHour(db, 3);
      await setStartOfDayHour(db, 7);
      final snap = await StoreRefs.settings.record('startOfDayHour').get(db);
      expect(snap?['value'], 7);
    });
  });
}
