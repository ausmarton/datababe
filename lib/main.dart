import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'providers/sync_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _AppWithSync()));
}

class _AppWithSync extends ConsumerStatefulWidget {
  const _AppWithSync();

  @override
  ConsumerState<_AppWithSync> createState() => _AppWithSyncState();
}

class _AppWithSyncState extends ConsumerState<_AppWithSync> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autoSyncProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const FilhoApp();
  }
}
