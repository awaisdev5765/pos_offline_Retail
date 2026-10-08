import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart' show DataClass, Variable;
import '../database/database.dart';
import 'network_discovery_service.dart';
import 'secure_sync_codec.dart';

class DatabaseSyncService {
  static final DatabaseSyncService _instance = DatabaseSyncService._internal();
  factory DatabaseSyncService() => _instance;
  DatabaseSyncService._internal();

  static const int _syncPort = 8081;
  static const int _heartbeatInterval = 30; // seconds

  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  Timer? _heartbeatTimer;
  Timer? _changeDebounceTimer;
  Completer<bool>? _authenticationCompleter;

  static const Duration _changeDebounceDuration = Duration(seconds: 2);
  final Set<String> _pendingTables = <String>{};
  final List<StreamSubscription> _tableSubscriptions = [];
  final List<Socket> _connectedClients = [];
  SecureSyncCodec? _secureCodec;
  bool _watchersStarted = false;
  int _suppressChangeBroadcast = 0;

  final StreamController<SyncStatus> _statusController =
      StreamController.broadcast();
  final StreamController<SyncProgress> _progressController =
      StreamController.broadcast();
  final StreamController<int> _connectedClientsCountController =
      StreamController.broadcast();

  Stream<SyncStatus> get statusStream => _statusController.stream;
  Stream<SyncProgress> get progressStream => _progressController.stream;
  Stream<int> get connectedClientsCountStream =>
      _connectedClientsCountController.stream;

  /// Get current number of connected clients (for admin server)
  int get connectedClientsCount => _connectedClients.length;

  /// Notify listeners of connected clients count change
  void _notifyClientsCountChanged() {
    if (!_connectedClientsCountController.isClosed) {
      _connectedClientsCountController.add(_connectedClients.length);
    }
  }

  AppDatabase? _database;
  NetworkDiscoveryService? _discoveryService;
  bool _isServer = false;
  bool _isConnected = false;
  SyncStatus _currentStatus = SyncStatus.disconnected;

  bool _initialized = false;
  bool _initializing = false;

  static const Map<String, String> _tableNameMap = {
    'products': 'products',
    'customers': 'customers',
    'sales': 'sales',
    'saleItems': 'sale_items',
    'payments': 'payments',
    'categories': 'categories',
    'suppliers': 'suppliers',
    'employees': 'employees',
    'expenses': 'expenses',
    'banks': 'banks',
    'bankPayments': 'bank_payments',
    'staffPerformances': 'staff_performances',
    'stockAdjustments': 'stock_adjustments',
    'settings': 'settings',
    'purchaseOrders': 'purchase_orders',
    'purchaseOrderItems': 'purchase_order_items',
    'returns': 'returns',
    'returnItems': 'return_items',
    'expenseHeads': 'expense_heads',
    'supplierPayments': 'supplier_payments',
    'productIMEIs': 'product_i_m_e_is',
    'productBundles': 'product_bundles',
    'productBundleItems': 'product_bundle_items',
    'employeeCommissions': 'employee_commissions',
    'productIngredients': 'product_ingredients',
  };

  static const List<String> _foreignKeyInsertOrder = <String>[
    'settings',
    'categories',
    'suppliers',
    'employees',
    'banks',
    'products',
    'customers',
    'expenseHeads',
    'productBundles',
    'purchaseOrders',
    'sales',
    'expenses',
    'saleItems',
    'payments',
    'stockAdjustments',
    'purchaseOrderItems',
    'returns',
    'returnItems',
    'bankPayments',
    'supplierPayments',
    'staffPerformances',
    'productIMEIs',
    'productBundleItems',
    'employeeCommissions',
    'productIngredients',
  ];

  Future<void> configurePairingCode(String pairingCode) async {
    _secureCodec = await SecureSyncCodec.fromPairingCode(pairingCode);
  }

