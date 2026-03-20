import 'dart:convert';

import 'package:flutter_test/flutter_test.dart' hide Finder;
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/backup/backup_service.dart';
import 'package:datababe/local/store_refs.dart';
import 'package:datababe/sync/sync_queue.dart';

void main() {
  late Database db;
  late BackupService service;
  const familyId = 'fam-1';
  final now = DateTime(2026, 3, 6, 10, 0);
  final later = DateTime(2026, 3, 6, 12, 0);

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('test.db');
    service = BackupService(db);
  });

  Map<String, dynamic> makeFamily() => {
        'name': 'Test Family',
        'createdBy': 'uid-1',
        'memberUids': ['uid-1'],
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
        'allergenCategories': <String>[],
      };

  Map<String, dynamic> makeChild(String name, {DateTime? modifiedAt}) => {
        'familyId': familyId,
        'name': name,
        'dateOfBirth': '2025-06-15T00:00:00.000',
        'notes': '',
        'createdAt': now.toIso8601String(),
        'modifiedAt': (modifiedAt ?? now).toIso8601String(),
        'isDeleted': false,
      };

  Map<String, dynamic> makeActivity(String id, {DateTime? modifiedAt}) => {
        'familyId': familyId,
        'childId': 'child-1',
        'type': 'feedBottle',
        'startTime': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'modifiedAt': (modifiedAt ?? now).toIso8601String(),
        'isDeleted': false,
        'volumeMl': 120.0,
      };

  group('export', () {
    test('empty family produces valid JSON with empty stores', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());

      final json = await service.exportFamily(familyId);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['version'], BackupService.currentVersion);
      expect(data['familyId'], familyId);
      expect(data['stores'], isA<Map>());

      final stores = data['stores'] as Map<String, dynamic>;
      expect(stores['families'], isA<Map>());
      expect((stores['families'] as Map).containsKey(familyId), isTrue);
      expect(stores['activities'], isA<Map>());
      expect((stores['activities'] as Map), isEmpty);
    });

    test('includes all records with correct IDs', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('Baby'));
      await StoreRefs.activities
          .record('act-1')
          .put(db, makeActivity('act-1'));

      final json = await service.exportFamily(familyId);
      final data = jsonDecode(json) as Map<String, dynamic>;
      final stores = data['stores'] as Map<String, dynamic>;

      expect((stores['children'] as Map).containsKey('child-1'), isTrue);
      expect((stores['activities'] as Map).containsKey('act-1'), isTrue);
    });

    test('filters by familyId', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('Baby'));

      // Different family's child.
      final otherChild = Map<String, dynamic>.from(makeChild('Other'));
      otherChild['familyId'] = 'fam-other';
      await StoreRefs.children.record('child-other').put(db, otherChild);

      final json = await service.exportFamily(familyId);
      final data = jsonDecode(json) as Map<String, dynamic>;
      final children =
          (data['stores'] as Map)['children'] as Map<String, dynamic>;

      expect(children.containsKey('child-1'), isTrue);
      expect(children.containsKey('child-other'), isFalse);
    });

    test('includes soft-deleted records', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());
      final deleted = makeChild('Deleted');
      deleted['isDeleted'] = true;
      await StoreRefs.children.record('child-del').put(db, deleted);

      final json = await service.exportFamily(familyId);
      final data = jsonDecode(json) as Map<String, dynamic>;
      final children =
          (data['stores'] as Map)['children'] as Map<String, dynamic>;

      expect(children.containsKey('child-del'), isTrue);
    });
  });

  group('restore', () {
    test('into empty store inserts all records', () async {
      // Create a backup JSON with data.
      await StoreRefs.families.record(familyId).put(db, makeFamily());
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('Baby'));
      final backupJson = await service.exportFamily(familyId);

      // Clear the database.
      await StoreRefs.families.drop(db);
      await StoreRefs.children.drop(db);

      final result = await service.restoreFamily(backupJson);

      expect(result.totalInserted, 2); // family + child
      expect(result.totalUpdated, 0);
      expect(result.totalSkipped, 0);

      // Verify data is in the store.
      final family = await StoreRefs.families.record(familyId).get(db);
      expect(family, isNotNull);
      expect(family!['name'], 'Test Family');
    });

    test('newer incoming wins', () async {
      // Local has old data.
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('OldName', modifiedAt: now));

      // Build backup with newer data.
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': later.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': makeChild('NewName', modifiedAt: later),
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result =
          await service.restoreFamily(jsonEncode(backupData));

      expect(result.stores['children']!.updated, 1);

      final child = await StoreRefs.children.record('child-1').get(db);
      expect(child!['name'], 'NewName');
    });

    test('newer local wins', () async {
      // Local has newer data.
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('LocalName', modifiedAt: later));

      // Build backup with older data.
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': makeChild('OldBackupName', modifiedAt: now),
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result =
          await service.restoreFamily(jsonEncode(backupData));

      expect(result.stores['children']!.skipped, 1);

      final child = await StoreRefs.children.record('child-1').get(db);
      expect(child!['name'], 'LocalName');
    });

    test('mixed: insert + update + skip', () async {
      // Existing: child-1 (old), child-2 (new).
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('Old', modifiedAt: now));
      await StoreRefs.children
          .record('child-2')
          .put(db, makeChild('NewerLocal', modifiedAt: later));

      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': later.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': makeChild('Updated', modifiedAt: later), // update
            'child-2': makeChild('OlderBackup', modifiedAt: now), // skip
            'child-3': makeChild('Brand New', modifiedAt: now), // insert
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result =
          await service.restoreFamily(jsonEncode(backupData));

      expect(result.stores['children']!.inserted, 1);
      expect(result.stores['children']!.updated, 1);
      expect(result.stores['children']!.skipped, 1);
    });

    test('enqueues only inserted and updated records, not skipped', () async {
      // Local: child-1 is newer (will be skipped), child-2 is older (will be updated).
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('LocalNewer', modifiedAt: later));
      await StoreRefs.children
          .record('child-2')
          .put(db, makeChild('LocalOlder', modifiedAt: now));

      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': later.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': makeChild('BackupOlder', modifiedAt: now), // skip
            'child-2': makeChild('BackupNewer', modifiedAt: later), // update
            'child-3': makeChild('BrandNew', modifiedAt: now), // insert
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      await service.restoreFamily(jsonEncode(backupData));

      final queueRecords = await StoreRefs.syncQueue.find(db);
      final queuedDocIds = queueRecords
          .map((r) => r.value['documentId'] as String)
          .toSet();

      // child-2 (updated) and child-3 (inserted) should be enqueued.
      expect(queuedDocIds, contains('child-2'));
      expect(queuedDocIds, contains('child-3'));
      // child-1 (skipped) should NOT be enqueued.
      expect(queuedDocIds, isNot(contains('child-1')));
    });

    test('restore works across multiple store types', () async {
      final ingredient = {
        'familyId': familyId,
        'name': 'egg',
        'allergens': ['egg'],
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      };
      final recipe = {
        'familyId': familyId,
        'name': 'omelette',
        'ingredients': ['egg'],
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      };
      final target = {
        'familyId': familyId,
        'childId': 'child-1',
        'activityType': 'feedBottle',
        'metric': 'count',
        'period': 'daily',
        'targetValue': 6,
        'isActive': true,
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      };
      final carer = {
        'familyId': familyId,
        'uid': 'uid-1',
        'displayName': 'Parent',
        'role': 'parent',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
        'isDeleted': false,
      };

      final backupData = {
        'version': 1,
        'appVersion': '1.1.0',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {'child-1': makeChild('Baby')},
          'carers': {'carer-1': carer},
          'activities': {'act-1': makeActivity('act-1')},
          'ingredients': {'ing-1': ingredient},
          'recipes': {'rec-1': recipe},
          'targets': {'tgt-1': target},
        },
      };

      final result =
          await service.restoreFamily(jsonEncode(backupData));

      expect(result.totalInserted, 7);
      expect(result.totalSkipped, 0);

      // Verify each store.
      expect(await StoreRefs.families.record(familyId).get(db), isNotNull);
      expect(await StoreRefs.children.record('child-1').get(db), isNotNull);
      expect(await StoreRefs.carers.record('carer-1').get(db), isNotNull);
      expect(await StoreRefs.activities.record('act-1').get(db), isNotNull);
      expect(await StoreRefs.ingredients.record('ing-1').get(db), isNotNull);
      expect(await StoreRefs.recipes.record('rec-1').get(db), isNotNull);
      expect(await StoreRefs.targets.record('tgt-1').get(db), isNotNull);
    });

    test('round-trip: export then restore produces matching data across all stores', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('Baby'));
      await StoreRefs.carers.record('carer-1').put(db, {
        'familyId': familyId,
        'uid': 'uid-1',
        'displayName': 'Parent',
        'role': 'parent',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
        'isDeleted': false,
      });
      await StoreRefs.activities
          .record('act-1')
          .put(db, makeActivity('act-1'));
      await StoreRefs.ingredients.record('ing-1').put(db, {
        'familyId': familyId,
        'name': 'egg',
        'allergens': ['egg'],
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      });
      await StoreRefs.recipes.record('rec-1').put(db, {
        'familyId': familyId,
        'name': 'omelette',
        'ingredients': ['egg'],
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      });
      await StoreRefs.targets.record('tgt-1').put(db, {
        'familyId': familyId,
        'childId': 'child-1',
        'activityType': 'feedBottle',
        'metric': 'count',
        'period': 'daily',
        'targetValue': 6,
        'isActive': true,
        'isDeleted': false,
        'createdBy': 'uid-1',
        'createdAt': now.toIso8601String(),
        'modifiedAt': now.toIso8601String(),
      });

      final backupJson = await service.exportFamily(familyId);

      // Clear all stores.
      for (final store in [
        StoreRefs.families,
        StoreRefs.children,
        StoreRefs.carers,
        StoreRefs.activities,
        StoreRefs.ingredients,
        StoreRefs.recipes,
        StoreRefs.targets,
      ]) {
        await store.drop(db);
      }

      final result = await service.restoreFamily(backupJson);
      expect(result.totalInserted, 7);

      expect(
          (await StoreRefs.families.record(familyId).get(db))!['name'],
          'Test Family');
      expect(
          (await StoreRefs.children.record('child-1').get(db))!['name'],
          'Baby');
      expect(
          (await StoreRefs.carers.record('carer-1').get(db))!['displayName'],
          'Parent');
      expect(
          (await StoreRefs.activities.record('act-1').get(db))!['type'],
          'feedBottle');
      expect(
          (await StoreRefs.ingredients.record('ing-1').get(db))!['name'],
          'egg');
      expect(
          (await StoreRefs.recipes.record('rec-1').get(db))!['name'],
          'omelette');
      expect(
          (await StoreRefs.targets.record('tgt-1').get(db))!['metric'],
          'count');
    });

    test('export includes appVersion in envelope', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());

      final json = await service.exportFamily(familyId, appVersion: '1.2.0');
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['appVersion'], '1.2.0');
    });

    test('handles backup with missing store keys gracefully', () async {
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'children': {'child-1': makeChild('Baby')},
          // All other stores missing.
        },
      };

      final result =
          await service.restoreFamily(jsonEncode(backupData));

      expect(result.stores['children']!.inserted, 1);
      // Missing stores should have zero counts.
      expect(result.stores['activities']!.inserted, 0);
      expect(result.stores['families']!.inserted, 0);
    });

    test('invalid version rejected', () async {
      final badData = jsonEncode({
        'version': 999,
        'stores': {},
      });

      expect(
        () => service.restoreFamily(badData),
        throwsA(isA<FormatException>()),
      );
    });

    test('null version rejected', () async {
      final badData = jsonEncode({
        'stores': {},
      });

      expect(
        () => service.restoreFamily(badData),
        throwsA(isA<FormatException>()),
      );
    });

    test('malformed JSON rejected', () async {
      expect(
        () => service.restoreFamily('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing stores key rejected', () async {
      final badData = jsonEncode({
        'version': 1,
        'familyId': familyId,
      });

      expect(
        () => service.restoreFamily(badData),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing modifiedAt falls back to createdAt', () async {
      // Local record with createdAt only (no modifiedAt).
      await StoreRefs.children.record('child-1').put(db, {
        'familyId': familyId,
        'name': 'LocalName',
        'dateOfBirth': '2025-06-15T00:00:00.000',
        'notes': '',
        'createdAt': now.toIso8601String(),
        'isDeleted': false,
      });

      // Incoming with createdAt only, newer.
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': later.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': {
              'familyId': familyId,
              'name': 'NewerName',
              'dateOfBirth': '2025-06-15T00:00:00.000',
              'notes': '',
              'createdAt': later.toIso8601String(),
              'isDeleted': false,
            },
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result = await service.restoreFamily(jsonEncode(backupData));
      expect(result.stores['children']!.updated, 1);

      final child = await StoreRefs.children.record('child-1').get(db);
      expect(child!['name'], 'NewerName');
    });

    test('incoming with createdAt only vs local with modifiedAt', () async {
      // Local with modifiedAt.
      await StoreRefs.children
          .record('child-1')
          .put(db, makeChild('LocalName', modifiedAt: later));

      // Incoming has only createdAt, older than local modifiedAt.
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': {
              'familyId': familyId,
              'name': 'OlderIncoming',
              'dateOfBirth': '2025-06-15T00:00:00.000',
              'notes': '',
              'createdAt': now.toIso8601String(),
              'isDeleted': false,
            },
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result = await service.restoreFamily(jsonEncode(backupData));
      expect(result.stores['children']!.skipped, 1);

      final child = await StoreRefs.children.record('child-1').get(db);
      expect(child!['name'], 'LocalName');
    });

    test('local has no timestamps at all → incoming wins', () async {
      // Local with no createdAt/modifiedAt.
      await StoreRefs.children.record('child-1').put(db, {
        'familyId': familyId,
        'name': 'NoTimestamp',
        'dateOfBirth': '2025-06-15T00:00:00.000',
        'notes': '',
        'isDeleted': false,
      });

      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': <String, dynamic>{},
          'children': {
            'child-1': makeChild('IncomingWins', modifiedAt: now),
          },
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final result = await service.restoreFamily(jsonEncode(backupData));
      expect(result.stores['children']!.updated, 1);

      final child = await StoreRefs.children.record('child-1').get(db);
      expect(child!['name'], 'IncomingWins');
    });

    test('compact JSON output (no indentation)', () async {
      await StoreRefs.families.record(familyId).put(db, makeFamily());

      final exported = await service.exportFamily(familyId);
      // Compact JSON should not contain newlines within the output
      // (except possibly at the very end, but within the body).
      expect(exported, isNot(contains('\n')));
    });

    test('double restore with identical timestamps → all skipped', () async {
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {'child-1': makeChild('Baby')},
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      final jsonStr = jsonEncode(backupData);

      // First restore: inserts.
      final result1 = await service.restoreFamily(jsonStr);
      expect(result1.totalInserted, 2);

      // Second restore with same data: all skipped.
      final result2 = await service.restoreFamily(jsonStr);
      expect(result2.totalInserted, 0);
      expect(result2.totalUpdated, 0);
      expect(result2.totalSkipped, 2);
    });

    test('restore with duplicate ingredient names deduplicates', () async {
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': <String, dynamic>{},
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': {
            'ing-1': {
              'familyId': familyId,
              'name': 'egg',
              'allergens': ['egg'],
              'isDeleted': false,
              'createdBy': 'uid-1',
              'createdAt': now.toIso8601String(),
              'modifiedAt': now.toIso8601String(),
            },
            'ing-2': {
              'familyId': familyId,
              'name': 'egg',
              'allergens': ['dairy'],
              'isDeleted': false,
              'createdBy': 'uid-1',
              'createdAt': later.toIso8601String(),
              'modifiedAt': later.toIso8601String(),
            },
          },
          'recipes': <String, dynamic>{},
          'targets': <String, dynamic>{},
        },
      };

      await service.restoreFamily(jsonEncode(backupData));

      // Only one should survive as non-deleted.
      final all = await StoreRefs.ingredients.find(db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('isDeleted', false),
            ]),
          ));
      expect(all.length, 1);
      expect(all.first.key, 'ing-1'); // oldest kept
    });

    test('restore with duplicate recipe names deduplicates', () async {
      final backupData = {
        'version': 1,
        'appVersion': '',
        'exportedAt': now.toIso8601String(),
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': <String, dynamic>{},
          'carers': <String, dynamic>{},
          'activities': <String, dynamic>{},
          'ingredients': <String, dynamic>{},
          'recipes': {
            'rec-1': {
              'familyId': familyId,
              'name': 'omelette',
              'ingredients': ['egg'],
              'isDeleted': false,
              'createdBy': 'uid-1',
              'createdAt': now.toIso8601String(),
              'modifiedAt': now.toIso8601String(),
            },
            'rec-2': {
              'familyId': familyId,
              'name': 'omelette',
              'ingredients': ['milk'],
              'isDeleted': false,
              'createdBy': 'uid-1',
              'createdAt': later.toIso8601String(),
              'modifiedAt': later.toIso8601String(),
            },
          },
          'targets': <String, dynamic>{},
        },
      };

      await service.restoreFamily(jsonEncode(backupData));

      final all = await StoreRefs.recipes.find(db,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('familyId', familyId),
              Filter.equals('isDeleted', false),
            ]),
          ));
      expect(all.length, 1);
      expect(all.first.key, 'rec-1'); // oldest kept
    });

    test('BackupResult counts are correct', () {
      final result = BackupResult({
        'children': const StoreResult(inserted: 2, updated: 1, skipped: 3),
        'activities': const StoreResult(inserted: 5, updated: 0, skipped: 1),
      });

      expect(result.totalInserted, 7);
      expect(result.totalUpdated, 1);
      expect(result.totalSkipped, 4);
    });
  });

  // ==========================================================================
  // Sync queue API usage (#27)
  // ==========================================================================
  group('restore uses SyncQueue API', () {
    test('inserted records get isNew: true in sync queue', () async {
      final backup = jsonEncode({
        'version': 1,
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {'child-new': makeChild('New Baby')},
          'activities': {},
          'carers': {},
          'ingredients': {},
          'recipes': {},
          'targets': {},
        },
      });

      await service.restoreFamily(backup);

      // Check sync queue entries
      final queue = SyncQueue(db);
      final entries = await queue.getPending();
      final childEntry = entries.firstWhere(
        (e) => e.collection == 'children' && e.documentId == 'child-new',
      );
      expect(childEntry.isNew, isTrue);
    });

    test('updated records get isNew: false in sync queue', () async {
      // Pre-seed a child record
      await StoreRefs.children
          .record('child-existing')
          .put(db, makeChild('Old Baby'));

      final backup = jsonEncode({
        'version': 1,
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {
            'child-existing': makeChild('Updated Baby', modifiedAt: later),
          },
          'activities': {},
          'carers': {},
          'ingredients': {},
          'recipes': {},
          'targets': {},
        },
      });

      await service.restoreFamily(backup);

      final queue = SyncQueue(db);
      final entries = await queue.getPending();
      final childEntry = entries.firstWhere(
        (e) =>
            e.collection == 'children' &&
            e.documentId == 'child-existing',
      );
      expect(childEntry.isNew, isFalse);
    });

    test('skipped records do not enqueue', () async {
      // Pre-seed with newer data
      await StoreRefs.children
          .record('child-skip')
          .put(db, makeChild('Newer Baby', modifiedAt: later));

      final backup = jsonEncode({
        'version': 1,
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {
            'child-skip': makeChild('Older Baby'), // older modifiedAt
          },
          'activities': {},
          'carers': {},
          'ingredients': {},
          'recipes': {},
          'targets': {},
        },
      });

      await service.restoreFamily(backup);

      final queue = SyncQueue(db);
      final entries = await queue.getPending();
      final childEntries = entries.where(
        (e) => e.collection == 'children' && e.documentId == 'child-skip',
      );
      expect(childEntries, isEmpty);
    });

    test('sync queue entries use SyncEntry format with all fields', () async {
      final backup = jsonEncode({
        'version': 1,
        'familyId': familyId,
        'stores': {
          'families': {familyId: makeFamily()},
          'children': {},
          'activities': {'act-1': makeActivity('act-1')},
          'carers': {},
          'ingredients': {},
          'recipes': {},
          'targets': {},
        },
      });

      await service.restoreFamily(backup);

      final queue = SyncQueue(db);
      final entries = await queue.getPending();
      final actEntry = entries.firstWhere(
        (e) => e.collection == 'activities' && e.documentId == 'act-1',
      );
      expect(actEntry.familyId, familyId);
      expect(actEntry.isNew, isTrue);
      expect(actEntry.createdAt, isNotNull);
    });
  });
}
