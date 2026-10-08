import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance =
      NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService() => _instance;
  NetworkDiscoveryService._internal();

  static const int _discoveryPort = 8080;
  static const int _syncPort = 8081;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _discoveryTimer;
  ServerSocket? _discoveryServer;

  final StreamController<List<POSServer>> _serversController =
      StreamController.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController.broadcast();

  bool _isInitialized = false;
  bool _isInitializing = false;
  Stream<List<POSServer>> get serversStream => _serversController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  List<POSServer> _discoveredServers = [];
  bool _isConnected = false;
  String? _currentServerAddress;
  String? _currentIP;

  /// Initialize network discovery
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;
    try {
      // Get current IP address
      _currentIP = await getCurrentIPAddress();

      // Start listening for connectivity changes
      _connectivitySubscription =
          Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

      // Start discovery
      await _startDiscovery();

      print('🌐 Network discovery service initialized');
      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing network discovery: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Start discovering POS servers on the network
  Future<void> _startDiscovery() async {
    try {
      // Start periodic discovery
      _discoveryTimer = Timer.periodic(Duration(seconds: 5), (_) {
        _scanNetwork();
      });

      // Initial scan
      _scanNetwork();

      print('🔍 Started discovering POS servers...');
    } catch (e) {
      print('❌ Error starting discovery: $e');
    }
  }

  /// Scan the network for POS servers (works on both WiFi and Ethernet)
  Future<void> _scanNetwork() async {
    // Get all network IPs (both WiFi and Ethernet)
    List<String> networkIPs = [];
    
    // Get current IP first
    if (_currentIP != null && _currentIP != '127.0.0.1') {
      networkIPs.add(_currentIP!);
    }
    
    // Also get all network interface IPs
    try {
      final interfaces = await NetworkInterface.list(
          includeLinkLocal: false, type: InternetAddressType.IPv4);
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && 
              address.type == InternetAddressType.IPv4 &&
              address.address.isNotEmpty &&
              !networkIPs.contains(address.address)) {
            networkIPs.add(address.address);
          }
        }
      }
    } catch (e) {
      print('⚠️ Error getting network interfaces: $e');
    }

    if (networkIPs.isEmpty) {
      print('⚠️ No network IPs available for scanning');
      return;
    }

    try {
      // Scan each network we're connected to
      final Set<String> scannedRanges = {};
      final List<Future<void>> scanTasks = [];

      for (final ip in networkIPs) {
        // Get network range (assuming /24 subnet)
        final ipParts = ip.split('.');
        if (ipParts.length != 4) continue;

        final networkBase = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}.';
        
        // Skip if we already scanned this network range
        if (scannedRanges.contains(networkBase)) continue;
        scannedRanges.add(networkBase);

        // Scan common IPs in the range (optimized: scan .1-.10, .100-.110, .200-.210, and .254)
        final scanIPs = <int>[];
        
        // Quick scan of common IPs first
        scanIPs.addAll([1, 2, 10, 100, 101, 102, 200, 201, 254]);
        
        // Add other IPs if needed (full scan)
        for (int i = 1; i <= 254; i++) {
          if (!scanIPs.contains(i)) {
            scanIPs.add(i);
          }
        }

        for (int i in scanIPs) {
          final scanIP = '$networkBase$i';
          if (!networkIPs.contains(scanIP)) {
            scanTasks.add(_checkServer(scanIP));
          }
        }
      }

      // Run scans in parallel (limit to 20 at a time for better performance)
      for (int i = 0; i < scanTasks.length; i += 20) {
        final batch = scanTasks.skip(i).take(20);
        await Future.wait(batch);
        
        // Small delay between batches to avoid overwhelming the network
        if (i + 20 < scanTasks.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      print('❌ Error scanning network: $e');
    }
  }

  /// Check if a specific IP is running a POS server
  Future<void> _checkServer(String ip) async {
    try {
      final socket = await Socket.connect(ip, _discoveryPort,
          timeout: Duration(seconds: 1));

      // Send discovery request
      final request = {
        'type': 'discovery_request',
        'timestamp': DateTime.now().toIso8601String(),
      };

      socket.add(utf8.encode(jsonEncode(request)));

      // Listen for response
      socket.listen(
        (data) {
          try {
            final response = jsonDecode(utf8.decode(data));
            if (response['type'] == 'discovery_response') {
              final server = POSServer(
                name: response['name'] ?? 'POS Server',
                address: ip,
                port: _discoveryPort,
                syncPort: _syncPort,
                isAdmin: response['isAdmin'] ?? false,
                lastSeen: DateTime.now(),
              );

              _addOrUpdateServer(server);
            }
          } catch (e) {
            // Ignore invalid responses
          }
        },
        onError: (error) {
          // Connection failed, ignore
        },
        onDone: () {
          socket.destroy();
        },
      );
    } catch (e) {
      // Connection failed, ignore
    }
  }

  /// Add or update server in discovered list
  void _addOrUpdateServer(POSServer server) {
    final existingIndex =
        _discoveredServers.indexWhere((s) => s.address == server.address);

    if (existingIndex >= 0) {
      _discoveredServers[existingIndex] = server;
    } else {
      _discoveredServers.add(server);
    }

    _serversController.add(List.from(_discoveredServers));
    print(
        '📡 Discovered server: ${server.name} (${server.address}:${server.port}) - Admin: ${server.isAdmin}');
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      _isConnected = false;
      _connectionStatusController.add(false);
      print('📡 Network disconnected');
    } else {
      _isConnected = true;
      _connectionStatusController.add(true);
      print('📡 Network connected');
    }
  }

  /// Get current network IP address (supports both WiFi and Ethernet)
  Future<String?> getCurrentIPAddress() async {
    try {
      final networkInfo = NetworkInfo();
      
      // Try WiFi first
      String? ip = await networkInfo.getWifiIP();
      if (ip != null && ip.isNotEmpty && ip != '127.0.0.1') {
        print('📡 Using WiFi IP: $ip');
        return ip;
      }
      
      // Try to get IP from network interfaces (works for both WiFi and Ethernet)
      try {
        final interfaces = await NetworkInterface.list(
            includeLinkLocal: false, type: InternetAddressType.IPv4);
        
        // Find first non-loopback interface with valid IP
        for (final interface in interfaces) {
          for (final address in interface.addresses) {
            if (!address.isLoopback && 
                address.type == InternetAddressType.IPv4 &&
                address.address.isNotEmpty) {
              print('📡 Using network interface IP: ${address.address} (${interface.name})');
              return address.address;
            }
          }
        }
      } catch (e) {
        print('⚠️ Error getting IP from interfaces: $e');
      }
      
      // Fallback: try to get any IP address
      try {
        final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
        if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
          final fallbackIp = interfaces.first.addresses.first.address;
          print('📡 Using fallback IP: $fallbackIp');
          return fallbackIp;
        }
      } catch (e) {
        print('⚠️ Error getting fallback IP: $e');
      }
      
      print('⚠️ Could not determine network IP address');
      return null;
    } catch (e) {
      print('❌ Error getting IP address: $e');
      return null;
    }
  }

  /// Get all discovered servers
  List<POSServer> get discoveredServers => List.from(_discoveredServers);

  /// Get admin servers only
  List<POSServer> get adminServers =>
      _discoveredServers.where((s) => s.isAdmin).toList();

  /// Check if connected to any server
  bool get isConnected => _isConnected && _currentServerAddress != null;

  /// Get current server address
  String? get currentServerAddress => _currentServerAddress;

  /// Connect to a specific server
  Future<bool> connectToServer(POSServer server) async {
    try {
      // Test connection to the server
      final socket = await Socket.connect(server.address, server.syncPort,
          timeout: Duration(seconds: 5));
      socket.destroy();

      _currentServerAddress = server.address;
      _isConnected = true;
      _connectionStatusController.add(true);

      print('✅ Connected to server: ${server.name} (${server.address})');
      return true;
    } catch (e) {
      print('❌ Failed to connect to server: $e');
      return false;
    }
  }

  /// Disconnect from current server
  void disconnect() {
    _currentServerAddress = null;
    _isConnected = false;
    _connectionStatusController.add(false);
    print('🔌 Disconnected from server');
  }

  /// Start advertising this PC as a POS server
  Future<void> startAdvertising(
      {required String serverName, required bool isAdmin}) async {
    try {
      // Close existing discovery server if any
      if (_discoveryServer != null) {
        try {
          await _discoveryServer!.close();
        } catch (e) {
          print('⚠️ Error closing existing discovery server: $e');
        }
        _discoveryServer = null;
      }

      if (_currentIP == null) {
        // Try to get IP again
        _currentIP = await getCurrentIPAddress();
        if (_currentIP == null) {
          throw Exception('Could not get IP address');
        }
      }

      // Start discovery server - try multiple binding methods
      try {
        _discoveryServer =
            await ServerSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      } catch (e) {
        // If binding fails, try individual interfaces
        print('⚠️ Failed to bind discovery server to anyIPv4, trying interfaces...');
        
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
              _discoveryServer = await ServerSocket.bind(
                  interface.addresses.first, _discoveryPort);
              print('✅ Discovery server bound to: ${interface.name} (${interface.addresses.first.address})');
            } else {
              // Fallback to loopback
              _discoveryServer = await ServerSocket.bind(
                  InternetAddress.loopbackIPv4, _discoveryPort);
              print('✅ Discovery server bound to loopback');
            }
          } else {
            // Last resort: loopback
            _discoveryServer = await ServerSocket.bind(
                InternetAddress.loopbackIPv4, _discoveryPort);
            print('✅ Discovery server bound to loopback (fallback)');
          }
        } catch (e2) {
          print('❌ Failed to bind discovery server: $e, $e2');
          rethrow;
        }
      }

      _discoveryServer!.listen((clientSocket) {
        clientSocket.listen(
          (data) {
            try {
              final request = jsonDecode(utf8.decode(data));
              if (request['type'] == 'discovery_request') {
                // Send discovery response
                final response = {
                  'type': 'discovery_response',
                  'name': serverName,
                  'isAdmin': isAdmin,
                  'timestamp': DateTime.now().toIso8601String(),
                };

                clientSocket.add(utf8.encode(jsonEncode(response)));
              }
            } catch (e) {
              // Ignore invalid requests
            }
          },
          onError: (error) {
            // Client disconnected
          },
          onDone: () {
            clientSocket.destroy();
          },
        );
      });

      print('📢 Advertising as POS server: $serverName (Admin: $isAdmin)');
    } catch (e) {
      print('❌ Error advertising server: $e');
    }
  }

  /// Stop advertising
  Future<void> stopAdvertising() async {
    try {
      await _discoveryServer?.close();
      _discoveryServer = null;
      print('🔇 Stopped advertising server');
    } catch (e) {
      print('❌ Error stopping advertisement: $e');
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    _discoveryTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _discoveryServer?.close();
    await _serversController.close();
    await _connectionStatusController.close();
  }
}

/// Represents a discovered POS server
class POSServer {
  final String name;
  final String address;
  final int port;
  final int syncPort;
  final bool isAdmin;
  final DateTime lastSeen;

  POSServer({
    required this.name,
    required this.address,
    required this.port,
    required this.syncPort,
    required this.isAdmin,
    required this.lastSeen,
  });

  @override
  String toString() {
    return 'POSServer(name: $name, address: $address, port: $port, isAdmin: $isAdmin)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is POSServer && other.address == address;
  }

  @override
  int get hashCode => address.hashCode;
}
