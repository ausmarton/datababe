import 'package:flutter_test/flutter_test.dart';
import 'package:datababe/models/enums.dart';
import 'package:datababe/utils/date_range_helpers.dart';

void main() {
  group('startOfDay', () {
    test('hour 0: same as midnight', () {
      final result = startOfDay(DateTime(2026, 3, 18, 14, 30), 0);
      expect(result, DateTime(2026, 3, 18));
    });

    test('hour 6: after start time returns same day', () {
      final result = startOfDay(DateTime(2026, 3, 18, 8, 0), 6);
      expect(result, DateTime(2026, 3, 18, 6));
    });

    test('hour 6: before start time returns previous day', () {
      final result = startOfDay(DateTime(2026, 3, 18, 3, 0), 6);
      expect(result, DateTime(2026, 3, 17, 6));
    });

    test('hour 6: exactly at start time returns same day', () {
      final result = startOfDay(DateTime(2026, 3, 18, 6, 0), 6);
      expect(result, DateTime(2026, 3, 18, 6));
    });

    test('hour 2: 01:59 rolls back', () {
      final result = startOfDay(DateTime(2026, 3, 18, 1, 59), 2);
      expect(result, DateTime(2026, 3, 17, 2));
    });

    test('hour 2: 02:00 is same day', () {
      final result = startOfDay(DateTime(2026, 3, 18, 2, 0), 2);
      expect(result, DateTime(2026, 3, 18, 2));
    });
  });

  group('computeRange', () {
    test('calendarDay: midnight to midnight', () {
      final anchor = DateTime(2026, 2, 26, 14, 30);
      final (start, end) = computeRange(TimeWindowMode.calendarDay, anchor);
      expect(start, DateTime(2026, 2, 26));
      expect(end, DateTime(2026, 2, 27));
    });

    test('calendarDay with startOfDayHour: shifts boundaries', () {
      final anchor = DateTime(2026, 2, 26, 14, 30);
      final (start, end) = computeRange(TimeWindowMode.calendarDay, anchor,
          startOfDayHour: 6);
      expect(start, DateTime(2026, 2, 26, 6));
      expect(end, DateTime(2026, 2, 27, 6));
    });

    test('calendarWeek: Monday to Monday', () {
      // 2026-02-26 is a Thursday
      final anchor = DateTime(2026, 2, 26);
      final (start, end) = computeRange(TimeWindowMode.calendarWeek, anchor);
      expect(start, DateTime(2026, 2, 23)); // Monday
      expect(end, DateTime(2026, 3, 2)); // Next Monday
    });

    test('calendarWeek: anchor on Monday', () {
      final anchor = DateTime(2026, 2, 23);
      final (start, end) = computeRange(TimeWindowMode.calendarWeek, anchor);
      expect(start, DateTime(2026, 2, 23));
      expect(end, DateTime(2026, 3, 2));
    });

    test('calendarWeek: anchor on Sunday', () {
      final anchor = DateTime(2026, 3, 1); // Sunday
      final (start, end) = computeRange(TimeWindowMode.calendarWeek, anchor);
      expect(start, DateTime(2026, 2, 23)); // Previous Monday
      expect(end, DateTime(2026, 3, 2));
    });

    test('calendarMonth: 1st to 1st', () {
      final anchor = DateTime(2026, 2, 15);
      final (start, end) = computeRange(TimeWindowMode.calendarMonth, anchor);
      expect(start, DateTime(2026, 2, 1));
      expect(end, DateTime(2026, 3, 1));
    });

    test('calendarMonth: year boundary', () {
      final anchor = DateTime(2025, 12, 15);
      final (start, end) = computeRange(TimeWindowMode.calendarMonth, anchor);
      expect(start, DateTime(2025, 12, 1));
      expect(end, DateTime(2026, 1, 1));
    });

    test('last24h: returns 24h range ending now', () {
      final (start, end) = computeRange(
          TimeWindowMode.last24h, DateTime(2026, 2, 26));
      expect(end.difference(start).inHours, 24);
    });

    test('last7Days: returns 7 day range', () {
      final (start, end) = computeRange(
          TimeWindowMode.last7Days, DateTime(2026, 2, 26));
      expect(end.difference(start).inDays, 7);
    });

    test('last30Days: returns 30 day range', () {
      final (start, end) = computeRange(
          TimeWindowMode.last30Days, DateTime(2026, 2, 26));
      expect(end.difference(start).inDays, 30);
    });
  });

  group('previousAnchor', () {
    test('calendarDay: goes back 1 day', () {
      final anchor = DateTime(2026, 2, 26);
      final prev = previousAnchor(TimeWindowMode.calendarDay, anchor);
      expect(prev, DateTime(2026, 2, 25));
    });

    test('calendarWeek: goes back 7 days', () {
      final anchor = DateTime(2026, 2, 26);
      final prev = previousAnchor(TimeWindowMode.calendarWeek, anchor);
      expect(prev, DateTime(2026, 2, 19));
    });

    test('calendarMonth: goes back 1 month', () {
      final anchor = DateTime(2026, 2, 15);
      final prev = previousAnchor(TimeWindowMode.calendarMonth, anchor);
      expect(prev, DateTime(2026, 1, 15));
    });

    test('calendarMonth: year boundary', () {
      final anchor = DateTime(2026, 1, 15);
      final prev = previousAnchor(TimeWindowMode.calendarMonth, anchor);
      expect(prev, DateTime(2025, 12, 15));
    });

    test('last24h: goes back 1 day (same as calendarDay)', () {
      final anchor = DateTime(2026, 3, 15);
      final prev = previousAnchor(TimeWindowMode.last24h, anchor);
      expect(prev, DateTime(2026, 3, 14));
    });

    test('last7Days: goes back 7 days (same as calendarWeek)', () {
      final anchor = DateTime(2026, 3, 15);
      final prev = previousAnchor(TimeWindowMode.last7Days, anchor);
      expect(prev, DateTime(2026, 3, 8));
    });

    test('last30Days: goes back 1 month (same as calendarMonth)', () {
      final anchor = DateTime(2026, 3, 15);
      final prev = previousAnchor(TimeWindowMode.last30Days, anchor);
      expect(prev, DateTime(2026, 2, 15));
    });
  });

  group('nextAnchor', () {
    test('calendarDay: goes forward 1 day', () {
      final anchor = DateTime(2026, 2, 26);
      final next = nextAnchor(TimeWindowMode.calendarDay, anchor);
      expect(next, DateTime(2026, 2, 27));
    });

    test('calendarWeek: goes forward 7 days', () {
      final anchor = DateTime(2026, 2, 26);
      final next = nextAnchor(TimeWindowMode.calendarWeek, anchor);
      expect(next, DateTime(2026, 3, 5));
    });

    test('calendarMonth: goes forward 1 month', () {
      final anchor = DateTime(2026, 2, 15);
      final next = nextAnchor(TimeWindowMode.calendarMonth, anchor);
      expect(next, DateTime(2026, 3, 15));
    });

    test('calendarMonth: year boundary forward', () {
      final anchor = DateTime(2025, 12, 15);
      final next = nextAnchor(TimeWindowMode.calendarMonth, anchor);
      expect(next, DateTime(2026, 1, 15));
    });

    test('last24h: goes forward 1 day', () {
      final anchor = DateTime(2026, 3, 15);
      final next = nextAnchor(TimeWindowMode.last24h, anchor);
      expect(next, DateTime(2026, 3, 16));
    });

    test('last7Days: goes forward 7 days', () {
      final anchor = DateTime(2026, 3, 15);
      final next = nextAnchor(TimeWindowMode.last7Days, anchor);
      expect(next, DateTime(2026, 3, 22));
    });

    test('last30Days: goes forward 1 month', () {
      final anchor = DateTime(2026, 3, 15);
      final next = nextAnchor(TimeWindowMode.last30Days, anchor);
      expect(next, DateTime(2026, 4, 15));
    });
  });

  group('rangeLabel', () {
    test('calendarDay: shows formatted date', () {
      final anchor = DateTime(2026, 2, 24); // Tuesday
      final label = rangeLabel(TimeWindowMode.calendarDay, anchor);
      expect(label, contains('24'));
      expect(label, contains('Feb'));
    });

    test('calendarWeek: shows date range', () {
      // 2026-02-23 is Monday, week ends 2026-03-01 (Sunday)
      final anchor = DateTime(2026, 2, 26); // Thursday
      final label = rangeLabel(TimeWindowMode.calendarWeek, anchor);
      expect(label, contains('23'));
      expect(label, contains('Feb'));
      expect(label, contains('1'));
      expect(label, contains('Mar'));
    });

    test('calendarDay with startOfDayHour: "Today" uses adjusted boundary', () {
      // Today with non-zero startOfDayHour should still show "Today"
      final now = DateTime.now();
      final anchor = DateTime(now.year, now.month, now.day);
      final label =
          rangeLabel(TimeWindowMode.calendarDay, anchor, startOfDayHour: 6);
      expect(label, 'Today');
    });

    test('calendarMonth: shows month and year', () {
      final anchor = DateTime(2026, 2, 15);
      final label = rangeLabel(TimeWindowMode.calendarMonth, anchor);
      expect(label, 'February 2026');
    });

    test('last24h: descriptive label', () {
      final label = rangeLabel(TimeWindowMode.last24h, DateTime.now());
      expect(label, 'Last 24 hours');
    });

    test('last7Days: descriptive label', () {
      final label = rangeLabel(TimeWindowMode.last7Days, DateTime.now());
      expect(label, 'Last 7 days');
    });

    test('last30Days: descriptive label', () {
      final label = rangeLabel(TimeWindowMode.last30Days, DateTime.now());
      expect(label, 'Last 30 days');
    });
  });

  group('isCalendarMode', () {
    test('calendar modes return true', () {
      expect(isCalendarMode(TimeWindowMode.calendarDay), isTrue);
      expect(isCalendarMode(TimeWindowMode.calendarWeek), isTrue);
      expect(isCalendarMode(TimeWindowMode.calendarMonth), isTrue);
    });

    test('rolling modes return false', () {
      expect(isCalendarMode(TimeWindowMode.last24h), isFalse);
      expect(isCalendarMode(TimeWindowMode.last7Days), isFalse);
      expect(isCalendarMode(TimeWindowMode.last30Days), isFalse);
    });
  });
}
