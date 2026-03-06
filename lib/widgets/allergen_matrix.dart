import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/insights_provider.dart';

class AllergenMatrix extends StatelessWidget {
  final WeeklyAllergenMatrix matrix;
  final void Function(int dayIndex, String allergen)? onDotTap;

  const AllergenMatrix({
    super.key,
    required this.matrix,
    this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    if (matrix.allergens.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dayFormat = DateFormat('E');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: day labels
        Row(
          children: [
            const SizedBox(width: 80), // allergen label column
            ...List.generate(7, (i) {
              final isFuture = matrix.days[i].isAfter(todayDate);
              return Expanded(
                child: Center(
                  child: Text(
                    dayFormat.format(matrix.days[i]).substring(0, 1),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isFuture
                              ? Theme.of(context).colorScheme.outlineVariant
                              : null,
                        ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 4),
        // Allergen rows
        ...matrix.allergens.map((allergen) {
          final exposedDays = matrix.matrix[allergen] ?? {};
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    allergen,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...List.generate(7, (i) {
                  final isFuture = matrix.days[i].isAfter(todayDate);
                  final isExposed = exposedDays.contains(i);
                  return Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: isExposed
                            ? () => onDotTap?.call(i, allergen)
                            : null,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFuture
                                ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                : isExposed
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
