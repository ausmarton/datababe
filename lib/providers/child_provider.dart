import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';

/// Currently selected child ID.
final selectedChildIdProvider = StateProvider<String?>((ref) => null);

/// All children across all families.
final allChildrenProvider = StreamProvider<List<ChildrenData>>((ref) {
  final dao = ref.watch(familyDaoProvider);
  return dao.watchAllChildren();
});

/// Currently selected child.
/// Auto-selects the first child when none is explicitly selected.
final selectedChildProvider = Provider<ChildrenData?>((ref) {
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
