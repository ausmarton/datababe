import 'dart:math';

/// WHO Child Growth Standards (0–24 months).
///
/// Data source: WHO Multicentre Growth Reference Study Group (2006).
/// Percentile values (P3, P15, P50, P85, P97) at monthly intervals.

/// Percentile values at a given age.
class GrowthPercentiles {
  final double p3;
  final double p15;
  final double p50;
  final double p85;
  final double p97;

  const GrowthPercentiles(this.p3, this.p15, this.p50, this.p85, this.p97);

  /// Estimate the percentile for a given [value] by interpolating between
  /// the standard percentile bands.
  double estimatePercentile(double value) {
    if (value <= p3) return 3.0;
    if (value >= p97) return 97.0;

    // Interpolate between adjacent bands
    final bands = [
      (3.0, p3),
      (15.0, p15),
      (50.0, p50),
      (85.0, p85),
      (97.0, p97),
    ];

    for (int i = 0; i < bands.length - 1; i++) {
      final (pctLow, valLow) = bands[i];
      final (pctHigh, valHigh) = bands[i + 1];
      if (value >= valLow && value <= valHigh) {
        final fraction = (value - valLow) / (valHigh - valLow);
        return pctLow + fraction * (pctHigh - pctLow);
      }
    }

    return 50.0; // fallback
  }
}

/// Average two GrowthPercentiles (for gender-neutral display).
GrowthPercentiles _avg(GrowthPercentiles a, GrowthPercentiles b) {
  return GrowthPercentiles(
    (a.p3 + b.p3) / 2,
    (a.p15 + b.p15) / 2,
    (a.p50 + b.p50) / 2,
    (a.p85 + b.p85) / 2,
    (a.p97 + b.p97) / 2,
  );
}

// =========================================================================
// Weight-for-age (kg), 0–24 months
// =========================================================================

const _weightBoys = <int, GrowthPercentiles>{
  0: GrowthPercentiles(2.5, 2.9, 3.3, 3.9, 4.4),
  1: GrowthPercentiles(3.4, 3.9, 4.5, 5.1, 5.8),
  2: GrowthPercentiles(4.3, 4.9, 5.6, 6.3, 7.1),
  3: GrowthPercentiles(5.0, 5.7, 6.4, 7.2, 8.0),
  4: GrowthPercentiles(5.6, 6.2, 7.0, 7.8, 8.7),
  5: GrowthPercentiles(6.0, 6.7, 7.5, 8.4, 9.3),
  6: GrowthPercentiles(6.4, 7.1, 7.9, 8.8, 9.8),
  7: GrowthPercentiles(6.7, 7.4, 8.3, 9.2, 10.3),
  8: GrowthPercentiles(6.9, 7.7, 8.6, 9.6, 10.7),
  9: GrowthPercentiles(7.1, 7.9, 8.9, 9.9, 11.0),
  10: GrowthPercentiles(7.4, 8.2, 9.2, 10.2, 11.4),
  11: GrowthPercentiles(7.6, 8.4, 9.4, 10.5, 11.7),
  12: GrowthPercentiles(7.7, 8.6, 9.6, 10.8, 12.0),
  13: GrowthPercentiles(7.9, 8.8, 9.9, 11.0, 12.3),
  14: GrowthPercentiles(8.1, 9.0, 10.1, 11.3, 12.6),
  15: GrowthPercentiles(8.3, 9.2, 10.3, 11.5, 12.8),
  16: GrowthPercentiles(8.4, 9.4, 10.5, 11.7, 13.1),
  17: GrowthPercentiles(8.6, 9.6, 10.7, 12.0, 13.4),
  18: GrowthPercentiles(8.8, 9.8, 10.9, 12.2, 13.7),
  19: GrowthPercentiles(8.9, 9.9, 11.1, 12.5, 13.9),
  20: GrowthPercentiles(9.1, 10.1, 11.3, 12.7, 14.2),
  21: GrowthPercentiles(9.2, 10.3, 11.5, 12.9, 14.5),
  22: GrowthPercentiles(9.4, 10.5, 11.8, 13.2, 14.7),
  23: GrowthPercentiles(9.5, 10.7, 12.0, 13.4, 15.0),
  24: GrowthPercentiles(9.7, 10.8, 12.2, 13.6, 15.3),
};

