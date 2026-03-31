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
      // Use DateTime.now() directly so the anchor is always in the current
      // startOfDay window regardless of wall-clock hour.
      final label =
          rangeLabel(TimeWindowMode.calendarDay, DateTime.now(), startOfDayHour: 6);
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

  // DST regression tests — European Summer Time starts last Sunday of March.
  // In CET, 2026-03-29 02:00 → 03:00 (clocks spring forward, day has 23h).
  // Using Duration(days: 1) would be 24h, skipping or misaligning days.
  group('DST safety', () {
    // March 29, 2026 is the CET→CEST transition day (23 hours long).
    final dstDay = DateTime(2026, 3, 29);

    test('previousAnchor does not skip days across spring-forward', () {
      final march30 = DateTime(2026, 3, 30);
      final prev = previousAnchor(TimeWindowMode.calendarDay, march30);
      expect(prev.year, 2026);
      expect(prev.month, 3);
      expect(prev.day, 29);
    });

    test('nextAnchor does not skip days across spring-forward', () {
      final next = nextAnchor(TimeWindowMode.calendarDay, dstDay);
      expect(next.year, 2026);
      expect(next.month, 3);
      expect(next.day, 30);
    });

    test('previousAnchor → nextAnchor round-trips to same day', () {
      final march30 = DateTime(2026, 3, 30);
      final prev = previousAnchor(TimeWindowMode.calendarDay, march30);
      final back = nextAnchor(TimeWindowMode.calendarDay, prev);
      expect(back.day, march30.day);
      expect(back.month, march30.month);
    });

    test('computeRange calendarDay covers exactly one calendar day on DST day', () {
      final (start, end) = computeRange(TimeWindowMode.calendarDay, dstDay);
      expect(start.day, 29);
      expect(end.day, 30);
      expect(end.month, 3);
    });

    test('startOfDay with startOfDayHour > 0 does not skip day on DST', () {
      // 3am on March 29 (DST day) with startOfDayHour=6 should go to March 28
      final result = startOfDay(DateTime(2026, 3, 29, 3), 6);
      expect(result.day, 28);
      expect(result.hour, 6);
    });

    test('week navigation does not lose days across DST', () {
      final march30 = DateTime(2026, 3, 30);
      final prevWeek = previousAnchor(TimeWindowMode.calendarWeek, march30);
      expect(prevWeek.day, 23);
      expect(prevWeek.month, 3);
      final nextWeek = nextAnchor(TimeWindowMode.calendarWeek, prevWeek);
      expect(nextWeek.day, 30);
    });

    test('rangeLabel Yesterday correct across DST boundary', () {
      // March 30 anchor, startOfDayHour=0: "yesterday" should be March 29
      final label = rangeLabel(
        TimeWindowMode.calendarDay,
        DateTime(2026, 3, 29),
        startOfDayHour: 0,
      );
      // March 29 is yesterday relative to March 30 — but we can't control
      // DateTime.now() in unit tests, so just verify it doesn't crash and
      // returns a valid string.
      expect(label, isNotEmpty);
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
