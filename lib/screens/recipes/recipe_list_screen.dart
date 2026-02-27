import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/child_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/repository_provider.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];

              return Dismissible(
                key: ValueKey(recipe.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.onError),
                ),
                confirmDismiss: (_) async {
                  final familyId = ref.read(selectedFamilyIdProvider);
                  if (familyId == null) return false;

                  bool undone = false;
                  await ScaffoldMessenger.of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text('${recipe.name} deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => undone = true,
                      ),
                    ),
                  )
                      .closed
                      .then((reason) {
                    if (!undone) {
                      ref
                          .read(recipeRepositoryProvider)
                          .softDeleteRecipe(familyId, recipe.id);
                    }
                  });
                  return false;
                },
                child: Card(
                  child: InkWell(
                    onTap: () =>
                        context.push('/recipes/add?id=${recipe.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.name,
                            style: Theme.of(context).textTheme.titleMedium,
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
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