const _weightGirls = <int, GrowthPercentiles>{
  0: GrowthPercentiles(2.4, 2.8, 3.2, 3.7, 4.2),
  1: GrowthPercentiles(3.2, 3.6, 4.2, 4.8, 5.5),
  2: GrowthPercentiles(3.9, 4.5, 5.1, 5.8, 6.6),
  3: GrowthPercentiles(4.5, 5.2, 5.8, 6.6, 7.5),
  4: GrowthPercentiles(5.0, 5.7, 6.4, 7.3, 8.2),
  5: GrowthPercentiles(5.4, 6.1, 6.9, 7.8, 8.8),
  6: GrowthPercentiles(5.7, 6.5, 7.3, 8.2, 9.3),
  7: GrowthPercentiles(6.0, 6.8, 7.6, 8.6, 9.8),
  8: GrowthPercentiles(6.3, 7.0, 7.9, 9.0, 10.2),
  9: GrowthPercentiles(6.5, 7.3, 8.2, 9.3, 10.5),
  10: GrowthPercentiles(6.7, 7.5, 8.5, 9.6, 10.9),
  11: GrowthPercentiles(6.9, 7.7, 8.7, 9.9, 11.2),
  12: GrowthPercentiles(7.0, 7.9, 8.9, 10.1, 11.5),
  13: GrowthPercentiles(7.2, 8.1, 9.2, 10.4, 11.8),
  14: GrowthPercentiles(7.4, 8.3, 9.4, 10.6, 12.1),
  15: GrowthPercentiles(7.6, 8.5, 9.6, 10.9, 12.4),
  16: GrowthPercentiles(7.7, 8.7, 9.8, 11.1, 12.6),
  17: GrowthPercentiles(7.9, 8.9, 10.0, 11.4, 12.9),
  18: GrowthPercentiles(8.1, 9.1, 10.2, 11.6, 13.2),
  19: GrowthPercentiles(8.2, 9.2, 10.4, 11.8, 13.5),
  20: GrowthPercentiles(8.4, 9.4, 10.6, 12.1, 13.7),
  21: GrowthPercentiles(8.6, 9.6, 10.9, 12.3, 14.0),
  22: GrowthPercentiles(8.7, 9.8, 11.1, 12.5, 14.3),
  23: GrowthPercentiles(8.9, 10.0, 11.3, 12.8, 14.6),
  24: GrowthPercentiles(9.0, 10.2, 11.5, 13.0, 14.8),
};

// =========================================================================
// Length-for-age (cm), 0–24 months
// =========================================================================

const _lengthBoys = <int, GrowthPercentiles>{
  0: GrowthPercentiles(46.3, 48.0, 49.9, 51.8, 53.4),
  1: GrowthPercentiles(50.8, 52.4, 54.7, 56.7, 58.6),
  2: GrowthPercentiles(54.4, 56.2, 58.4, 60.6, 62.4),
  3: GrowthPercentiles(57.3, 59.1, 61.4, 63.5, 65.5),
  4: GrowthPercentiles(59.7, 61.5, 63.9, 66.0, 68.0),
  5: GrowthPercentiles(61.7, 63.6, 65.9, 68.2, 70.1),
  6: GrowthPercentiles(63.3, 65.2, 67.6, 69.9, 71.9),
  7: GrowthPercentiles(64.8, 66.7, 69.2, 71.5, 73.5),
  8: GrowthPercentiles(66.2, 68.1, 70.6, 72.9, 75.0),
  9: GrowthPercentiles(67.5, 69.5, 72.0, 74.3, 76.5),
  10: GrowthPercentiles(68.7, 70.7, 73.3, 75.6, 77.9),
  11: GrowthPercentiles(69.9, 71.9, 74.5, 76.9, 79.2),
  12: GrowthPercentiles(71.0, 73.0, 75.7, 78.1, 80.5),
  13: GrowthPercentiles(72.1, 74.1, 76.9, 79.3, 81.8),
  14: GrowthPercentiles(73.1, 75.2, 78.0, 80.5, 83.0),
  15: GrowthPercentiles(74.1, 76.2, 79.1, 81.7, 84.2),
  16: GrowthPercentiles(75.0, 77.2, 80.2, 82.8, 85.4),
  17: GrowthPercentiles(76.0, 78.2, 81.2, 83.9, 86.5),
  18: GrowthPercentiles(76.9, 79.1, 82.3, 85.0, 87.7),
  19: GrowthPercentiles(77.7, 80.1, 83.2, 86.1, 88.8),
  20: GrowthPercentiles(78.6, 81.0, 84.2, 87.1, 89.8),
  21: GrowthPercentiles(79.4, 81.9, 85.1, 88.1, 90.9),
  22: GrowthPercentiles(80.2, 82.8, 86.0, 89.1, 91.9),
  23: GrowthPercentiles(81.0, 83.6, 86.9, 90.0, 92.9),
  24: GrowthPercentiles(81.7, 84.4, 87.8, 90.9, 93.9),
};

