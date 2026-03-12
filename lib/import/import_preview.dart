import '../models/activity_model.dart';
import '../models/enums.dart';
import 'csv_parser.dart';

/// Classification of a CSV row during import analysis.
enum CandidateStatus {
  /// No fingerprint match — will be imported.
  newActivity,

  /// Fingerprint matches an existing record.
  duplicate,

  /// Row failed parsing.
  parseError,
}

/// A single CSV row classified for import preview.
class ImportCandidate {
  /// 1-based CSV row number (for display).
  final int rowNumber;

  /// Classification of this row.
  final CandidateStatus status;

  /// The built ActivityModel (non-null for newActivity/duplicate).
  final ActivityModel? model;

  /// The parsed activity data (non-null for newActivity/duplicate).
  final ParsedActivity? parsed;

  /// Parse error details (non-null for parseError).
  final ParseError? error;

  /// Parsed activity type (null for errors).
  final ActivityType? type;

  /// Parsed start time (null for errors).
  final DateTime? startTime;

  const ImportCandidate({
    required this.rowNumber,
    required this.status,
    this.model,
    this.parsed,
    this.error,
    this.type,
    this.startTime,
  });
}

/// Filter criteria for the import preview.
class ImportFilter {
  /// Inclusive start date (null = no lower bound).
  final DateTime? dateFrom;

  /// Inclusive end date (null = no upper bound).
  final DateTime? dateTo;

  /// Activity types to exclude (empty = include all).
  final Set<ActivityType> excludedTypes;

  const ImportFilter({
    this.dateFrom,
    this.dateTo,
    this.excludedTypes = const {},
  });

  /// Returns true if the candidate passes this filter.
  /// Parse errors always pass regardless of filter settings.
  bool matches(ImportCandidate c) {
    if (c.status == CandidateStatus.parseError) return true;

    final time = c.startTime;
    if (time != null) {
      if (dateFrom != null && time.isBefore(dateFrom!)) return false;
      if (dateTo != null && time.isAfter(dateTo!)) return false;
    }

    final t = c.type;
    if (t != null && excludedTypes.contains(t)) return false;

    return true;
  }

  ImportFilter copyWith({
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    Set<ActivityType>? excludedTypes,
  }) {
    return ImportFilter(
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      excludedTypes: excludedTypes ?? this.excludedTypes,
    );
  }
}

/// Result of analyzing a CSV file before import.
class ImportPreview {
  final List<ImportCandidate> candidates;
  final String childId;
  final String familyId;

  const ImportPreview({
    required this.candidates,
    required this.childId,
    required this.familyId,
  });

  int get totalRows => candidates.length;

  int get newCount =>
      candidates.where((c) => c.status == CandidateStatus.newActivity).length;

  int get duplicateCount =>
      candidates.where((c) => c.status == CandidateStatus.duplicate).length;

  int get errorCount =>
      candidates.where((c) => c.status == CandidateStatus.parseError).length;

  /// Earliest start time across all parseable candidates.
  DateTime? get minDate {
    DateTime? min;
    for (final c in candidates) {
      final t = c.startTime;
      if (t != null && (min == null || t.isBefore(min))) min = t;
    }
    return min;
  }

  /// Latest start time across all parseable candidates.
  DateTime? get maxDate {
    DateTime? max;
    for (final c in candidates) {
      final t = c.startTime;
      if (t != null && (max == null || t.isAfter(max))) max = t;
    }
    return max;
  }

  /// All unique activity types present in parseable candidates.
  Set<ActivityType> get presentTypes {
    final types = <ActivityType>{};
    for (final c in candidates) {
      if (c.type != null) types.add(c.type!);
    }
    return types;
  }
}
