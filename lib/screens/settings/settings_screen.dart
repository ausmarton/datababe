import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';

import '../../import/csv_importer.dart';
import '../../utils/file_reader.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/sync_provider.dart';
import '../../sync/sync_engine.dart';

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
            leading: const Icon(Icons.warning_amber),
            title: const Text('Manage Allergens'),
            subtitle:
                const Text('Define allergen categories for ingredient tagging'),
            onTap: () => context.push('/settings/allergens'),
          ),
          ListTile(
            leading: const Icon(Icons.egg),
            title: const Text('Manage Ingredients'),
            subtitle: const Text('Create ingredients with allergen tags'),
            onTap: () => context.push('/ingredients'),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Manage Recipes'),
            subtitle: const Text('Create and edit recipes for solids logging'),
            onTap: () => context.push('/recipes'),
          ),
          ListTile(
            leading: const Icon(Icons.track_changes),
            title: const Text('Goals'),
            subtitle: const Text('Set and track daily/weekly targets'),
            onTap: () => context.push('/goals'),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import CSV'),
            subtitle: const Text('Import data from a CSV export'),
            onTap: () => _importCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Backup'),
            subtitle: const Text('Save family data as JSON'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Backup'),
            subtitle: const Text('Merge data from a JSON backup'),
            onTap: () => _restoreBackup(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const _SectionHeader(title: 'Sync'),
          _SyncStatusTile(),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final engine = ref.read(syncEngineProvider);
    final monitor = ref.read(connectivityMonitorProvider);
    final pending = await engine.pendingCount;

    // Warn if offline with unsynced changes.
    if (!monitor.isOnline && pending > 0 && context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsynced changes'),
          content: Text(
            'You have $pending unsynced change${pending == 1 ? '' : 's'}. '
            'Signing out while offline will discard them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Sign out anyway'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Best-effort push before clearing.
    try {
      await engine.syncNow();
    } catch (_) {}

    // Clear local data to prevent leaking to next user.
    await engine.clearLocalData();

    // Reset selection state.
    ref.read(selectedFamilyIdProvider.notifier).state = null;
    ref.read(selectedChildIdProvider.notifier).state = null;

    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No family selected')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Exporting...'),
          ],
        ),
      ),
    );

    try {
      final backupService = ref.read(backupServiceProvider);
      final jsonContent = await backupService.exportFamily(familyId);
      final bytes = Uint8List.fromList(utf8.encode(jsonContent));
      final now = DateTime.now();
      final datePart =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await FileSaver.instance.saveFile(
        name: 'datababe-backup-$datePart',
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup'),
        content: const Text(
          'This will merge backup data into your current family. '
          'Newer records win.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
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
            Text('Restoring...'),
          ],
        ),
      ),
    );

    try {
      final file = result.files.first;
      final jsonContent = await readFileContent(file);

      final backupService = ref.read(backupServiceProvider);
      final backupResult = await backupService.restoreFamily(jsonContent);

      // Push (conditional) + pull (corrects stale data).
      final engine = ref.read(syncEngineProvider);
      await engine.syncNow();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored: ${backupResult.totalInserted} added, '
              '${backupResult.totalUpdated} updated, '
              '${backupResult.totalSkipped} skipped',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
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

    // Confirm the target child before importing.
    final childName = ref.read(selectedChildProvider)?.name ?? 'selected child';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm import'),
        content: Text('Import activities to $childName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

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
      final csvContent = await readFileContent(file);

      final importer = CsvImporter(ref.read(activityRepositoryProvider));
      final importResult = await importer.importFromString(
        csvContent,
        childId,
        familyId,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final msg = importResult.skipped > 0
            ? 'Imported ${importResult.imported}, skipped ${importResult.skipped} duplicates'
            : 'Imported ${importResult.imported} activities';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        // Trigger immediate sync to push imported activities to Firestore.
        if (importResult.imported > 0) {
          final engine = ref.read(syncEngineProvider);
          final pushResult = await engine.syncNow();
          if (context.mounted) {
            final syncMsg = pushResult.failed > 0
                ? 'Synced ${pushResult.pushed}, ${pushResult.failed} failed'
                : pushResult.pushed > 0
                    ? 'Synced ${pushResult.pushed} to cloud'
                    : 'Nothing to sync';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(syncMsg)),
            );
          }
        }
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

class _SyncStatusTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSync = ref.watch(lastSyncTimeProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider);

    final status = syncStatus.valueOrNull ?? SyncStatus.idle;
    final lastTime = lastSync.valueOrNull;
    final pending = pendingCount.valueOrNull ?? 0;

    final statusLabel = switch (status) {
      SyncStatus.idle => 'Synced',
      SyncStatus.syncing => 'Syncing...',
      SyncStatus.error => 'Sync error',
      SyncStatus.offline => 'Offline',
    };

    final subtitle = StringBuffer(statusLabel);
    if (pending > 0) {
      subtitle.write(' ($pending pending)');
    }
    if (lastTime != null) {
      final ago = DateTime.now().difference(lastTime);
      if (ago.inMinutes < 1) {
        subtitle.write(' — just now');
      } else if (ago.inHours < 1) {
        subtitle.write(' — ${ago.inMinutes}m ago');
      } else {
        subtitle.write(' — ${ago.inHours}h ago');
      }
    }

    return ListTile(
      leading: const Icon(Icons.sync),
      title: const Text('Sync Now'),
      subtitle: Text(subtitle.toString()),
      trailing: status == SyncStatus.syncing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: status == SyncStatus.syncing
          ? null
          : () async {
              final engine = ref.read(syncEngineProvider);
              final result = await engine.syncNow();
              if (context.mounted) {
                final msg = result.failed > 0
                    ? 'Pushed ${result.pushed}, ${result.failed} failed'
                    : result.pushed > 0
                        ? 'Pushed ${result.pushed} to cloud'
                        : 'Sync complete';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
    );
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
