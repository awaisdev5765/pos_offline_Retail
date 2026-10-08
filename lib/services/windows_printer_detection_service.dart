import 'dart:convert';
import 'dart:io';

class WindowsPrinterDetectionService {
  /// Detect all available printers on Windows
  static Future<List<WindowsPrinter>> detectAllPrinters() async {
    if (!Platform.isWindows) {
      return [];
    }

    try {
      final printers = <WindowsPrinter>[];
      final powerShellPrinters = await _fetchPrintersWithPowerShell();

      if (powerShellPrinters.isNotEmpty) {
        printers.addAll(powerShellPrinters);
      } else {
        printers.addAll(await _fetchPrintersWithWmic());
      }

      return printers;
    } catch (e) {
      print('Error detecting printers: $e');
      return [];
    }
  }

  /// Detect thermal printers specifically
  static Future<List<WindowsPrinter>> detectThermalPrinters() async {
    final allPrinters = await detectAllPrinters();
    return allPrinters.where((printer) => printer.isThermal).toList();
  }

  /// Check if a printer is a thermal printer based on name and driver
  static bool _isThermalPrinter(String name, String driver) {
    final thermalKeywords = [
      'thermal',
      'receipt',
      'pos',
      'esc/pos',
      'epson',
      'star',
      'citizen',
      'zebra',
      'bixolon',
      'tm-',
      'tm ',
      'receipt printer',
      'pos printer',
      'thermal printer',
      'black copper', // Generic thermal printer brand
      'blackcopper',
      'bc-',
      'bc ',
      '58mm',
      '80mm',
      'xprinter',
      'xprinter',
      'rp80',
      'rp58',
      'tsp100',
      'tsp143',
      'tsp650',
      'tsp700',
      'tsp800',
      'impact',
      'impact printer',
      'dot matrix',
      'dotmatrix',
      'serial printer',
      'parallel printer',
      'usb printer',
      'network printer',
      'printer port',
      'lpt',
      'com',
      'usb001',
      'usb002',
    ];

    final nameLower = name.toLowerCase();
    final driverLower = driver.toLowerCase();

    return thermalKeywords.any((keyword) =>
        nameLower.contains(keyword) || driverLower.contains(keyword));
  }

  /// Get network printers (IP-based) – limited scan of common hosts for responsiveness.
  static Future<List<NetworkPrinter>> detectNetworkPrinters() async {
    try {
      final result = await Process.run('ipconfig', []);
      if (result.exitCode != 0) return [];

      final lines = result.stdout.toString().split('\n');
      final ipRanges = <String>{};

      for (final line in lines) {
        final match = RegExp(r'(\d{1,3}\.){3}\d{1,3}').firstMatch(line);
        if (match != null) {
          final ip = match.group(0);
          if (ip != null && ip.contains('.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              final range = '${parts[0]}.${parts[1]}.${parts[2]}';
              ipRanges.add(range);
            }
          }
        }
      }

      if (ipRanges.isEmpty) return [];

      final List<int> commonHosts = [
        2,
        5,
        10,
        20,
        30,
        40,
        50,
        60,
        70,
        80,
        90,
        100,
        101,
        102,
        110,
        120,
        130,
        140,
        150,
        160,
        170,
        180,
        190,
        200,
        210,
        220,
        230,
        240,
      ];

      final networkPrinters = <NetworkPrinter>[];
      final futures = <Future<void>>[];

      for (final range in ipRanges) {
        for (final host in commonHosts) {
          final ip = '$range.$host';
          futures.add(_isPrinterAtIP(ip).then((isPrinter) {
            if (isPrinter) {
              networkPrinters.add(NetworkPrinter(
                ip: ip,
                port: 9100,
                name: 'Network Printer $ip',
              ));
            }
          }));
        }
      }

      await Future.wait(futures);
      return networkPrinters;
    } catch (e) {
      print('Error detecting network printers: $e');
      return [];
    }
  }

