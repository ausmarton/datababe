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
final selectedChildProvider = Provider<ChildrenData?>((ref) {
  final childId = ref.watch(selectedChildIdProvider);
  final children = ref.watch(allChildrenProvider).valueOrNull;
  if (childId == null || children == null) return null;
  try {
    return children.firstWhere((c) => c.id == childId);
  } catch (_) {
    return null;
  }
});
