import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_discovery_service.dart';
import '../services/database_sync_service.dart';
import '../services/secure_sync_codec.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../services/device_identity_service.dart';
import '../widgets/app_snack_bar.dart';
import '../providers/network_provider.dart';

class NetworkConfigScreen extends ConsumerStatefulWidget {
  const NetworkConfigScreen({super.key});

  @override
  ConsumerState<NetworkConfigScreen> createState() =>
      _NetworkConfigScreenState();
}

class _NetworkConfigScreenState extends ConsumerState<NetworkConfigScreen> {
  final TextEditingController _serverNameController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();
  bool _obscurePairingCode = true;
  bool _isAdmin = false;
  bool _isInitialized = false;
  String? _currentIP;
  List<POSServer> _discoveredServers = [];
  SyncStatus _syncStatus = SyncStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final discoveryService = NetworkDiscoveryService();
      final syncService = DatabaseSyncService();
      final databaseService = DatabaseService(ref.read(databaseProvider));

      await discoveryService.initialize();
      await syncService.initialize(databaseService.db, discoveryService);

      // Get current IP
      _currentIP = await discoveryService.getCurrentIPAddress();

      // Listen to server discovery
      discoveryService.serversStream.listen((servers) {
        if (mounted) {
          setState(() {
            _discoveredServers = servers;
          });
        }
      });

      // Listen to sync status
      syncService.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _syncStatus = status;
          });
        }
      });

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('network.err_init'.tr(namedArgs: {'error': '$e'}))),
        );
      }
    }
  }

  String _localizedSyncStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.disconnected:
        return 'network.msg_disconnected'.tr();
      case SyncStatus.connecting:
        return 'network.msg_connecting'.tr();
      case SyncStatus.connected:
        return 'network.msg_connected'.tr();
      case SyncStatus.serverRunning:
        return 'network.msg_server_running'.tr();
      case SyncStatus.syncing:
        return 'network.msg_syncing'.tr();
      case SyncStatus.error:
        return 'network.msg_error'.tr();
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.disconnected:
        return Colors.grey;
      case SyncStatus.connecting:
      case SyncStatus.syncing:
        return Colors.orange;
      case SyncStatus.connected:
      case SyncStatus.serverRunning:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  Future<void> _startAsAdmin() async {
    if (_serverNameController.text.trim().isEmpty) {
      AppSnackBar.show(
        context,
        SnackBar(content: Text('network.server_name_required'.tr())),
      );
      return;
    }
    if (_pairingCodeController.text.trim().length <
        SecureSyncCodec.minimumPairingCodeLength) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Pairing code must contain at least 12 characters.'),
        ),
      );
      return;
    }

    try {
      final syncService = DatabaseSyncService();

      final success = await syncService.startAsServer(
        serverName: _serverNameController.text.trim(),
        pairingCode: _pairingCodeController.text,
      );
      if (!mounted) return;
      if (success) {
        await DeviceIdentityService.markAsAdminDevice(
          displayName: _serverNameController.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _isAdmin = true;
        });

        AppSnackBar.show(
          context,
          SnackBar(content: Text('network.started_admin'.tr())),
        );
      } else {
        AppSnackBar.show(
          context,
          SnackBar(content: Text('network.failed_admin'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
            content:
                Text('network.err_generic'.tr(namedArgs: {'error': '$e'}))),
      );
    }
  }

  Future<void> _connectToServer(POSServer server) async {
    if (_pairingCodeController.text.trim().length <
        SecureSyncCodec.minimumPairingCodeLength) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Enter the admin PC pairing code first.'),
        ),
      );
      return;
    }
    try {
      final syncService = DatabaseSyncService();
      final success = await syncService.connectToServer(
        server.address,
        pairingCode: _pairingCodeController.text,
      );
      if (!mounted) return;

      if (success) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text(
                  'network.connected_to'.tr(namedArgs: {'name': server.name}))),
        );
      } else {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('network.failed_connect'
                  .tr(namedArgs: {'name': server.name}))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
            content:
                Text('network.err_generic'.tr(namedArgs: {'error': '$e'}))),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      final syncService = DatabaseSyncService();
      await syncService.disconnect();
      if (!mounted) return;

      setState(() {
        _isAdmin = false;
      });

      AppSnackBar.show(
        context,
        SnackBar(content: Text('network.disconnected'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        SnackBar(
            content:
                Text('network.err_generic'.tr(namedArgs: {'error': '$e'}))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('network.config_loading_title'.tr()),
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('network.screen_title'.tr()),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_syncStatus != SyncStatus.disconnected)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _disconnect,
              tooltip: 'network.disconnect_tooltip'.tr(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: _getStatusColor(_syncStatus),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'network.current_status'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_localizedSyncStatus(_syncStatus)),
                    if (_currentIP != null) ...[
                      const SizedBox(height: 4),
                      Text('network.ip_label'
                          .tr(namedArgs: {'ip': _currentIP!})),
                    ],
                    // Show connected clients count if running as admin server
                    if (_syncStatus == SyncStatus.serverRunning) ...[
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final clientsCountAsync =
                              ref.watch(connectedClientsCountProvider);
                          return clientsCountAsync.when(
                            data: (count) => Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      AppColors.primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.computer,
                                    color: AppColors.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'network.clients_connected'
                                        .tr(namedArgs: {'count': '$count'}),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Admin Server Setup
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'network.admin_setup_title'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'network.admin_setup_body'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverNameController,
                      decoration: InputDecoration(
                        labelText: 'network.server_name_label'.tr(),
                        hintText: 'network.server_name_hint'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pairingCodeController,
                      obscureText: _obscurePairingCode,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Secure pairing code',
                        hintText: 'Minimum 12 characters',
                        helperText:
                            'Enter the same private code on every authorized PC.',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscurePairingCode
                              ? 'Show pairing code'
                              : 'Hide pairing code',
                          onPressed: () => setState(() {
                            _obscurePairingCode = !_obscurePairingCode;
                          }),
                          icon: Icon(
                            _obscurePairingCode
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isAdmin ? null : _startAsAdmin,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(_isAdmin
                            ? 'network.running_as_admin'.tr()
                            : 'network.start_as_admin'.tr()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Discovered Servers
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.network_check,
                          color: AppColors.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'network.available_servers'.tr(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_discoveredServers.isEmpty)
                      Text('network.no_servers'.tr())
                    else
                      ..._discoveredServers.map((server) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: server.isAdmin
                                    ? AppColors.primaryColor
                                    : Colors.blue,
                                child: Icon(
                                  server.isAdmin
                                      ? Icons.admin_panel_settings
                                      : Icons.computer,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(server.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('network.ip_prefix'
                                      .tr(namedArgs: {'ip': server.address})),
                                  Text(
                                    server.isAdmin
                                        ? 'network.role_admin_server'.tr()
                                        : 'network.role_client_server'.tr(),
                                    style: TextStyle(
                                      color: server.isAdmin
                                          ? AppColors.primaryColor
                                          : Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () => _connectToServer(server),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('common.connect'.tr()),
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'network.instructions_title'.tr(),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.blue.shade700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'network.instructions_body'.tr(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serverNameController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }
}