  void _requireSecureCodec() {
    if (_secureCodec == null) {
      throw StateError(
        'A pairing code is required before starting or connecting multi-PC sync.',
      );
    }
  }

  /// Initialize the sync service
  Future<void> initialize(
      AppDatabase database, NetworkDiscoveryService discoveryService) async {
    if (_initialized) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _initializing = true;
    try {
      _database = database;
      _discoveryService = discoveryService;

      _discoveryService!.serversStream.listen(_onServersDiscovered);
      _startTableWatchers();

      print('🔄 Database sync service initialized');
      _initialized = true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Database sync service initialization failed: $e');
    } finally {
      _initializing = false;
    }
  }

  /// Start as admin server (main PC)
  Future<bool> startAsServer({String? serverName, String? pairingCode}) async {
    try {
      if (pairingCode != null) await configurePairingCode(pairingCode);
      _requireSecureCodec();
      // Close existing server socket if any
      if (_serverSocket != null) {
        try {
          await _serverSocket!.close();
        } catch (e) {
          print('⚠️ Error closing existing server socket: $e');
        }
        _serverSocket = null;
      }

      // Check if already running as server
      if (_isServer && _serverSocket != null) {
        print('ℹ️ Server already running on port $_syncPort');
        return true;
      }

      _isServer = true;

      // Try to bind to the port with proper error handling
      try {
        _serverSocket =
            await ServerSocket.bind(InternetAddress.anyIPv4, _syncPort);
      } catch (e) {
        // If binding fails, try to bind to all interfaces individually
        print('⚠️ Failed to bind to anyIPv4, trying individual interfaces...');

        // Try binding to localhost first, then any available interface
        try {
          _serverSocket =
              await ServerSocket.bind(InternetAddress.loopbackIPv4, _syncPort);
          print('✅ Bound to loopback interface');
        } catch (e2) {
          // Try to get actual network interface and bind to it
          try {
            final interfaces = await NetworkInterface.list(
                includeLinkLocal: false, type: InternetAddressType.IPv4);

            if (interfaces.isNotEmpty) {
              // Try the first non-loopback interface
              final interface = interfaces.firstWhere(
                (iface) => !iface.addresses.any(
                  (addr) => addr.isLoopback,
                ),
                orElse: () => interfaces.first,
              );

              if (interface.addresses.isNotEmpty) {
                _serverSocket = await ServerSocket.bind(
                    interface.addresses.first, _syncPort);
                print(
                    '✅ Bound to interface: ${interface.name} (${interface.addresses.first.address})');
              } else {
                throw Exception('No valid network interface found');
              }
            } else {
              throw Exception('No network interfaces available');
            }
          } catch (e3) {
            print('❌ All binding attempts failed: $e, $e2, $e3');
            _updateStatus(SyncStatus.error);
            _isServer = false;
            return false;
          }
        }
      }

      _serverSocket!.listen(_handleClientConnection);

      _updateStatus(SyncStatus.serverRunning);
      print('🖥️ Started as admin server on port $_syncPort');

      // Start advertising as admin server
      await _discoveryService!.startAdvertising(
        serverName:
            serverName ?? 'Admin-PC-${DateTime.now().millisecondsSinceEpoch}',
        isAdmin: true,
      );

      return true;
    } catch (e) {
      print('❌ Error starting server: $e');
      _updateStatus(SyncStatus.error);
      _isServer = false;
      return false;
    }
  }

