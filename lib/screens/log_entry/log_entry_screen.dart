import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../models/ingredient_model.dart';
import '../../models/recipe_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';
import '../../repositories/duplicate_name_exception.dart';
import '../../utils/activity_helpers.dart';
import '../../utils/allergen_helpers.dart';

class LogEntryScreen extends ConsumerStatefulWidget {
  final String activityType;
  final String? activityId;
  final String? copyFromId;

  const LogEntryScreen({
    super.key,
    required this.activityType,
    this.activityId,
    this.copyFromId,
  });

  @override
  ConsumerState<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends ConsumerState<LogEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late ActivityType _type;
  bool _saving = false;
  bool _isDirty = false;

  // Common fields
  late DateTime _startTime;
  DateTime? _endTime;

  // Feed (Bottle)
  FeedType _feedType = FeedType.formula;
  final _volumeController = TextEditingController();

  // Feed (Breast)
  final _rightBreastController = TextEditingController();
  final _leftBreastController = TextEditingController();

  // Diaper / Potty
  DiaperContents _contents = DiaperContents.poo;
  ContentSize _contentSize = ContentSize.medium;
  ContentSize? _peeSize;
  PooColour? _pooColour;
  PooConsistency? _pooConsistency;

  // Meds
  final _medNameController = TextEditingController();
  final _doseController = TextEditingController();
  final _doseUnitController = TextEditingController();

  // Solids
  final _foodDescController = TextEditingController();
  FoodReaction _reaction = FoodReaction.none;
  String? _recipeId;
  List<String>? _ingredientNames;
  List<String>? _allergenNames;

  // Growth
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _headController = TextEditingController();

  // Temperature
  final _tempController = TextEditingController();

  // Notes
  final _notesController = TextEditingController();

  bool _loading = false;
  DateTime _originalCreatedAt = DateTime.now();
  String? _originalCreatedBy;

  @override
  void initState() {
    super.initState();
    _type = parseActivityType(widget.activityType) ?? ActivityType.feedBottle;
    _startTime = DateTime.now();

    if (widget.activityId != null) {
      _loadExisting();
    } else if (widget.copyFromId != null) {
      _loadCopySource();
    }
  }

  Future<void> _loadExisting() async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    setState(() => _loading = true);

    final repo = ref.read(activityRepositoryProvider);
    final activity = await repo.getActivity(familyId, widget.activityId!);

