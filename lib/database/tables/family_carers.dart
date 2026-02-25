import 'package:drift/drift.dart';

class FamilyCarers extends Table {
  TextColumn get familyId => text()();
  TextColumn get carerId => text()();
  TextColumn get inviteCode => text().nullable()();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {familyId, carerId};
}
