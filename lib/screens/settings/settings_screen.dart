import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../import/csv_importer.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(user?.displayName ?? 'Signed in'),
            subtitle: Text(user?.email ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _signOut(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Manage Recipes'),
            subtitle: const Text('Create and edit recipes for solids logging'),
            onTap: () => context.push('/recipes'),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import CSV'),
            subtitle: const Text('Import data from a CSV export'),
            onTap: () => _importCsv(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    if (childId == null || familyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a child first')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Importing...'),
          ],
        ),
      ),
    );

    try {
      final file = result.files.first;

      String csvContent;
      if (file.bytes != null) {
        csvContent = utf8.decode(file.bytes!);
      } else {
        throw Exception('Could not read file');
      }

      final importer = CsvImporter(ref.read(activityRepositoryProvider));
      final count = await importer.importFromString(
        csvContent,
        childId,
        familyId,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count activities')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
