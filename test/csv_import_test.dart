import 'package:flutter_test/flutter_test.dart';
import 'package:filho/import/csv_parser.dart';
import 'package:filho/models/enums.dart';

void main() {
  late CsvParser parser;

  setUp(() {
    parser = CsvParser();
  });

  test('parses bottle feed', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.feedBottle);
    expect(activities.first.feedType, 'formula');
    expect(activities.first.volumeMl, 200.0);
  });

  test('parses breast feed', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","2026-01-14 22:20","2026-01-14 22:31","00:11","00:03R","Breast","00:07L",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.feedBreast);
    expect(activities.first.rightBreastMinutes, 3);
    expect(activities.first.leftBreastMinutes, 7);
    expect(activities.first.durationMinutes, 11);
  });

  test('parses diaper with poo', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-02-22 14:07",,"green",,,"Poo:medium",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.diaper);
    expect(activities.first.contents, 'poo');
    expect(activities.first.contentSize, 'medium');
    expect(activities.first.pooColour, 'green');
  });

  test('parses diaper with both', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-01-07 17:00",,"green",,,"Both, pee:medium poo:medium",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.contents, 'both');
    expect(activities.first.contentSize, 'medium');
    expect(activities.first.peeSize, 'medium');
  });

  test('parses diaper with consistency', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-01-28 20:00",,"yellow","Diarrhea",,"Poo:medium",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.pooColour, 'yellow');
    expect(activities.first.pooConsistency, 'diarrhea');
  });

  test('parses medication', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Meds","2026-02-25 09:47",,,"2oz","Levothyroxine oral solution 50 mcg/5 ml",,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.meds);
    expect(activities.first.dose, '2oz');
    expect(activities.first.medicationName,
        'Levothyroxine oral solution 50 mcg/5 ml');
  });

  test('parses solids', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Solids","2026-02-25 11:15",,,"1 tsp of mango",,"MEH",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.solids);
    expect(activities.first.foodDescription, '1 tsp of mango');
    expect(activities.first.reaction, 'meh');
  });

  test('parses growth', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Growth","2026-02-09 12:01",,,"6.66kg","62.5cm","41cm",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.growth);
    expect(activities.first.weightKg, 6.66);
    expect(activities.first.lengthCm, 62.5);
    expect(activities.first.headCircumferenceCm, 41.0);
  });

  test('parses tummy time', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Tummy time","2025-11-15 12:43","2025-11-15 12:47","00:04",,,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.tummyTime);
    expect(activities.first.durationMinutes, 4);
  });

  test('parses pump', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Pump","2025-10-03 04:30",,,"25ml",,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.pump);
    expect(activities.first.volumeMl, 25.0);
  });

  test('parses temperature', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Temp","2025-12-29 23:40",,,"37.6\u00b0C",,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.temperature);
    expect(activities.first.tempCelsius, 37.6);
  });

  test('parses potty', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Potty","2026-01-01 20:25",,,,,"Pee:small",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.potty);
    expect(activities.first.contents, 'pee');
    expect(activities.first.contentSize, 'small');
  });

  test('parses bath', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Bath","2025-12-12 20:00","2025-12-12 20:05","00:05",,,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.bath);
    expect(activities.first.durationMinutes, 5);
  });

  test('parses skin to skin', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Skin to skin","2025-10-08 14:21","2025-10-08 14:37","00:15",,,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.skinToSkin);
    expect(activities.first.durationMinutes, 15);
  });

  test('parses multiple activities', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n'
        '"Solids","2026-02-25 11:15",,,"1 tsp of mango",,"MEH",\n'
        '"Meds","2026-02-25 09:47",,,"2oz","Levothyroxine oral solution 50 mcg/5 ml",,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 3);
  });

  test('skips rows with invalid dates', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","invalid",,,"Formula","Bottle","200ml",\n'
        '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
  });

  test('handles indoor play', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Indoor play","2025-12-12 12:48","2025-12-12 12:55","00:07",,,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.indoorPlay);
    expect(activities.first.durationMinutes, 7);
  });

  test('handles outdoor play', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Outdoor play","2025-11-26 22:50","2025-11-26 23:05","00:15",,,,\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.outdoorPlay);
    expect(activities.first.durationMinutes, 15);
  });

  test('handles pee-only diaper', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-01-03 09:30",,,,,"Pee:large",\n';
    final activities = parser.parse(csv);
    expect(activities.length, 1);
    expect(activities.first.contents, 'pee');
    expect(activities.first.contentSize, 'large');
  });
}
