import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';

import '../../import/csv_importer.dart';

/// Dialog showing CSV import results with optional reject download.
class ImportResultDialog extends StatelessWidget {
  final ImportResult result;
  const ImportResultDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import complete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Imported: ${result.imported}'),
            if (result.skipped > 0)
              Text('Skipped (duplicates): ${result.skipped}'),
            if (result.parseErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Parse errors: ${result.parseErrors.length}',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 4),
              ...result.parseErrors.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text(
                      'Row ${e.rowNumber}: ${e.reason}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )),
            ],
          ],
        ),
      ),
      actions: [
        if (result.skippedRows.isNotEmpty ||
            result.parseErrors.isNotEmpty)
          TextButton(
            onPressed: () => _downloadRejects(context),
            child: const Text('Download rejects CSV'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }

  Future<void> _downloadRejects(BuildContext context) async {
    final lines = <String>[];
    lines.add(
        'Type,Start,End,Duration,Start Condition,Start Location,End Condition,Notes');
    for (final row in result.skippedRows) {
      lines.add(row);
    }
    for (final e in result.parseErrors) {
      lines.add('# Row ${e.rowNumber}: ${e.reason} (type: ${e.rawType})');
    }

    final content = lines.join('\n');
    final bytes = Uint8List.fromList(utf8.encode(content));
    final now = DateTime.now();
    final datePart =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await FileSaver.instance.saveFile(
        name: 'datababe-rejects-$datePart',
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejects file saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }
}
