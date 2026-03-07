import '../models/family_model.dart';
import '../models/child_model.dart';
import '../models/carer_model.dart';
import 'cascaded_change.dart';

abstract class FamilyRepository {
  Stream<List<FamilyModel>> watchFamilies(String uid);

  Stream<List<ChildModel>> watchChildren(String familyId);

  Future<FamilyModel> createFamily(FamilyModel family);

  Future<ChildModel> createChild(String familyId, ChildModel child);

  Future<CarerModel> createCarer(String familyId, CarerModel carer);

  Future<void> createFamilyWithChild({
    required FamilyModel family,
    required ChildModel child,
    required CarerModel carer,
  });

  // --- Members ---

  Stream<List<CarerModel>> watchCarers(String familyId);

  Future<void> updateCarerRole(
      String familyId, String carerId, String newRole);

  Future<void> removeMember({
    required String familyId,
    required String memberUid,
    required String carerId,
  });

  // --- Allergen Categories ---

  Future<void> updateAllergenCategories(
      String familyId, List<String> categories);

  /// Rename an allergen category and cascade to ingredients, targets, and activities.
  /// Returns the list of cascaded changes (for sync enqueue).
  Future<List<CascadedChange>> renameAllergenCategory(
      String familyId, String oldName, String newName);

  /// Remove an allergen category and cascade to ingredients, targets, and activities.
  /// Targets with matching allergenName are deactivated.
  /// Returns the list of cascaded changes (for sync enqueue).
  Future<List<CascadedChange>> removeAllergenCategory(
      String familyId, String name);
}
