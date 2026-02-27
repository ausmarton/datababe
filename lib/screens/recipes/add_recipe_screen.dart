import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/ingredient_model.dart';
import '../../models/recipe_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/allergen_helpers.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  final String? recipeId;

  const AddRecipeScreen({super.key, this.recipeId});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ingredients = <String>[];
  bool _saving = false;
  bool _loading = false;

  DateTime _originalCreatedAt = DateTime.now();
  String _originalCreatedBy = '';

  bool get _isEdit => widget.recipeId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    setState(() => _loading = true);

    final repo = ref.read(recipeRepositoryProvider);
    final recipe = await repo.getRecipe(familyId, widget.recipeId!);

    if (recipe == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _nameController.text = recipe.name;
      _ingredients
        ..clear()
        ..addAll(recipe.ingredients);
      _originalCreatedAt = recipe.createdAt;
      _originalCreatedBy = recipe.createdBy;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addIngredientByName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (_ingredients.contains(normalized)) return;
    setState(() => _ingredients.add(normalized));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one ingredient')),
      );
      return;
    }

    final familyId = ref.read(selectedFamilyIdProvider);
    final user = ref.read(currentUserProvider);
    if (familyId == null || user == null) return;

    final normalizedName = _nameController.text.trim().toLowerCase();
    final existing = ref.read(recipesProvider).valueOrNull ?? [];
    if (existing.any((r) => r.name.toLowerCase() == normalizedName && r.id != widget.recipeId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recipe "$normalizedName" already exists')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final recipe = RecipeModel(
        id: widget.recipeId ?? const Uuid().v4(),
        name: normalizedName,
        ingredients: _ingredients,
        createdBy: _isEdit ? _originalCreatedBy : user.uid,
        createdAt: _isEdit ? _originalCreatedAt : now,
        modifiedAt: now,
      );

      final repo = ref.read(recipeRepositoryProvider);
      if (_isEdit) {
        await repo.updateRecipe(familyId, recipe);
      } else {
        await repo.createRecipe(familyId, recipe);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recipe: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit Recipe' : 'New Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final allIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? <IngredientModel>[];
    final derivedAllergens =
        computeAllergensByName(_ingredients, allIngredients);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Recipe' : 'New Recipe'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Autocomplete<IngredientModel>(
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return allIngredients;
                return allIngredients.where(
                    (i) => i.name.contains(query));
              },
              displayStringForOption: (i) => i.name,
              fieldViewBuilder:
                  (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Add ingredient',
                    border: OutlineInputBorder(),
                    hintText: 'Type to search or add new',
                  ),
                  onFieldSubmitted: (_) {
                    _addIngredientByName(controller.text);
                    controller.clear();
                  },
                );
              },
              onSelected: (ingredient) {
                _addIngredientByName(ingredient.name);
              },
            ),
            const SizedBox(height: 12),
            if (_ingredients.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _ingredients.map((name) {
                  final match = allIngredients
                      .where((i) => i.name == name)
                      .firstOrNull;
                  final hasAllergens =
                      match != null && match.allergens.isNotEmpty;
                  return Chip(
                    label: Text(name),
                    avatar: hasAllergens
                        ? const Icon(Icons.warning_amber, size: 16)
                        : null,
                    onDeleted: () =>
                        setState(() => _ingredients.remove(name)),
                  );
                }).toList(),
              ),
            if (derivedAllergens.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: derivedAllergens
                    .map((a) => Chip(
                          label: Text(a,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall),
                          avatar: const Icon(Icons.warning_amber,
                              size: 14),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ],
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
