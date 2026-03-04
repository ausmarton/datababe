import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity and exposes streams for sync triggers.
class ConnectivityMonitor {
  final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  final _restoredController = StreamController<void>.broadcast();
  bool _wasOffline = false;
  bool _isOnline = true;

  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online && _wasOffline) {
      _restoredController.add(null);
    }
    _wasOffline = !online;
    _isOnline = online;
  }

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Emits when connectivity is restored after being offline.
  Stream<void> get onConnectivityRestored => _restoredController.stream;

  /// Stream of current online status.
  Stream<bool> get onlineStream =>
      _connectivity.onConnectivityChanged.map((results) =>
          results.any((r) => r != ConnectivityResult.none));

  void dispose() {
    _subscription.cancel();
    _restoredController.close();
  }
}
