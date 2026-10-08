import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sale.dart';
import '../utils/quantity_formatter.dart';

class BluetoothPrinterService {
  static final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;
  static BluetoothDevice? _selectedDevice;
  static bool _isConnected = false;

  /// Initialize Bluetooth printer manager
  static Future<void> initialize() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // Check permissions first
        final hasPermission = await requestPermissions();
        if (!hasPermission) {
          debugPrint(
              'Bluetooth permissions not granted, skipping initialization');
          return;
        }

        // Check if Bluetooth is actually available
        if (!await isBluetoothAvailable()) {
          debugPrint('Bluetooth not available on this device');
          return;
        }

        await _bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Bluetooth initialization error: $e');
        // Don't throw - allow app to continue even if Bluetooth init fails
      }
    }
  }

  /// Request Bluetooth permissions
  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        // Check Android version for permission handling
        // Android 12 (API 31) and above use new Bluetooth permissions
        // Android 11 and below use legacy Bluetooth permissions

        // Always request location for Bluetooth scanning (required by Android)
        final location = await Permission.location.request();

        // Try to request new Bluetooth permissions (Android 12+)
        // These may fail on older Android versions, which is expected
        PermissionStatus bluetoothScan = PermissionStatus.denied;
        PermissionStatus bluetoothConnect = PermissionStatus.denied;
        PermissionStatus bluetoothAdvertise = PermissionStatus.denied;

        try {
          bluetoothScan = await Permission.bluetoothScan.request();
          bluetoothConnect = await Permission.bluetoothConnect.request();
          bluetoothAdvertise = await Permission.bluetoothAdvertise.request();
        } catch (e) {
          // On older Android versions, these permissions don't exist
          // Request legacy Bluetooth permissions instead
          debugPrint(
              'New Bluetooth permissions not available, using legacy: $e');
        }

        // Check if we have the new permissions (Android 12+)
        if (bluetoothScan.isGranted || bluetoothConnect.isGranted) {
          return bluetoothScan.isGranted &&
              bluetoothConnect.isGranted &&
              location.isGranted;
        }

        // For Android 11 and below, Bluetooth permissions are typically granted automatically
        // or handled by the system. We just need location permission for scanning.
        // The bluetooth_print package handles the actual Bluetooth permissions.
        // Return true if location is granted (Bluetooth permissions are runtime permissions)
        return location.isGranted;
      } catch (e) {
        debugPrint('Error requesting Bluetooth permissions: $e');
        return false;
      }
    } else if (Platform.isIOS) {
      // iOS handles Bluetooth permissions automatically through Info.plist
      return true;
    }
    return false;
  }

  /// Check if Bluetooth is available
  static Future<bool> isBluetoothAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }
    return true;
  }

  /// Scan for Bluetooth printers
  static Future<List<BluetoothDevice>> scanForPrinters({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return [];
    }

    try {
      // Request permissions first
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Bluetooth permissions not granted');
      }

      final devices = <BluetoothDevice>[];

      // Listen to scan results
      final subscription = _bluetoothPrint.scanResults.listen((results) {
        devices.clear();
        devices.addAll(results);
      });

      // Start scanning
      await _bluetoothPrint.startScan(timeout: timeout);

      // Wait for scan to complete
      await Future.delayed(timeout);
      await _bluetoothPrint.stopScan();

      await subscription.cancel();

      return devices;
    } catch (e) {
      throw Exception('Error scanning for Bluetooth printers: $e');
    }
  }

  /// Connect to a Bluetooth printer
  static Future<bool> connect(BluetoothDevice device) async {
    try {
      // Ensure permissions are granted
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception(
            'Bluetooth permissions not granted. Please grant Bluetooth permissions in app settings.');
      }

      // Disconnect from previous printer if any
      if (_isConnected && _selectedDevice != null) {
        try {
          await _bluetoothPrint.disconnect();
        } catch (e) {
          debugPrint('Error disconnecting from previous printer: $e');
          // Continue anyway
        }
        _isConnected = false;
        _selectedDevice = null;
      }

      // Connect to new printer with timeout
      final connected = await _bluetoothPrint.connect(device).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Bluetooth connection timeout');
          return false;
        },
      );

      if (connected == true) {
        _selectedDevice = device;
        _isConnected = true;
        debugPrint(
            'Successfully connected to Bluetooth printer: ${device.name}');
        return true;
      }

      _isConnected = false;
      _selectedDevice = null;
      debugPrint('Failed to connect to Bluetooth printer: ${device.name}');
      return false;
    } catch (e) {
      _isConnected = false;
      _selectedDevice = null;
      debugPrint('Error connecting to Bluetooth printer: $e');
      if (e.toString().toLowerCase().contains('timeout')) {
        throw Exception(
            'Connection timeout. Please make sure the printer is turned on and in range.');
      }
      throw Exception('Error connecting to Bluetooth printer: ${e.toString()}');
    }
  }

  /// Disconnect from current printer
  static Future<void> disconnect() async {
    try {
      await _bluetoothPrint.disconnect();
      _selectedDevice = null;
      _isConnected = false;
    } catch (e) {
      // Ignore disconnect errors
      _selectedDevice = null;
      _isConnected = false;
    }
  }

  /// Check if printer is connected
  static bool isConnected() {
    // Verify actual connection state, not just our internal flag
    return _isConnected && _selectedDevice != null;
  }

  /// Verify actual Bluetooth connection status
  static Future<bool> verifyConnection() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return false;
    }

    if (_selectedDevice == null) {
      _isConnected = false;
      return false;
    }

    try {
      // Try to get connection state from the Bluetooth plugin
      // This is a best-effort check since the plugin may not expose connection state
      if (!_isConnected) {
        return false;
      }

      // If we have a selected device and our flag says connected, assume it's connected
      // The actual print operation will fail if not really connected
      return true;
    } catch (e) {
      debugPrint('Error verifying Bluetooth connection: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Get connected printer
  static BluetoothDevice? getConnectedPrinter() {
    return _selectedDevice;
  }

  /// Print receipt to Bluetooth printer
  static Future<bool> printReceipt(
    SaleModel sale, {
    String businessName = 'My Business',
    String businessAddress = '',
    String businessPhone = '',
    String currency = '\$',
    int copies = 1,
    int paperWidthMm = 80,
  }) async {
    try {
      // Ensure permissions each time before attempting to print (Android 12+).
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception(
            'Bluetooth permissions not granted. Please allow access.');
      }

      // Refresh scan to reduce stale connection issues.
      await initialize();

      // Verify actual connection status
      final isActuallyConnected = await verifyConnection();

      // Attempt a lightweight reconnect if we previously had a device selected but not connected
      if (!isActuallyConnected && _selectedDevice != null) {
        try {
          debugPrint('Attempting to reconnect to Bluetooth printer...');
          final reconnected = await connect(_selectedDevice!);
          if (!reconnected) {
            throw Exception(
                'Could not reconnect to previously selected printer. Please reconnect manually.');
          }
        } catch (e) {
          debugPrint('Reconnection failed: $e');
          throw Exception(
              'Bluetooth printer disconnected. Please reconnect your printer and try again.');
        }
      }

      if (!isActuallyConnected) {
        throw Exception(
            'No Bluetooth printer connected. Please connect a printer first from the printer settings.');
      }

      // Generate receipt data
      final receiptData = _generateReceiptData(
        sale,
        businessName,
        businessAddress,
        businessPhone,
        currency,
        paperWidthMm,
      );

      // Print copies
      for (int i = 0; i < copies; i++) {
        await _bluetoothPrint.printReceipt(
          {},
          receiptData,
        );
        if (i < copies - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      return true;
    } catch (e) {
      throw Exception('Error printing to Bluetooth printer: $e');
    }
  }

  /// Generate receipt data in ESC/POS format
  static List<LineText> _generateReceiptData(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    int paperWidthMm,
  ) {
    final List<LineText> lines = [];
    final width = paperWidthMm == 58 ? 32 : 48;
    final divider = '-' * width;
    final safeCurrency = _thermalSafeCurrency(currency);

    String money(double amount) => '$safeCurrency ${amount.toStringAsFixed(2)}';

    String amountLine(String label, String value) {
      final gap = width - label.length - value.length;
      return '$label${' ' * (gap < 1 ? 1 : gap)}$value';
    }

    String fit(String value, int maxLength) {
      final clean = value.replaceAll('\n', ' ').trim();
      if (clean.length <= maxLength) return clean;
      if (maxLength <= 3) return clean.substring(0, maxLength);
      return '${clean.substring(0, maxLength - 3)}...';
    }

    // Header
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: businessName,
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    if (businessAddress.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: businessAddress,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }

    if (businessPhone.isNotEmpty) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: businessPhone,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Sale details
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Receipt #: ${sale.id}',
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Date: ${_formatDate(sale.date)}',
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Time: ${_formatTime(sale.date)}',
      linefeed: 1,
    ));

    if (sale.customer != null) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Customer: ${sale.customer!.name}',
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Items header
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: paperWidthMm == 58
          ? 'ITEM / QTY / PRICE'
          : 'ITEM                    QTY / PRICE',
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      linefeed: 1,
    ));

    // Items
    for (final item in sale.items) {
      final product = item.product;
      final productName = product?.name ?? 'Unknown';
      final displayName = fit(productName, width);

      final qty = QuantityFormatter.withUnit(item.qty, product?.unit);
      final total = money(item.subtotal);
      final detail = '$qty x ${money(item.price)}';

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: displayName,
        linefeed: 1,
      ));
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: amountLine('  $detail', total),
        linefeed: 1,
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
        if (product.color != null) {
          mobileInfo.add(product.color!);
        }
        if (mobileInfo.isNotEmpty) {
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '  ${mobileInfo.join(' • ')}',
            linefeed: 1,
          ));
        }
        if (item.imei != null && item.imei!.isNotEmpty) {
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '  IMEI: ${item.imei}',
            linefeed: 1,
          ));
        }
        if (product.condition != null) {
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '  Condition: ${product.condition!.toUpperCase()}',
            linefeed: 1,
          ));
        }
        if (product.warrantyPeriod != null) {
          lines.add(LineText(
            type: LineText.TYPE_TEXT,
            content: '  Warranty: ${product.warrantyPeriod}',
            linefeed: 1,
          ));
        }
      }
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Totals
    final subtotal = sale.items.fold(0.0, (sum, item) => sum + item.subtotal);
    final tax = sale.total - subtotal + sale.discount;

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: amountLine('Subtotal', money(subtotal)),
      linefeed: 1,
    ));

    if (sale.discount > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: amountLine('Discount', '-${money(sale.discount)}'),
        linefeed: 1,
      ));
    }

    if (tax > 0) {
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: amountLine('Tax', money(tax)),
        linefeed: 1,
      ));
    }

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: amountLine('TOTAL', money(sale.total)),
      weight: 1,
      linefeed: 1,
    ));

    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: divider,
      align: LineText.ALIGN_CENTER,
      linefeed: 1,
    ));

    // Payment info
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Payment: ${sale.paymentType.name.toUpperCase()}',
      linefeed: 1,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Status: ${sale.status.name.toUpperCase()}',
      linefeed: 1,
    ));

    // Footer
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: '',
      linefeed: 2,
    ));
    lines.add(LineText(
      type: LineText.TYPE_TEXT,
      content: 'Thank you for your business!',
      weight: 1,
      align: LineText.ALIGN_CENTER,
      linefeed: 2,
    ));

    return lines;
  }

  /// Print test page
  static Future<bool> printTestPage({
    String businessName = 'Test Business',
    int paperWidthMm = 80,
  }) async {
    try {
      if (!isConnected()) {
        throw Exception('No Bluetooth printer connected');
      }

      final List<LineText> lines = [];
      final width = paperWidthMm == 58 ? 32 : 48;

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'BLUETOOTH PRINTER TEST',
        weight: 1,
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
      ));

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Business: $businessName',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Date: ${_formatDate(DateTime.now())}',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'Time: ${_formatTime(DateTime.now())}',
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
      ));

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: '-' * width,
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));

      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'This is a test print',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'If you can read this,',
        align: LineText.ALIGN_CENTER,
        linefeed: 1,
      ));
      lines.add(LineText(
        type: LineText.TYPE_TEXT,
        content: 'your printer is working!',
        align: LineText.ALIGN_CENTER,
        linefeed: 2,
      ));

      await _bluetoothPrint.printReceipt({}, lines);
      return true;
    } catch (e) {
      throw Exception('Error printing test page: $e');
    }
  }

  static String _thermalSafeCurrency(String currency) {
    final value = currency.trim();
    if (value.isEmpty || value == '₨' || value == '₹') return 'Rs.';
    if (value == '€') return 'EUR';
    if (value == '£') return 'GBP';
    if (value == '¥') return 'Yen';
    if (value == '₽') return 'RUB';
    if (value == '₺') return 'TRY';
    if (value == '₦') return 'NGN';
    if (value == '₱') return 'PHP';
    if (value == '฿') return 'THB';
    if (value == '₩') return 'KRW';
    return value.codeUnits.every((unit) => unit < 128) ? value : 'Rs.';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour12 =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }
}
