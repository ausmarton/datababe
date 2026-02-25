import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'filho.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
