import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../local/database_provider.dart';
import '../local/store_refs.dart';

/// Key for start-of-day hour in the settings store.
const _startOfDayKey = 'startOfDayHour';

/// Watches the user's start-of-day hour (0-23, default 0 = midnight).
final startOfDayHourProvider = StreamProvider<int>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return StoreRefs.settings
      .record(_startOfDayKey)
      .onSnapshot(db)
      .map((snapshot) {
    final value = snapshot?.value['value'];
    return value is int ? value.clamp(0, 23) : 0;
  });
});

/// Updates the start-of-day hour.
Future<void> setStartOfDayHour(Database db, int hour) async {
  await StoreRefs.settings
      .record(_startOfDayKey)
      .put(db, {'value': hour.clamp(0, 23)});
}
