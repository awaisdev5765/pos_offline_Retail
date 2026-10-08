import 'dart:async';

import '../services/database_service.dart';
import '../services/database_sync_service.dart';
import '../services/device_identity_service.dart';
import '../services/network_discovery_service.dart';

/// Handles multi-PC initialization logic so secondary PCs can auto-connect to the admin server.
class MultiPcBootstrapper {
  static final MultiPcBootstrapper _instance = MultiPcBootstrapper._internal();
  factory MultiPcBootstrapper() => _instance;
  MultiPcBootstrapper._internal();

  bool _servicesInitialized = false;
  bool _initializingServices = false;
  bool _adminServerStarted = false;

  Future<void> _ensureServices(DatabaseService database) async {
    if (_servicesInitialized) return;
    if (_initializingServices) {
      while (_initializingServices) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializingServices = true;
    try {
      final discoveryService = NetworkDiscoveryService();
      final syncService = DatabaseSyncService();

      await discoveryService.initialize();
      await syncService.initialize(database.db, discoveryService);

      _servicesInitialized = true;
    } catch (e) {
      // Initialization failures shouldn't crash the app; log and continue.
      // ignore: avoid_print
      print('MultiPcBootstrapper: service initialization failed -> $e');
    } finally {
      _initializingServices = false;
    }
  }

  /// Attempts to bootstrap multi-PC networking. Returns true if an admin server was found/started.
  Future<bool> bootstrap(DatabaseService database,
      {Duration timeout = const Duration(seconds: 8)}) async {
    await _ensureServices(database);

    final syncService = DatabaseSyncService();
    final discoveryService = NetworkDiscoveryService();

    Map<String, String> settings = {};
    try {
      settings = await database.getSettings();
    } catch (_) {
      // ignore errors when database is empty.
    }

    final bool setupComplete = settings['business_setup_complete'] == 'true';
    final String? businessName = settings['business_name'];
    final bool isAdminDevice = await DeviceIdentityService.isAdminDevice();

    if (setupComplete && isAdminDevice) {
      return _startAdminServer(syncService, businessName);
    }

    if (setupComplete && !isAdminDevice) {
      // Already has data locally; no need to run setup. Optionally connect if admin available.
      _attemptProactiveClientConnect(syncService, discoveryService);
      await DeviceIdentityService.markAsClientDevice();
      return syncService.isConnected;
    }

    // No setup locally – attempt to auto connect to an admin server.
    _attemptProactiveClientConnect(syncService, discoveryService);

    final bool connected = await _waitForConnection(syncService, timeout);
    if (connected) {
      await _waitForSyncCompletion(syncService, const Duration(seconds: 8));
      await DeviceIdentityService.markAsClientDevice();
      return true;
    }

    return false;
  }

  Future<bool> _startAdminServer(
      DatabaseSyncService syncService, String? businessName) async {
    if (_adminServerStarted && syncService.isServer) {
      return true;
    }

    if (syncService.isServer) {
      _adminServerStarted = true;
      return true;
    }

    final advertisedName = _buildServerName(businessName);
    final success = await syncService.startAsServer(serverName: advertisedName);
    if (success) {
      _adminServerStarted = true;
      await DeviceIdentityService.markAsAdminDevice(
          displayName: advertisedName);
    }
    return success;
  }

  void _attemptProactiveClientConnect(DatabaseSyncService syncService,
      NetworkDiscoveryService discoveryService) {
    if (syncService.isConnected || syncService.isServer) return;

    final adminServers = discoveryService.adminServers;
    if (adminServers.isNotEmpty) {
      syncService.connectToServer(adminServers.first.address);
    }
  }

  Future<bool> _waitForConnection(
      DatabaseSyncService syncService, Duration timeout) async {
    if (syncService.isConnected || syncService.isServer) return true;

    final completer = Completer<bool>();
    late StreamSubscription<SyncStatus> sub;

    sub = syncService.statusStream.listen((status) {
      if (status == SyncStatus.connected ||
          status == SyncStatus.serverRunning) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else if (status == SyncStatus.error) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      }
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(syncService.isConnected || syncService.isServer);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  Future<void> _waitForSyncCompletion(
      DatabaseSyncService syncService, Duration timeout) async {
    final completer = Completer<void>();
    late StreamSubscription<SyncProgress> sub;

    sub = syncService.progressStream.listen((progress) {
      if (progress.percentage >= 100 && !completer.isCompleted) {
        completer.complete();
      }
    });

    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    await sub.cancel();
  }

  String _buildServerName(String? businessName) {
    final trimmed = businessName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Offline POS Admin Server';
    }
    return '$trimmed Admin Server';
  }
}
