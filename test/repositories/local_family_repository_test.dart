import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:datababe/models/family_model.dart';
import 'package:datababe/models/child_model.dart';
import 'package:datababe/models/carer_model.dart';
import 'package:datababe/repositories/local_family_repository.dart';

void main() {
  late LocalFamilyRepository repo;
  const uid = 'uid-1';

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('test.db');
    repo = LocalFamilyRepository(db);
  });

  final now = DateTime(2026, 3, 1);

  FamilyModel makeFamily(String id) => FamilyModel(
        id: id,
        name: 'Test Family',
        createdBy: uid,
        memberUids: [uid],
        createdAt: now,
        modifiedAt: now,
      );

  test('createFamily and watchFamilies returns family', () async {
    await repo.createFamily(makeFamily('fam-1'));
    final list = await repo.watchFamilies(uid).first;
    expect(list.length, 1);
    expect(list.first.name, 'Test Family');
  });

  test('watchFamilies filters by uid membership', () async {
    await repo.createFamily(makeFamily('fam-2'));
    final list = await repo.watchFamilies('other-uid').first;
    expect(list, isEmpty);
  });

  test('createFamilyWithChild creates all three entities', () async {
    final family = makeFamily('fam-3');
    final child = ChildModel(
      id: 'child-1',
      name: 'Baby',
      dateOfBirth: DateTime(2025, 6, 1),
      createdAt: now,
      modifiedAt: now,
    );
    final carer = CarerModel(
      id: 'carer-1',
      uid: uid,
      displayName: 'Parent',
      role: 'parent',
      createdAt: now,
      modifiedAt: now,
    );

    await repo.createFamilyWithChild(
      family: family,
      child: child,
      carer: carer,
    );

    final families = await repo.watchFamilies(uid).first;
    expect(families.length, 1);

    final children = await repo.watchChildren('fam-3').first;
    expect(children.length, 1);
    expect(children.first.name, 'Baby');

    final carers = await repo.watchCarers('fam-3').first;
    expect(carers.length, 1);
    expect(carers.first.displayName, 'Parent');
  });

  test('updateAllergenCategories modifies family', () async {
    await repo.createFamily(makeFamily('fam-4'));
    await repo.updateAllergenCategories('fam-4', ['lactose', 'nuts']);
    final families = await repo.watchFamilies(uid).first;
    expect(families.first.allergenCategories, ['lactose', 'nuts']);
  });

  test('removeMember removes uid from family and deletes carer', () async {
    final family = FamilyModel(
      id: 'fam-5',
      name: 'Test',
      createdBy: uid,
      memberUids: [uid, 'uid-2'],
      createdAt: now,
      modifiedAt: now,
    );
    await repo.createFamily(family);
    final carer = CarerModel(
      id: 'carer-2',
      uid: 'uid-2',
      displayName: 'Carer 2',
      role: 'carer',
      createdAt: now,
      modifiedAt: now,
    );
    await repo.createCarer('fam-5', carer);

    await repo.removeMember(
      familyId: 'fam-5',
      memberUid: 'uid-2',
      carerId: 'carer-2',
    );

    final families = await repo.watchFamilies(uid).first;
    expect(families.first.memberUids, [uid]);

    final carers = await repo.watchCarers('fam-5').first;
    expect(carers, isEmpty);
  });
}
