import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/recipe_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/child_provider.dart';
import '../../providers/repository_provider.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  final String? recipeId;

  const AddRecipeScreen({super.key, this.recipeId});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ingredientController = TextEditingController();
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
    _ingredientController.dispose();
    super.dispose();
  }

  void _addIngredient() {
    final text = _ingredientController.text.trim().toLowerCase();
    if (text.isEmpty) return;
    if (_ingredients.contains(text)) {
      _ingredientController.clear();
      return;
    }
    setState(() {
      _ingredients.add(text);
      _ingredientController.clear();
    });
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

    setState(() => _saving = true);

    final now = DateTime.now();
    final recipe = RecipeModel(
      id: widget.recipeId ?? const Uuid().v4(),
      name: _nameController.text.trim(),
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Edit Recipe' : 'New Recipe')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ingredientController,
                    decoration: const InputDecoration(
                      labelText: 'Add ingredient',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_ingredients.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _ingredients
                    .map((i) => Chip(
                          label: Text(i),
                          onDeleted: () =>
                              setState(() => _ingredients.remove(i)),
                        ))
                    .toList(),
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