  /// Connect to admin server (client PC)
  Future<bool> connectToServer(String serverAddress,
      {String? pairingCode}) async {
    try {
      if (pairingCode != null) await configurePairingCode(pairingCode);
      _requireSecureCodec();
      // Close existing connection if any
      if (_clientSocket != null) {
        try {
          await _clientSocket!.close();
        } catch (e) {
          // Ignore errors when closing
        }
        _clientSocket = null;
      }

      _isServer = false;
      _updateStatus(SyncStatus.connecting);

      _clientSocket = await Socket.connect(serverAddress, _syncPort,
          timeout: Duration(seconds: 10));

      // Set up error and close handlers to maintain connection
      _clientSocket!
          .map<List<int>>((data) => data)
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        _handleServerMessage,
        onError: (error) {
          print('⚠️ Socket error: $error');
          // Try to reconnect automatically
          _handleSocketDisconnection(serverAddress);
        },
        onDone: () {
          print('⚠️ Socket connection closed');
          // Try to reconnect automatically
          _handleSocketDisconnection(serverAddress);
        },
        cancelOnError: false, // Don't cancel on error, handle it manually
      );

      // Send initial sync request
      _authenticationCompleter = Completer<bool>();
      await _sendMessage({
        'type': 'sync_request',
        'timestamp': DateTime.now().toIso8601String(),
      });
      final authenticated = await _authenticationCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      _authenticationCompleter = null;
      if (!authenticated) {
        _clientSocket?.destroy();
        _clientSocket = null;
        _updateStatus(SyncStatus.error);
        return false;
      }

      _isConnected = true;
      _updateStatus(SyncStatus.connected);
      if (_pendingTables.isNotEmpty) {
        _scheduleChangeFlush();
      }

      // Start heartbeat
      _startHeartbeat();

      print('🔗 Connected to admin server: $serverAddress');
      return true;
    } catch (e) {
      print('❌ Error connecting to server: $e');
      _updateStatus(SyncStatus.error);
      _isConnected = false;
      return false;
    }
  }

  /// Handle socket disconnection and attempt to reconnect
  void _handleSocketDisconnection(String? serverAddress) {
    if (!_isConnected || _isServer) {
      return; // Don't reconnect if we're server or already disconnected
    }

    _isConnected = false;
    _updateStatus(SyncStatus.disconnected);
    _heartbeatTimer?.cancel();

    // Attempt to reconnect after a delay
    if (serverAddress != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isConnected && !_isServer) {
          print('🔄 Attempting to reconnect to server: $serverAddress');
          connectToServer(serverAddress);
        }
      });
    }
  }

  /// Handle client connections (server side)
  void _handleClientConnection(Socket clientSocket) {
    print('👤 Client connected: ${clientSocket.remoteAddress.address}');

    clientSocket
        .map<List<int>>((data) => data)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (data) => _handleClientMessage(clientSocket, data),
      onError: (error) {
        print('⚠️ Client error: $error');
        // Don't remove immediately, try to handle gracefully
        try {
          _connectedClients.remove(clientSocket);
          _notifyClientsCountChanged(); // Notify count change
        } catch (e) {
          // Ignore
        }
      },
      onDone: () {
        print('👤 Client disconnected: ${clientSocket.remoteAddress.address}');
        try {
          _connectedClients.remove(clientSocket);
          _notifyClientsCountChanged(); // Notify count change
          clientSocket.destroy();
        } catch (e) {
          // Ignore cleanup errors
        }
      },
      cancelOnError: false, // Keep connection alive on errors
    );
  }

  /// Handle messages from clients (server side)
  void _handleClientMessage(Socket clientSocket, String data) async {
    try {
      final message = await _secureCodec!.decode(data);
      if (!_connectedClients.contains(clientSocket)) {
        _connectedClients.add(clientSocket);
        _notifyClientsCountChanged();
        if (_pendingTables.isNotEmpty) _scheduleChangeFlush();
        await _sendMessageToClient(clientSocket, {'type': 'auth_ack'});
      }
      final type = message['type'] as String;

      switch (type) {
        case 'sync_request':
          await _handleSyncRequest(clientSocket, message);
          break;
        case 'data_update':
          await _handleDataUpdate(message);
          break;
        case 'heartbeat':
          await _sendMessageToClient(clientSocket, {'type': 'heartbeat_ack'});
          break;
      }
    } catch (e) {
      print('❌ Rejected unauthenticated or invalid client message: $e');
      _connectedClients.remove(clientSocket);
      _notifyClientsCountChanged();
      clientSocket.destroy();
    }
  }

  /// Handle messages from server (client side)
  void _handleServerMessage(String data) async {
    try {
      final message = await _secureCodec!.decode(data);
      if (_authenticationCompleter?.isCompleted == false) {
        _authenticationCompleter!.complete(true);
      }
      final type = message['type'] as String;

      switch (type) {
        case 'auth_ack':
          break;
        case 'sync_data':
          await _handleSyncData(message);
          break;
        case 'heartbeat_ack':
          // Heartbeat acknowledged
          break;
        case 'data_updated':
          await _handleDataUpdated(message);
          break;
      }
    } catch (e) {
      print('❌ Rejected unauthenticated or invalid server message: $e');
      if (_authenticationCompleter?.isCompleted == false) {
        _authenticationCompleter!.complete(false);
      }
      _clientSocket?.destroy();
      _isConnected = false;
      _updateStatus(SyncStatus.error);
    }
  }

  /// Handle sync request from client
  Future<void> _handleSyncRequest(
      Socket clientSocket, Map<String, dynamic> message) async {
    try {
      _updateProgress(SyncProgress(0, 'Preparing sync data...'));

      // Get all data from database
      final syncData = await _getAllDataForSync();

      _updateProgress(SyncProgress(50, 'Sending data to client...'));

      // Send sync data to client
      await _sendMessageToClient(clientSocket, {
        'type': 'sync_data',
        'data': syncData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _updateProgress(SyncProgress(100, 'Sync completed'));
      print('📤 Sync data sent to client');
    } catch (e) {
      print('❌ Error handling sync request: $e');
      await _sendMessageToClient(clientSocket, {
        'type': 'sync_error',
        'error': e.toString(),
      });
    }
  }

  /// Handle sync data from server
  Future<void> _handleSyncData(Map<String, dynamic> message) async {
    try {
      _updateProgress(SyncProgress(0, 'Receiving sync data...'));

      final data = message['data'] as Map<String, dynamic>;
      final tables =
          (message['tables'] as List<dynamic>?)?.map((e) => '$e').toList();

      _updateProgress(SyncProgress(25, 'Updating local database...'));

      // Update local database with received data
      await _updateLocalDatabase(data, tables: tables);

      // Log sync completion details
      if (tables != null && tables.contains('employees')) {
        try {
          final employeeCount = (data['employees'] as List?)?.length ?? 0;
          print('✅ Employees synced: $employeeCount employees');
        } catch (e) {
          print('⚠️ Could not count synced employees: $e');
        }
      }

      _updateProgress(SyncProgress(100, 'Sync completed'));
      print('📥 Sync data received and applied');
    } catch (e) {
      print('❌ Error handling sync data: $e');
    }
  }

  /// Handle data update from client
  /// IMPORTANT: Admin data always takes priority. We merge client data but prioritize admin's own data.
  Future<void> _handleDataUpdate(Map<String, dynamic> message) async {
    try {
      final data = message['data'] as Map<String, dynamic>;
      final tables =
          (message['tables'] as List<dynamic>?)?.map((e) => '$e').toList();
      final targetTables =
          tables ?? data.keys.map((key) => '$key').toList(growable: false);

      // Merge client data with admin data, prioritizing admin data
      await _mergeClientDataWithAdmin(data, tables: targetTables);

      // Broadcast admin's current data (with priority) to all connected clients
      // This ensures admin's data is the source of truth
      final adminData = await _getTablesDataForSync(targetTables);
      await _broadcastToClients({
        'type': 'data_updated',
        'tables': targetTables,
        'data': adminData,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'admin', // Mark as admin data (highest priority)
      });

      print(
          '📡 Client data merged (admin priority) and broadcasted to clients');
    } catch (e) {
      print('❌ Error handling data update: $e');
    }
  }

  /// Merge client data with admin data, giving priority to admin data
  /// This ensures admin's data is always the source of truth
  Future<void> _mergeClientDataWithAdmin(Map<String, dynamic> clientData,
      {List<String>? tables}) async {
    if (_database == null) return;

    final targetTables =
        tables ?? clientData.keys.map((key) => '$key').toList(growable: false);
    if (targetTables.isEmpty) return;

    try {
      // Get admin's current data for these tables
      final adminData = await _getTablesDataForSync(targetTables);

      // For each table, merge data with admin priority
      // Admin data overwrites client data for same records
      for (final table in targetTables) {
        final tableName = _tableNameMap[table];
        if (tableName == null) continue;

        final clientRows = clientData[table];
        final adminRows = adminData[table];

        if (clientRows == null || clientRows is! List) continue;

        // Get admin row IDs for priority check
        final adminRowsById = <int, Map<String, dynamic>>{};
        if (adminRows is List) {
          for (final row in adminRows) {
            final map = _rowToMap(row);
            final id = map['id'];
            if (id != null) {
              adminRowsById[int.tryParse(id.toString()) ?? 0] = map;
            }
          }
        }

        // Start transaction for this table
        await _database!.customStatement('BEGIN TRANSACTION');
        _suppressChangeBroadcast++;

        try {
          // Insert or update client data, but skip if admin has the same record
          for (final clientRow in clientRows) {
            final clientMap = _rowToMap(clientRow);
            final clientId = clientMap['id'];
            final clientIdInt =
                clientId != null ? int.tryParse(clientId.toString()) ?? 0 : 0;

            // Skip if admin already has this record (admin priority)
            if (clientIdInt > 0 && adminRowsById.containsKey(clientIdInt)) {
              final adminMap = adminRowsById[clientIdInt]!;
              if (!_rowsEquivalent(adminMap, clientMap)) {
                throw StateError(
                  'Sync conflict in $tableName for record $clientIdInt. '
                  'The admin copy was kept; manual reconciliation is required.',
                );
              }
              continue;
            }

            // Insert new records from client (sales, payments, etc. that don't exist in admin)
            // Only insert if it's a new record or if admin doesn't have it
            try {
              // Check if record exists
              final exists = await _database!.customSelect(
                'SELECT COUNT(*) as count FROM $tableName WHERE id = ?',
                variables: [Variable<int>(clientIdInt)],
              ).getSingle();

              if (exists.read<int>('count') == 0) {
                // Insert new record from client
                final columns = clientMap.keys.join(', ');
                final values =
                    clientMap.values.map((v) => _formatValue(v)).join(', ');

                await _database!.customStatement(
                  'INSERT INTO $tableName ($columns) VALUES ($values)',
                );
              }
            } catch (e) {
              // If insert fails, try update (for tables without id)
              try {
                final columns =
                    clientMap.keys.where((k) => k != 'id').join(', ');

                if (columns.isNotEmpty) {
                  await _database!.customStatement(
                    'INSERT OR REPLACE INTO $tableName (${clientMap.keys.join(', ')}) VALUES (${clientMap.values.map((v) => _formatValue(v)).join(', ')})',
                  );
                }
              } catch (e2) {
                print('⚠️ Could not merge client data for $tableName: $e2');
              }
            }
          }

          await _database!.customStatement('COMMIT');
        } catch (e) {
          await _database!.customStatement('ROLLBACK');
          rethrow;
        } finally {
          _releaseChangeSuppression(delay: const Duration(milliseconds: 200));
        }
      }

      print('✅ Client data merged with admin data (admin priority maintained)');
    } catch (e) {
      print('❌ Error merging client data: $e');
      rethrow;
    }
  }

  /// Get data for specific tables only (for sync)
  Future<Map<String, dynamic>> _getTablesDataForSync(
      List<String> tables) async {
    if (_database == null) throw Exception('Database not initialized');

    final Map<String, dynamic> result = {};

    for (final tableKey in tables) {
      final tableName = _tableNameMap[tableKey];
      if (tableName == null) continue;
      final rows =
          await _database!.customSelect('SELECT * FROM $tableName').get();
      result[tableKey] = rows
          .map((row) => Map<String, dynamic>.from(row.data))
          .toList(growable: false);
    }

    return result;
  }

  /// Handle data updated notification
  Future<void> _handleDataUpdated(Map<String, dynamic> message) async {
    try {
      final data = message['data'] as Map<String, dynamic>;
      final tables =
          (message['tables'] as List<dynamic>?)?.map((e) => '$e').toList();

      // Update local database
      await _updateLocalDatabase(data, tables: tables);

      print('📥 Data updated from server');
    } catch (e) {
      print('❌ Error handling data updated: $e');
    }
  }

  /// Get all data for synchronization
  Future<Map<String, dynamic>> _getAllDataForSync() async {
    if (_database == null) throw Exception('Database not initialized');
    return _getTablesDataForSync(_tableNameMap.keys.toList(growable: false));
  }

  /// Update local database with sync data
  Future<void> _updateLocalDatabase(Map<String, dynamic> data,
      {List<String>? tables}) async {
    if (_database == null) return;

    final targetTables =
        tables ?? data.keys.map((key) => '$key').toList(growable: false);
    if (targetTables.isEmpty) return;

    try {
      // Start transaction
      await _database!.customStatement('BEGIN TRANSACTION');
      _suppressChangeBroadcast++;

      final orderedTargets = _foreignKeyInsertOrder
          .where(targetTables.contains)
          .toList(growable: false);

      for (final table in orderedTargets.reversed) {
        final tableName = _tableNameMap[table];
        if (tableName == null) continue;
        await _database!.customStatement('DELETE FROM $tableName');
      }

      for (final table in orderedTargets) {
        final tableName = _tableNameMap[table];
        if (tableName == null) continue;
        final rows = data[table];
        if (rows is List) {
          await _insertTableData(tableName, rows);
        } else if (rows != null) {
          await _insertTableData(tableName, [rows]);
        }
      }

      // Commit transaction
      await _database!.customStatement('COMMIT');

      print('✅ Local database updated successfully');
    } catch (e) {
      // Rollback on error
      await _database!.customStatement('ROLLBACK');
      print('❌ Error updating local database: $e');
      rethrow;
    } finally {
      _releaseChangeSuppression(delay: const Duration(milliseconds: 200));
    }
  }

  /// Insert table data
  Future<void> _insertTableData(String tableName, List<dynamic> data) async {
    if (data.isEmpty) return;

    for (final row in data) {
      try {
        final map = _rowToMap(row);

        // For employees table, ensure all required fields are present
        if (tableName == 'employees') {
          // Ensure boolean fields are properly formatted
          if (map['isActive'] != null && map['isActive'] is! bool) {
            map['isActive'] =
                map['isActive'].toString().toLowerCase() == 'true';
          }
          if (map['canLogin'] != null && map['canLogin'] is! bool) {
            map['canLogin'] =
                map['canLogin'].toString().toLowerCase() == 'true';
          }
        }

        final columns = map.keys.join(', ');
        final values = map.values.map((v) => _formatValue(v)).join(', ');

        await _database!.customStatement(
          'INSERT INTO $tableName ($columns) VALUES ($values)',
        );
      } catch (e) {
        print('⚠️ Error inserting row into $tableName: $e');
        print('Row data: $row');
        // Continue with next row instead of failing completely
        rethrow; // Re-throw for now to see errors, but we could continue
      }
    }
  }

  Map<String, dynamic> _rowToMap(dynamic row) {
    if (row is Map<String, dynamic>) return row;
    if (row is DataClass) return Map<String, dynamic>.from(row.toJson());
    if (row is Map) {
      return row.map(
        (key, value) => MapEntry('$key', value),
      );
    }
    throw ArgumentError('Unsupported row type for sync: ${row.runtimeType}');
  }

  bool _rowsEquivalent(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (!second.containsKey(entry.key) ||
          '${second[entry.key]}' != '${entry.value}') {
        return false;
      }
    }
    return true;
  }

  /// Format value for SQL
  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is String) return "'${value.replaceAll("'", "''")}'";
    if (value is DateTime) return "'${value.toIso8601String()}'";
    return value.toString();
  }

  /// Send message to client
  Future<void> _sendMessageToClient(
      Socket clientSocket, Map<String, dynamic> message) async {
    try {
      final frame = await _secureCodec!.encode(message);
      final data = utf8.encode('$frame\n');
      clientSocket.add(data);
    } catch (e) {
      print('❌ Error sending message to client: $e');
    }
  }

  /// Send message to server
  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (_clientSocket == null) return;

    try {
      final frame = await _secureCodec!.encode(message);
      final data = utf8.encode('$frame\n');
      _clientSocket!.add(data);
    } catch (e) {
      print('❌ Error sending message to server: $e');
    }
  }

  /// Broadcast to all connected clients
  Future<void> _broadcastToClients(Map<String, dynamic> message) async {
    if (_connectedClients.isEmpty) return;

    final frame = await _secureCodec!.encode(message);
    final payload = utf8.encode('$frame\n');
    for (final client in List<Socket>.from(_connectedClients)) {
      try {
        client.add(payload);
      } catch (e) {
        print('❌ Error broadcasting to client: $e');
      }
    }
  }

  /// Start heartbeat timer
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer =
        Timer.periodic(Duration(seconds: _heartbeatInterval), (timer) {
      if (_isConnected && !_isServer) {
        _sendMessage({'type': 'heartbeat'});
      }
    });
  }

  /// Handle server discovery
  void _onServersDiscovered(List<POSServer> servers) {
    if (_isServer || _isConnected || _secureCodec == null) return;

    // Find admin servers
    final adminServers = servers.where((s) => s.isAdmin).toList();
    if (adminServers.isNotEmpty) {
      // Connect to first admin server
      connectToServer(adminServers.first.address);
    }
  }

  /// Update status
  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// Update progress
  void _updateProgress(SyncProgress progress) {
    _progressController.add(progress);
  }

  /// Get current status
  SyncStatus get currentStatus => _currentStatus;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Check if server
  bool get isServer => _isServer;

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _changeDebounceTimer?.cancel();

    await _clientSocket?.close();
    await _serverSocket?.close();
    for (final client in _connectedClients) {
      try {
        await client.close();
      } catch (_) {
        client.destroy();
      }
    }
    _connectedClients.clear();
    _notifyClientsCountChanged(); // Notify count change

    if (_isServer) {
      await _discoveryService?.stopAdvertising();
    }

    _isConnected = false;
    _isServer = false;
    _updateStatus(SyncStatus.disconnected);

    print('🔌 Disconnected from sync service');
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await disconnect();
    await _statusController.close();
    await _progressController.close();
    await _connectedClientsCountController.close();
    for (final sub in _tableSubscriptions) {
      await sub.cancel();
    }
    _tableSubscriptions.clear();
    _watchersStarted = false;
  }

  void _startTableWatchers() {
    if (_watchersStarted || _database == null) return;
    _watchersStarted = true;
    _suppressChangeBroadcast++;

    void watch<T>(Stream<List<T>> stream, String tableKey) {
      final sub = stream.listen((_) => _markTableDirty(tableKey));
      _tableSubscriptions.add(sub);
    }

    watch(_database!.select(_database!.products).watch(), 'products');
    watch(_database!.select(_database!.customers).watch(), 'customers');
    watch(_database!.select(_database!.sales).watch(), 'sales');
    watch(_database!.select(_database!.saleItems).watch(), 'saleItems');
    watch(_database!.select(_database!.payments).watch(), 'payments');
    watch(_database!.select(_database!.categories).watch(), 'categories');
    watch(_database!.select(_database!.suppliers).watch(), 'suppliers');
    watch(_database!.select(_database!.employees).watch(), 'employees');
    watch(_database!.select(_database!.expenses).watch(), 'expenses');
    watch(_database!.select(_database!.banks).watch(), 'banks');
    watch(_database!.select(_database!.bankPayments).watch(), 'bankPayments');
    watch(_database!.select(_database!.staffPerformances).watch(),
        'staffPerformances');
    watch(_database!.select(_database!.stockAdjustments).watch(),
        'stockAdjustments');
    watch(_database!.select(_database!.settings).watch(), 'settings');
    watch(
        _database!.select(_database!.purchaseOrders).watch(), 'purchaseOrders');
    watch(_database!.select(_database!.purchaseOrderItems).watch(),
        'purchaseOrderItems');
    watch(_database!.select(_database!.returns).watch(), 'returns');
    watch(_database!.select(_database!.returnItems).watch(), 'returnItems');
    watch(_database!.select(_database!.expenseHeads).watch(), 'expenseHeads');
    watch(_database!.select(_database!.supplierPayments).watch(),
        'supplierPayments');
    watch(_database!.select(_database!.productIMEIs).watch(), 'productIMEIs');
    watch(
        _database!.select(_database!.productBundles).watch(), 'productBundles');
    watch(_database!.select(_database!.productBundleItems).watch(),
        'productBundleItems');
    watch(_database!.select(_database!.employeeCommissions).watch(),
        'employeeCommissions');
    watch(_database!.select(_database!.productIngredients).watch(),
        'productIngredients');

    _releaseChangeSuppression(delay: const Duration(seconds: 1));
  }

  void _markTableDirty(String tableKey) {
    if (_suppressChangeBroadcast > 0) return;
    if (!_pendingTables.add(tableKey)) {
      _scheduleChangeFlush();
      return;
    }
    _scheduleChangeFlush();
  }

  void _scheduleChangeFlush() {
    if (_pendingTables.isEmpty) return;
    _changeDebounceTimer?.cancel();
    _changeDebounceTimer =
        Timer(_changeDebounceDuration, () => _flushPendingChanges());
  }

  Future<void> _flushPendingChanges() async {
    if (_database == null || _pendingTables.isEmpty) return;

    final bool canSend =
        _isServer ? _connectedClients.isNotEmpty : _isConnected;
    if (!canSend) return;

    final tables = List<String>.from(_pendingTables);
    _pendingTables.clear();

    final data = await _buildTablePayload(tables);
    if (data.isEmpty) return;

    final message = {
      'tables': tables,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_isServer) {
      if (_connectedClients.isEmpty) return;
      await _broadcastToClients({
        'type': 'data_updated',
        ...message,
      });
    } else if (_isConnected) {
      await _sendMessage({
        'type': 'data_update',
        ...message,
      });
    }
  }

  Future<Map<String, dynamic>> _buildTablePayload(List<String> tables) async {
    return _getTablesDataForSync(tables);
  }

  void _releaseChangeSuppression({Duration delay = Duration.zero}) {
    if (_suppressChangeBroadcast == 0) return;
    if (delay == Duration.zero) {
      _suppressChangeBroadcast--;
      return;
    }
    Future.delayed(delay, () {
      if (_suppressChangeBroadcast > 0) {
        _suppressChangeBroadcast--;
      }
    });
  }
}

/// Sync status enum
enum SyncStatus {
  disconnected,
  connecting,
  connected,
  serverRunning,
  syncing,
  error,
}

/// Sync progress class
class SyncProgress {
  final int percentage;
  final String message;

  SyncProgress(this.percentage, this.message);
}
