import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

Future<String> readFileContent(PlatformFile file) async {
  if (file.bytes != null) return utf8.decode(file.bytes!);
  if (file.path != null) return File(file.path!).readAsString();
  throw Exception('Could not read file');
}
