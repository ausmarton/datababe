import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/ingredient_model.dart';
import '../../providers/child_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/repository_provider.dart';
import '../../widgets/data_error_widget.dart';

final _ingredientSearchProvider = StateProvider<String>((ref) => '');

class IngredientListScreen extends ConsumerWidget {
  const IngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);
    final search = ref.watch(_ingredientSearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: ingredientsAsync.when(
          data: (list) => Text('Ingredients (${list.length})'),
          loading: () => const Text('Ingredients'),
          error: (_, __) => const Text('Ingredients'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/ingredients/add'),
        child: const Icon(Icons.add),
      ),
      body: ingredientsAsync.when(
        data: (ingredients) {
          if (ingredients.isEmpty) {
            return const Center(
              child: Text('No ingredients yet.\nTap + to create one.'),
            );
          }

          final filtered = search.isEmpty
              ? ingredients
              : ingredients
                  .where((i) => i.name.toLowerCase().contains(search))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search ingredients...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => ref
                      .read(_ingredientSearchProvider.notifier)
                      .state = v,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching ingredients'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final ingredient = filtered[index];
                          return _IngredientCard(ingredient: ingredient);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(ingredientsProvider),
        ),
      ),
    );
  }
}

class _IngredientCard extends ConsumerWidget {
  final IngredientModel ingredient;

  const _IngredientCard({required this.ingredient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () =>
            context.push('/ingredients/add?id=${ingredient.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ingredient.name,
                      style:
                          Theme.of(context).textTheme.titleMedium,
                    ),
                    if (ingredient.allergens.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: ingredient.allergens
                            .map((a) => Chip(
                                  label: Text(a),
                                  avatar: const Icon(
                                      Icons.warning_amber,
                                      size: 16),
                                  visualDensity:
                                      VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    _deleteIngredient(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteIngredient(
      BuildContext context, WidgetRef ref) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ingredient?'),
        content:
            Text('Are you sure you want to delete "${ingredient.name}"?'),
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
    if (!context.mounted) return;

    try {
      await ref
          .read(ingredientRepositoryProvider)
          .softDeleteIngredient(familyId, ingredient.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ingredient.name} deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}
