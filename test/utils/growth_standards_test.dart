import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/utils/growth_standards.dart';

void main() {
  // =========================================================================
  // ageInMonths
  // =========================================================================

  group('ageInMonths', () {
    test('same date is 0 months', () {
      expect(ageInMonths(DateTime(2025, 9, 1), DateTime(2025, 9, 1)), 0);
    });

    test('exactly 6 months later', () {
      expect(ageInMonths(DateTime(2025, 9, 1), DateTime(2026, 3, 1)), 6);
    });

    test('day before month boundary reduces by 1', () {
      // Born Sep 15, measured Oct 14 = still 0 months (day < dob day)
      expect(ageInMonths(DateTime(2025, 9, 15), DateTime(2025, 10, 14)), 0);
    });

    test('day on or after month boundary counts the month', () {
      expect(ageInMonths(DateTime(2025, 9, 15), DateTime(2025, 10, 15)), 1);
    });

    test('24 months', () {
      expect(ageInMonths(DateTime(2024, 3, 1), DateTime(2026, 3, 1)), 24);
    });

    test('never negative', () {
      // Measurement before birth
      expect(ageInMonths(DateTime(2026, 3, 1), DateTime(2025, 9, 1)), 0);
    });
  });

  // =========================================================================
  // getWhoPercentiles
  // =========================================================================

  group('getWhoPercentiles', () {
    test('returns data for male weight at 6 months', () {
      final p = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: 6,
        gender: 'male',
      )!;
      expect(p.p50, 7.9);
      expect(p.p3, 6.4);
      expect(p.p97, 9.8);
    });

    test('returns data for female length at 12 months', () {
      final p = getWhoPercentiles(
        metric: GrowthStandardMetric.length,
        ageMonths: 12,
        gender: 'female',
      )!;
      expect(p.p50, 74.0);
    });

    test('returns data for head at birth (male)', () {
      final p = getWhoPercentiles(
        metric: GrowthStandardMetric.head,
        ageMonths: 0,
        gender: 'male',
      )!;
      expect(p.p50, 34.5);
    });

    test('null gender returns average of male and female', () {
      final avg = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: 6,
      )!;
      final male = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: 6,
        gender: 'male',
      )!;
      final female = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: 6,
        gender: 'female',
      )!;
      expect(avg.p50, (male.p50 + female.p50) / 2);
      expect(avg.p3, (male.p3 + female.p3) / 2);
    });

    test('ageMonths clamped to 0-24', () {
      final p = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: 30,
        gender: 'male',
      )!;
      // Should return month 24 data
      expect(p.p50, 12.2);
    });

    test('negative ageMonths clamped to 0', () {
      final p = getWhoPercentiles(
        metric: GrowthStandardMetric.weight,
        ageMonths: -5,
        gender: 'male',
      )!;
      expect(p.p50, 3.3); // month 0 boys weight
    });
  });

  // =========================================================================
  // GrowthPercentiles.estimatePercentile
  // =========================================================================

  group('GrowthPercentiles.estimatePercentile', () {
    // Using boys weight at 6 months: P3=6.4, P15=7.1, P50=7.9, P85=8.8, P97=9.8
    final p6m = getWhoPercentiles(
      metric: GrowthStandardMetric.weight,
      ageMonths: 6,
      gender: 'male',
    )!;

    test('value at P50 returns 50', () {
      expect(p6m.estimatePercentile(7.9), 50.0);
    });

    test('value at P3 returns 3', () {
      expect(p6m.estimatePercentile(6.4), 3.0);
    });

    test('value at P97 returns 97', () {
      expect(p6m.estimatePercentile(9.8), 97.0);
    });

    test('value below P3 returns 3', () {
      expect(p6m.estimatePercentile(5.0), 3.0);
    });

    test('value above P97 returns 97', () {
      expect(p6m.estimatePercentile(11.0), 97.0);
    });

    test('value between P15 and P50 interpolates', () {
      // Midpoint between P15=7.1 and P50=7.9 → ~32.5
      final result = p6m.estimatePercentile(7.5);
      expect(result, greaterThan(15.0));
      expect(result, lessThan(50.0));
      // 7.5 is 0.4/0.8 = 0.5 of the way from 7.1 to 7.9 → 15 + 0.5*35 = 32.5
      expect(result, closeTo(32.5, 0.1));
    });

    test('value between P85 and P97 interpolates', () {
      final result = p6m.estimatePercentile(9.3);
      expect(result, greaterThan(85.0));
      expect(result, lessThan(97.0));
    });
  });

  // =========================================================================
  // computePercentile
  // =========================================================================

  group('computePercentile', () {
    test('computes percentile for weight measurement', () {
      final pct = computePercentile(
        metric: GrowthStandardMetric.weight,
        value: 7.9,
        dateOfBirth: DateTime(2025, 9, 1),
        measurementDate: DateTime(2026, 3, 1), // 6 months
        gender: 'male',
      );
      expect(pct, 50.0);
    });

    test('returns null for age > 24 months', () {
      final pct = computePercentile(
        metric: GrowthStandardMetric.weight,
        value: 12.0,
        dateOfBirth: DateTime(2023, 1, 1),
        measurementDate: DateTime(2026, 3, 1), // ~38 months
        gender: 'male',
      );
      expect(pct, isNull);
    });

    test('works without gender (uses average)', () {
      final pct = computePercentile(
        metric: GrowthStandardMetric.length,
        value: 67.0,
        dateOfBirth: DateTime(2025, 9, 1),
        measurementDate: DateTime(2026, 3, 1), // 6 months
      );
      expect(pct, isNotNull);
      expect(pct, greaterThan(0));
      expect(pct, lessThan(100));
    });
  });
}
