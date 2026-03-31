import 'package:intl/intl.dart';
import '../models/enums.dart';

/// Returns the start of the "logical day" containing [now], given a
/// [startOfDayHour] (0-23). For example, with startOfDayHour=6:
///   - 2026-03-18 08:00 → 2026-03-18 06:00 (same day)
///   - 2026-03-18 03:00 → 2026-03-17 06:00 (previous day)
DateTime startOfDay(DateTime now, int startOfDayHour) {
  final candidate = DateTime(now.year, now.month, now.day, startOfDayHour);
  if (!now.isBefore(candidate)) return candidate;
  // Use date arithmetic (not Duration) to avoid DST issues.
  return DateTime(now.year, now.month, now.day - 1, startOfDayHour);
}

/// Computes the [start, end) interval for a given time window mode and anchor.
///
/// [startOfDayHour] shifts the day boundary for calendarDay mode (0-23).
(DateTime start, DateTime end) computeRange(
    TimeWindowMode mode, DateTime anchor,
    {int startOfDayHour = 0}) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
      final start =
          DateTime(anchor.year, anchor.month, anchor.day, startOfDayHour);
      return (start, DateTime(start.year, start.month, start.day + 1, start.hour));

    case TimeWindowMode.calendarWeek:
      // Monday = 1
      final weekday = anchor.weekday;
      final monday =
          DateTime(anchor.year, anchor.month, anchor.day - (weekday - 1));
      return (monday, DateTime(monday.year, monday.month, monday.day + 7));

    case TimeWindowMode.calendarMonth:
      final start = DateTime(anchor.year, anchor.month);
      final end = DateTime(anchor.year, anchor.month + 1);
      return (start, end);

    case TimeWindowMode.last24h:
      final now = DateTime.now();
      return (now.subtract(const Duration(hours: 24)), now);

    case TimeWindowMode.last7Days:
      final now = DateTime.now();
      return (now.subtract(const Duration(days: 7)), now);

    case TimeWindowMode.last30Days:
      final now = DateTime.now();
      return (now.subtract(const Duration(days: 30)), now);
  }
}

/// Steps the anchor back one period.
DateTime previousAnchor(TimeWindowMode mode, DateTime anchor) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
    case TimeWindowMode.last24h:
      return DateTime(anchor.year, anchor.month, anchor.day - 1,
          anchor.hour, anchor.minute, anchor.second);
    case TimeWindowMode.calendarWeek:
    case TimeWindowMode.last7Days:
      return DateTime(anchor.year, anchor.month, anchor.day - 7,
          anchor.hour, anchor.minute, anchor.second);
    case TimeWindowMode.calendarMonth:
    case TimeWindowMode.last30Days:
      return DateTime(anchor.year, anchor.month - 1, anchor.day);
  }
}

/// Steps the anchor forward one period.
DateTime nextAnchor(TimeWindowMode mode, DateTime anchor) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
    case TimeWindowMode.last24h:
      return DateTime(anchor.year, anchor.month, anchor.day + 1,
          anchor.hour, anchor.minute, anchor.second);
    case TimeWindowMode.calendarWeek:
    case TimeWindowMode.last7Days:
      return DateTime(anchor.year, anchor.month, anchor.day + 7,
          anchor.hour, anchor.minute, anchor.second);
    case TimeWindowMode.calendarMonth:
    case TimeWindowMode.last30Days:
      return DateTime(anchor.year, anchor.month + 1, anchor.day);
  }
}

/// Human-readable label for the current range.
String rangeLabel(TimeWindowMode mode, DateTime anchor,
    {int startOfDayHour = 0}) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
      final today = startOfDay(DateTime.now(), startOfDayHour);
      final anchorDay = startOfDay(anchor, startOfDayHour);
      if (anchorDay == today) return 'Today';
      final yesterday = DateTime(
          today.year, today.month, today.day - 1, today.hour);
      if (anchorDay == yesterday) return 'Yesterday';
      return DateFormat('EEE d MMM').format(anchor);

    case TimeWindowMode.calendarWeek:
      final (start, end) = computeRange(mode, anchor);
      final endDisplay = DateTime(
          end.year, end.month, end.day - 1, end.hour);
      return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(endDisplay)}';

    case TimeWindowMode.calendarMonth:
      return DateFormat('MMMM yyyy').format(anchor);

    case TimeWindowMode.last24h:
      return 'Last 24 hours';
    case TimeWindowMode.last7Days:
      return 'Last 7 days';
    case TimeWindowMode.last30Days:
      return 'Last 30 days';
  }
}

/// True for calendar modes where navigation arrows should be shown.
bool isCalendarMode(TimeWindowMode mode) {
  return mode == TimeWindowMode.calendarDay ||
      mode == TimeWindowMode.calendarWeek ||
      mode == TimeWindowMode.calendarMonth;
}
