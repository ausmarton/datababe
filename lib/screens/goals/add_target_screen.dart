import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/target_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/target_provider.dart';
import '../../utils/activity_helpers.dart';

class AddTargetScreen extends ConsumerStatefulWidget {
  final String? targetId;

  const AddTargetScreen({super.key, this.targetId});

  @override
  ConsumerState<AddTargetScreen> createState() => _AddTargetScreenState();
}

class _AddTargetScreenState extends ConsumerState<AddTargetScreen> {
  ActivityType _activityType = ActivityType.feedBottle;
  TargetMetric _metric = TargetMetric.totalVolumeMl;
  TargetPeriod _period = TargetPeriod.daily;
  final _valueController = TextEditingController();
  String? _selectedIngredient;
  String? _selectedAllergen;
  bool _saving = false;

  bool get _isEdit => widget.targetId != null;
  String? _editId;
  String? _originalCreatedBy;
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    if (widget.targetId != null) {
      // Deferred to post-frame so ref.read is available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadExistingTarget();
      });
    }
  }

  void _loadExistingTarget() {
    final targets = ref.read(targetsProvider).valueOrNull ?? [];
    final target =
        targets.where((t) => t.id == widget.targetId).firstOrNull;
    if (target == null) return;

    final type = parseActivityType(target.activityType);
    final metric = TargetMetric.values
        .where((m) => m.name == target.metric)
        .firstOrNull;
    final period = TargetPeriod.values
        .where((p) => p.name == target.period)
        .firstOrNull;

    setState(() {
      _editId = target.id;
      _originalCreatedBy = target.createdBy;
      _originalCreatedAt = target.createdAt;
      if (type != null) _activityType = type;
      if (metric != null) _metric = metric;
      if (period != null) _period = period;
      _valueController.text = target.targetValue % 1 == 0
          ? target.targetValue.round().toString()
          : target.targetValue.toString();
      _selectedIngredient = target.ingredientName;
      _selectedAllergen = target.allergenName;
    });
  }

  /// Returns the metrics supported by the selected activity type.
  List<TargetMetric> get _supportedMetrics {
    switch (_activityType) {
      case ActivityType.feedBottle:
        return [TargetMetric.totalVolumeMl, TargetMetric.count];
      case ActivityType.feedBreast:
        return [TargetMetric.count, TargetMetric.totalDurationMinutes];
      case ActivityType.diaper:
      case ActivityType.potty:
        return [TargetMetric.count];
      case ActivityType.solids:
        return [
          TargetMetric.count,
          TargetMetric.uniqueFoods,
          TargetMetric.ingredientExposures,
          TargetMetric.allergenExposures,
          TargetMetric.allergenExposureDays,
        ];
      case ActivityType.meds:
        return [TargetMetric.count];
      case ActivityType.pump:
        return [TargetMetric.totalVolumeMl, TargetMetric.count];
      case ActivityType.tummyTime:
      case ActivityType.indoorPlay:
      case ActivityType.outdoorPlay:
      case ActivityType.bath:
      case ActivityType.skinToSkin:
      case ActivityType.sleep:
        return [TargetMetric.count, TargetMetric.totalDurationMinutes];
      case ActivityType.growth:
      case ActivityType.temperature:
        return [TargetMetric.count];
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valueText = _valueController.text.trim();
    final value = double.tryParse(valueText);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target value')),
      );
      return;
    }

    if (_metric == TargetMetric.ingredientExposures &&
        (_selectedIngredient == null || _selectedIngredient!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ingredient')),
      );
      return;
    }

    if ((_metric == TargetMetric.allergenExposures ||
            _metric == TargetMetric.allergenExposureDays) &&
        (_selectedAllergen == null || _selectedAllergen!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an allergen')),
      );
      return;
    }

    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (childId == null || familyId == null || user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No child or family selected. '
                  'Please go back and select a child first.')),
        );
      }
      return;
    }

    final existingTargets = ref.read(targetsProvider).valueOrNull ?? [];
    final isDuplicate = existingTargets.any((t) =>
        (_isEdit ? t.id != _editId : true) && // Exclude self in edit mode
        t.activityType == _activityType.name &&
        t.metric == _metric.name &&
        t.period == _period.name &&
        t.ingredientName == (_metric == TargetMetric.ingredientExposures
            ? _selectedIngredient?.toLowerCase() : null) &&
        t.allergenName == (_metric == TargetMetric.allergenExposures ||
                _metric == TargetMetric.allergenExposureDays
            ? _selectedAllergen?.toLowerCase() : null));

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A goal with these settings already exists')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final target = TargetModel(
        id: _isEdit ? _editId! : const Uuid().v4(),
        childId: childId,
        activityType: _activityType.name,
        metric: _metric.name,
        period: _period.name,
        targetValue: value,
        createdBy: _isEdit ? _originalCreatedBy ?? user.uid : user.uid,
        createdAt: _isEdit ? _originalCreatedAt ?? now : now,
        modifiedAt: now,
        ingredientName: _metric == TargetMetric.ingredientExposures
            ? _selectedIngredient!.toLowerCase()
            : null,
        allergenName: _metric == TargetMetric.allergenExposures ||
                _metric == TargetMetric.allergenExposureDays
            ? _selectedAllergen!.toLowerCase()
            : null,
      );

      final repo = ref.read(targetRepositoryProvider);
      if (_isEdit) {
        await repo.updateTarget(familyId, target);
      } else {
        await repo.createTarget(familyId, target);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save goal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure family/child auto-selection is triggered even outside ShellRoute.
    ref.watch(selectedChildProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Goal' : 'Add Goal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Activity type
          DropdownButtonFormField<ActivityType>(
            value: _activityType,
            decoration: const InputDecoration(
              labelText: 'Activity type',
              border: OutlineInputBorder(),
            ),
            items: ActivityType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(activityIcon(t),
                              size: 20, color: activityColor(t)),
                          const SizedBox(width: 8),
                          Text(activityDisplayName(t)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: _isEdit
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() {
                      _activityType = v;
                      final supported = _supportedMetrics;
                      if (!supported.contains(_metric)) {
                        _metric = supported.first;
                      }
                    });
                  },
          ),
          const SizedBox(height: 16),

          // Metric
          DropdownButtonFormField<TargetMetric>(
            value: _supportedMetrics.contains(_metric)
                ? _metric
                : _supportedMetrics.first,
            decoration: const InputDecoration(
              labelText: 'Metric',
              border: OutlineInputBorder(),
            ),
            items: _supportedMetrics
                .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(_metricLabel(m)),
                    ))
                .toList(),
            onChanged: _isEdit
                ? null
                : (v) {
                    if (v != null) setState(() => _metric = v);
                  },
          ),
          const SizedBox(height: 16),

          // Ingredient name (only for ingredient exposures)
          if (_metric == TargetMetric.ingredientExposures) ...[
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return const [];
                final ingredients =
                    ref.read(ingredientsProvider).valueOrNull ?? [];
                return ingredients
                    .map((i) => i.name)
                    .where((name) => name.contains(query))
                    .toList();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., egg, cow\'s milk',
                  ),
                  onChanged: (v) =>
                      _selectedIngredient = v.trim(),
                );
              },
              onSelected: (selection) {
                _selectedIngredient = selection;
              },
            ),
            const SizedBox(height: 16),
          ],

          // Allergen name (for allergen exposures or exposure days)
          if (_metric == TargetMetric.allergenExposures ||
              _metric == TargetMetric.allergenExposureDays) ...[
            Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                final categories =
                    ref.read(allergenCategoriesProvider);
                if (query.isEmpty) return categories;
                return categories
                    .where((c) => c.contains(query))
                    .toList();
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Allergen name',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., lactose, nuts',
                  ),
                  onChanged: (v) =>
                      _selectedAllergen = v.trim(),
                );
              },
              onSelected: (selection) {
                _selectedAllergen = selection;
              },
            ),
            const SizedBox(height: 16),
          ],

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
            onSelectionChanged: _isEdit
                ? null
                : (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),

          // Target value
          TextFormField(
            controller: _valueController,
            decoration: InputDecoration(
              labelText: 'Target value',
              border: const OutlineInputBorder(),
              suffixText: _metricUnit(_metric),
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _metricLabel(TargetMetric m) {
    return switch (m) {
      TargetMetric.totalVolumeMl => 'Total volume (ml)',
      TargetMetric.count => 'Count',
      TargetMetric.uniqueFoods => 'Unique foods',
      TargetMetric.totalDurationMinutes => 'Total duration (min)',
      TargetMetric.ingredientExposures => 'Ingredient exposures',
      TargetMetric.allergenExposures => 'Allergen exposures',
      TargetMetric.allergenExposureDays => 'Allergen exposure days',
    };
  }

  String _metricUnit(TargetMetric m) {
    return switch (m) {
      TargetMetric.totalVolumeMl => 'ml',
      TargetMetric.count => '',
      TargetMetric.uniqueFoods => 'foods',
      TargetMetric.totalDurationMinutes => 'min',
      TargetMetric.ingredientExposures => 'exposures',
      TargetMetric.allergenExposures => 'exposures',
      TargetMetric.allergenExposureDays => 'days',
    };
  }
}
