import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:path_provider/path_provider.dart';

/// Provider for the local Sembast database.
/// Must be overridden at app startup with the opened database.
final localDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError(
    'localDatabaseProvider must be overridden with an opened Database',
  );
});

/// Opens the local Sembast database.
/// Uses IndexedDB on web, file-based on mobile/desktop.
Future<Database> openLocalDatabase() async {
  if (kIsWeb) {
    final factory = databaseFactoryWeb;
    return factory.openDatabase('datababe.db');
  } else {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/datababe.db';
    final factory = databaseFactoryIo;
    return factory.openDatabase(dbPath);
  }
}
