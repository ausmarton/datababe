import 'package:uuid/uuid.dart';

import 'activity_model.dart';

/// A staged entry for bulk-add. Wraps an ActivityModel template with mutable
/// time fields so the user can adjust before saving.
class BulkEntry {
  final String id;
  final ActivityModel template;
  DateTime startTime;
  DateTime? endTime;

  BulkEntry({
    String? id,
    required this.template,
    required this.startTime,
    this.endTime,
  }) : id = id ?? const Uuid().v4();

  /// Creates a new ActivityModel from this staged entry.
  ActivityModel toActivityModel({
    required String childId,
    required DateTime now,
    String? createdBy,
  }) {
    return ActivityModel(
      id: const Uuid().v4(),
      childId: childId,
      type: template.type,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: endTime != null
          ? endTime!.difference(startTime).inMinutes
          : template.durationMinutes,
      createdBy: createdBy,
      createdAt: now,
      modifiedAt: now,
      notes: template.notes,
      feedType: template.feedType,
      volumeMl: template.volumeMl,
      rightBreastMinutes: template.rightBreastMinutes,
      leftBreastMinutes: template.leftBreastMinutes,
      contents: template.contents,
      contentSize: template.contentSize,
      pooColour: template.pooColour,
      pooConsistency: template.pooConsistency,
      peeSize: template.peeSize,
      medicationName: template.medicationName,
      dose: template.dose,
      doseUnit: template.doseUnit,
      foodDescription: template.foodDescription,
      reaction: template.reaction,
      recipeId: template.recipeId,
      ingredientNames: template.ingredientNames,
      allergenNames: template.allergenNames,
      weightKg: template.weightKg,
      lengthCm: template.lengthCm,
      headCircumferenceCm: template.headCircumferenceCm,
      tempCelsius: template.tempCelsius,
    );
  }
}
