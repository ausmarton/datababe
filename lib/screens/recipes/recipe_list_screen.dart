import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/recipe_model.dart';
import '../../providers/child_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';
import '../../utils/allergen_helpers.dart';

final _recipeSearchProvider = StateProvider<String>((ref) => '');

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    final allIngredients =
        ref.watch(ingredientsProvider).valueOrNull ?? [];
    final search = ref.watch(_recipeSearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: recipesAsync.when(
          data: (list) => Text('Recipes (${list.length})'),
          loading: () => const Text('Recipes'),
          error: (_, __) => const Text('Recipes'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recipes/add'),
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return const Center(
              child: Text('No recipes yet.\nTap + to create one.'),
            );
          }

          final filtered = search.isEmpty
              ? recipes
              : recipes
                  .where((r) => r.name.toLowerCase().contains(search))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search recipes...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      ref.read(_recipeSearchProvider.notifier).state = v,
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No matching recipes'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final recipe = filtered[index];
                          final allergens = computeAllergensByName(
                              recipe.ingredients, allIngredients);
                          return _RecipeCard(
                              recipe: recipe, allergens: allergens);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  final RecipeModel recipe;
  final Set<String> allergens;

  const _RecipeCard({required this.recipe, required this.allergens});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () => context.push('/recipes/add?id=${recipe.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        Text(
                          '${recipe.ingredients.length} ingredients',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: recipe.ingredients
                          .map((i) => Chip(
                                label: Text(i),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                    if (allergens.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: allergens
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
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteRecipe(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteRecipe(BuildContext context, WidgetRef ref) async {
    final familyId = ref.read(selectedFamilyIdProvider);
    if (familyId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content:
            Text('Are you sure you want to delete "${recipe.name}"?'),
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
          .read(recipeRepositoryProvider)
          .softDeleteRecipe(familyId, recipe.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${recipe.name} deleted')),
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