const _lengthGirls = <int, GrowthPercentiles>{
  0: GrowthPercentiles(45.4, 47.2, 49.1, 51.0, 52.9),
  1: GrowthPercentiles(49.8, 51.4, 53.7, 55.6, 57.6),
  2: GrowthPercentiles(53.0, 54.8, 57.1, 59.2, 61.1),
  3: GrowthPercentiles(55.6, 57.5, 59.8, 62.0, 64.0),
  4: GrowthPercentiles(57.8, 59.7, 62.1, 64.3, 66.4),
  5: GrowthPercentiles(59.6, 61.5, 64.0, 66.2, 68.5),
  6: GrowthPercentiles(61.2, 63.2, 65.7, 68.0, 70.3),
  7: GrowthPercentiles(62.7, 64.7, 67.3, 69.6, 72.0),
  8: GrowthPercentiles(64.0, 66.0, 68.7, 71.1, 73.5),
  9: GrowthPercentiles(65.3, 67.3, 70.1, 72.6, 75.0),
  10: GrowthPercentiles(66.5, 68.5, 71.5, 74.0, 76.4),
  11: GrowthPercentiles(67.7, 69.8, 72.8, 75.3, 77.8),
  12: GrowthPercentiles(68.9, 71.0, 74.0, 76.6, 79.2),
  13: GrowthPercentiles(70.0, 72.1, 75.2, 77.8, 80.5),
  14: GrowthPercentiles(71.0, 73.2, 76.4, 79.1, 81.7),
  15: GrowthPercentiles(72.0, 74.3, 77.5, 80.2, 83.0),
  16: GrowthPercentiles(73.0, 75.3, 78.6, 81.4, 84.2),
  17: GrowthPercentiles(74.0, 76.3, 79.7, 82.5, 85.4),
  18: GrowthPercentiles(74.9, 77.3, 80.7, 83.6, 86.5),
  19: GrowthPercentiles(75.8, 78.2, 81.7, 84.7, 87.6),
  20: GrowthPercentiles(76.7, 79.2, 82.7, 85.7, 88.7),
  21: GrowthPercentiles(77.5, 80.0, 83.7, 86.7, 89.8),
  22: GrowthPercentiles(78.4, 80.9, 84.6, 87.7, 90.8),
  23: GrowthPercentiles(79.2, 81.8, 85.5, 88.7, 91.9),
  24: GrowthPercentiles(80.0, 82.7, 86.4, 89.6, 92.9),
};

// =========================================================================
// Head circumference-for-age (cm), 0–24 months
// =========================================================================

const _headBoys = <int, GrowthPercentiles>{
  0: GrowthPercentiles(32.1, 33.1, 34.5, 35.8, 36.9),
  1: GrowthPercentiles(34.9, 35.9, 37.3, 38.5, 39.6),
  2: GrowthPercentiles(36.8, 37.8, 39.1, 40.3, 41.5),
  3: GrowthPercentiles(38.1, 39.1, 40.5, 41.7, 42.9),
  4: GrowthPercentiles(39.2, 40.2, 41.6, 42.8, 43.9),
  5: GrowthPercentiles(40.1, 41.1, 42.6, 43.7, 44.8),
  6: GrowthPercentiles(40.9, 41.9, 43.3, 44.5, 45.6),
  7: GrowthPercentiles(41.5, 42.5, 44.0, 45.2, 46.3),
  8: GrowthPercentiles(42.0, 43.1, 44.5, 45.8, 46.9),
  9: GrowthPercentiles(42.5, 43.5, 45.0, 46.3, 47.4),
  10: GrowthPercentiles(42.9, 43.9, 45.4, 46.7, 47.9),
  11: GrowthPercentiles(43.2, 44.3, 45.8, 47.0, 48.3),
  12: GrowthPercentiles(43.5, 44.6, 46.1, 47.4, 48.6),
  13: GrowthPercentiles(43.8, 44.9, 46.3, 47.6, 48.9),
  14: GrowthPercentiles(44.0, 45.1, 46.6, 47.9, 49.2),
  15: GrowthPercentiles(44.2, 45.3, 46.8, 48.1, 49.4),
  16: GrowthPercentiles(44.4, 45.5, 47.0, 48.3, 49.6),
  17: GrowthPercentiles(44.5, 45.7, 47.2, 48.5, 49.8),
  18: GrowthPercentiles(44.7, 45.8, 47.4, 48.7, 50.0),
  19: GrowthPercentiles(44.8, 46.0, 47.5, 48.9, 50.2),
  20: GrowthPercentiles(45.0, 46.1, 47.7, 49.0, 50.4),
  21: GrowthPercentiles(45.1, 46.2, 47.8, 49.2, 50.5),
  22: GrowthPercentiles(45.2, 46.4, 48.0, 49.3, 50.7),
  23: GrowthPercentiles(45.3, 46.5, 48.1, 49.5, 50.8),
  24: GrowthPercentiles(45.5, 46.6, 48.3, 49.6, 51.0),
};

