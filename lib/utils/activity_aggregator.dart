import '../models/activity_model.dart';
import '../models/enums.dart';

class ActivitySummary {
  final int totalCount;

  // Bottle feeds
  final int bottleFeedCount;
  final double bottleFeedTotalMl;

  // Breast feeds
  final int breastFeedCount;
  final int breastFeedTotalMinutes;

  // Diapers
  final int diaperCount;
  final Map<String, int> diaperBreakdown; // contents -> count

  // Solids
  final int solidsCount;
  final Set<String> uniqueFoods;
  final Map<String, int> reactionBreakdown;

  // Meds
  final Map<String, int> medsBreakdown; // name -> count

  // Growth (latest in range)
  final double? latestWeightKg;
  final double? latestLengthCm;
  final double? latestHeadCm;

  // Temperature
  final double? latestTempC;
  final double? minTempC;
  final double? maxTempC;

  // Duration activities: type -> total minutes
  final Map<String, int> durationTotals;
  final Map<String, int> durationCounts;

  // Pump
  final int pumpCount;
  final double pumpTotalMl;

  // Potty
  final int pottyCount;
  final Map<String, int> pottyBreakdown;

  // Ingredient exposures
  final Map<String, int> ingredientExposures;

  // Allergen exposures
  final Map<String, int> allergenExposures;

  // Allergen exposure days (distinct calendar days per allergen)
  final Map<String, int> allergenExposureDays;

  const ActivitySummary({
    required this.totalCount,
    required this.bottleFeedCount,
    required this.bottleFeedTotalMl,
    required this.breastFeedCount,
    required this.breastFeedTotalMinutes,
    required this.diaperCount,
    required this.diaperBreakdown,
    required this.solidsCount,
    required this.uniqueFoods,
    required this.reactionBreakdown,
    required this.medsBreakdown,
    this.latestWeightKg,
    this.latestLengthCm,
    this.latestHeadCm,
    this.latestTempC,
    this.minTempC,
    this.maxTempC,
    required this.durationTotals,
    required this.durationCounts,
    required this.pumpCount,
    required this.pumpTotalMl,
    required this.pottyCount,
    required this.pottyBreakdown,
    required this.ingredientExposures,
    required this.allergenExposures,
    required this.allergenExposureDays,
  });
}

