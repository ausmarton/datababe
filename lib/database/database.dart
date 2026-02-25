import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/families.dart';
import 'tables/children.dart';
import 'tables/carers.dart';
import 'tables/family_carers.dart';
import 'tables/activities.dart';
import 'daos/activity_dao.dart';
import 'daos/family_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Families, Children, Carers, FamilyCarers, Activities],
  daos: [ActivityDao, FamilyDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'filho',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
