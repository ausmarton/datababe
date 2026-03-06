import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backup/backup_service.dart';
import '../local/database_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.watch(localDatabaseProvider));
});
