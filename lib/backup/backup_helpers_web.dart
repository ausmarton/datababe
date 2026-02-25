import 'dart:convert';

import 'package:file_saver/file_saver.dart';

/// Save a backup file as a browser download (web).
Future<void> saveBackupFile(String json, String filename) async {
  final bytes = utf8.encode(json);
  await FileSaver.instance.saveFile(
    name: filename,
    bytes: bytes,
    mimeType: MimeType.json,
  );
}
