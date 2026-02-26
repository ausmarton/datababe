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