const _headGirls = <int, GrowthPercentiles>{
  0: GrowthPercentiles(31.5, 32.4, 33.9, 35.0, 36.2),
  1: GrowthPercentiles(34.2, 35.1, 36.5, 37.8, 38.9),
  2: GrowthPercentiles(35.8, 36.8, 38.3, 39.5, 40.7),
  3: GrowthPercentiles(37.1, 38.1, 39.5, 40.8, 42.0),
  4: GrowthPercentiles(38.1, 39.1, 40.6, 41.8, 43.0),
  5: GrowthPercentiles(38.9, 40.0, 41.5, 42.7, 43.9),
  6: GrowthPercentiles(39.6, 40.7, 42.2, 43.4, 44.6),
  7: GrowthPercentiles(40.2, 41.3, 42.8, 44.1, 45.3),
  8: GrowthPercentiles(40.7, 41.8, 43.4, 44.6, 45.8),
  9: GrowthPercentiles(41.2, 42.3, 43.8, 45.1, 46.3),
  10: GrowthPercentiles(41.5, 42.7, 44.2, 45.5, 46.7),
  11: GrowthPercentiles(41.9, 43.0, 44.6, 45.9, 47.1),
  12: GrowthPercentiles(42.2, 43.3, 44.9, 46.2, 47.5),
  13: GrowthPercentiles(42.4, 43.6, 45.2, 46.5, 47.8),
  14: GrowthPercentiles(42.7, 43.8, 45.4, 46.7, 48.0),
  15: GrowthPercentiles(42.9, 44.0, 45.7, 47.0, 48.3),
  16: GrowthPercentiles(43.1, 44.2, 45.9, 47.2, 48.5),
  17: GrowthPercentiles(43.2, 44.4, 46.0, 47.4, 48.7),
  18: GrowthPercentiles(43.4, 44.6, 46.2, 47.5, 48.9),
  19: GrowthPercentiles(43.5, 44.7, 46.3, 47.7, 49.0),
  20: GrowthPercentiles(43.7, 44.9, 46.5, 47.9, 49.2),
  21: GrowthPercentiles(43.8, 45.0, 46.7, 48.0, 49.4),
  22: GrowthPercentiles(43.9, 45.1, 46.8, 48.2, 49.5),
  23: GrowthPercentiles(44.1, 45.3, 46.9, 48.3, 49.7),
  24: GrowthPercentiles(44.2, 45.4, 47.0, 48.4, 49.8),
};

// =========================================================================
// Public API
// =========================================================================

enum GrowthStandardMetric { weight, length, head }

/// Get the WHO percentile data for a given metric, age in months, and gender.
///
/// [gender] should be 'male', 'female', or null. When null, returns the
/// average of boy and girl values.
/// [ageMonths] is clamped to 0–24.
GrowthPercentiles? getWhoPercentiles({
  required GrowthStandardMetric metric,
  required int ageMonths,
  String? gender,
}) {
  final month = ageMonths.clamp(0, 24);

  final Map<int, GrowthPercentiles> boys;
  final Map<int, GrowthPercentiles> girls;

  switch (metric) {
    case GrowthStandardMetric.weight:
      boys = _weightBoys;
      girls = _weightGirls;
    case GrowthStandardMetric.length:
      boys = _lengthBoys;
      girls = _lengthGirls;
    case GrowthStandardMetric.head:
      boys = _headBoys;
      girls = _headGirls;
  }

  if (gender == 'male') return boys[month];
  if (gender == 'female') return girls[month];

  // Average for unknown gender
  final b = boys[month];
  final g = girls[month];
  if (b == null || g == null) return null;
  return _avg(b, g);
}

/// Compute the child's age in months at a given date.
int ageInMonths(DateTime dateOfBirth, DateTime measurementDate) {
  int months = (measurementDate.year - dateOfBirth.year) * 12 +
      measurementDate.month - dateOfBirth.month;
  if (measurementDate.day < dateOfBirth.day) months--;
  return max(0, months);
}

/// Compute percentile for a single measurement.
double? computePercentile({
  required GrowthStandardMetric metric,
  required double value,
  required DateTime dateOfBirth,
  required DateTime measurementDate,
  String? gender,
}) {
  final months = ageInMonths(dateOfBirth, measurementDate);
  if (months > 24) return null;
  final pct = getWhoPercentiles(
    metric: metric,
    ageMonths: months,
    gender: gender,
  );
  return pct?.estimatePercentile(value);
}
