import 'package:csv/csv.dart';
import '../models/enums.dart';

/// A row that could not be parsed from the CSV.
class ParseError {
  final int rowNumber; // 1-based (after header)
  final String rawType; // The type column value (or empty)
  final String reason; // e.g. "invalid date", "unknown type", "too few columns"

  const ParseError({
    required this.rowNumber,
    required this.rawType,
    required this.reason,
  });
}

/// Result of parsing a CSV file — parsed activities plus any errors.
class ParseResult {
  final List<ParsedActivity> activities;
  final List<ParseError> errors;

  const ParseResult({required this.activities, required this.errors});
}

/// A parsed activity — pure data, no database dependency.
class ParsedActivity {
  final ActivityType type;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;

  // Feed (Bottle)
  final String? feedType;
  final double? volumeMl;

  // Feed (Breast)
  final int? rightBreastMinutes;
  final int? leftBreastMinutes;

  // Diaper / Potty
  final String? contents;
  final String? contentSize;
  final String? peeSize;
  final String? pooColour;
  final String? pooConsistency;

  // Meds
  final String? medicationName;
  final String? dose;

  // Solids
  final String? foodDescription;
  final String? reaction;

  // Growth
  final double? weightKg;
  final double? lengthCm;
  final double? headCircumferenceCm;

  // Temperature
  final double? tempCelsius;

  // Notes
  final String? notes;

  /// The original CSV row values (for rejects file).
  final List<dynamic> rawCsvRow;

  ParsedActivity({
    required this.type,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.feedType,
    this.volumeMl,
    this.rightBreastMinutes,
    this.leftBreastMinutes,
    this.contents,
    this.contentSize,
    this.peeSize,
    this.pooColour,
    this.pooConsistency,
    this.medicationName,
    this.dose,
    this.foodDescription,
    this.reaction,
    this.weightKg,
    this.lengthCm,
    this.headCircumferenceCm,
    this.tempCelsius,
    this.notes,
    this.rawCsvRow = const [],
  });
}

/// Parses CSV content into [ParsedActivity] objects.
///
/// CSV columns:
///   0: Type, 1: Start, 2: End, 3: Duration,
///   4: Start Condition, 5: Start Location, 6: End Condition, 7: Notes
///
/// Columns are overloaded — different activity types use them differently.
class CsvParser {
  /// Parse CSV content into a [ParseResult] with activities and errors.
  ParseResult parse(String csvContent) {
    final normalized =
        csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.isEmpty) {
      return const ParseResult(activities: [], errors: []);
    }

    final dataRows = rows.skip(1).toList();
    final results = <ParsedActivity>[];
    final errors = <ParseError>[];

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNumber = i + 1; // 1-based after header

      if (row.length < 8) {
        errors.add(ParseError(
          rowNumber: rowNumber,
          rawType: row.isNotEmpty ? _str(row[0]) : '',
          reason: 'too few columns',
        ));
        continue;
      }

      final type = _str(row[0]);
      final startStr = _str(row[1]);
      final endStr = _str(row[2]);
      final durationStr = _str(row[3]);
      final col4 = _str(row[4]);
      final col5 = _str(row[5]);
      final col6 = _str(row[6]);
      final col7 = _str(row[7]);

      if (startStr.isEmpty) {
        errors.add(ParseError(
          rowNumber: rowNumber,
          rawType: type,
          reason: 'invalid date: (empty)',
        ));
        continue;
      }

      final startTime = _parseDateTime(startStr);
      if (startTime == null) {
        errors.add(ParseError(
          rowNumber: rowNumber,
          rawType: type,
          reason: 'invalid date: $startStr',
        ));
        continue;
      }

      final endTime = endStr.isNotEmpty ? _parseDateTime(endStr) : null;
      final duration = _parseDurationMinutes(durationStr);

      final entry = _parseRow(
        type: type,
        startTime: startTime,
        endTime: endTime,
        duration: duration,
        col3Raw: durationStr,
        col4: col4,
        col5: col5,
        col6: col6,
        col7: col7,
      );

