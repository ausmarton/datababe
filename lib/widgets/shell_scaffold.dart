import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/sync_provider.dart';
import '../sync/sync_engine.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/timeline')) return 1;
    if (location.startsWith('/insights')) return 2;
    if (location.startsWith('/family')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 8,
            child: _SyncDot(status: syncStatus.valueOrNull),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/timeline');
            case 2:
              context.go('/insights');
            case 3:
              context.go('/family');
            case 4:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Timeline',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.family_restroom_outlined),
            selectedIcon: Icon(Icons.family_restroom),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _SyncDot extends StatelessWidget {
  final SyncStatus? status;

  const _SyncDot({this.status});

  @override
  Widget build(BuildContext context) {
    final (color, tooltip) = switch (status) {
      SyncStatus.idle => (Colors.green, 'Synced'),
      SyncStatus.syncing => (Colors.amber, 'Syncing...'),
      SyncStatus.error => (Colors.red, 'Sync error'),
      SyncStatus.offline => (Colors.grey, 'Offline'),
      null => (Colors.grey, 'Unknown'),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
