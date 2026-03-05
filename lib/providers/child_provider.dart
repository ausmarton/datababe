import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/child_model.dart';
import 'auth_provider.dart';
import 'initial_sync_provider.dart';
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

/// Watch families for the current user.
/// Depends on initialSyncProvider so the Sembast stream is created
/// AFTER sync writes data — avoids race on web where onSnapshots
/// may miss writes that happened before the stream was created.
final userFamiliesProvider = StreamProvider((ref) {
  final syncState = ref.watch(initialSyncProvider);
  if (syncState.isLoading) return Stream.value([]);

  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(familyRepositoryProvider);
  return repo.watchFamilies(user.uid);
});

/// Auto-selects the first family when none is explicitly selected.
final selectedFamilyProvider = Provider((ref) {
  final familyId = ref.watch(selectedFamilyIdProvider);
  final families = ref.watch(userFamiliesProvider).valueOrNull;
  if (families == null || families.isEmpty) return null;

  if (familyId == null) {
    Future.microtask(() {
      ref.read(selectedFamilyIdProvider.notifier).state = families.first.id;
    });
    return families.first;
  }

  try {
    return families.firstWhere((f) => f.id == familyId);
  } catch (_) {
    return null;
  }
});

/// Currently selected child.
/// Auto-selects the first child when none is explicitly selected.
/// Also triggers family auto-selection via selectedFamilyProvider.
final selectedChildProvider = Provider<ChildModel?>((ref) {
  // Watch selectedFamilyProvider to trigger auto-family-selection.
  ref.watch(selectedFamilyProvider);
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