    if (activity == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (activity.isDeleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry no longer exists')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() {
      _startTime = activity.startTime;
      _endTime = activity.endTime;
      _originalCreatedAt = activity.createdAt;
      _originalCreatedBy = activity.createdBy;
      _populateFields(activity);
      _loading = false;
    });
  }

  Future<void> _loadCopySource() async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    setState(() => _loading = true);

    final repo = ref.read(activityRepositoryProvider);
    final activity = await repo.getActivity(familyId, widget.copyFromId!);

    if (activity == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source entry not found')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    if (activity.isDeleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Source entry no longer exists')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    setState(() {
      // Keep _startTime as DateTime.now(), _endTime as null
      _populateFields(activity);
      _loading = false;
    });
  }

  void _populateFields(ActivityModel activity) {
    // Feed (Bottle)
    if (activity.feedType != null) {
      _feedType = FeedType.values.where((e) => e.name == activity.feedType).firstOrNull ?? _feedType;
    }
    if (activity.volumeMl != null) _volumeController.text = activity.volumeMl.toString();

    // Feed (Breast)
    if (activity.rightBreastMinutes != null) _rightBreastController.text = activity.rightBreastMinutes.toString();
    if (activity.leftBreastMinutes != null) _leftBreastController.text = activity.leftBreastMinutes.toString();

    // Diaper / Potty
    if (activity.contents != null) {
      _contents = DiaperContents.values.where((e) => e.name == activity.contents).firstOrNull ?? _contents;
    }
    if (activity.contentSize != null) {
      _contentSize = ContentSize.values.where((e) => e.name == activity.contentSize).firstOrNull ?? _contentSize;
    }
    if (activity.peeSize != null) {
      _peeSize = ContentSize.values.where((e) => e.name == activity.peeSize).firstOrNull;
    }
    if (activity.pooColour != null) {
      _pooColour = PooColour.values.where((e) => e.name == activity.pooColour).firstOrNull;
    }
    if (activity.pooConsistency != null) {
      _pooConsistency = PooConsistency.values.where((e) => e.name == activity.pooConsistency).firstOrNull;
    }

    // Meds
    if (activity.medicationName != null) _medNameController.text = activity.medicationName!;
    if (activity.dose != null) _doseController.text = activity.dose!;
    if (activity.doseUnit != null) _doseUnitController.text = activity.doseUnit!;

    // Solids
    if (activity.foodDescription != null) _foodDescController.text = activity.foodDescription!;
    if (activity.reaction != null) {
      _reaction = FoodReaction.values.where((e) => e.name == activity.reaction).firstOrNull ?? _reaction;
    }
    _recipeId = activity.recipeId;
    _ingredientNames = activity.ingredientNames;
    _allergenNames = activity.allergenNames;

    // Growth
    if (activity.weightKg != null) _weightController.text = activity.weightKg.toString();
    if (activity.lengthCm != null) _lengthController.text = activity.lengthCm.toString();
    if (activity.headCircumferenceCm != null) _headController.text = activity.headCircumferenceCm.toString();

    // Temperature
    if (activity.tempCelsius != null) _tempController.text = activity.tempCelsius.toString();

    // Notes
    if (activity.notes != null) _notesController.text = activity.notes!;
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _rightBreastController.dispose();
    _leftBreastController.dispose();
    _medNameController.dispose();
    _doseController.dispose();
    _doseUnitController.dispose();
    _foodDescController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _headController.dispose();
    _tempController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startTime : (_endTime ?? _startTime);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    setState(() {
      _isDirty = true;
      final dt = DateTime(date.year, date.month, date.day, current.hour, current.minute);
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _startTime : (_endTime ?? _startTime);
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    setState(() {
      _isDirty = true;
      final dt = DateTime(current.year, current.month, current.day, time.hour, time.minute);
      if (isStart) {
        _startTime = dt;
      } else {
        _endTime = dt;
      }
    });
  }

  int? _computeDuration() {
    if (_endTime == null) return null;
    return _endTime!.difference(_startTime).inMinutes;
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This action cannot be undone.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final repo = ref.read(activityRepositoryProvider);
    try {
      await repo.softDeleteActivity(familyId, widget.activityId!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate duration: endTime must be after startTime
    if (_hasDuration && _endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    if (childId == null || familyId == null) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final isEdit = widget.activityId != null;
    final id = widget.activityId ?? const Uuid().v4();
    final duration = _computeDuration();
    final user = ref.read(currentUserProvider);

    final entry = ActivityModel(
      id: id,
      childId: childId,
      type: _type.name,
      startTime: _startTime,
      endTime: _endTime,
      durationMinutes: duration,
      createdBy: isEdit ? _originalCreatedBy : user?.uid,
      createdAt: isEdit ? _originalCreatedAt : now,
      modifiedAt: now,

      // Feed (Bottle)
      feedType: _type == ActivityType.feedBottle ? _feedType.name : null,
      volumeMl: _parseDouble(_volumeController.text),

      // Feed (Breast)
      rightBreastMinutes: _parseInt(_rightBreastController.text),
      leftBreastMinutes: _parseInt(_leftBreastController.text),

      // Diaper / Potty
      contents: _type == ActivityType.diaper || _type == ActivityType.potty
          ? _contents.name
          : null,
      contentSize: _type == ActivityType.diaper || _type == ActivityType.potty
          ? _contentSize.name
          : null,
      pooColour: _type == ActivityType.diaper && _pooColour != null
          ? _pooColour!.name
          : null,
      pooConsistency:
          _type == ActivityType.diaper && _pooConsistency != null
              ? _pooConsistency!.name
              : null,
      peeSize: _type == ActivityType.diaper &&
              _contents == DiaperContents.both &&
              _peeSize != null
          ? _peeSize!.name
          : null,

      // Meds
      medicationName: _nullIfEmpty(_medNameController.text),
      dose: _nullIfEmpty(_doseController.text),
      doseUnit: _nullIfEmpty(_doseUnitController.text),

      // Solids
      foodDescription: _nullIfEmpty(_foodDescController.text),
      reaction: _type == ActivityType.solids ? _reaction.name : null,
      recipeId: _type == ActivityType.solids ? _recipeId : null,
      ingredientNames: _type == ActivityType.solids ? _ingredientNames : null,
      allergenNames: _type == ActivityType.solids ? _allergenNames : null,

      // Growth
      weightKg: _parseDouble(_weightController.text),
      lengthCm: _parseDouble(_lengthController.text),
      headCircumferenceCm: _parseDouble(_headController.text),

      // Temperature
      tempCelsius: _parseDouble(_tempController.text),

      // Notes
      notes: _nullIfEmpty(_notesController.text),
    );

    final repo = ref.read(activityRepositoryProvider);
    try {
      if (widget.activityId != null) {
        await repo.updateActivity(familyId, entry);
      } else {
        await repo.insertActivity(familyId, entry);
      }
      if (mounted) {
        _isDirty = false;
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

  double? _parseDouble(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  int? _parseInt(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String? _nullIfEmpty(String s) {
    final trimmed = s.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.activityId != null;
    final isCopy = widget.copyFromId != null;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(activityDisplayName(_type))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to go back?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          _isDirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          '${isEdit ? 'Edit' : isCopy ? 'Copy' : 'Log'} ${activityDisplayName(_type)}',
        ),
        actions: [
          if (isEdit) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy as new',
              onPressed: () => context.pushReplacement(
                '/log/${widget.activityType}?copyFrom=${widget.activityId}',
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        onChanged: () {
          if (!_isDirty) setState(() => _isDirty = true);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Start date
            ListTile(
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_startTime)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDate(isStart: true),
            ),
            // Start time
            ListTile(
              title: const Text('Time'),
              subtitle: Text(DateFormat.Hm().format(_startTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _pickTime(isStart: true),
            ),

            // End time (for duration-based activities)
            if (_hasDuration) ...[
              ListTile(
                title: const Text('End date'),
                subtitle: Text(
                  _endTime != null ? DateFormat.yMMMd().format(_endTime!) : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _pickDate(isStart: false),
              ),
              ListTile(
                title: const Text('End time'),
                subtitle: Text(
                  _endTime != null ? DateFormat.Hm().format(_endTime!) : 'Not set',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickTime(isStart: false),
              ),
              if (_endTime != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _endTime!.isBefore(_startTime)
                      ? Text(
                          'End time must be after start time',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        )
                      : Text(
                          'Duration: ${formatDuration(_computeDuration())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
            ],

            const Divider(height: 32),

            // Type-specific fields
            ..._buildTypeFields(),

            const SizedBox(height: 16),

            // Notes (for all types)
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
      ),
    ),
    );
  }

  bool get _hasDuration => const [
        ActivityType.feedBreast,
        ActivityType.tummyTime,
        ActivityType.indoorPlay,
        ActivityType.outdoorPlay,
        ActivityType.pump,
        ActivityType.bath,
        ActivityType.skinToSkin,
        ActivityType.sleep,
      ].contains(_type);

  List<Widget> _buildTypeFields() {
    switch (_type) {
      case ActivityType.feedBottle:
        return _buildBottleFields();
      case ActivityType.feedBreast:
        return _buildBreastFields();
      case ActivityType.diaper:
        return _buildDiaperFields();
      case ActivityType.meds:
        return _buildMedsFields();
      case ActivityType.solids:
        return _buildSolidsFields();
      case ActivityType.growth:
        return _buildGrowthFields();
      case ActivityType.temperature:
        return _buildTempFields();
      case ActivityType.pump:
        return _buildPumpFields();
      case ActivityType.potty:
        return _buildPottyFields();
      case ActivityType.tummyTime:
      case ActivityType.indoorPlay:
      case ActivityType.outdoorPlay:
      case ActivityType.bath:
      case ActivityType.skinToSkin:
      case ActivityType.sleep:
        return []; // Duration-only, handled above
    }
  }

  List<Widget> _buildBottleFields() {
    return [
      SegmentedButton<FeedType>(
        segments: const [
          ButtonSegment(value: FeedType.formula, label: Text('Formula')),
          ButtonSegment(value: FeedType.breastMilk, label: Text('Breast Milk')),
        ],
        selected: {_feedType},
        onSelectionChanged: (s) => setState(() => _feedType = s.first),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _volumeController,
        decoration: const InputDecoration(
          labelText: 'Volume (ml)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  List<Widget> _buildBreastFields() {
    return [
      TextFormField(
        controller: _rightBreastController,
        decoration: const InputDecoration(
          labelText: 'Right breast (minutes)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _leftBreastController,
        decoration: const InputDecoration(
          labelText: 'Left breast (minutes)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  List<Widget> _buildDiaperFields() {
    return [
      SegmentedButton<DiaperContents>(
        segments: const [
          ButtonSegment(value: DiaperContents.pee, label: Text('Pee')),
          ButtonSegment(value: DiaperContents.poo, label: Text('Poo')),
          ButtonSegment(value: DiaperContents.both, label: Text('Both')),
        ],
        selected: {_contents},
        onSelectionChanged: (s) => setState(() => _contents = s.first),
      ),
      const SizedBox(height: 16),
      SegmentedButton<ContentSize>(
        segments: const [
          ButtonSegment(value: ContentSize.small, label: Text('Small')),
          ButtonSegment(value: ContentSize.medium, label: Text('Medium')),
          ButtonSegment(value: ContentSize.large, label: Text('Large')),
        ],
        selected: {_contentSize},
        onSelectionChanged: (s) => setState(() => _contentSize = s.first),
      ),
      if (_contents == DiaperContents.both) ...[
        const SizedBox(height: 16),
        SegmentedButton<ContentSize>(
          segments: const [
            ButtonSegment(value: ContentSize.small, label: Text('Pee: S')),
            ButtonSegment(value: ContentSize.medium, label: Text('Pee: M')),
            ButtonSegment(value: ContentSize.large, label: Text('Pee: L')),
          ],
          selected: {_peeSize ?? ContentSize.medium},
          onSelectionChanged: (s) => setState(() => _peeSize = s.first),
        ),
      ],
      if (_contents == DiaperContents.poo || _contents == DiaperContents.both) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<PooColour>(
          value: _pooColour,
          decoration: const InputDecoration(
            labelText: 'Colour',
            border: OutlineInputBorder(),
          ),
          items: PooColour.values
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _pooColour = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PooConsistency>(
          value: _pooConsistency,
          decoration: const InputDecoration(
            labelText: 'Consistency',
            border: OutlineInputBorder(),
          ),
          items: PooConsistency.values
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c.name),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _pooConsistency = v),
        ),
      ],
    ];
  }

  List<Widget> _buildMedsFields() {
    return [
      TextFormField(
        controller: _medNameController,
        decoration: const InputDecoration(
          labelText: 'Medication name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _doseController,
              decoration: const InputDecoration(
                labelText: 'Dose',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _doseUnitController,
              decoration: const InputDecoration(
                labelText: 'Unit',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _showRecipePicker() {
    final recipes = ref.read(recipesProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RecipePickerSheet(
        recipes: recipes,
        onSelected: (recipe) {
          final allIngredients =
              ref.read(ingredientsProvider).valueOrNull ?? [];
          final allergens = computeAllergensByName(
              recipe.ingredients, allIngredients);
          setState(() {
            _isDirty = true;
            _recipeId = recipe.id;
            _ingredientNames = List<String>.from(recipe.ingredients);
            _allergenNames =
                allergens.isNotEmpty ? allergens.toList() : null;
            _foodDescController.text = recipe.name;
          });
          Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _clearRecipe() {
    setState(() {
      _recipeId = null;
      _ingredientNames = null;
      _allergenNames = null;
      _foodDescController.clear();
    });
  }

  void _addStandaloneIngredient(String name, {List<String>? knownAllergens}) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final current = _ingredientNames ?? [];
    if (current.contains(normalized)) return;
    final allIngredients =
        ref.read(ingredientsProvider).valueOrNull ?? [];
    final updated = [...current, normalized];
    final allergens = computeAllergensByName(updated, allIngredients);
    // Merge any known allergens not yet in the computed set (e.g., newly
    // created ingredient whose stream hasn't propagated yet).
    if (knownAllergens != null) {
      for (final a in knownAllergens) {
        allergens.add(a.trim().toLowerCase());
      }
    }
    setState(() {
      _ingredientNames = updated;
      _allergenNames = allergens.isNotEmpty ? allergens.toList() : null;
    });
  }

  void _removeStandaloneIngredient(String name) {
    final current = _ingredientNames ?? [];
    final updated = current.where((i) => i != name).toList();
    final allIngredients =
        ref.read(ingredientsProvider).valueOrNull ?? [];
    final allergens = computeAllergensByName(updated, allIngredients);
    setState(() {
      _ingredientNames = updated.isEmpty ? null : updated;
      _allergenNames = allergens.isNotEmpty ? allergens.toList() : null;
    });
  }

  void _showCreateIngredientDialog(String name) {
    final allergenCategories = ref.read(allergenCategoriesProvider);
    var selectedAllergens = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Create "$name"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Allergen categories:'),
              const SizedBox(height: 8),
              if (allergenCategories.isEmpty)
                const Text('No allergen categories defined',
                    style: TextStyle(color: Colors.grey))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: allergenCategories.map((cat) {
                    final selected = selectedAllergens.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (v) {
                        setDialogState(() {
                          if (v) {
                            selectedAllergens.add(cat);
                          } else {
                            selectedAllergens.remove(cat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final familyId = ref.read(selectedFamilyIdProvider);
                if (familyId == null) return;

                final now = DateTime.now();
                final user = ref.read(currentUserProvider);
                final ingredient = IngredientModel(
                  id: const Uuid().v4(),
                  name: name.toLowerCase(),
                  allergens: selectedAllergens.toList(),
                  createdBy: user?.uid ?? '',
                  createdAt: now,
                  modifiedAt: now,
                );

                try {
                  final repo = ref.read(ingredientRepositoryProvider);
                  await repo.createIngredient(familyId, ingredient);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _addStandaloneIngredient(name,
                      knownAllergens: selectedAllergens.toList());
                } on DuplicateNameException {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    _addStandaloneIngredient(name);
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Failed to create: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSolidsFields() {
    final allIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? [];
    // Watch recipes so the provider is warm when user taps "Pick a Recipe".
    final recipesAsync = ref.watch(recipesProvider);
    final recipes = recipesAsync.valueOrNull ?? [];
    return [
      if (_recipeId != null) ...[
        Row(
          children: [
            Expanded(
              child: Chip(
                avatar: const Icon(Icons.menu_book, size: 18),
                label: Text(_foodDescController.text),
                onDeleted: _clearRecipe,
              ),
            ),
          ],
        ),
        if (_ingredientNames != null && _ingredientNames!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              '${_ingredientNames!.length} ingredients: ${_ingredientNames!.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ] else ...[
        OutlinedButton.icon(
          onPressed: recipes.isEmpty ? null : _showRecipePicker,
          icon: const Icon(Icons.menu_book),
          label: Text(recipes.isEmpty
              ? 'No recipes available'
              : 'Pick a Recipe'),
        ),
        const SizedBox(height: 12),
        // Standalone ingredient picker (always shown)
        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            final names = allIngredients.map((i) => i.name).toList();
            if (query.isEmpty) return names;
            final matches = names.where((n) => n.toLowerCase().contains(query)).toList();
            if (query.isNotEmpty && !names.contains(query)) {
              matches.add('+ Create "$query"');
            }
            return matches;
          },
          fieldViewBuilder:
              (context, controller, focusNode, onSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Add ingredient',
                border: OutlineInputBorder(),
                hintText: 'Type to search or create ingredients',
              ),
              onFieldSubmitted: (_) {
                final text = controller.text.trim().toLowerCase();
                if (text.isEmpty) return;
                final known = allIngredients.any((i) => i.name == text);
                if (known) {
                  _addStandaloneIngredient(text);
                } else {
                  _showCreateIngredientDialog(text);
                }
                controller.clear();
              },
            );
          },
          onSelected: (name) {
            if (name.startsWith('+ Create "')) {
              final newName = name.substring(10, name.length - 1);
              _showCreateIngredientDialog(newName);
            } else {
              _addStandaloneIngredient(name);
            }
          },
        ),
        if (_ingredientNames != null && _ingredientNames!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _ingredientNames!
                .map((name) => Chip(
                      label: Text(name),
                      onDeleted: () =>
                          _removeStandaloneIngredient(name),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
      ],
      if (_allergenNames != null && _allergenNames!.isNotEmpty) ...[
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: _allergenNames!
              .map((a) => Chip(
                    label: Text(a,
                        style: Theme.of(context).textTheme.labelSmall),
                    avatar: const Icon(Icons.warning_amber, size: 14),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
      ],
      TextFormField(
        controller: _foodDescController,
        decoration: const InputDecoration(
          labelText: 'Food description',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),
      SegmentedButton<FoodReaction>(
        segments: const [
          ButtonSegment(value: FoodReaction.loved, label: Text('Loved')),
          ButtonSegment(value: FoodReaction.meh, label: Text('Meh')),
          ButtonSegment(value: FoodReaction.disliked, label: Text('Disliked')),
          ButtonSegment(value: FoodReaction.none, label: Text('N/A')),
        ],
        selected: {_reaction},
        onSelectionChanged: (s) => setState(() => _reaction = s.first),
      ),
    ];
  }

  List<Widget> _buildGrowthFields() {
    return [
      TextFormField(
        controller: _weightController,
        decoration: const InputDecoration(
          labelText: 'Weight (kg)',
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _lengthController,
        decoration: const InputDecoration(
          labelText: 'Length (cm)',
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _headController,
        decoration: const InputDecoration(
          labelText: 'Head circumference (cm)',
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ];
  }

  List<Widget> _buildTempFields() {
    return [
      TextFormField(
        controller: _tempController,
        decoration: const InputDecoration(
          labelText: 'Temperature (°C)',
          border: OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ];
  }

  List<Widget> _buildPumpFields() {
    return [
      TextFormField(
        controller: _volumeController,
        decoration: const InputDecoration(
          labelText: 'Volume (ml)',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    ];
  }

  List<Widget> _buildPottyFields() {
    return [
      SegmentedButton<DiaperContents>(
        segments: const [
          ButtonSegment(value: DiaperContents.pee, label: Text('Pee')),
          ButtonSegment(value: DiaperContents.poo, label: Text('Poo')),
          ButtonSegment(value: DiaperContents.both, label: Text('Both')),
        ],
        selected: {_contents},
        onSelectionChanged: (s) => setState(() => _contents = s.first),
      ),
      const SizedBox(height: 16),
      SegmentedButton<ContentSize>(
        segments: const [
          ButtonSegment(value: ContentSize.small, label: Text('Small')),
          ButtonSegment(value: ContentSize.medium, label: Text('Medium')),
          ButtonSegment(value: ContentSize.large, label: Text('Large')),
        ],
        selected: {_contentSize},
        onSelectionChanged: (s) => setState(() => _contentSize = s.first),
      ),
    ];
  }
}

/// Bottom sheet with search for picking a recipe.
class _RecipePickerSheet extends StatefulWidget {
  final List<RecipeModel> recipes;
  final ValueChanged<RecipeModel> onSelected;

  const _RecipePickerSheet({
    required this.recipes,
    required this.onSelected,
  });

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.recipes
        : widget.recipes
            .where((r) => r.name.contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search recipes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matching recipes'))
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      return ListTile(
                        title: Text(recipe.name),
                        subtitle: Text(recipe.ingredients.join(', ')),
                        leading: const Icon(Icons.menu_book),
                        onTap: () => widget.onSelected(recipe),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
