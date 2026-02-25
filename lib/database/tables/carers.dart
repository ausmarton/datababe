import 'package:drift/drift.dart';

class Carers extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  TextColumn get role => text()(); // 'parent' or 'carer'
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
