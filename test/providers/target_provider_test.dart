import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/models/enums.dart';
import 'package:datababe/providers/target_provider.dart';

void main() {
  group('periodMatchesMode', () {
    test('daily matches calendarDay', () {
      expect(periodMatchesMode('daily', TimeWindowMode.calendarDay), isTrue);
    });

    test('daily matches last24h', () {
      expect(periodMatchesMode('daily', TimeWindowMode.last24h), isTrue);
    });

    test('daily does not match weekly modes', () {
      expect(
          periodMatchesMode('daily', TimeWindowMode.calendarWeek), isFalse);
      expect(periodMatchesMode('daily', TimeWindowMode.last7Days), isFalse);
    });

    test('daily does not match monthly modes', () {
      expect(
          periodMatchesMode('daily', TimeWindowMode.calendarMonth), isFalse);
      expect(periodMatchesMode('daily', TimeWindowMode.last30Days), isFalse);
    });

    test('weekly matches calendarWeek', () {
      expect(
          periodMatchesMode('weekly', TimeWindowMode.calendarWeek), isTrue);
    });

    test('weekly matches last7Days', () {
      expect(periodMatchesMode('weekly', TimeWindowMode.last7Days), isTrue);
    });

    test('weekly does not match daily modes', () {
      expect(
          periodMatchesMode('weekly', TimeWindowMode.calendarDay), isFalse);
      expect(periodMatchesMode('weekly', TimeWindowMode.last24h), isFalse);
    });

    test('monthly matches calendarMonth', () {
      expect(
          periodMatchesMode('monthly', TimeWindowMode.calendarMonth), isTrue);
    });

    test('monthly matches last30Days', () {
      expect(periodMatchesMode('monthly', TimeWindowMode.last30Days), isTrue);
    });

    test('monthly does not match daily or weekly modes', () {
      expect(
          periodMatchesMode('monthly', TimeWindowMode.calendarDay), isFalse);
      expect(
          periodMatchesMode('monthly', TimeWindowMode.calendarWeek), isFalse);
    });

    test('unknown period returns false for all modes', () {
      for (final mode in TimeWindowMode.values) {
        expect(periodMatchesMode('yearly', mode), isFalse);
      }
    });

    test('empty string period returns false', () {
      expect(periodMatchesMode('', TimeWindowMode.calendarDay), isFalse);
    });
  });
}
