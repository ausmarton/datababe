import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/activity_model.dart';
import 'package:datababe/models/bulk_entry.dart';

void main() {
  final now = DateTime(2026, 3, 12, 14, 0);

  ActivityModel makeTemplate({
    String type = 'feedBottle',
    String? feedType,
    double? volumeMl,
    String? medicationName,
    String? dose,
    String? doseUnit,
    int? durationMinutes,
    String? notes,
    List<String>? ingredientNames,
    List<String>? allergenNames,
  }) {
    return ActivityModel(
      id: 'source-id',
      childId: 'source-child',
      type: type,
      startTime: DateTime(2026, 3, 10, 8, 0),
      createdAt: DateTime(2026, 3, 10),
      modifiedAt: DateTime(2026, 3, 10),
      feedType: feedType,
      volumeMl: volumeMl,
      medicationName: medicationName,
      dose: dose,
      doseUnit: doseUnit,
      durationMinutes: durationMinutes,
      notes: notes,
      ingredientNames: ingredientNames,
      allergenNames: allergenNames,
    );
  }

  group('BulkEntry.toActivityModel', () {
    test('generates new UUID (not template id)', () {
      final template = makeTemplate();
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.id, isNot(equals('source-id')));
      expect(model.id, isNotEmpty);
    });

    test('uses provided childId (not template childId)', () {
      final template = makeTemplate();
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(childId: 'new-child', now: now);

      expect(model.childId, equals('new-child'));
      expect(model.childId, isNot(equals('source-child')));
    });

    test('preserves bottle feed fields from template', () {
      final template = makeTemplate(
        type: 'feedBottle',
        feedType: 'formula',
        volumeMl: 120.0,
        notes: 'with cereal',
      );
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.type, equals('feedBottle'));
      expect(model.feedType, equals('formula'));
      expect(model.volumeMl, equals(120.0));
      expect(model.notes, equals('with cereal'));
    });

    test('preserves medication fields from template', () {
      final template = makeTemplate(
        type: 'meds',
        medicationName: 'Vitamin D',
        dose: '5',
        doseUnit: 'drops',
      );
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 9, 0),
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.type, equals('meds'));
      expect(model.medicationName, equals('Vitamin D'));
      expect(model.dose, equals('5'));
      expect(model.doseUnit, equals('drops'));
    });

    test('uses entry startTime (not template startTime)', () {
      final template = makeTemplate();
      final entryStart = DateTime(2026, 3, 11, 14, 30);
      final entry = BulkEntry(
        template: template,
        startTime: entryStart,
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.startTime, equals(entryStart));
    });

    test('computes durationMinutes from endTime if set', () {
      final template = makeTemplate(durationMinutes: 999);
      final start = DateTime(2026, 3, 11, 8, 0);
      final end = DateTime(2026, 3, 11, 8, 45);
      final entry = BulkEntry(
        template: template,
        startTime: start,
        endTime: end,
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.durationMinutes, equals(45));
      expect(model.endTime, equals(end));
    });

    test('uses template durationMinutes if endTime is null', () {
      final template = makeTemplate(durationMinutes: 15);
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.durationMinutes, equals(15));
      expect(model.endTime, isNull);
    });

    test('sets createdBy when provided', () {
      final template = makeTemplate();
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(
        childId: 'c1',
        now: now,
        createdBy: 'user-uid-123',
      );

      expect(model.createdBy, equals('user-uid-123'));
    });

    test('createdBy is null when not provided', () {
      final template = makeTemplate();
      final entry = BulkEntry(
        template: template,
        startTime: DateTime(2026, 3, 11, 8, 0),
      );

      final model = entry.toActivityModel(childId: 'c1', now: now);

      expect(model.createdBy, isNull);
    });
  });
}
