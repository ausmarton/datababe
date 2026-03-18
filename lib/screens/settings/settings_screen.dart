import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:go_router/go_router.dart';

import '../../import/csv_analyzer.dart';
import '../../local/database_provider.dart';
import '../../utils/file_reader.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../sync/sync_engine_interface.dart';

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
          const _SectionHeader(title: 'Preferences'),
          _StartOfDayTile(),
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
          _DiagnosticsTile(),
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

    // Confirm the target child before importing + soft-delete toggle.
    final childName = ref.read(selectedChildProvider)?.name ?? 'selected child';
    var includeDeleted = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Confirm import'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import activities to $childName?'),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: includeDeleted,
                onChanged: (v) => setState(() => includeDeleted = v ?? true),
                title: const Text('Include previously deleted entries'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ],
          ),
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
            Text('Analyzing...'),
          ],
        ),
      ),
    );

    try {
      final file = result.files.first;
      final csvContent = await readFileContent(file);

      final user = ref.read(currentUserProvider);
      final analyzer = CsvAnalyzer(ref.read(activityRepositoryProvider));
      final preview = await analyzer.analyze(
        csvContent,
        childId,
        familyId,
        includeSoftDeleted: !includeDeleted,
        createdBy: user?.uid,
      );

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        if (preview.totalRows == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No parseable activities in CSV')),
          );
          return;
        }

        context.push('/import/preview', extra: preview);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    }
  }
}

class _StartOfDayTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sodHour = ref.watch(startOfDayHourProvider).valueOrNull ?? 0;
    final label =
        '${sodHour.toString().padLeft(2, '0')}:00';

    return ListTile(
      leading: const Icon(Icons.schedule),
      title: const Text('Start of day'),
      subtitle: Text('Day starts at $label'),
      trailing: Text(label, style: Theme.of(context).textTheme.titleMedium),
      onTap: () async {
        final picked = await showDialog<int>(
          context: context,
          builder: (context) => _StartOfDayDialog(current: sodHour),
        );
        if (picked != null) {
          final db = ref.read(localDatabaseProvider);
          await setStartOfDayHour(db, picked);
        }
      },
    );
  }
}

class _StartOfDayDialog extends StatefulWidget {
  final int current;
  const _StartOfDayDialog({required this.current});

  @override
  State<_StartOfDayDialog> createState() => _StartOfDayDialogState();
}

class _StartOfDayDialogState extends State<_StartOfDayDialog> {
  late int _hour;

  @override
  void initState() {
    super.initState();
    _hour = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final label = '${_hour.toString().padLeft(2, '0')}:00';
    return AlertDialog(
      title: const Text('Start of day'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Activities before this time count as the previous day.'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => _hour = (_hour - 1) % 24),
                icon: const Icon(Icons.remove),
              ),
              Text(label, style: Theme.of(context).textTheme.headlineMedium),
              IconButton(
                onPressed: () => setState(() => _hour = (_hour + 1) % 24),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _hour),
          child: const Text('Save'),
        ),
      ],
    );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_syncResultMessage(result))),
                );
              }
            },
    );
  }
}

String _syncResultMessage(SyncResult result) {
  final parts = <String>[];
  if (result.pushed > 0) parts.add('pushed ${result.pushed}');
  if (result.pushFailed > 0) parts.add('${result.pushFailed} push failed');
  if (result.reconciled > 0) parts.add('removed ${result.reconciled} stale');
  if (result.reconcileError != null) {
    parts.add('reconcile error: ${result.reconcileError}');
  }
  return parts.isEmpty ? 'Sync complete — no changes' : parts.join(', ');
}

class _DiagnosticsTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DiagnosticsTile> createState() => _DiagnosticsTileState();
}

class _DiagnosticsTileState extends ConsumerState<_DiagnosticsTile> {
  Map<String, dynamic>? _diagnostics;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Diagnostics'),
          subtitle: const Text('Check local DB state'),
          onTap: _runDiagnostics,
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        if (_diagnostics != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local DB State',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ..._diagnostics!.entries
                        .where((e) => e.key != 'pendingSync')
                        .map((e) {
                      final info = e.value as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${e.key}: ${info['localCount']} local, '
                          'lastPull: ${info['lastPull'] ?? 'never'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }),
                    const Divider(),
                    Text(
                      'Pending sync: ${_diagnostics!['pendingSync']}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _forceResync,
              icon: const Icon(Icons.refresh),
              label: const Text('Force Full Re-sync'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _runDiagnostics() async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No family selected')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final engine = ref.read(syncEngineProvider);
      final diag = await engine.getDiagnostics(familyId);
      if (mounted) setState(() => _diagnostics = diag);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Diagnostics failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceResync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force full re-sync?'),
        content: const Text(
          'This clears all sync timestamps and re-pulls everything '
          'from the server. Local unsynced changes will be pushed first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-sync'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _diagnostics = null;
    });

    try {
      final engine = ref.read(syncEngineProvider);
      final familyIds = await engine.fetchFamilyIds();
      await engine.forceFullResync(familyIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full re-sync complete')),
        );
        await _runDiagnostics();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Re-sync failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
