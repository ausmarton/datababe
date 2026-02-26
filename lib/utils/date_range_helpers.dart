import 'package:intl/intl.dart';
import '../models/enums.dart';

/// Computes the [start, end) interval for a given time window mode and anchor.
(DateTime start, DateTime end) computeRange(
    TimeWindowMode mode, DateTime anchor) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
      final start = DateTime(anchor.year, anchor.month, anchor.day);
      return (start, start.add(const Duration(days: 1)));

    case TimeWindowMode.calendarWeek:
      // Monday = 1
      final weekday = anchor.weekday;
      final monday =
          DateTime(anchor.year, anchor.month, anchor.day - (weekday - 1));
      return (monday, monday.add(const Duration(days: 7)));

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
      return anchor.subtract(const Duration(days: 1));
    case TimeWindowMode.calendarWeek:
    case TimeWindowMode.last7Days:
      return anchor.subtract(const Duration(days: 7));
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
      return anchor.add(const Duration(days: 1));
    case TimeWindowMode.calendarWeek:
    case TimeWindowMode.last7Days:
      return anchor.add(const Duration(days: 7));
    case TimeWindowMode.calendarMonth:
    case TimeWindowMode.last30Days:
      return DateTime(anchor.year, anchor.month + 1, anchor.day);
  }
}

/// Human-readable label for the current range.
String rangeLabel(TimeWindowMode mode, DateTime anchor) {
  switch (mode) {
    case TimeWindowMode.calendarDay:
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
      if (anchorDay == today) return 'Today';
      if (anchorDay == today.subtract(const Duration(days: 1))) {
        return 'Yesterday';
      }
      return DateFormat('EEE d MMM').format(anchor);

    case TimeWindowMode.calendarWeek:
      final (start, end) = computeRange(mode, anchor);
      final endDisplay = end.subtract(const Duration(days: 1));
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
