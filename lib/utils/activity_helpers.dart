import 'package:flutter/material.dart';
import '../models/enums.dart';

/// Display name for an activity type.
String activityDisplayName(ActivityType type) {
  switch (type) {
    case ActivityType.feedBottle:
      return 'Bottle Feed';
    case ActivityType.feedBreast:
      return 'Breast Feed';
    case ActivityType.diaper:
      return 'Diaper';
    case ActivityType.meds:
      return 'Medication';
    case ActivityType.solids:
      return 'Solids';
    case ActivityType.growth:
      return 'Growth';
    case ActivityType.tummyTime:
      return 'Tummy Time';
    case ActivityType.indoorPlay:
      return 'Indoor Play';
    case ActivityType.outdoorPlay:
      return 'Outdoor Play';
    case ActivityType.pump:
      return 'Pump';
    case ActivityType.temperature:
      return 'Temperature';
    case ActivityType.bath:
      return 'Bath';
    case ActivityType.skinToSkin:
      return 'Skin to Skin';
    case ActivityType.potty:
      return 'Potty';
  }
}

/// Icon for an activity type.
IconData activityIcon(ActivityType type) {
  switch (type) {
    case ActivityType.feedBottle:
      return Icons.baby_changing_station;
    case ActivityType.feedBreast:
      return Icons.woman;
    case ActivityType.diaper:
      return Icons.baby_changing_station;
    case ActivityType.meds:
      return Icons.medication;
    case ActivityType.solids:
      return Icons.restaurant;
    case ActivityType.growth:
      return Icons.straighten;
    case ActivityType.tummyTime:
      return Icons.accessibility_new;
    case ActivityType.indoorPlay:
      return Icons.toys;
    case ActivityType.outdoorPlay:
      return Icons.park;
    case ActivityType.pump:
      return Icons.water_drop;
    case ActivityType.temperature:
      return Icons.thermostat;
    case ActivityType.bath:
      return Icons.bathtub;
    case ActivityType.skinToSkin:
      return Icons.favorite;
    case ActivityType.potty:
      return Icons.wc;
  }
}

/// Colour for an activity type.
Color activityColor(ActivityType type) {
  switch (type) {
    case ActivityType.feedBottle:
      return Colors.blue;
    case ActivityType.feedBreast:
      return Colors.purple;
    case ActivityType.diaper:
      return Colors.amber;
    case ActivityType.meds:
      return Colors.red;
    case ActivityType.solids:
      return Colors.orange;
    case ActivityType.growth:
      return Colors.teal;
    case ActivityType.tummyTime:
      return Colors.green;
    case ActivityType.indoorPlay:
      return Colors.indigo;
    case ActivityType.outdoorPlay:
      return Colors.lightGreen;
    case ActivityType.pump:
      return Colors.deepPurple;
    case ActivityType.temperature:
      return Colors.deepOrange;
    case ActivityType.bath:
      return Colors.cyan;
    case ActivityType.skinToSkin:
      return Colors.pink;
    case ActivityType.potty:
      return Colors.brown;
  }
}

/// Parse an ActivityType from its stored string name.
ActivityType? parseActivityType(String name) {
  for (final type in ActivityType.values) {
    if (type.name == name) return type;
  }
  return null;
}

/// Format a duration in minutes to a human-readable string.
String formatDuration(int? minutes) {
  if (minutes == null) return '';
  if (minutes < 60) return '${minutes}min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}min';
}
