import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/family_provider.dart';
import '../../providers/insights_provider.dart';

/// Selected period for the detail screen (7, 14, or 30 days).
final _detailPeriodProvider = StateProvider<int>((ref) => 14);

class AllergenDetailScreen extends ConsumerWidget {
  const AllergenDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allergenCategoriesProvider);

    if (categories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Allergen Tracking')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Define your allergen categories in Settings > Manage Allergens to start tracking exposure.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/settings/allergens'),
                  child: const Text('Manage Allergens'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Allergen Tracking')),
      body: const _DetailBody(),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_detailPeriodProvider);
    final coveragePeriod = ref.watch(allergenCoveragePeriodProvider);

    // Temporarily override coverage period for this screen's view
    // We use the detail period provider to control the display
    final coverage = ref.watch(allergenCoverageProvider);
    final categories = ref.watch(allergenCategoriesProvider);

    if (coverage == null) {
      return const Center(child: Text('No data available'));
    }

    // Compute coverage for the detail period if different from global
    final effectiveCoverage = period != coveragePeriod ? null : coverage;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 14, label: Text('14d')),
            ButtonSegment(value: 30, label: Text('30d')),
          ],
          selected: {period},
          onSelectionChanged: (s) {
            ref.read(_detailPeriodProvider.notifier).state = s.first;
            ref.read(allergenCoveragePeriodProvider.notifier).state = s.first;
          },
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 16),

        // Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coverage: ${(effectiveCoverage ?? coverage).covered.length} / ${categories.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if ((effectiveCoverage ?? coverage).covered.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (effectiveCoverage ?? coverage)
                        .covered
                        .map((a) => Chip(
                              label: Text(a),
                              backgroundColor: Colors.green.withValues(alpha: 0.15),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                if ((effectiveCoverage ?? coverage).missing.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (effectiveCoverage ?? coverage)
                        .missing
                        .map((a) => Chip(
                              label: Text(a),
                              side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Per-allergen rows
        ...categories.map((cat) {
          final normalized = cat.trim().toLowerCase();
          final cov = effectiveCoverage ?? coverage;
          final count = cov.exposureCounts[normalized] ?? 0;
          final lastDate = cov.lastExposed[normalized];

          return _AllergenRow(
            category: cat,
            exposureCount: count,
            lastExposed: lastDate,
            maxCount: cov.exposureCounts.values.fold(0, (a, b) => a > b ? a : b),
          );
        }),
      ],
    );
  }
}

class _AllergenRow extends ConsumerStatefulWidget {
  final String category;
  final int exposureCount;
  final DateTime? lastExposed;
  final int maxCount;

  const _AllergenRow({
    required this.category,
    required this.exposureCount,
    this.lastExposed,
    required this.maxCount,
  });

  @override
  ConsumerState<_AllergenRow> createState() => _AllergenRowState();
}

class _AllergenRowState extends ConsumerState<_AllergenRow> {
  bool _expanded = false;

  String _formatLastExposed(DateTime? date) {
    if (date == null) return 'Never';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        widget.maxCount > 0 ? widget.exposureCount / widget.maxCount : 0.0;

    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(widget.category),
            subtitle: Text(
              '${widget.exposureCount}x  |  Last: ${_formatLastExposed(widget.lastExposed)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              color: widget.exposureCount > 0 ? Colors.green : Colors.grey,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
            ),
          ),
          if (_expanded) _buildIngredientList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildIngredientList() {
    final details = ref.watch(
        allergenIngredientDrilldownProvider(widget.category));

    if (details.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No ingredients tagged with this allergen'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: details.map((d) {
          final lastStr = d.lastExposure != null
              ? _formatLastExposed(d.lastExposure)
              : 'Never';
          return ListTile(
            dense: true,
            title: Text(d.ingredientName),
            trailing: Text(
              '${d.exposureCount}x  |  $lastStr',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }).toList(),
      ),
    );
  }
}
