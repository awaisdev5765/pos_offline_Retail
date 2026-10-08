import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/network_provider.dart';
import '../services/database_sync_service.dart';

class NetworkStatusIndicator extends ConsumerWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStatusProvider);

    return networkStatus.when(
      data: (status) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(status).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getStatusIcon(status),
                size: 12,
                color: _getStatusColor(status),
              ),
              const SizedBox(width: 4),
              Text(
                _getStatusText(status),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(status),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 12,
              color: Colors.red,
            ),
            SizedBox(width: 4),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
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

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.disconnected:
        return Icons.wifi_off;
      case SyncStatus.connecting:
        return Icons.wifi_find;
      case SyncStatus.connected:
        return Icons.wifi;
      case SyncStatus.serverRunning:
        return Icons.dns;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.error:
        return Icons.error_outline;
    }
  }

  String _getStatusText(SyncStatus status) {
    switch (status) {
      case SyncStatus.disconnected:
        return 'Offline';
      case SyncStatus.connecting:
        return 'Connecting...';
      case SyncStatus.connected:
        return 'Connected';
      case SyncStatus.serverRunning:
        return 'Admin Server';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.error:
        return 'Error';
    }
  }
}

class NetworkStatusTooltip extends ConsumerWidget {
  const NetworkStatusTooltip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkStatus = ref.watch(networkStatusProvider);
    final discoveredServers = ref.watch(discoveredServersProvider);

    return networkStatus.when(
      data: (status) {
        return Tooltip(
          message:
              _getTooltipMessage(status, discoveredServers.valueOrNull ?? []),
          child: const NetworkStatusIndicator(),
        );
      },
      loading: () => const NetworkStatusIndicator(),
      error: (error, stack) => const NetworkStatusIndicator(),
    );
  }

  String _getTooltipMessage(SyncStatus status, List<dynamic> servers) {
    switch (status) {
      case SyncStatus.disconnected:
        return 'Not connected to any server. Click to configure network settings.';
      case SyncStatus.connecting:
        return 'Connecting to admin server...';
      case SyncStatus.connected:
        return 'Connected to admin server. Data is being synchronized.';
      case SyncStatus.serverRunning:
        return 'Running as admin server. ${servers.length} client(s) connected.';
      case SyncStatus.syncing:
        return 'Synchronizing data with other PCs...';
      case SyncStatus.error:
        return 'Network error occurred. Click to retry connection.';
    }
  }
}
