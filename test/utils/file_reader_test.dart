import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:datababe/utils/file_reader_io.dart';

void main() {
  group('readFileContent', () {
    test('returns decoded string when bytes are populated', () async {
      final content = 'hello world';
      final file = PlatformFile(
        name: 'test.txt',
        size: content.length,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );

      final result = await readFileContent(file);
      expect(result, equals(content));
    });

    test('reads from file path when bytes are null', () async {
      final tmpFile = File('${Directory.systemTemp.path}/file_reader_test.txt');
      tmpFile.writeAsStringSync('path content');
      addTearDown(() => tmpFile.deleteSync());

      final file = PlatformFile(
        name: 'test.txt',
        size: 12,
        path: tmpFile.path,
      );

      final result = await readFileContent(file);
      expect(result, equals('path content'));
    });

    test('throws when both bytes and path are null', () {
      final file = PlatformFile(
        name: 'test.txt',
        size: 0,
      );

      expect(() => readFileContent(file), throwsException);
    });
  });
}