      if (entry != null) {
        results.add(ParsedActivity(
          type: entry.type,
          startTime: entry.startTime,
          endTime: entry.endTime,
          durationMinutes: entry.durationMinutes,
          feedType: entry.feedType,
          volumeMl: entry.volumeMl,
          rightBreastMinutes: entry.rightBreastMinutes,
          leftBreastMinutes: entry.leftBreastMinutes,
          contents: entry.contents,
          contentSize: entry.contentSize,
          peeSize: entry.peeSize,
          pooColour: entry.pooColour,
          pooConsistency: entry.pooConsistency,
          medicationName: entry.medicationName,
          dose: entry.dose,
          foodDescription: entry.foodDescription,
          reaction: entry.reaction,
          weightKg: entry.weightKg,
          lengthCm: entry.lengthCm,
          headCircumferenceCm: entry.headCircumferenceCm,
          tempCelsius: entry.tempCelsius,
          notes: entry.notes,
          rawCsvRow: row,
        ));
      } else {
        errors.add(ParseError(
          rowNumber: rowNumber,
          rawType: type,
          reason: 'unknown type: $type',
        ));
      }
    }

    return ParseResult(activities: results, errors: errors);
  }

  ParsedActivity? _parseRow({
    required String type,
    required DateTime startTime,
    DateTime? endTime,
    int? duration,
    required String col3Raw,
    required String col4,
    required String col5,
    required String col6,
    required String col7,
  }) {
    switch (type) {
      case 'Feed':
        return _parseFeed(startTime, endTime, duration, col4, col5, col6);
      case 'Diaper':
        return _parseDiaper(startTime, col3Raw, col4, col6);
      case 'Meds':
        return _parseMeds(startTime, col4, col5);
      case 'Solids':
        return _parseSolids(startTime, col4, col6);
      case 'Growth':
        return _parseGrowth(startTime, col4, col5, col6);
      case 'Tummy time':
        return _duration(ActivityType.tummyTime, startTime, endTime, duration);
      case 'Indoor play':
        return _duration(ActivityType.indoorPlay, startTime, endTime, duration);
      case 'Outdoor play':
        return _duration(
            ActivityType.outdoorPlay, startTime, endTime, duration);
      case 'Pump':
        return _parsePump(startTime, endTime, duration, col4);
      case 'Temp':
        return _parseTemp(startTime, col4);
      case 'Bath':
        return _duration(ActivityType.bath, startTime, endTime, duration);
      case 'Skin to skin':
        return _duration(ActivityType.skinToSkin, startTime, endTime, duration);
      case 'Potty':
        return _parsePotty(startTime, col6);
      default:
        return null;
    }
  }

  ParsedActivity _parseFeed(DateTime startTime, DateTime? endTime,
      int? duration, String col4, String col5, String col6) {
    if (col5.toLowerCase() == 'breast') {
      int? rightMin;
      int? leftMin;
      if (col4.toUpperCase().endsWith('R')) {
        rightMin = _parseBreastDuration(col4);
      }
      if (col6.toUpperCase().endsWith('L')) {
        leftMin = _parseBreastDuration(col6);
      }
      return ParsedActivity(
        type: ActivityType.feedBreast,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: duration,
        rightBreastMinutes: rightMin,
        leftBreastMinutes: leftMin,
      );
    } else {
      final feedType =
          col4.toLowerCase().contains('breast') ? 'breastMilk' : 'formula';
      return ParsedActivity(
        type: ActivityType.feedBottle,
        startTime: startTime,
        feedType: feedType,
        volumeMl: _parseVolumeMl(col6),
      );
    }
  }

  ParsedActivity _parseDiaper(
      DateTime startTime, String col3Raw, String col4, String col6) {
    final parsed = _parseDiaperContents(col6);
    return ParsedActivity(
      type: ActivityType.diaper,
      startTime: startTime,
      contents: parsed.contents,
      contentSize: parsed.size,
      peeSize: parsed.peeSize,
      pooColour: col3Raw.isNotEmpty ? col3Raw.toLowerCase() : null,
      pooConsistency: col4.isNotEmpty ? col4.toLowerCase() : null,
    );
  }

  ParsedActivity _parseMeds(DateTime startTime, String col4, String col5) {
    return ParsedActivity(
      type: ActivityType.meds,
      startTime: startTime,
      medicationName: col5.isNotEmpty ? col5 : null,
      dose: col4.isNotEmpty ? col4 : null,
    );
  }

  ParsedActivity _parseSolids(DateTime startTime, String col4, String col6) {
    String? reaction;
    switch (col6.toUpperCase()) {
      case 'LOVED':
        reaction = 'loved';
      case 'MEH':
        reaction = 'meh';
      case 'DISLIKED':
        reaction = 'disliked';
    }
    return ParsedActivity(
      type: ActivityType.solids,
      startTime: startTime,
      foodDescription: col4.isNotEmpty ? col4 : null,
      reaction: reaction,
    );
  }

  ParsedActivity _parseGrowth(
      DateTime startTime, String col4, String col5, String col6) {
    return ParsedActivity(
      type: ActivityType.growth,
      startTime: startTime,
      weightKg: _parseValueWithUnit(col4, 'kg'),
      lengthCm: _parseValueWithUnit(col5, 'cm'),
      headCircumferenceCm: _parseValueWithUnit(col6, 'cm'),
    );
  }

  ParsedActivity _duration(ActivityType activityType, DateTime startTime,
      DateTime? endTime, int? duration) {
    return ParsedActivity(
      type: activityType,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
    );
  }

  ParsedActivity _parsePump(
      DateTime startTime, DateTime? endTime, int? duration, String col4) {
    return ParsedActivity(
      type: ActivityType.pump,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
      volumeMl: _parseVolumeMl(col4),
    );
  }

  ParsedActivity _parseTemp(DateTime startTime, String col4) {
    final cleaned = col4.replaceAll('°C', '').replaceAll('°', '').trim();
    return ParsedActivity(
      type: ActivityType.temperature,
      startTime: startTime,
      tempCelsius: double.tryParse(cleaned),
    );
  }

  ParsedActivity _parsePotty(DateTime startTime, String col6) {
    final parsed = _parseDiaperContents(col6);
    return ParsedActivity(
      type: ActivityType.potty,
      startTime: startTime,
      contents: parsed.contents,
      contentSize: parsed.size,
    );
  }

  // --- Parsing helpers ---

  DateTime? _parseDateTime(String s) {
    try {
      return DateTime.parse(s.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }

  int? _parseDurationMinutes(String s) {
    if (s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  int? _parseBreastDuration(String s) {
    final cleaned = s.replaceAll(RegExp(r'[RL]$', caseSensitive: false), '');
    return _parseDurationMinutes(cleaned);
  }

  double? _parseVolumeMl(String s) {
    final cleaned = s.toLowerCase().replaceAll('ml', '').trim();
    return double.tryParse(cleaned);
  }

  double? _parseValueWithUnit(String s, String unit) {
    final cleaned = s.toLowerCase().replaceAll(unit.toLowerCase(), '').trim();
    return double.tryParse(cleaned);
  }

  String _str(dynamic v) => v?.toString().trim() ?? '';

  ({String? contents, String? size, String? peeSize}) _parseDiaperContents(
      String s) {
    final lower = s.toLowerCase().trim();

    if (lower.startsWith('both')) {
      String? pooSize;
      String? peeSize;
      final pooMatch = RegExp(r'poo:(\w+)').firstMatch(lower);
      if (pooMatch != null) pooSize = pooMatch.group(1);
      final peeMatch = RegExp(r'pee:(\w+)').firstMatch(lower);
      if (peeMatch != null) peeSize = peeMatch.group(1);
      return (contents: 'both', size: pooSize, peeSize: peeSize);
    } else if (lower.startsWith('poo')) {
      final parts = lower.split(':');
      return (
        contents: 'poo',
        size: parts.length > 1 ? parts[1].trim() : null,
        peeSize: null,
      );
    } else if (lower.startsWith('pee')) {
      final parts = lower.split(':');
      return (
        contents: 'pee',
        size: parts.length > 1 ? parts[1].trim() : null,
        peeSize: null,
      );
    }

    return (contents: null, size: null, peeSize: null);
  }
}
