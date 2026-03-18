import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/enums.dart';
import 'package:datababe/utils/activity_helpers.dart';

void main() {
  group('activityDisplayName', () {
    test('returns correct name for every type', () {
      expect(activityDisplayName(ActivityType.feedBottle), 'Bottle Feed');
      expect(activityDisplayName(ActivityType.feedBreast), 'Breast Feed');
      expect(activityDisplayName(ActivityType.diaper), 'Diaper');
      expect(activityDisplayName(ActivityType.meds), 'Medication');
      expect(activityDisplayName(ActivityType.solids), 'Solids');
      expect(activityDisplayName(ActivityType.growth), 'Growth');
      expect(activityDisplayName(ActivityType.tummyTime), 'Tummy Time');
      expect(activityDisplayName(ActivityType.indoorPlay), 'Indoor Play');
      expect(activityDisplayName(ActivityType.outdoorPlay), 'Outdoor Play');
      expect(activityDisplayName(ActivityType.pump), 'Pump');
      expect(activityDisplayName(ActivityType.temperature), 'Temperature');
      expect(activityDisplayName(ActivityType.bath), 'Bath');
      expect(activityDisplayName(ActivityType.skinToSkin), 'Skin to Skin');
      expect(activityDisplayName(ActivityType.potty), 'Potty');
      expect(activityDisplayName(ActivityType.sleep), 'Sleep');
    });
  });

  group('activityIcon', () {
    test('returns an IconData for every type', () {
      for (final type in ActivityType.values) {
        expect(activityIcon(type), isA<IconData>());
      }
    });

    test('returns expected icons for key types', () {
      expect(activityIcon(ActivityType.meds), Icons.medication);
      expect(activityIcon(ActivityType.solids), Icons.restaurant);
      expect(activityIcon(ActivityType.bath), Icons.bathtub);
      expect(activityIcon(ActivityType.temperature), Icons.thermostat);
      expect(activityIcon(ActivityType.potty), Icons.wc);
      expect(activityIcon(ActivityType.sleep), Icons.bedtime);
    });
  });

  group('activityColor', () {
    test('returns a Color for every type', () {
      for (final type in ActivityType.values) {
        expect(activityColor(type), isA<Color>());
      }
    });

    test('returns distinct colors for bottle vs breast', () {
      expect(activityColor(ActivityType.feedBottle),
          isNot(activityColor(ActivityType.feedBreast)));
    });
  });

  group('parseActivityType', () {
    test('parses valid type names', () {
      expect(parseActivityType('feedBottle'), ActivityType.feedBottle);
      expect(parseActivityType('diaper'), ActivityType.diaper);
      expect(parseActivityType('tummyTime'), ActivityType.tummyTime);
      expect(parseActivityType('skinToSkin'), ActivityType.skinToSkin);
    });

    test('returns null for unknown type', () {
      expect(parseActivityType('unknown'), isNull);
      expect(parseActivityType(''), isNull);
    });

    test('is case sensitive', () {
      expect(parseActivityType('FeedBottle'), isNull);
      expect(parseActivityType('DIAPER'), isNull);
    });

    test('round-trips all enum values', () {
      for (final type in ActivityType.values) {
        expect(parseActivityType(type.name), type);
      }
    });
  });

  group('formatDuration', () {
    test('null returns empty string', () {
      expect(formatDuration(null), '');
    });

    test('0 minutes', () {
      expect(formatDuration(0), '0min');
    });

    test('minutes under an hour', () {
      expect(formatDuration(1), '1min');
      expect(formatDuration(30), '30min');
      expect(formatDuration(59), '59min');
    });

    test('exact hours', () {
      expect(formatDuration(60), '1h');
      expect(formatDuration(120), '2h');
      expect(formatDuration(180), '3h');
    });

    test('hours and minutes', () {
      expect(formatDuration(61), '1h 1min');
      expect(formatDuration(90), '1h 30min');
      expect(formatDuration(150), '2h 30min');
    });

    test('large values', () {
      expect(formatDuration(1440), '24h');
      expect(formatDuration(1441), '24h 1min');
    });
  });
}
