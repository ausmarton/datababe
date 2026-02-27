import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/child_provider.dart';
import '../../providers/family_provider.dart';
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

    final updated = [...categories, text];
    await ref
        .read(familyRepositoryProvider)
        .updateAllergenCategories(familyId, updated);
    _controller.clear();
  }

  Future<void> _remove(String allergen) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final categories = ref.read(allergenCategoriesProvider);
    final updated = categories.where((c) => c != allergen).toList();
    await ref
        .read(familyRepositoryProvider)
        .updateAllergenCategories(familyId, updated);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allergenCategoriesProvider);

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
              children: categories
                  .map((c) => Chip(
                        label: Text(c),
                        onDeleted: () => _remove(c),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
