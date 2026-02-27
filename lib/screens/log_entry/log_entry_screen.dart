import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/activity_model.dart';
import '../../models/enums.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';
import '../../providers/child_provider.dart';
import '../../utils/activity_helpers.dart';

class LogEntryScreen extends ConsumerStatefulWidget {
  final String activityType;
  final String? activityId;

  const LogEntryScreen({
    super.key,
    required this.activityType,
    this.activityId,
  });

  @override
  ConsumerState<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends ConsumerState<LogEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late ActivityType _type;
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    _type = parseActivityType(widget.activityType) ?? ActivityType.feedBottle;
    _startTime = DateTime.now();

    if (widget.activityId != null) {
      _loadExisting();
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

      // Growth
      if (activity.weightKg != null) _weightController.text = activity.weightKg.toString();
      if (activity.lengthCm != null) _lengthController.text = activity.lengthCm.toString();
      if (activity.headCircumferenceCm != null) _headController.text = activity.headCircumferenceCm.toString();

      // Temperature
      if (activity.tempCelsius != null) _tempController.text = activity.tempCelsius.toString();

      // Notes
      if (activity.notes != null) _notesController.text = activity.notes!;

      _loading = false;
    });
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

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startTime : (_endTime ?? _startTime);
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
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
    await repo.softDeleteActivity(familyId, widget.activityId!);

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final childId = ref.read(selectedChildIdProvider);
    final familyId = ref.read(selectedFamilyIdProvider);
    if (childId == null || familyId == null) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final isEdit = widget.activityId != null;
    final id = widget.activityId ?? const Uuid().v4();
    final duration = _computeDuration();

    final entry = ActivityModel(
      id: id,
      childId: childId,
      type: _type.name,
      startTime: _startTime,
      endTime: _endTime,
      durationMinutes: duration,
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
    if (widget.activityId != null) {
      await repo.updateActivity(familyId, entry);
    } else {
      await repo.insertActivity(familyId, entry);
    }

    if (mounted) Navigator.of(context).pop();
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
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    final isEdit = widget.activityId != null;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(activityDisplayName(_type))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'Log'} ${activityDisplayName(_type)}'),
        actions: [
          if (isEdit)
            IconButton(
              icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Start time
            ListTile(
              title: const Text('Time'),
              subtitle: Text(dateFormat.format(_startTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _pickDateTime(isStart: true),
            ),

            // End time (for duration-based activities)
            if (_hasDuration) ...[
              ListTile(
                title: const Text('End time'),
                subtitle: Text(
                  _endTime != null ? dateFormat.format(_endTime!) : 'Not set',
                ),
                trailing: const Icon(Icons.access_time),
                onTap: () => _pickDateTime(isStart: false),
              ),
              if (_computeDuration() != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
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
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipes yet. Create one in Recipes.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final recipe = recipes[index];
          return ListTile(
            title: Text(recipe.name),
            subtitle: Text(recipe.ingredients.join(', ')),
            leading: const Icon(Icons.menu_book),
            onTap: () {
              setState(() {
                _recipeId = recipe.id;
                _ingredientNames = List<String>.from(recipe.ingredients);
                _foodDescController.text = recipe.name;
              });
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  void _clearRecipe() {
    setState(() {
      _recipeId = null;
      _ingredientNames = null;
      _foodDescController.clear();
    });
  }

  List<Widget> _buildSolidsFields() {
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
          onPressed: _showRecipePicker,
          icon: const Icon(Icons.menu_book),
          label: const Text('Pick a Recipe'),
        ),
        const SizedBox(height: 12),
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
