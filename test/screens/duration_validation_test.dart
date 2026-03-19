import 'package:datababe/utils/activity_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for duration computation edge cases.
void main() {
  group('formatDuration edge cases', () {
    test('null returns empty string', () {
      expect(formatDuration(null), '');
    });

    test('0 minutes returns "0min"', () {
      expect(formatDuration(0), '0min');
    });

    test('positive minutes formats correctly', () {
      expect(formatDuration(15), '15min');
      expect(formatDuration(60), '1h');
      expect(formatDuration(90), '1h 30min');
    });

    test('negative minutes formats with minus sign', () {
      // This is the bug scenario — negative durations should not occur
      // but if they do, formatDuration should still handle them
      expect(formatDuration(-30), '-30min');
    });
  });

  group('Duration computation (endTime - startTime)', () {
    test('endTime after startTime gives positive duration', () {
      final start = DateTime(2026, 3, 19, 10, 0);
      final end = DateTime(2026, 3, 19, 11, 30);
      expect(end.difference(start).inMinutes, 90);
    });

    test('endTime before startTime gives negative duration', () {
      final start = DateTime(2026, 3, 19, 11, 30);
      final end = DateTime(2026, 3, 19, 10, 0);
      expect(end.difference(start).inMinutes, -90);
    });

    test('endTime equal to startTime gives zero duration', () {
      final start = DateTime(2026, 3, 19, 10, 0);
      final end = DateTime(2026, 3, 19, 10, 0);
      expect(end.difference(start).inMinutes, 0);
    });

    test('endTime on next day gives correct positive duration', () {
      final start = DateTime(2026, 3, 19, 23, 0);
      final end = DateTime(2026, 3, 20, 1, 0);
      expect(end.difference(start).inMinutes, 120);
    });
  });
}
