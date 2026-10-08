import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/quantity_formatter.dart';
import '../models/sale.dart';
import '../models/product.dart';

/// Printer connection status
enum PrinterConnectionStatus {
  connected,
  disconnected,
  notConfigured,
  error,
}

class EnhancedThermalPrintServiceV2 {
  static const int defaultPort = 9100;
  static const int timeout = 10; // seconds
  static const int maxRetries = 3;

  // ESC/POS Commands
  static const String ESC = '\x1B';
  static const String GS = '\x1D';
  static const String LF = '\x0A';
  static const String CR = '\x0D';
  static const String FF = '\x0C';
  static const String CAN = '\x18';

  /// Print receipt to thermal printer via network
  static Future<bool> printReceipt(
    SaleModel sale, {
    String? printerIp,
    int port = defaultPort,
    String businessName = 'My Business',
    String businessAddress = '',
    String businessPhone = '',
    String currency = '\$',
    int copies = 1,
  }) async {
    int retryCount = 0;
    Socket? socket;

    try {
      // Get printer IP if not provided
      final ip = printerIp ?? await _getPrinterIp();
      if (ip == null || ip.isEmpty) {
        if (kDebugMode) {
          print('Printer IP not found. Please check printer connection.');
        }
        return false;
      }

      // Test connection first before attempting to print (with timeout)
      final connectionResult =
          await testPrinterConnectionWithError(ip, port: port).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          if (kDebugMode) {
            print('Connection test timeout for printer at $ip:$port');
          }
          return (
            isConnected: false,
            errorMessage:
                'Connection test timed out. Printer may be offline or on a different network.'
          );
        },
      );
      if (!connectionResult.isConnected) {
        if (kDebugMode) {
          print(
              'Printer connection test failed: ${connectionResult.errorMessage}');
        }
        return false;
      }

      while (retryCount < maxRetries) {
        try {
          // Generate receipt data
          final receiptData = _generateReceiptData(
            sale,
            businessName,
            businessAddress,
            businessPhone,
            currency,
          );

          // Send to printer with timeout protection
          socket = await Socket.connect(ip, port,
              timeout: Duration(seconds: timeout));

          // Initialize printer
          socket.add(_initializePrinter());

          // Send receipt data
          for (int i = 0; i < copies; i++) {
            socket.add(receiptData);
            if (i < copies - 1) {
              socket.add(_cutPaper());
            }
          }

          // Finalize printing
          socket.add(_finalizePrint());

          await socket.flush();
          await socket.close();

          if (kDebugMode) {
            print('✓ Receipt printed successfully to $ip:$port');
          }
          return true;
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('Print attempt $retryCount failed: $e');
          }

          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
          }

