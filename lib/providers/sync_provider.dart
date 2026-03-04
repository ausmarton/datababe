import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_provider.dart';
import '../sync/connectivity_monitor.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_metadata.dart';
import '../sync/sync_queue.dart';

final syncQueueProvider = Provider<SyncQueue>((ref) {
  return SyncQueue(ref.watch(localDatabaseProvider));
});

final syncMetadataProvider = Provider<SyncMetadata>((ref) {
  return SyncMetadata(ref.watch(localDatabaseProvider));
});

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(monitor.dispose);
  return monitor;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(localDatabaseProvider),
    firestore: FirebaseFirestore.instance,
    queue: ref.watch(syncQueueProvider),
    metadata: ref.watch(syncMetadataProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.statusStream;
});

final isOnlineProvider = StreamProvider<bool>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  return monitor.onlineStream;
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.lastSyncTime;
});

final pendingSyncCountProvider = FutureProvider<int>((ref) {
  final queue = ref.watch(syncQueueProvider);
  return queue.pendingCount();
});
