import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor online/offline status and Firestore sync state
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  
  bool _isOnline = true;
  bool _isSyncing = false;
  int _pendingWrites = 0;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get currentStatus => ConnectionStatus(
    isOnline: _isOnline,
    isSyncing: _isSyncing,
    pendingWrites: _pendingWrites,
  );

  void initialize() {
    // Monitor network connectivity
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOffline = !_isOnline;
      // Check if any result is not 'none'
      _isOnline = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
      
      print('[ConnectivityService] Network changed: $_isOnline (results: $results)');
      
      if (wasOffline && _isOnline) {
        // Just came back online - trigger sync
        print('[ConnectivityService] Reconnected! Triggering sync...');
        _handleReconnection();
      } else if (!_isOnline) {
        print('[ConnectivityService] Offline detected');
        _isSyncing = false;
      }
      
      _emitStatus();
    });

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      _isOnline = results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
      print('[ConnectivityService] Initial connectivity: $_isOnline (results: $results)');
      _emitStatus();
    });
  }

  void _handleReconnection() {
    _isSyncing = true;
    _emitStatus();
    
    // Firestore auto-syncs, we just show indicator for 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      _isSyncing = false;
      _pendingWrites = 0;
      _emitStatus();
    });
  }

  void incrementPendingWrites() {
    if (!_isOnline) {
      _pendingWrites++;
      _emitStatus();
    }
  }

  void _emitStatus() {
    print('[ConnectivityService] Emitting status: online=$_isOnline, syncing=$_isSyncing, pending=$_pendingWrites');
    _statusController.add(currentStatus);
  }

  void dispose() {
    _statusController.close();
  }
}

class ConnectionStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingWrites;

  ConnectionStatus({
    required this.isOnline,
    required this.isSyncing,
    required this.pendingWrites,
  });

  String get displayText {
    if (isSyncing) return 'Syncing...';
    if (!isOnline && pendingWrites > 0) return 'Offline ($pendingWrites pending)';
    if (!isOnline) return 'Offline';
    return 'Online';
  }

  bool get showIndicator => !isOnline || isSyncing;
}
