import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/import/csv_parser.dart';
import 'package:datababe/models/enums.dart';

void main() {
  late CsvParser parser;

  setUp(() {
    parser = CsvParser();
  });

  test('parses bottle feed', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.feedBottle);
    expect(activities.first.feedType, 'formula');
    expect(activities.first.volumeMl, 200.0);
  });

  test('parses breast feed', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","2026-01-14 22:20","2026-01-14 22:31","00:11","00:03R","Breast","00:07L",\n';
    final activities = parser.parse(csv).activities;
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
    final activities = parser.parse(csv).activities;
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
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.contents, 'both');
    expect(activities.first.contentSize, 'medium');
    expect(activities.first.peeSize, 'medium');
  });

  test('parses diaper with consistency', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-01-28 20:00",,"yellow","Diarrhea",,"Poo:medium",\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.pooColour, 'yellow');
    expect(activities.first.pooConsistency, 'diarrhea');
  });

  test('parses medication', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Meds","2026-02-25 09:47",,,"2oz","Levothyroxine oral solution 50 mcg/5 ml",,\n';
    final activities = parser.parse(csv).activities;
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
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.solids);
    expect(activities.first.foodDescription, '1 tsp of mango');
    expect(activities.first.reaction, 'meh');
  });

  test('parses growth', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Growth","2026-02-09 12:01",,,"6.66kg","62.5cm","41cm",\n';
    final activities = parser.parse(csv).activities;
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
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.tummyTime);
    expect(activities.first.durationMinutes, 4);
  });

  test('parses pump', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Pump","2025-10-03 04:30",,,"25ml",,,\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.pump);
    expect(activities.first.volumeMl, 25.0);
  });

  test('parses temperature', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Temp","2025-12-29 23:40",,,"37.6\u00b0C",,,\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.temperature);
    expect(activities.first.tempCelsius, 37.6);
  });

  test('parses potty', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Potty","2026-01-01 20:25",,,,,"Pee:small",\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.potty);
    expect(activities.first.contents, 'pee');
    expect(activities.first.contentSize, 'small');
  });

  test('parses bath', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Bath","2025-12-12 20:00","2025-12-12 20:05","00:05",,,,\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.bath);
    expect(activities.first.durationMinutes, 5);
  });

  test('parses skin to skin', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Skin to skin","2025-10-08 14:21","2025-10-08 14:37","00:15",,,,\n';
    final activities = parser.parse(csv).activities;
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
    final activities = parser.parse(csv).activities;
    expect(activities.length, 3);
  });

  test('skips rows with invalid dates', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Feed","invalid",,,"Formula","Bottle","200ml",\n'
        '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
  });

  test('handles indoor play', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Indoor play","2025-12-12 12:48","2025-12-12 12:55","00:07",,,,\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.indoorPlay);
    expect(activities.first.durationMinutes, 7);
  });

  test('handles outdoor play', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Outdoor play","2025-11-26 22:50","2025-11-26 23:05","00:15",,,,\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.type, ActivityType.outdoorPlay);
    expect(activities.first.durationMinutes, 15);
  });

  test('handles pee-only diaper', () {
    const csv =
        '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
        '"Diaper","2026-01-03 09:30",,,,,"Pee:large",\n';
    final activities = parser.parse(csv).activities;
    expect(activities.length, 1);
    expect(activities.first.contents, 'pee');
    expect(activities.first.contentSize, 'large');
  });

  group('parse error tracking', () {
    test('reports too few columns', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30"\n';
      final result = parser.parse(csv);
      expect(result.activities, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.reason, 'too few columns');
      expect(result.errors.first.rawType, 'Feed');
    });

    test('reports invalid date', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","not-a-date",,,"Formula","Bottle","200ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.reason, contains('invalid date'));
      expect(result.errors.first.reason, contains('not-a-date'));
    });

    test('reports empty start time as invalid date', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","",,,"Formula","Bottle","200ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.reason, contains('invalid date'));
    });

    test('reports unknown type', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"SomeRandomType","2026-02-25 10:30",,,,,,\n';
      final result = parser.parse(csv);
      expect(result.activities, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.first.reason, 'unknown type: SomeRandomType');
    });

    test('valid rows still parsed alongside errors', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n'
          '"BadType","2026-02-25 11:00",,,,,,\n'
          '"Solids","2026-02-25 11:15",,,"banana",,"Loved",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(2));
      expect(result.errors, hasLength(1));
      expect(result.errors.first.reason, 'unknown type: BadType');
    });

    test('error includes correct row number', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n'
          '"Feed","bad-date",,,"Formula","Bottle","200ml",\n'
          '"BadType","2026-02-25 11:00",,,,,,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.errors, hasLength(2));
      expect(result.errors[0].rowNumber, 2);
      expect(result.errors[0].reason, contains('invalid date'));
      expect(result.errors[1].rowNumber, 3);
      expect(result.errors[1].reason, contains('unknown type'));
    });

    test('rawCsvRow preserved on parsed activities', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n';
      final result = parser.parse(csv);
      expect(result.activities.first.rawCsvRow, isNotEmpty);
      expect(result.activities.first.rawCsvRow[0], 'Feed');
    });
  });

  group('edge cases — untrusted input', () {
    test('empty CSV returns empty result', () {
      final result = parser.parse('');
      expect(result.activities, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('header-only CSV returns empty result', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n';
      final result = parser.parse(csv);
      expect(result.activities, isEmpty);
      expect(result.errors, isEmpty);
    });

    test('Windows line endings (\\r\\n) parsed correctly', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\r\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\r\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.feedBottle);
    });

    test('Mac line endings (\\r) parsed correctly', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\r'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\r';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.feedBottle);
    });

    test('unquoted cells parsed correctly', () {
      const csv =
          'Type,Start,End,Duration,Start Condition,Start Location,End Condition,Notes\n'
          'Feed,2026-02-25 10:30,,,Formula,Bottle,200ml,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.feedBottle);
      expect(result.activities.first.volumeMl, 200.0);
    });

    test('mixed quoted and unquoted cells', () {
      const csv =
          'Type,"Start",End,Duration,"Start Condition",Start Location,"End Condition",Notes\n'
          '"Feed",2026-02-25 10:30,,,Formula,"Bottle","200ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.feedType, 'formula');
    });

    test('notes field preserved on parsed activities', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml","was hungry"\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      // Notes are in col7 but feed parsing doesn't extract notes explicitly —
      // rawCsvRow still has the data.
      expect(result.activities.first.rawCsvRow[7], 'was hungry');
    });

    test('growth with partial fields (only weight)', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Growth","2026-02-09 12:01",,,"6.66kg","","",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.weightKg, 6.66);
      expect(result.activities.first.lengthCm, isNull);
      expect(result.activities.first.headCircumferenceCm, isNull);
    });

    test('bottle feed with breast milk type', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Breast Milk","Bottle","150ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.feedBottle);
      expect(result.activities.first.feedType, 'breastMilk');
      expect(result.activities.first.volumeMl, 150.0);
    });

    test('diaper with empty optional columns', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Diaper","2026-02-22 14:07",,"","","","Poo:small",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.diaper);
      expect(result.activities.first.contents, 'poo');
      expect(result.activities.first.contentSize, 'small');
      expect(result.activities.first.pooColour, isNull);
      expect(result.activities.first.pooConsistency, isNull);
    });

    test('pump with duration and volume', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Pump","2025-10-03 04:30","2025-10-03 04:50","00:20","25ml",,,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.pump);
      expect(result.activities.first.volumeMl, 25.0);
      expect(result.activities.first.durationMinutes, 20);
    });

    test('temperature without degree symbol', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Temp","2025-12-29 23:40",,,"37.6",,,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.tempCelsius, 37.6);
    });

    test('temperature with unparseable value returns null tempCelsius', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Temp","2025-12-29 23:40",,,"not-a-number",,,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.tempCelsius, isNull);
    });

    test('breast feed with zero-minute side', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-01-14 22:20","2026-01-14 22:31","00:11","00:00R","Breast","00:11L",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.feedBreast);
      expect(result.activities.first.rightBreastMinutes, 0);
      expect(result.activities.first.leftBreastMinutes, 11);
    });

    test('many rows parsed correctly', () {
      final buffer = StringBuffer(
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n');
      for (int i = 0; i < 100; i++) {
        final hour = (i % 24).toString().padLeft(2, '0');
        buffer.write('"Diaper","2026-02-${(i % 28 + 1).toString().padLeft(2, '0')} $hour:00",,"","","","Pee:small",\n');
      }
      final result = parser.parse(buffer.toString());
      expect(result.activities, hasLength(100));
    });

    test('multiple errors report correct row numbers', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","200ml",\n'
          '"BadType1","2026-02-25 11:00",,,,,,\n'
          '"Solids","2026-02-25 12:00",,,"banana",,"Loved",\n'
          '"BadType2","2026-02-25 13:00",,,,,,\n'
          '"Feed","not-a-date",,,"Formula","Bottle","200ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(2));
      expect(result.errors, hasLength(3));
      expect(result.errors[0].rowNumber, 2);
      expect(result.errors[0].reason, contains('unknown type'));
      expect(result.errors[1].rowNumber, 4);
      expect(result.errors[1].reason, contains('unknown type'));
      expect(result.errors[2].rowNumber, 5);
      expect(result.errors[2].reason, contains('invalid date'));
    });

    test('solids with empty reaction defaults to null reaction', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Solids","2026-02-25 11:15",,,"banana","","",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.solids);
      expect(result.activities.first.foodDescription, 'banana');
      expect(result.activities.first.reaction, isNull);
    });

    test('meds with empty dose and name', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Meds","2026-02-25 09:47",,,"","","",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.meds);
      expect(result.activities.first.dose, isNull);
      expect(result.activities.first.medicationName, isNull);
    });

    test('duration-only activity with end time computes duration', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Tummy time","2025-11-15 12:00","2025-11-15 12:30","00:30",,,,\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.durationMinutes, 30);
      expect(result.activities.first.endTime, isNotNull);
    });

    test('bottle feed with zero volume', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Feed","2026-02-25 10:30",,,"Formula","Bottle","0ml",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.volumeMl, 0.0);
    });

    test('potty with both contents', () {
      const csv =
          '"Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"\n'
          '"Potty","2026-01-01 20:25",,,,,"Both, pee:small poo:medium",\n';
      final result = parser.parse(csv);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.type, ActivityType.potty);
      expect(result.activities.first.contents, 'both');
    });
  });
}