          try {
            await socket?.close();
          } catch (_) {}
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error printing receipt: $e');
      }
      return false;
    }
  }

  /// Print raw ESC/POS data to thermal printer
  static Future<bool> printRawData(
    SaleModel sale,
    Uint8List escPosData, {
    String? printerIp,
    int port = defaultPort,
    int copies = 1,
  }) async {
    int retryCount = 0;
    Socket? socket;

    try {
      final ip = printerIp;
      if (ip == null || ip.isEmpty) {
        if (kDebugMode) {
          print('Printer IP not provided');
        }
        return false;
      }

      // Test connection first
      final connectionResult =
          await testPrinterConnectionWithError(ip, port: port).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          return (isConnected: false, errorMessage: 'Connection timeout');
        },
      );

      if (!connectionResult.isConnected) {
        if (kDebugMode) {
          print('Printer connection failed: ${connectionResult.errorMessage}');
        }
        return false;
      }

      while (retryCount < maxRetries) {
        try {
          // Connect to printer
          socket = await Socket.connect(ip, port,
              timeout: Duration(seconds: timeout));

          // Send data for each copy
          for (int i = 0; i < copies; i++) {
            socket.add(escPosData);
            if (i < copies - 1) {
              socket.add(_cutPaper());
            }
          }

          // Finalize
          socket.add(_finalizePrint());
          await socket.flush();
          await socket.close();

          if (kDebugMode) {
            print('✓ Raw ESC/POS data printed successfully');
          }
          return true;
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print('Print attempt $retryCount failed: $e');
          }

          if (retryCount < maxRetries) {
            await Future.delayed(Duration(seconds: retryCount));
          }

          try {
            await socket?.close();
          } catch (_) {}
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error printing raw data: $e');
      }
      return false;
    }
  }

  /// Test printer connection
  /// Returns a tuple: (isConnected: bool, errorMessage: String?)
  static Future<({bool isConnected, String? errorMessage})>
      testPrinterConnectionWithError(String printerIp,
          {int port = defaultPort}) async {
    Socket? socket;
    try {
      // Check if trying to connect to device's own IP (which doesn't make sense)
      final networkInfo = NetworkInfo();
      final deviceIP = await networkInfo.getWifiIP();
      if (deviceIP != null && printerIp == deviceIP) {
        final errorMessage =
            'Cannot use your device\'s own IP address ($deviceIP) as the printer IP. Please enter the printer\'s IP address instead.';
        if (kDebugMode) {
          print('Printer connection test failed: $errorMessage');
        }
        return (isConnected: false, errorMessage: errorMessage);
      }

      socket =
          await Socket.connect(printerIp, port, timeout: Duration(seconds: 5));
      socket.destroy();
      return (isConnected: true, errorMessage: null);
    } catch (e) {
      // Clean up on error
      try {
        socket?.destroy();
      } catch (_) {
        // Ignore cleanup errors
      }

      // Provide helpful error messages based on exception type
      String errorMessage = 'Connection failed';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('operation not permitted') ||
          errorStr.contains('errno = 1')) {
        // Check if it's the device's own IP
        try {
          final networkInfo = NetworkInfo();
          final deviceIP = await networkInfo.getWifiIP();
          if (deviceIP != null && printerIp == deviceIP) {
            errorMessage =
                'Cannot use your device\'s own IP address ($deviceIP) as the printer IP. Please enter the printer\'s actual IP address.';
          } else {
            errorMessage =
                'Connection not permitted. Check if the printer IP ($printerIp) is correct and the printer is accessible on your network.';
          }
        } catch (_) {
          errorMessage =
              'Connection not permitted. Check if the printer IP ($printerIp) is correct.';
        }
      } else if (errorStr.contains('timeout')) {
        errorMessage =
            'Connection timeout. Printer may be offline or on a different network.';
      } else if (errorStr.contains('refused')) {
        errorMessage =
            'Connection refused. Printer may not be configured for network printing.';
      } else {
        errorMessage = 'Failed to connect to $printerIp:$port. $e';
      }

      if (kDebugMode) {
        print('Printer connection test failed: $errorMessage');
      }
      return (isConnected: false, errorMessage: errorMessage);
    }
  }

  static Uint8List _initializePrinter() {
    final List<int> commands = [];

    // Reset printer
    commands.addAll(utf8.encode('${ESC}@'));

    // Set character set
    commands.addAll(utf8.encode('${ESC}R\x00')); // USA

    // Set alignment to center
    commands.addAll(utf8.encode('${ESC}a\x01'));

    // Set line spacing
    commands.addAll(utf8.encode('${ESC}3\x18')); // 24 dots

    return Uint8List.fromList(commands);
  }

  /// Cut paper command
  static Uint8List _cutPaper() {
    return Uint8List.fromList(utf8.encode('${GS}V\x00'));
  }

  /// Finalize printing
  static Uint8List _finalizePrint() {
    final List<int> commands = [];

    // Feed paper
    commands.addAll(utf8.encode('${ESC}d\x03')); // Feed 3 lines

    // Cut paper
    commands.addAll(utf8.encode('${GS}V\x00'));

    // Reset alignment
    commands.addAll(utf8.encode('${ESC}a\x00'));

    return Uint8List.fromList(commands);
  }

  /// Set text alignment
  static Uint8List _setAlignment(int alignment) {
    return Uint8List.fromList(utf8.encode('${ESC}a$alignment'));
  }

  /// Set text size
  static Uint8List _setTextSize(int width, int height) {
    return Uint8List.fromList(
        utf8.encode('${GS}!${(width - 1) | ((height - 1) << 4)}'));
  }

  /// Set bold text
  static Uint8List _setBold(bool bold) {
    return Uint8List.fromList(utf8.encode('${ESC}E${bold ? '\x01' : '\x00'}'));
  }

  /// Print line with proper formatting
  static Uint8List _printLine(String text,
      {bool bold = false, bool center = false, int size = 1}) {
    final List<int> commands = [];

    if (center) {
      commands.addAll(utf8.encode('${ESC}a\x01')); // Center
    } else {
      commands.addAll(utf8.encode('${ESC}a\x00')); // Left
    }

    if (bold) {
      commands.addAll(utf8.encode('${ESC}E\x01')); // Bold on
    }

    if (size > 1) {
      commands.addAll(_setTextSize(size, size));
    }

    commands.addAll(utf8.encode('$text$LF'));

    if (bold) {
      commands.addAll(utf8.encode('${ESC}E\x00')); // Bold off
    }

    if (size > 1) {
      commands.addAll(_setTextSize(1, 1)); // Reset size
    }

    return Uint8List.fromList(commands);
  }

  /// Print separator line
  static Uint8List _printSeparator() {
    return Uint8List.fromList(utf8.encode('${'=' * 32}$LF'));
  }

  /// Get available printer IP addresses
  /// Scans the local network for printers on port 9100 (common thermal printer port)
  /// Works for both WiFi and LAN connections on the same network
  static Future<List<String>> getAvailablePrinters() async {
    try {
      final networkInfo = NetworkInfo();

      // Try to get IP address - works for both WiFi and LAN
      String? deviceIP;
      try {
        deviceIP = await networkInfo.getWifiIP();
      } catch (e) {
        if (kDebugMode) {
          print('Could not get WiFi IP: $e');
        }
      }

      // If WiFi IP is null, try to get any local IP
      if (deviceIP == null || deviceIP.isEmpty) {
        try {
          // Try to connect to a known service to get local IP
          // Or use platform-specific methods if available
          if (kDebugMode) {
            print(
                'No IP address found. Cannot scan for printers automatically.');
          }
          return [];
        } catch (e) {
          if (kDebugMode) {
            print('Could not determine network IP: $e');
          }
          return [];
        }
      }

      // Get network range
      final parts = deviceIP.split('.');
      if (parts.length != 4) {
        if (kDebugMode) {
          print('Invalid IP format: $deviceIP');
        }
        return [];
      }

      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}.';
      final List<String> availablePrinters = [];

      if (kDebugMode) {
        print(
            'Scanning network $networkBase* for printers on port $defaultPort (Device IP: $deviceIP)');
      }

      // Expanded list of common printer IPs to check
      // This includes common router-assigned IPs for both WiFi and LAN devices
      final commonIPs = [
        // Router and common network devices
        '${networkBase}1',
        '${networkBase}2',
        // Common printer IP ranges
        '${networkBase}100',
        '${networkBase}101',
        '${networkBase}102',
        '${networkBase}103',
        '${networkBase}104',
        '${networkBase}105',
        '${networkBase}150',
        '${networkBase}151',
        '${networkBase}152',
        // Extended range for LAN-connected devices
        '${networkBase}200',
        '${networkBase}201',
        '${networkBase}202',
        '${networkBase}203',
        '${networkBase}204',
        '${networkBase}205',
        '${networkBase}206',
        '${networkBase}207',
        '${networkBase}208',
        '${networkBase}209',
        '${networkBase}210',
        // Additional common ranges
        '${networkBase}50',
        '${networkBase}51',
        '${networkBase}52',
      ];

      // Scan printers in parallel with timeout
      final futures = commonIPs.map((ip) async {
        try {
          final socket = await Socket.connect(ip, defaultPort,
              timeout: Duration(
                  milliseconds: 300)); // Reduced timeout for faster scanning
          socket.destroy();
          if (kDebugMode) {
            print('Found printer at $ip');
          }
          return ip;
        } catch (e) {
          return null;
        }
      });

      final results = await Future.wait(futures);
      availablePrinters.addAll(results.whereType<String>());

      if (kDebugMode) {
        if (availablePrinters.isEmpty) {
          print(
              'No printers found on network $networkBase* after scanning ${commonIPs.length} IPs.');
          print(
              'If your printer is on the same network (WiFi/LAN), try entering its IP manually.');
        } else {
          print(
              'Found ${availablePrinters.length} printer(s): ${availablePrinters.join(", ")}');
        }
      }

      return availablePrinters;
    } catch (e) {
      if (kDebugMode) {
        print('Error scanning for printers: $e');
      }
      return [];
    }
  }

  /// Test printer connection (backward compatible)
  static Future<bool> testPrinterConnection(String printerIp,
      {int port = defaultPort}) async {
    final result = await testPrinterConnectionWithError(printerIp, port: port);
    return result.isConnected;
  }

  /// Check if printer is connected and available
  static Future<PrinterConnectionStatus> checkPrinterStatus(
      String? printerIp) async {
    try {
      final ip = printerIp ?? await _getPrinterIp();
      if (ip == null) {
        return PrinterConnectionStatus.notConfigured;
      }

      final isConnected = await testPrinterConnection(ip);
      if (isConnected) {
        return PrinterConnectionStatus.connected;
      } else {
        return PrinterConnectionStatus.disconnected;
      }
    } catch (e) {
      return PrinterConnectionStatus.error;
    }
  }

  /// Generate receipt data in ESC/POS format
  static Uint8List _generateReceiptData(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
  ) {
    final List<int> data = [];
    const int paperWidth =
        48; // 80mm thermal printers are typically 48 chars wide
    final safeCurrency = _normalizeCurrencySymbol(currency);

    // Header
    data.addAll(
        _printLine(businessName.trim(), bold: true, center: true, size: 2));
    data.addAll(
        _printLine(_centerText('SALES RECEIPT', paperWidth), bold: true));
    data.addAll(_printLine(''));

    if (businessAddress.isNotEmpty) {
      for (final line in _wrapText(businessAddress.trim(), paperWidth)) {
        data.addAll(_printLine(_centerText(line, paperWidth)));
      }
    }
    if (businessPhone.isNotEmpty) {
      data.addAll(_printLine(_centerText(businessPhone.trim(), paperWidth)));
    }

    data.addAll(_printLine(_divider(paperWidth)));

    // Sale details
    data.addAll(
        _printLine(_lineLeftRight('Receipt #', '${sale.id}', paperWidth)));
    data.addAll(
        _printLine(_lineLeftRight('Date', _formatDate(sale.date), paperWidth)));
    data.addAll(
        _printLine(_lineLeftRight('Time', _formatTime(sale.date), paperWidth)));

    if (sale.customer != null) {
      for (final line
          in _wrapText('Customer: ${sale.customer!.name}', paperWidth)) {
        data.addAll(_printLine(line));
      }
    }

    data.addAll(_printLine(_lineLeftRight(
      'Payment',
      sale.paymentType.name.toUpperCase(),
      paperWidth,
    )));
    data.addAll(_printLine(_lineLeftRight(
      'Status',
      sale.status.name.toUpperCase(),
      paperWidth,
    )));
    data.addAll(_printLine(_divider(paperWidth)));

    // Items header
    data.addAll(_printLine(
        _lineLeftRight('ITEMS', '${sale.items.length} item(s)', paperWidth),
        bold: true));
    data.addAll(_printLine(_divider(paperWidth)));

    // Items
    for (final item in sale.items) {
      final product = item.product;
      final productName = product?.name ?? 'Unknown';
      final qty = QuantityFormatter.withUnit(
          item.qty, item.unit.isNotEmpty ? item.unit : product?.unit);
      final unitPrice = '$safeCurrency${item.price.toStringAsFixed(2)}';
      final lineTotal = '$safeCurrency${item.subtotal.toStringAsFixed(2)}';

      for (final nameLine in _wrapText(productName, paperWidth)) {
        data.addAll(_printLine(nameLine, bold: true));
      }
      data.addAll(_printLine(
        _lineLeftRight('$qty x $unitPrice', lineTotal, paperWidth),
      ));

      // Add mobile phone details if available
      if (product != null &&
          (product.brand != null ||
              product.modelName != null ||
              item.imei != null)) {
        final mobileInfo = <String>[];
        if (product.brand != null && product.modelName != null) {
          mobileInfo.add('${product.brand} ${product.modelName}');
        }
        if (product.storageCapacity != null) {
          mobileInfo.add(product.storageCapacity!);
        }
        if (product.ram != null) {
          mobileInfo.add('${product.ram} RAM');
        }
        if (product.color != null) {
          mobileInfo.add(product.color!);
        }
        if (mobileInfo.isNotEmpty) {
          for (final line
              in _wrapText('  ${mobileInfo.join(' | ')}', paperWidth)) {
            data.addAll(_printLine(line, size: 0));
          }
        }
        if (item.imei != null && item.imei!.isNotEmpty) {
          for (final line in _wrapText('  IMEI: ${item.imei}', paperWidth)) {
            data.addAll(_printLine(line, size: 0));
          }
        }
        if (product.condition != null) {
          data.addAll(_printLine(
              '  Condition: ${product.condition!.toUpperCase()}',
              size: 0));
        }
        if (product.warrantyPeriod != null) {
          data.addAll(
              _printLine('  Warranty: ${product.warrantyPeriod}', size: 0));
        }
        final warrantyExpiry = _getWarrantyExpiryLabel(product, sale.date);
        if (warrantyExpiry != null) {
          data.addAll(_printLine('  Warranty Ends: $warrantyExpiry', size: 0));
        }
        if (product.tradeInValue != null) {
          data.addAll(_printLine(
              '  Trade-in Value: $safeCurrency${product.tradeInValue!.toStringAsFixed(2)}',
              size: 0));
        }
      }
      data.addAll(_printLine(_divider(paperWidth)));
    }

    // Calculate subtotal and tax
    final subtotal = sale.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final storedTax = sale.items.fold(0.0, (sum, item) => sum + item.taxAmount);
    final tax =
        storedTax > 0 ? storedTax : sale.total - subtotal + sale.discount;

    // Totals
    data.addAll(_printLine(_lineLeftRight(
      'Subtotal',
      '$safeCurrency${subtotal.toStringAsFixed(2)}',
      paperWidth,
    )));

    if (sale.discount > 0) {
      data.addAll(_printLine(_lineLeftRight(
        'Discount',
        '-$safeCurrency${sale.discount.toStringAsFixed(2)}',
        paperWidth,
      )));
    }

    if (tax > 0) {
      data.addAll(_printLine(_lineLeftRight(
        'Tax',
        '$safeCurrency${tax.toStringAsFixed(2)}',
        paperWidth,
      )));
    }

    data.addAll(_printLine(_divider(paperWidth)));
    data.addAll(_printLine(
      _lineLeftRight(
          'TOTAL', '$safeCurrency${sale.total.toStringAsFixed(2)}', paperWidth),
      bold: true,
      size: 1,
    ));
    if (sale.paid > 0) {
      data.addAll(_printLine(_lineLeftRight(
        'Paid',
        '$safeCurrency${sale.paid.toStringAsFixed(2)}',
        paperWidth,
      )));
    }
    if (sale.due > 0) {
      data.addAll(_printLine(
          _lineLeftRight(
            'Due',
            '$safeCurrency${sale.due.toStringAsFixed(2)}',
            paperWidth,
          ),
          bold: true));
    }
    data.addAll(_printLine(_divider(paperWidth)));

    // Footer
    data.addAll(_printLine(''));
    data.addAll(_printLine(
        _centerText('Thank you for your business!', paperWidth),
        center: false));
    data.addAll(_printLine(_centerText('Please visit again', paperWidth),
        center: false, size: 0));
    data.addAll(_printLine(''));
    data.addAll(_printLine(_centerText('Powered by Offline POS', paperWidth),
        center: false, size: 0));
    data.addAll(_printLine(''));
    data.addAll(_printLine(''));

    return Uint8List.fromList(data);
  }

  static String _normalizeCurrencySymbol(String currency) {
    // Many thermal printers using default code pages cannot render Unicode symbols reliably.
    // Use ASCII fallback for consistent output.
    final trimmed = currency.trim();
    if (trimmed.isEmpty) return 'Rs.';

    // Map Unicode symbols to ASCII equivalents
    if (trimmed == '₨' || trimmed == '₹') return 'Rs.';
    if (trimmed == '¥') return 'Yen'; // Chinese/Japanese Yen
    if (trimmed == '€') return 'EUR';
    if (trimmed == '£') return 'GBP';
    if (trimmed == '₽') return 'RUB';
    if (trimmed == '₺') return 'TRY';
    if (trimmed == '₦') return 'NGN';
    if (trimmed == '₵') return 'GHS';
    if (trimmed == '₱') return 'PHP';
    if (trimmed == '₫') return 'VND';
    if (trimmed == '฿') return 'THB';
    if (trimmed == '₩') return 'KRW';
    if (trimmed == '₪') return 'ILS';

    // If it's ASCII, use as-is
    return trimmed;
  }

  static String _divider(int width) => '-' * width;

  static String _centerText(String text, int width) {
    final safe = text.trim();
    if (safe.length >= width) return safe.substring(0, width);
    final left = ((width - safe.length) / 2).floor();
    final right = width - safe.length - left;
    return '${' ' * left}$safe${' ' * right}';
  }

  static String _lineLeftRight(String left, String right, int width) {
    final l = left.trim();
    final r = right.trim();
    if (l.length + r.length + 1 > width) {
      final leftAllowed = (width - r.length - 1).clamp(0, width);
      final truncatedLeft = leftAllowed > 0 && l.length > leftAllowed
          ? l.substring(0, leftAllowed)
          : l;
      final spaces = (width - truncatedLeft.length - r.length).clamp(1, width);
      return '$truncatedLeft${' ' * spaces}$r';
    }
    final spaces = width - l.length - r.length;
    return '$l${' ' * spaces}$r';
  }

  static List<String> _wrapText(String text, int width) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.isEmpty) return [''];
    final words = normalized.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (word.length > width) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = '';
        }
        for (var i = 0; i < word.length; i += width) {
          lines.add(word.substring(i, (i + width).clamp(0, word.length)));
        }
        continue;
      }

      if (current.isEmpty) {
        current = word;
      } else if ((current.length + 1 + word.length) <= width) {
        current = '$current $word';
      } else {
        lines.add(current);
        current = word;
      }
    }

    if (current.isNotEmpty) {
      lines.add(current);
    }
    return lines;
  }

  /// Returns a formatted warranty expiry date based on sale date and product warrantyPeriod (e.g. "12 months").
  static String? _getWarrantyExpiryLabel(
      ProductModel product, DateTime saleDate) {
    if (product.warrantyPeriod == null) return null;
    final months =
        int.tryParse(product.warrantyPeriod!.replaceAll(RegExp(r'[^0-9]'), ''));
    if (months == null || months <= 0) return null;
    final expiry =
        DateTime(saleDate.year, saleDate.month + months, saleDate.day);
    return _formatDate(expiry);
  }

  /// Format date for receipt
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Format time for receipt
  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Print test page
  static Future<bool> printTestPage({
    String? printerIp,
    int port = defaultPort,
    String businessName = 'Test Business',
  }) async {
    try {
      final ip = printerIp ?? await _getPrinterIp();
      if (ip == null) {
        throw Exception('Printer IP not found');
      }

      final socket =
          await Socket.connect(ip, port, timeout: Duration(seconds: timeout));

      // Initialize printer
      socket.add(_initializePrinter());

      // Test content
      final testData = _generateTestData(businessName);
      socket.add(testData);

      // Finalize
      socket.add(_finalizePrint());
      await socket.flush();
      socket.destroy();

      return true;
    } catch (e) {
      throw Exception('Failed to print test page: $e');
    }
  }

  /// Generate test data
  static Uint8List _generateTestData(String businessName) {
    final List<int> data = [];

    data.addAll(
        _printLine('THERMAL PRINTER TEST', bold: true, center: true, size: 2));
    data.addAll(_printLine('', center: true));
    data.addAll(_printLine('Business: $businessName', center: true));
    data.addAll(_printLine('', center: true));
    data.addAll(
        _printLine('Date: ${_formatDate(DateTime.now())}', center: true));
    data.addAll(
        _printLine('Time: ${_formatTime(DateTime.now())}', center: true));
    data.addAll(_printLine('', center: true));
    data.addAll(_printSeparator());
    data.addAll(_printLine('', center: true));
    data.addAll(_printLine('This is a test print', center: true));
    data.addAll(_printLine('If you can read this,', center: true));
    data.addAll(_printLine('your printer is working!', center: true));
    data.addAll(_printLine('', center: true));
    data.addAll(_printLine('', center: true));

    return Uint8List.fromList(data);
  }

  /// Check if printer is configured and available
  static Future<bool> isPrinterConfigured() async {
    try {
      final printers = await getAvailablePrinters().timeout(
        const Duration(seconds: 3),
        onTimeout: () => <String>[],
      );
      if (printers.isEmpty) {
        return false;
      }

      // Test actual connection to first available printer
      final isConnected = await testPrinterConnection(printers.first);
      return isConnected;
    } catch (e) {
      // Fail gracefully - no printer is fine, don't crash
      return false;
    }
  }

  /// Get printer IP (simplified version)
  static Future<String?> _getPrinterIp() async {
    try {
      final printers = await getAvailablePrinters().timeout(
        const Duration(seconds: 5),
        onTimeout: () => <String>[],
      );
      return printers.isNotEmpty ? printers.first : null;
    } catch (e) {
      // Fail gracefully - return null if no printer found
      return null;
    }
  }
}
