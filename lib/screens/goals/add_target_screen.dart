import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/enums.dart';
import '../../models/target_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/activity_helpers.dart';

class AddTargetScreen extends ConsumerStatefulWidget {
  const AddTargetScreen({super.key});

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

    if (_metric == TargetMetric.allergenExposures &&
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

    setState(() => _saving = true);

    try {
      final target = TargetModel(
        id: const Uuid().v4(),
        childId: childId,
        activityType: _activityType.name,
        metric: _metric.name,
        period: _period.name,
        targetValue: value,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        ingredientName: _metric == TargetMetric.ingredientExposures
            ? _selectedIngredient!.toLowerCase()
            : null,
        allergenName: _metric == TargetMetric.allergenExposures
            ? _selectedAllergen!.toLowerCase()
            : null,
      );

      final repo = ref.read(targetRepositoryProvider);
      await repo.createTarget(familyId, target);

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
      appBar: AppBar(title: const Text('Add Goal')),
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
            onChanged: (v) {
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
            onChanged: (v) {
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
                final recipes =
                    ref.read(recipesProvider).valueOrNull ?? [];
                final allIngredients = <String>{};
                for (final recipe in recipes) {
                  for (final ingredient in recipe.ingredients) {
                    allIngredients.add(ingredient);
                  }
                }
                return allIngredients
                    .where((i) => i.contains(query))
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

          // Allergen name (only for allergen exposures)
          if (_metric == TargetMetric.allergenExposures) ...[
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
            onSelectionChanged: (s) => setState(() => _period = s.first),
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
    };
  }
}
