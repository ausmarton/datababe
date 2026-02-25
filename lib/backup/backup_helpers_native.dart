import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Save a backup file using the native share sheet (Android).
Future<void> saveBackupFile(String json, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(utf8.encode(json));

  await Share.shareXFiles([XFile(file.path)]);
}
