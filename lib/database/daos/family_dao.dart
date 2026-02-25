import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/families.dart';
import '../tables/children.dart';
import '../tables/carers.dart';
import '../tables/family_carers.dart';

part 'family_dao.g.dart';

@DriftAccessor(tables: [Families, Children, Carers, FamilyCarers])
class FamilyDao extends DatabaseAccessor<AppDatabase> with _$FamilyDaoMixin {
  FamilyDao(super.db);

  // --- Families ---

  Future<List<Family>> getAllFamilies() => select(families).get();

  Stream<List<Family>> watchAllFamilies() => select(families).watch();

  Future<void> insertFamily(FamiliesCompanion entry) =>
      into(families).insert(entry);

  // --- Children ---

  Stream<List<ChildrenData>> watchChildren(String familyId) {
    return (select(children)..where((c) => c.familyId.equals(familyId)))
        .watch();
  }

  Stream<List<ChildrenData>> watchAllChildren() => select(children).watch();

  Future<List<ChildrenData>> getAllChildren() => select(children).get();

  Future<ChildrenData?> getChild(String id) {
    return (select(children)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertChild(ChildrenCompanion entry) =>
      into(children).insert(entry);

  Future<void> updateChild(ChildrenCompanion entry) {
    return (update(children)..where((c) => c.id.equals(entry.id.value)))
        .write(entry);
  }

  // --- Carers ---

  Future<List<Carer>> getAllCarers() => select(carers).get();

  Stream<List<Carer>> watchAllCarers() => select(carers).watch();

  Future<void> insertCarer(CarersCompanion entry) =>
      into(carers).insert(entry);

  Future<Carer?> getCarer(String id) {
    return (select(carers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  // --- Family-Carer links ---

  Future<void> addCarerToFamily(FamilyCarersCompanion entry) =>
      into(familyCarers).insert(entry);

  Stream<List<Carer>> watchCarersInFamily(String familyId) {
    final query = select(carers).join([
      innerJoin(
        familyCarers,
        familyCarers.carerId.equalsExp(carers.id) &
            familyCarers.familyId.equals(familyId),
      ),
    ]);
    return query.watch().map(
          (rows) => rows.map((row) => row.readTable(carers)).toList(),
        );
  }
}
