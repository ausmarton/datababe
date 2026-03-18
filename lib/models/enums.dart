/// Activity types that can be logged.
enum ActivityType {
  feedBottle,
  feedBreast,
  diaper,
  meds,
  solids,
  growth,
  tummyTime,
  indoorPlay,
  outdoorPlay,
  pump,
  temperature,
  bath,
  skinToSkin,
  potty,
  sleep,
}

/// Feed type for bottle feeds.
enum FeedType {
  formula,
  breastMilk,
}

/// What's in the diaper / potty.
enum DiaperContents {
  pee,
  poo,
  both,
}

/// Size descriptor for diaper/potty contents.
enum ContentSize {
  small,
  medium,
  large,
}

/// Poo colour.
enum PooColour {
  yellow,
  green,
  brown,
}

/// Poo consistency.
enum PooConsistency {
  solid,
  soft,
  diarrhea,
}

/// Reaction to solid food.
enum FoodReaction {
  loved,
  meh,
  disliked,
  none,
}

/// Carer role within a family.
enum CarerRole {
  parent,
  carer,
}

/// Status of a family invite.
enum InviteStatus {
  pending,
  accepted,
  declined,
}

/// Time window modes for timeline views.
enum TimeWindowMode {
  calendarDay,
  calendarWeek,
  calendarMonth,
  last24h,
  last7Days,
  last30Days,
}

/// Period for targets/goals.
enum TargetPeriod {
  daily,
  weekly,
  monthly,
}

/// Metric for targets/goals.
enum TargetMetric {
  totalVolumeMl,
  count,
  uniqueFoods,
  totalDurationMinutes,
  ingredientExposures,
  allergenExposures,
  allergenExposureDays,
}
