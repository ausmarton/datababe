import 'package:drift/drift.dart';

class Children extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get dateOfBirth => dateTime()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
