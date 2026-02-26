import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../backup/backup_helpers.dart';
import '../../backup/backup_service.dart';
import '../../import/csv_importer.dart';
import '../../providers/database_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/sync_provider.dart';
import '../../sync/sync_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncEnabled = ref.watch(syncEnabledProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Cloud Sync'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync),
            title: const Text('Google Drive Sync'),
            subtitle: Text(syncEnabled ? 'Enabled' : 'Disabled'),
            value: syncEnabled,
            onChanged: (value) => _toggleSync(context, ref, value),
          ),
          if (syncEnabled) ...[
            ListTile(
              leading: syncStatus == SyncStatus.syncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: const Text('Sync Now'),
              subtitle: Text(_syncStatusText(syncStatus, lastSynced)),
              enabled: syncStatus != SyncStatus.syncing,
              onTap: () => _syncNow(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              subtitle: const Text('Disconnect Google Drive'),
              onTap: () => _signOut(context, ref),
            ),
          ],
          const Divider(height: 1, indent: 16, endIndent: 16),
          const _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import CSV'),
            subtitle: const Text('Import data from a CSV export'),
            onTap: () => _importCsv(context, ref),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const _SectionHeader(title: 'Backup'),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export Backup'),
            subtitle: const Text('Save all data as a JSON file'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Restore from Backup'),
            subtitle: const Text('Replace all data from a JSON backup'),
            onTap: () => _restoreBackup(context, ref),
          ),
        ],
      ),
    );
  }

  String _syncStatusText(SyncStatus status, DateTime? lastSynced) {
    switch (status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Sync failed. Tap to retry.';
      case SyncStatus.offline:
        return 'Offline. Will sync when connected.';
      case SyncStatus.notSignedIn:
        return 'Not signed in. Tap to retry.';
      case SyncStatus.success:
      case SyncStatus.idle:
        if (lastSynced != null) {
          final fmt = DateFormat('dd/MM/yyyy HH:mm').format(lastSynced);
          return 'Last synced: $fmt';
        }
        return 'Not synced yet';
    }
  }

  Future<void> _toggleSync(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      // Sign in first
      final provider = ref.read(cloudStorageProvider);
      final signedIn = await provider.signIn();
      if (!signedIn) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google sign-in cancelled')),
          );
        }
        return;
      }
    } else {
      // Sign out when disabling
      await ref.read(cloudStorageProvider).signOut();
      await ref.read(lastSyncedAtProvider.notifier).clear();
      ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;
    }

    await ref.read(syncEnabledProvider.notifier).setEnabled(enable);

    if (enable) {
      // Trigger initial sync
      ref.read(autoSyncProvider).onDataChanged();
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(autoSyncProvider).syncNow();
    if (!context.mounted) return;

    if (result.status == SyncStatus.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync complete')),
      );
    } else if (result.status == SyncStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: ${result.errorMessage}')),
      );
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(cloudStorageProvider).signOut();
    await ref.read(syncEnabledProvider.notifier).setEnabled(false);
    await ref.read(lastSyncedAtProvider.notifier).clear();
    ref.read(syncStatusProvider.notifier).state = SyncStatus.idle;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out of Google Drive')),
      );
    }
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
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
      final db = ref.read(databaseProvider);
      final json = await exportToJson(db);
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final filename = 'filho-backup-$date.json';

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      await saveBackupFile(json, filename);

      if (context.mounted) {
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will replace all existing data with the contents of this '
          'backup file. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

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
      String jsonContent;
      if (file.bytes != null) {
        jsonContent = utf8.decode(file.bytes!);
      } else {
        throw Exception('Could not read file');
      }

      final db = ref.read(databaseProvider);
      final backupResult = await importFromJson(db, jsonContent);

      ref.read(autoSyncProvider).onDataChanged();

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$backupResult')),
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
    if (childId == null) {
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

    // Show loading indicator on the root navigator (matching showDialog default)
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

      // On web, file.path is null — use bytes instead
      String csvContent;
      if (file.bytes != null) {
        csvContent = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        // Native platforms: read via importer (won't be reached on web)
        throw Exception('File reading from path not supported on this platform');
      } else {
        throw Exception('Could not read file');
      }

      final importer = CsvImporter(ref.read(activityDaoProvider));
      final count = await importer.importFromString(csvContent, childId);

      ref.read(autoSyncProvider).onDataChanged();

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
