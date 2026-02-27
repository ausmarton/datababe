import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/child_provider.dart';
import '../../providers/ingredient_provider.dart';
import '../../providers/repository_provider.dart';

class IngredientListScreen extends ConsumerWidget {
  const IngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredientsAsync = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingredients')),
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];

              return Dismissible(
                key: ValueKey(ingredient.id),
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
                      content: Text('${ingredient.name} deleted'),
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
                          .read(ingredientRepositoryProvider)
                          .softDeleteIngredient(familyId, ingredient.id);
                    }
                  });
                  return false;
                },
                child: Card(
                  child: InkWell(
                    onTap: () => context
                        .push('/ingredients/add?id=${ingredient.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
