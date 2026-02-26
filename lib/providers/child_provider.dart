import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/child_model.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

/// Currently selected family ID.
final selectedFamilyIdProvider = StateProvider<String?>((ref) => null);

/// Currently selected child ID.
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// All children in the selected family.
final allChildrenProvider = StreamProvider<List<ChildModel>>((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final repo = ref.watch(familyRepositoryProvider);
  if (familyId == null) return Stream.value([]);
  return repo.watchChildren(familyId);
});

/// Watch families for the current user and auto-select the first one.
final userFamiliesProvider = StreamProvider((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(familyRepositoryProvider);
  return repo.watchFamilies(user.uid);
});

/// Currently selected child.
/// Auto-selects the first child when none is explicitly selected.
final selectedChildProvider = Provider<ChildModel?>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final children = ref.watch(allChildrenProvider).valueOrNull;
  if (children == null || children.isEmpty) return null;

  // Auto-select first child if none selected
  if (childId == null) {
    Future.microtask(() {
      ref.read(selectedChildIdProvider.notifier).state = children.first.id;
    });
    return children.first;
  }

  try {
    return children.firstWhere((c) => c.id == childId);
  } catch (_) {
    return null;
  }
});
