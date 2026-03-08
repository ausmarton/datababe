import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/target_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/target_provider.dart';

class BulkAllergenTargetsScreen extends ConsumerStatefulWidget {
  const BulkAllergenTargetsScreen({super.key});

  @override
  ConsumerState<BulkAllergenTargetsScreen> createState() =>
      _BulkAllergenTargetsScreenState();
}

class _BulkAllergenTargetsScreenState
    extends ConsumerState<BulkAllergenTargetsScreen> {
  TargetPeriod _period = TargetPeriod.weekly;
  final _valueController = TextEditingController(text: '3');
  final _selected = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(selectedChildProvider);

    final categories = ref.watch(allergenCategoriesProvider);
    final existingTargets = ref.watch(targetsProvider).valueOrNull ?? [];

    if (categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bulk Allergen Goals')),
        body: const Center(
          child: Text(
              'No allergen categories defined.\nGo to Settings > Manage Allergens first.'),
        ),
      );
    }

    // Determine which allergens already have targets for the selected period.
    final existingAllergenNames = existingTargets
        .where((t) =>
            t.metric == TargetMetric.allergenExposures.name &&
            t.period == _period.name)
        .map((t) => t.allergenName?.toLowerCase())
        .whereType<String>()
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Allergen Goals')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Create allergen exposure goals for multiple allergens at once.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),

          // Period
          SegmentedButton<TargetPeriod>(
            segments: const [
              ButtonSegment(
                  value: TargetPeriod.daily, label: Text('Daily')),
              ButtonSegment(
                  value: TargetPeriod.weekly, label: Text('Weekly')),
              ButtonSegment(
                  value: TargetPeriod.monthly, label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),

          // Target value
          TextFormField(
            controller: _valueController,
            decoration: const InputDecoration(
              labelText: 'Target exposures (each)',
              border: OutlineInputBorder(),
              suffixText: 'exposures',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Allergen checkboxes
          Text('Select allergens',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...categories.map((cat) {
            final normalized = cat.trim().toLowerCase();
            final hasExisting = existingAllergenNames.contains(normalized);
            return CheckboxListTile(
              value: _selected.contains(normalized),
              onChanged: hasExisting
                  ? null
                  : (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(normalized);
                        } else {
                          _selected.remove(normalized);
                        }
                      });
                    },
              title: Text(cat),
              subtitle:
                  hasExisting ? const Text('Already has a goal') : null,
              dense: true,
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    for (final cat in categories) {
                      final n = cat.trim().toLowerCase();
                      if (!existingAllergenNames.contains(n)) {
                        _selected.add(n);
                      }
                    }
                  });
                },
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: () => setState(() => _selected.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed:
                _saving || _selected.isEmpty ? null : _saveAll,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Create ${_selected.length} goal${_selected.length == 1 ? '' : 's'}'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll() async {
    final valueText = _valueController.text.trim();
    final value = double.tryParse(valueText);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (childId == null || familyId == null || user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No child or family selected.')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(targetRepositoryProvider);
      final now = DateTime.now();
      final uuid = const Uuid();

      for (final allergen in _selected) {
        final target = TargetModel(
          id: uuid.v4(),
          childId: childId,
          activityType: ActivityType.solids.name,
          metric: TargetMetric.allergenExposures.name,
          period: _period.name,
          targetValue: value,
          createdBy: user.uid,
          createdAt: now,
          modifiedAt: now,
          allergenName: allergen,
        );
        await repo.createTarget(familyId, target);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Created ${_selected.length} allergen goal${_selected.length == 1 ? '' : 's'}')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save goals: $e')),
        );
      }
    }
  }
}
