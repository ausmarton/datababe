import 'package:drift/drift.dart';

/// Single table for all activity types.
///
/// Each activity type uses a subset of the columns. Unused columns are null.
/// This avoids complex joins for the timeline view while keeping the schema
/// manageable.
class Activities extends Table {
  // --- Common fields ---
  TextColumn get id => text()();
  TextColumn get childId => text()();
  TextColumn get type => text()(); // ActivityType enum name
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get createdBy => text().nullable()(); // carer ID
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get modifiedAt => dateTime()();
  TextColumn get lockedBy => text().nullable()(); // parent ID who locked it
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  // --- Feed (Bottle) ---
  TextColumn get feedType => text().nullable()(); // formula, breastMilk
  RealColumn get volumeMl => real().nullable()();

  // --- Feed (Breast) ---
  IntColumn get rightBreastMinutes => integer().nullable()();
  IntColumn get leftBreastMinutes => integer().nullable()();

  // --- Diaper / Potty ---
  TextColumn get contents => text().nullable()(); // pee, poo, both
  TextColumn get contentSize => text().nullable()(); // small, medium, large
  TextColumn get pooColour => text().nullable()(); // yellow, green, brown
  TextColumn get pooConsistency => text().nullable()(); // solid, soft, diarrhea
  TextColumn get peeSize => text().nullable()(); // for "both" diapers

  // --- Meds ---
  TextColumn get medicationName => text().nullable()();
  TextColumn get dose => text().nullable()();
  TextColumn get doseUnit => text().nullable()();

  // --- Solids ---
  TextColumn get foodDescription => text().nullable()();
  TextColumn get reaction => text().nullable()(); // loved, meh, disliked, none

  // --- Growth ---
  RealColumn get weightKg => real().nullable()();
  RealColumn get lengthCm => real().nullable()();
  RealColumn get headCircumferenceCm => real().nullable()();

  // --- Temperature ---
  RealColumn get tempCelsius => real().nullable()();

  // --- General notes ---
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
