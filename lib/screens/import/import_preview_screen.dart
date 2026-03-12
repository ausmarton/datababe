import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../import/csv_importer.dart';
import '../../import/import_preview.dart';
import '../../models/enums.dart';
import '../../providers/repository_provider.dart';
import '../../providers/sync_provider.dart';
import '../../sync/sync_engine_interface.dart';
import '../../utils/activity_helpers.dart';

/// Preview screen for CSV import with filtering and row selection.
class ImportPreviewScreen extends ConsumerStatefulWidget {
  final ImportPreview preview;
  const ImportPreviewScreen({super.key, required this.preview});

  @override
  ConsumerState<ImportPreviewScreen> createState() =>
      _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends ConsumerState<ImportPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ImportFilter _filter = const ImportFilter();
  final Set<int> _deselected = {}; // row numbers of deselected new candidates
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ImportCandidate> get _newCandidates => widget.preview.candidates
      .where((c) =>
          c.status == CandidateStatus.newActivity && _filter.matches(c))
      .toList();

  List<ImportCandidate> get _duplicateCandidates => widget.preview.candidates
      .where(
          (c) => c.status == CandidateStatus.duplicate && _filter.matches(c))
      .toList();

  List<ImportCandidate> get _errorCandidates => widget.preview.candidates
      .where((c) => c.status == CandidateStatus.parseError)
      .toList();

  List<ImportCandidate> get _selectedCandidates =>
      _newCandidates.where((c) => !_deselected.contains(c.rowNumber)).toList();

  int get _selectedCount => _selectedCandidates.length;

  bool get _allSelected => _deselected.isEmpty;

