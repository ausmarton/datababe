import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/ingredient_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/repository_provider.dart';
import '../../repositories/duplicate_name_exception.dart';

class AddIngredientScreen extends ConsumerStatefulWidget {
  final String? ingredientId;

  const AddIngredientScreen({super.key, this.ingredientId});

  @override
  ConsumerState<AddIngredientScreen> createState() =>
      _AddIngredientScreenState();
}

class _AddIngredientScreenState extends ConsumerState<AddIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _selectedAllergens = <String>{};
  bool _saving = false;
  bool _loading = false;

  DateTime _originalCreatedAt = DateTime.now();
  String _originalCreatedBy = '';
  String? _originalName;

  bool get _isEdit => widget.ingredientId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    setState(() => _loading = true);

    final repo = ref.read(ingredientRepositoryProvider);
    final ingredient =
        await repo.getIngredient(familyId, widget.ingredientId!);

    if (ingredient == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _nameController.text = ingredient.name;
      _selectedAllergens
        ..clear()
        ..addAll(ingredient.allergens);
      _originalCreatedAt = ingredient.createdAt;
      _originalCreatedBy = ingredient.createdBy;
      _originalName = ingredient.name;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final familyId = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (familyId == null || user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No family selected')),
        );
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final normalizedName = _nameController.text.trim().toLowerCase();
      final ingredient = IngredientModel(
        id: widget.ingredientId ?? const Uuid().v4(),
        name: normalizedName,
        allergens: _selectedAllergens.toList(),
        createdBy: _isEdit ? _originalCreatedBy : user.uid,
        createdAt: _isEdit ? _originalCreatedAt : now,
        modifiedAt: now,
      );

      final repo = ref.read(ingredientRepositoryProvider);
      if (_isEdit && _originalName != null && _originalName != normalizedName) {
        await repo.renameIngredient(familyId, ingredient, _originalName!);
      } else if (_isEdit) {
        await repo.updateIngredient(familyId, ingredient);
      } else {
        await repo.createIngredient(familyId, ingredient);
      }

      if (mounted) Navigator.of(context).pop();
    } on DuplicateNameException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save ingredient: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar:
            AppBar(title: Text(_isEdit ? 'Edit Ingredient' : 'New Ingredient')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allergenCategories = ref.watch(allergenCategoriesProvider);

    return Scaffold(
      appBar:
          AppBar(title: Text(_isEdit ? 'Edit Ingredient' : 'New Ingredient')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ingredient name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            if (allergenCategories.isNotEmpty) ...[
              Text(
                'Allergens',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: allergenCategories.map((allergen) {
                  final selected = _selectedAllergens.contains(allergen);
                  return FilterChip(
                    label: Text(allergen),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selectedAllergens.add(allergen);
                        } else {
                          _selectedAllergens.remove(allergen);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ] else
              Text(
                'No allergen categories defined. Add them in Settings > Manage Allergens.',
                style: Theme.of(context).textTheme.bodySmall,
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
}
