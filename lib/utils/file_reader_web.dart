import 'dart:convert';

import 'package:file_picker/file_picker.dart';

Future<String> readFileContent(PlatformFile file) async {
  if (file.bytes != null) return utf8.decode(file.bytes!);
  throw Exception('Could not read file');
}
