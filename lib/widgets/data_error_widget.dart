import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-friendly error widget with a retry button.
///
/// Use this instead of raw `Text('Error: $e')` in `.when(error:)` handlers.
class DataErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const DataErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyMessage(error),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _friendlyMessage(Object error) {
    final msg = error.toString();
    if (msg.contains('DatabaseException') || msg.contains('sembast')) {
      return 'Could not read local data. Try closing and reopening the app.';
    }
    if (msg.contains('permission') || msg.contains('Permission')) {
      return 'Permission denied. Check your account access.';
    }
    return 'Please try again. If the problem persists, restart the app.';
  }
}

/// Helper to create a retry callback that invalidates a provider.
VoidCallback retryProvider(WidgetRef ref, ProviderListenable provider) {
  return () => ref.invalidate(provider as ProviderOrFamily);
}