class ActivityAggregator {
  static ActivitySummary compute(List<ActivityModel> activities) {
    int bottleFeedCount = 0;
    double bottleFeedTotalMl = 0;
    int breastFeedCount = 0;
    int breastFeedTotalMinutes = 0;
    int diaperCount = 0;
    final diaperBreakdown = <String, int>{};
    int solidsCount = 0;
    final uniqueFoods = <String>{};
    final reactionBreakdown = <String, int>{};
    final medsBreakdown = <String, int>{};

    double? latestWeightKg;
    double? latestLengthCm;
    double? latestHeadCm;
    DateTime? latestGrowthTime;

    double? latestTempC;
    double? minTempC;
    double? maxTempC;

    final durationTotals = <String, int>{};
    final durationCounts = <String, int>{};

    int pumpCount = 0;
    double pumpTotalMl = 0;
    int pottyCount = 0;
    final pottyBreakdown = <String, int>{};
    final ingredientExposures = <String, int>{};
    final allergenExposures = <String, int>{};
    final allergenDaySets = <String, Set<String>>{};

    for (final a in activities) {
      final type = ActivityType.values
          .where((t) => t.name == a.type)
          .firstOrNull;
      if (type == null) continue;

      switch (type) {
        case ActivityType.feedBottle:
          bottleFeedCount++;
          if (a.volumeMl != null) bottleFeedTotalMl += a.volumeMl!;

        case ActivityType.feedBreast:
          breastFeedCount++;
          final total = (a.rightBreastMinutes ?? 0) +
              (a.leftBreastMinutes ?? 0);
          if (total > 0) {
            breastFeedTotalMinutes += total;
          } else if (a.durationMinutes != null) {
            breastFeedTotalMinutes += a.durationMinutes!;
          }

        case ActivityType.diaper:
          diaperCount++;
          if (a.contents != null) {
            diaperBreakdown[a.contents!] =
                (diaperBreakdown[a.contents!] ?? 0) + 1;
          }

        case ActivityType.solids:
          solidsCount++;
          if (a.foodDescription != null) {
            for (final food in a.foodDescription!.split(',')) {
              final trimmed = food.trim().toLowerCase();
              if (trimmed.isNotEmpty) uniqueFoods.add(trimmed);
            }
          }
          if (a.reaction != null) {
            reactionBreakdown[a.reaction!] =
                (reactionBreakdown[a.reaction!] ?? 0) + 1;
          }
          // Count ingredient exposures
          if (a.ingredientNames != null && a.ingredientNames!.isNotEmpty) {
            for (final ingredient in a.ingredientNames!) {
              final n = ingredient.trim().toLowerCase();
              if (n.isNotEmpty) {
                ingredientExposures[n] =
                    (ingredientExposures[n] ?? 0) + 1;
              }
            }
          } else if (a.foodDescription != null) {
            for (final food in a.foodDescription!.split(',')) {
              final n = food.trim().toLowerCase();
              if (n.isNotEmpty) {
                ingredientExposures[n] =
                    (ingredientExposures[n] ?? 0) + 1;
              }
            }
          }
          // Count allergen exposures + distinct days
          if (a.allergenNames != null) {
            final dayKey =
                '${a.startTime.year}-${a.startTime.month}-${a.startTime.day}';
            for (final allergen in a.allergenNames!) {
              final n = allergen.trim().toLowerCase();
              if (n.isNotEmpty) {
                allergenExposures[n] =
                    (allergenExposures[n] ?? 0) + 1;
                (allergenDaySets[n] ??= {}).add(dayKey);
              }
            }
          }

        case ActivityType.meds:
          final name = a.medicationName ?? 'Unknown';
          medsBreakdown[name] = (medsBreakdown[name] ?? 0) + 1;

        case ActivityType.growth:
          if (latestGrowthTime == null ||
              a.startTime.isAfter(latestGrowthTime)) {
            latestGrowthTime = a.startTime;
            if (a.weightKg != null) latestWeightKg = a.weightKg;
            if (a.lengthCm != null) latestLengthCm = a.lengthCm;
            if (a.headCircumferenceCm != null) {
              latestHeadCm = a.headCircumferenceCm;
            }
          }

        case ActivityType.temperature:
          final temp = a.tempCelsius;
          if (temp != null) {
            latestTempC = temp;
            if (minTempC == null || temp < minTempC) {
              minTempC = temp;
            }
            if (maxTempC == null || temp > maxTempC) {
              maxTempC = temp;
            }
          }

        case ActivityType.pump:
          pumpCount++;
          if (a.volumeMl != null) pumpTotalMl += a.volumeMl!;
          if (a.durationMinutes != null) {
            durationTotals[type.name] =
                (durationTotals[type.name] ?? 0) + a.durationMinutes!;
            durationCounts[type.name] =
                (durationCounts[type.name] ?? 0) + 1;
          }

        case ActivityType.potty:
          pottyCount++;
          if (a.contents != null) {
            pottyBreakdown[a.contents!] =
                (pottyBreakdown[a.contents!] ?? 0) + 1;
          }

        case ActivityType.tummyTime:
        case ActivityType.indoorPlay:
        case ActivityType.outdoorPlay:
        case ActivityType.bath:
        case ActivityType.skinToSkin:
          if (a.durationMinutes != null) {
            durationTotals[type.name] =
                (durationTotals[type.name] ?? 0) + a.durationMinutes!;
            durationCounts[type.name] =
                (durationCounts[type.name] ?? 0) + 1;
          }
      }
    }

    return ActivitySummary(
      totalCount: activities.length,
      bottleFeedCount: bottleFeedCount,
      bottleFeedTotalMl: bottleFeedTotalMl,
      breastFeedCount: breastFeedCount,
      breastFeedTotalMinutes: breastFeedTotalMinutes,
      diaperCount: diaperCount,
      diaperBreakdown: diaperBreakdown,
      solidsCount: solidsCount,
      uniqueFoods: uniqueFoods,
      reactionBreakdown: reactionBreakdown,
      medsBreakdown: medsBreakdown,
      latestWeightKg: latestWeightKg,
      latestLengthCm: latestLengthCm,
      latestHeadCm: latestHeadCm,
      latestTempC: latestTempC,
      minTempC: minTempC,
      maxTempC: maxTempC,
      durationTotals: durationTotals,
      durationCounts: durationCounts,
      pumpCount: pumpCount,
      pumpTotalMl: pumpTotalMl,
      pottyCount: pottyCount,
      pottyBreakdown: pottyBreakdown,
      ingredientExposures: ingredientExposures,
      allergenExposures: allergenExposures,
      allergenExposureDays: {
        for (final e in allergenDaySets.entries) e.key: e.value.length,
      },
    );
  }
}