  @override
  Widget build(BuildContext context) {
    final newList = _newCandidates;
    final dupList = _duplicateCandidates;
    final errList = _errorCandidates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Preview'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'New (${newList.length})'),
            Tab(text: 'Duplicates (${dupList.length})'),
            Tab(text: 'Errors (${errList.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(),
          _buildFilterBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNewTab(newList),
                _buildDuplicateTab(dupList),
                _buildErrorTab(errList),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSummaryCard() {
    final p = widget.preview;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${p.totalRows} rows \u00b7 ${p.newCount} new \u00b7 '
          '${p.duplicateCount} duplicates \u00b7 ${p.errorCount} errors',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final presentTypes = widget.preview.presentTypes.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return ExpansionTile(
      title: const Text('Filters'),
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _DatePickerField(
                  label: 'From',
                  value: _filter.dateFrom,
                  onChanged: (d) => setState(() {
                    _filter = _filter.copyWith(dateFrom: () => d);
                  }),
                ),
              ),
              const SizedBox(width: 8),
              const Text('\u2014'),
              const SizedBox(width: 8),
              Expanded(
                child: _DatePickerField(
                  label: 'To',
                  value: _filter.dateTo,
                  onChanged: (d) => setState(() {
                    _filter = _filter.copyWith(
                      dateTo: () =>
                          d != null ? DateTime(d.year, d.month, d.day, 23, 59, 59) : null,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: presentTypes.map((type) {
              final excluded = _filter.excludedTypes.contains(type);
              return FilterChip(
                label: Text(activityDisplayName(type)),
                selected: !excluded,
                onSelected: (selected) {
                  setState(() {
                    final types = Set<ActivityType>.from(_filter.excludedTypes);
                    if (selected) {
                      types.remove(type);
                    } else {
                      types.add(type);
                    }
                    _filter = _filter.copyWith(excludedTypes: types);
                  });
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Showing ${_newCandidates.length} of ${widget.preview.newCount} new',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildNewTab(List<ImportCandidate> candidates) {
    if (candidates.isEmpty) {
      return const Center(child: Text('No new activities'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_allSelected) {
                      _deselected.addAll(
                          candidates.map((c) => c.rowNumber));
                    } else {
                      _deselected.clear();
                    }
                  });
                },
                child: Text(_allSelected ? 'Deselect All' : 'Select All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final c = candidates[index];
              final selected = !_deselected.contains(c.rowNumber);
              return CheckboxListTile(
                value: selected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _deselected.remove(c.rowNumber);
                    } else {
                      _deselected.add(c.rowNumber);
                    }
                  });
                },
                secondary: Icon(
                  activityIcon(c.type!),
                  color: activityColor(c.type!),
                ),
                title: Text(_candidateTitle(c)),
                subtitle: Text(_candidateSubtitle(c)),
                dense: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateTab(List<ImportCandidate> candidates) {
    if (candidates.isEmpty) {
      return const Center(child: Text('No duplicates'));
    }
    return ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final c = candidates[index];
        return ListTile(
          leading: Icon(
            activityIcon(c.type!),
            color: Colors.grey,
          ),
          title: Text(
            _candidateTitle(c),
            style: const TextStyle(color: Colors.grey),
          ),
          subtitle: Text(_candidateSubtitle(c)),
          trailing: Text(
            'Duplicate',
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 12,
            ),
          ),
          dense: true,
        );
      },
    );
  }

  Widget _buildErrorTab(List<ImportCandidate> candidates) {
    if (candidates.isEmpty) {
      return const Center(child: Text('No errors'));
    }
    return ListView.builder(
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final c = candidates[index];
        return ListTile(
          leading: Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error),
          title: Text(
            'Row ${c.error!.rowNumber}: ${c.error!.reason}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          subtitle: c.error!.rawType.isNotEmpty
              ? Text('Type: ${c.error!.rawType}')
              : null,
          dense: true,
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final selected = _selectedCount;
    final total = _newCandidates.length;
    final hasImportable = selected > 0;
    final label =
        selected == total ? 'Import All ($total)' : 'Import Selected ($selected)';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _importing ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _importing || !hasImportable ? null : _doImport,
                child: _importing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doImport() async {
    setState(() => _importing = true);

    try {
      final importer = CsvImporter(ref.read(activityRepositoryProvider));
      final result = await importer.importSelected(
        widget.preview.familyId,
        _selectedCandidates,
      );

      if (!mounted) return;

      // Trigger sync.
      if (result.imported > 0) {
        final engine = ref.read(syncEngineProvider);
        final syncResult = await engine.syncNow();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${result.imported} activities. ${_syncMsg(syncResult)}',
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No activities imported')),
        );
      }

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  String _syncMsg(SyncResult r) {
    final parts = <String>[];
    if (r.pushed > 0) parts.add('pushed ${r.pushed}');
    if (r.pushFailed > 0) parts.add('${r.pushFailed} push failed');
    return parts.isEmpty ? 'Sync complete' : parts.join(', ');
  }

  String _candidateTitle(ImportCandidate c) {
    final time = c.startTime;
    final timeStr = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : '';
    return '$timeStr  ${activityDisplayName(c.type!)}';
  }

  String _candidateSubtitle(ImportCandidate c) {
    final model = c.model;
    if (model == null) return '';
    final parts = <String>[];
    final date = c.startTime;
    if (date != null) {
      parts.add(
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    }
    switch (c.type) {
      case ActivityType.feedBottle:
        if (model.feedType != null) parts.add(model.feedType!);
        if (model.volumeMl != null) parts.add('${model.volumeMl}ml');
      case ActivityType.feedBreast:
        if (model.rightBreastMinutes != null) {
          parts.add('R:${model.rightBreastMinutes}');
        }
        if (model.leftBreastMinutes != null) {
          parts.add('L:${model.leftBreastMinutes}');
        }
      case ActivityType.diaper || ActivityType.potty:
        if (model.contents != null) parts.add(model.contents!);
        if (model.contentSize != null) parts.add(model.contentSize!);
      case ActivityType.meds:
        if (model.medicationName != null) parts.add(model.medicationName!);
        if (model.dose != null) parts.add(model.dose!);
      case ActivityType.solids:
        if (model.foodDescription != null) parts.add(model.foodDescription!);
        if (model.reaction != null) parts.add(model.reaction!);
      case ActivityType.growth:
        if (model.weightKg != null) parts.add('${model.weightKg}kg');
        if (model.lengthCm != null) parts.add('${model.lengthCm}cm');
      case ActivityType.pump:
        if (model.volumeMl != null) parts.add('${model.volumeMl}ml');
        if (model.durationMinutes != null) {
          parts.add(formatDuration(model.durationMinutes));
        }
      case ActivityType.temperature:
        if (model.tempCelsius != null) parts.add('${model.tempCelsius}\u00b0C');
      default:
        if (model.durationMinutes != null) {
          parts.add(formatDuration(model.durationMinutes));
        }
    }
    if (model.notes != null && model.notes!.isNotEmpty) {
      parts.add(model.notes!);
    }
    return parts.join(' \u00b7 ');
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = value != null
        ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
        : label;

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        onChanged(picked);
      },
      onLongPress: () => onChanged(null),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(text),
      ),
    );
  }
}
