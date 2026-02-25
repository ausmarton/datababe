import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

/// Single database instance shared across the app.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provides the ActivityDao.
final activityDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).activityDao;
});

/// Provides the FamilyDao.
final familyDaoProvider = Provider((ref) {
  return ref.watch(databaseProvider).familyDao;
});