  /// Check if there's a printer at specific IP
  static Future<bool> _isPrinterAtIP(String ip) async {
    try {
      final socket = await Socket.connect(ip, 9100,
          timeout: const Duration(milliseconds: 600));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<WindowsPrinter>> _fetchPrintersWithPowerShell() async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          r'try { Get-Printer | Select-Object Name,PortName,DriverName,WorkOffline,PrinterStatus | ConvertTo-Json -Compress } catch { Write-Error $PSItem.Exception.Message }'
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        final errorMsg = (result.stderr ?? result.stdout ?? '').toString();
        if (errorMsg.isNotEmpty && !errorMsg.contains('Get-Printer')) {
          print('PowerShell printer detection error: $errorMsg');
        }
        return [];
      }

      final stdout = result.stdout?.toString().trim();
      if (stdout == null || stdout.isEmpty) {
        print('PowerShell returned empty printer list');
        return [];
      }

      try {
        final parsed = jsonDecode(stdout);
        final List<dynamic> entries = parsed is List ? parsed : [parsed];

        final printers = entries
            .map<WindowsPrinter?>((dynamic item) {
              if (item is Map<String, dynamic>) {
                final name = (item['Name'] ?? '').toString().trim();
                if (name.isEmpty) return null;
                final port = (item['PortName'] ?? '').toString().trim();
                final driver = (item['DriverName'] ?? '').toString().trim();
                final workOffline =
                    (item['WorkOffline'] ?? false).toString().toLowerCase() ==
                        'true';
                final status = (item['PrinterStatus'] ?? '').toString().trim();

                return WindowsPrinter(
                  name: name,
                  port: port,
                  driver: driver,
                  isOffline: workOffline,
                  status: status,
                  isThermal: _isThermalPrinter(name, driver),
                );
              }
              return null;
            })
            .whereType<WindowsPrinter>()
            .toList();
        
        print('PowerShell detected ${printers.length} printers');
        return printers;
      } catch (e) {
        print('Error parsing PowerShell printer output: $e');
        print('Output was: $stdout');
        return [];
      }
    } catch (e) {
      print('PowerShell detection failed: $e');
      return [];
    }
  }

  static Future<List<WindowsPrinter>> _fetchPrintersWithWmic() async {
    try {
      final result = await Process.run(
        'wmic',
        [
          'printer',
          'get',
          'name,portname,drivername,workoffline,printerstatus',
          '/format:csv'
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        print('WMIC printer detection error: ${result.stderr}');
        return [];
      }

      final lines = result.stdout.toString().split('\n');
      final printers = <WindowsPrinter>[];

      for (final line in lines) {
        if (line.trim().isEmpty || line.contains('Node')) continue;

        final parts = line.split(',');
        if (parts.length >= 5) {
          final name = parts[1].trim();
          final port = parts[2].trim();
          final driver = parts[3].trim();
          final workOffline = parts[4].trim().toLowerCase() == 'true';
          final status = parts.length > 5 ? parts[5].trim() : '';

          if (name.isNotEmpty && name.toLowerCase() != 'name') {
            printers.add(WindowsPrinter(
              name: name,
              port: port,
              driver: driver,
              isOffline: workOffline,
              status: status,
              isThermal: _isThermalPrinter(name, driver),
            ));
          }
        }
      }

      return printers;
    } catch (e) {
      print('WMIC detection failed: $e');
      return [];
    }
  }

  /// Test printer connection
  static Future<bool> testPrinterConnection(String printerName) async {
    try {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-Printer -Name "${printerName.replaceAll('"', '""')}" | Select-Object Name, PrinterStatus'
        ],
        runInShell: true,
      );

      return result.exitCode == 0 &&
          !(result.stdout ?? '').toString().toLowerCase().contains('error');
    } catch (_) {
      return false;
    }
  }

  /// Get printer status
  static Future<PrinterStatus> getPrinterStatus(String printerName) async {
    try {
      final escaped = printerName.replaceAll('"', '""');
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Get-Printer -Name "$escaped" | Select-Object PrinterStatus, WorkOffline | ConvertTo-Json'
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        return PrinterStatus.unknown;
      }

      final stdout = result.stdout?.toString().trim();
      if (stdout == null || stdout.isEmpty) return PrinterStatus.unknown;

      final parsed = jsonDecode(stdout);
      if (parsed is Map<String, dynamic>) {
        final workOffline =
            (parsed['WorkOffline'] ?? false).toString().toLowerCase() == 'true';
        if (workOffline) return PrinterStatus.offline;

        final statusValue = parsed['PrinterStatus'];
        final statusInt = statusValue is num
            ? statusValue.toInt()
            : int.tryParse(statusValue.toString());

        switch (statusInt) {
          case 3:
            return PrinterStatus.ready;
          case 4:
            return PrinterStatus.printing;
          case 7:
            return PrinterStatus.offline;
          default:
            return PrinterStatus.unknown;
        }
      }

      return PrinterStatus.unknown;
    } catch (_) {
      return PrinterStatus.unknown;
    }
  }
}

class WindowsPrinter {
  final String name;
  final String port;
  final String driver;
  final bool isOffline;
  final String status;
  final bool isThermal;

  WindowsPrinter({
    required this.name,
    required this.port,
    required this.driver,
    required this.isOffline,
    required this.status,
    required this.isThermal,
  });

  @override
  String toString() {
    return 'WindowsPrinter(name: $name, port: $port, thermal: $isThermal, offline: $isOffline)';
  }
}

class NetworkPrinter {
  final String ip;
  final int port;
  final String name;

  NetworkPrinter({
    required this.ip,
    required this.port,
    required this.name,
  });

  @override
  String toString() {
    return 'NetworkPrinter(ip: $ip, port: $port, name: $name)';
  }
}

enum PrinterStatus {
  ready,
  printing,
  offline,
  error,
  unknown,
}
