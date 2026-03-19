import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/repository_provider.dart';

class ManageAllergensScreen extends ConsumerStatefulWidget {
  const ManageAllergensScreen({super.key});

  @override
  ConsumerState<ManageAllergensScreen> createState() =>
      _ManageAllergensScreenState();
}

class _ManageAllergensScreenState
    extends ConsumerState<ManageAllergensScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim().toLowerCase();
    if (text.isEmpty) return;

    final categories = ref.read(allergenCategoriesProvider);
    if (categories.contains(text)) {
      _controller.clear();
      return;
    }

    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    try {
      final updated = [...categories, text];
      await ref
          .read(familyRepositoryProvider)
          .updateAllergenCategories(familyId, updated);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add allergen: $e')),
        );
      }
    }
  }

  Future<void> _remove(String allergen, int usageCount) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete allergen?'),
        content: Text(
          usageCount > 0
              ? '"$allergen" is used by $usageCount ingredient${usageCount == 1 ? '' : 's'}. '
                  'Removing it will update all affected ingredients, targets, and activities.'
              : 'Remove "$allergen"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(familyRepositoryProvider)
          .removeAllergenCategory(familyId, allergen);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove allergen: $e')),
        );
      }
    }
  }

  Future<void> _rename(String oldName) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final renameController = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename allergen'),
        content: TextField(
          controller: renameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) =>
              Navigator.of(ctx).pop(value.trim().toLowerCase()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx)
                .pop(renameController.text.trim().toLowerCase()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    // Dispose after a post-frame callback so the dialog's widget tree has
    // fully unmounted and no longer references the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      renameController.dispose();
    });

    if (newName == null || newName.isEmpty || newName == oldName) return;

    final categories = ref.read(allergenCategoriesProvider);
    if (categories.contains(newName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Allergen "$newName" already exists')),
        );
      }
      return;
    }

    try {
      await ref
          .read(familyRepositoryProvider)
          .renameAllergenCategory(familyId, oldName, newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to rename allergen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allergenCategoriesProvider);
    final ingredients =
        ref.watch(ingredientsProvider).valueOrNull ?? [];

    // Count how many ingredients use each allergen
    final usageCounts = <String, int>{};
    for (final cat in categories) {
      usageCounts[cat] = ingredients
          .where((i) =>
              i.allergens.any((a) => a.toLowerCase() == cat.toLowerCase()))
          .length;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Allergens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Add allergen category',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., lactose, nuts, gluten',
                  ),
                  onFieldSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _add,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const Text('No allergen categories defined yet.')
          else
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: categories.map((c) {
                final count = usageCounts[c] ?? 0;
                final label =
                    count > 0 ? '$c ($count)' : c;
                return GestureDetector(
                  onTap: () => _rename(c),
                  child: Chip(
                    label: Text(label),
                    onDeleted: () => _remove(c, count),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
