import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/bulk_entry.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/activity_helpers.dart';

class BulkAddScreen extends ConsumerStatefulWidget {
  const BulkAddScreen({super.key});

  @override
  ConsumerState<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends ConsumerState<BulkAddScreen> {
  final List<BulkEntry> _staged = [];
  late DateTime _targetDate;
  DateTime? _sourceDate;
  List<ActivityModel> _sourceActivities = [];
  Set<String> _selectedSourceIds = {};
  bool _saving = false;
  bool _loadingSource = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _targetDate = DateTime(now.year, now.month, now.day - 1);
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _pickSourceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _sourceDate ?? DateTime(_targetDate.year, _targetDate.month, _targetDate.day - 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _sourceDate = picked);
      await _loadSourceDay(picked);
    }
  }

  Future<void> _loadSourceDay(DateTime date) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    final childId = ref.read(selectedChildIdProvider);
    if (familyId == null || childId == null) return;

    setState(() => _loadingSource = true);

    final repo = ref.read(activityRepositoryProvider);
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1);

    try {
      final activities = await repo.findByTimeRange(
        familyId,
        childId,
        dayStart,
        dayEnd,
      );
      if (mounted) {
        setState(() {
          _sourceActivities =
              activities.where((a) => !a.isDeleted).toList()
                ..sort((a, b) => a.startTime.compareTo(b.startTime));
          _selectedSourceIds = _sourceActivities.map((a) => a.id).toSet();
          _loadingSource = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSource = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load activities: $e')),
        );
      }
    }
  }

  void _addSelectedFromSource() {
    final selected = _sourceActivities
        .where((a) => _selectedSourceIds.contains(a.id))
        .toList();
    if (selected.isEmpty) return;

    final newEntries = selected.map((source) {
      final sourceTimeOfDay = TimeOfDay.fromDateTime(source.startTime);
      final mappedStart = DateTime(
        _targetDate.year,
        _targetDate.month,
        _targetDate.day,
        sourceTimeOfDay.hour,
        sourceTimeOfDay.minute,
      );

      DateTime? mappedEnd;
      if (source.endTime != null) {
        final duration = source.endTime!.difference(source.startTime);
        mappedEnd = mappedStart.add(duration);
      }

      return BulkEntry(
        template: source,
        startTime: mappedStart,
        endTime: mappedEnd,
      );
    }).toList();

    setState(() {
      _staged.addAll(newEntries);
      _staged.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  void _quickAdd(ActivityType type) {
    DateTime nextTime;
    if (_staged.isEmpty) {
      nextTime = DateTime(
        _targetDate.year,
        _targetDate.month,
        _targetDate.day,
        8,
        0,
      );
    } else {
      nextTime =
          _staged.last.startTime.add(const Duration(minutes: 30));
    }

    final template = ActivityModel(
      id: '',
      childId: '',
      type: type.name,
      startTime: nextTime,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    setState(() {
      _staged.add(BulkEntry(template: template, startTime: nextTime));
    });
  }

  Future<void> _pickTime(BulkEntry entry) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(entry.startTime),
    );
    if (time == null || !mounted) return;

    setState(() {
      final duration = entry.endTime?.difference(entry.startTime);
      entry.startTime = DateTime(
        _targetDate.year,
        _targetDate.month,
        _targetDate.day,
        time.hour,
        time.minute,
      );
      if (duration != null) {
        entry.endTime = entry.startTime.add(duration);
      }
      _staged.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  void _removeEntry(BulkEntry entry) {
    setState(() => _staged.removeWhere((e) => e.id == entry.id));
  }

  Future<void> _saveAll() async {
    if (_staged.isEmpty) return;

    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    if (childId == null || familyId == null) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final user = ref.read(currentUserProvider);
    final models = _staged
        .map((e) => e.toActivityModel(
              childId: childId,
              now: now,
              createdBy: user?.uid,
            ))
        .toList();

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.insertActivities(familyId, models);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved ${models.length} activities'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.Hm();

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Add')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Target date
          Card(
            child: ListTile(
              title: Text('Adding to: ${dateFormat.format(_targetDate)}'),
              trailing: TextButton(
                onPressed: _pickTargetDate,
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Copy from day
          ExpansionTile(
            title: const Text('Copy from day'),
            initiallyExpanded: false,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sourceDate != null
                            ? 'Source: ${dateFormat.format(_sourceDate!)}'
                            : 'Select a source day',
                      ),
                    ),
                    TextButton(
                      onPressed: _pickSourceDate,
                      child: const Text('Pick day'),
                    ),
                  ],
                ),
              ),
              if (_loadingSource)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_sourceDate != null &&
                  _sourceActivities.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No activities found for this day'),
                )
              else
                ..._sourceActivities.map((a) {
                  final type = parseActivityType(a.type);
                  return CheckboxListTile(
                    value: _selectedSourceIds.contains(a.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedSourceIds.add(a.id);
                        } else {
                          _selectedSourceIds.remove(a.id);
                        }
                      });
                    },
                    secondary: Icon(
                      type != null ? activityIcon(type) : Icons.help_outline,
                      color: type != null ? activityColor(type) : Colors.grey,
                    ),
                    title: Text(
                      type != null ? activityDisplayName(type) : a.type,
                    ),
                    subtitle: Text(timeFormat.format(a.startTime)),
                  );
                }),
              if (_sourceActivities.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: FilledButton(
                    onPressed: _selectedSourceIds.isEmpty
                        ? null
                        : _addSelectedFromSource,
                    child: Text(
                      'Add Selected (${_selectedSourceIds.length})',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick add
          Text('Quick Add', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ActivityType.values.map((type) {
              return ActionChip(
                avatar: Icon(activityIcon(type), size: 18),
                label: Text(activityDisplayName(type)),
                onPressed: () => _quickAdd(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Staged entries
          Text(
            'Staged (${_staged.length} ${_staged.length == 1 ? 'entry' : 'entries'})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (_staged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No entries staged yet'),
              ),
            )
          else
            ..._staged.map((entry) {
              final type = parseActivityType(entry.template.type);
              return Card(
                child: ListTile(
                  leading: Icon(
                    type != null ? activityIcon(type) : Icons.help_outline,
                    color: type != null ? activityColor(type) : Colors.grey,
                  ),
                  title: Text(
                    type != null ? activityDisplayName(type) : entry.template.type,
                  ),
                  subtitle: TextButton(
                    onPressed: () => _pickTime(entry),
                    child: Text(timeFormat.format(entry.startTime)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeEntry(entry),
                  ),
                ),
              );
            }),
        ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed:
                      _staged.isEmpty || _saving ? null : _saveAll,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Save All (${_staged.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
