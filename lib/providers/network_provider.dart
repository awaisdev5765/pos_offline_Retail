import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_discovery_service.dart';
import '../services/database_sync_service.dart';
import '../services/database_service.dart';
import '../services/device_identity_service.dart';

// Network Discovery Service Provider
final networkDiscoveryProvider = Provider<NetworkDiscoveryService>((ref) {
  return NetworkDiscoveryService();
});

// Database Sync Service Provider
final databaseSyncProvider = Provider<DatabaseSyncService>((ref) {
  return DatabaseSyncService();
});

// Network Status Provider
final networkStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(databaseSyncProvider);
  return syncService.statusStream;
});

// Discovered Servers Provider
final discoveredServersProvider = StreamProvider<List<POSServer>>((ref) {
  final discoveryService = ref.watch(networkDiscoveryProvider);
  return discoveryService.serversStream;
});

// Connection Status Provider
final connectionStatusProvider = StreamProvider<bool>((ref) {
  final discoveryService = ref.watch(networkDiscoveryProvider);
  return discoveryService.connectionStatusStream;
});

// Sync Progress Provider
final syncProgressProvider = StreamProvider<SyncProgress>((ref) {
  final syncService = ref.watch(databaseSyncProvider);
  return syncService.progressStream;
});

// Connected Clients Count Provider (for admin server)
final connectedClientsCountProvider = StreamProvider<int>((ref) {
  final syncService = ref.watch(databaseSyncProvider);
  return syncService.connectedClientsCountStream;
});

// Network Configuration Provider
final networkConfigProvider =
    StateNotifierProvider<NetworkConfigNotifier, NetworkConfigState>((ref) {
  return NetworkConfigNotifier(ref);
});

class NetworkConfigNotifier extends StateNotifier<NetworkConfigState> {
  final Ref ref;

  NetworkConfigNotifier(this.ref) : super(NetworkConfigState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final discoveryService = ref.read(networkDiscoveryProvider);
      final syncService = ref.read(databaseSyncProvider);
      final databaseService = ref.read(databaseServiceProvider);

      await discoveryService.initialize();
      await syncService.initialize(databaseService.db, discoveryService);

      state = state.copyWith(
        isInitialized: true,
        currentIP: await discoveryService.getCurrentIPAddress(),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  Future<void> startAsAdmin(String serverName, String pairingCode) async {
    try {
      final syncService = ref.read(databaseSyncProvider);

      final success = await syncService.startAsServer(
        serverName: serverName,
        pairingCode: pairingCode,
      );
      if (success) {
        await DeviceIdentityService.markAsAdminDevice(displayName: serverName);
        state = state.copyWith(
          isAdmin: true,
          serverName: serverName,
        );
      } else {
        state = state.copyWith(
          error: 'Failed to start as admin server',
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  Future<void> connectToServer(POSServer server, String pairingCode) async {
    try {
      final syncService = ref.read(databaseSyncProvider);
      final success = await syncService.connectToServer(
        server.address,
        pairingCode: pairingCode,
      );

      if (success) {
        state = state.copyWith(
          connectedServer: server,
          isConnected: true,
        );
      } else {
        state = state.copyWith(
          error: 'Failed to connect to server',
        );
      }
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    try {
      final syncService = ref.read(databaseSyncProvider);
      final discoveryService = ref.read(networkDiscoveryProvider);

      await syncService.disconnect();
      await discoveryService.stopAdvertising();
      await DeviceIdentityService.markAsClientDevice();

      state = state.copyWith(
        isAdmin: false,
        isConnected: false,
        connectedServer: null,
        serverName: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class NetworkConfigState {
  final bool isInitialized;
  final bool isAdmin;
  final bool isConnected;
  final String? currentIP;
  final String? serverName;
  final POSServer? connectedServer;
  final String? error;

  NetworkConfigState({
    this.isInitialized = false,
    this.isAdmin = false,
    this.isConnected = false,
    this.currentIP,
    this.serverName,
    this.connectedServer,
    this.error,
  });

  NetworkConfigState copyWith({
    bool? isInitialized,
    bool? isAdmin,
    bool? isConnected,
    String? currentIP,
    String? serverName,
    POSServer? connectedServer,
    String? error,
  }) {
    return NetworkConfigState(
      isInitialized: isInitialized ?? this.isInitialized,
      isAdmin: isAdmin ?? this.isAdmin,
      isConnected: isConnected ?? this.isConnected,
      currentIP: currentIP ?? this.currentIP,
      serverName: serverName ?? this.serverName,
      connectedServer: connectedServer ?? this.connectedServer,
      error: error ?? this.error,
    );
  }
}
