import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/quantity_formatter.dart';
import '../models/sale.dart';

class ThermalPrintService {
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

    while (retryCount < maxRetries) {
      try {
        // Get printer IP if not provided
        final ip = printerIp ?? await _getPrinterIp();
        if (ip == null) {
          throw Exception(
              'Printer IP not found. Please check printer connection.');
        }

        // Generate receipt data
        final receiptData = _generateReceiptData(
          sale,
          businessName,
          businessAddress,
          businessPhone,
          currency,
        );

        // Send to printer
        final socket =
            await Socket.connect(ip, port, timeout: Duration(seconds: timeout));

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
        socket.destroy();

        return true;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          throw Exception(
              'Failed to print receipt after $maxRetries attempts: $e');
        }
        // Wait before retry
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return false;
  }

  /// Initialize printer with proper settings
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
  static Future<List<String>> getAvailablePrinters() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      if (wifiIP == null) return [];

      // Get network range
      final parts = wifiIP.split('.');
      if (parts.length != 4) return [];

      final networkBase = '${parts[0]}.${parts[1]}.${parts[2]}.';
      final List<String> availablePrinters = [];

      // Scan common printer IPs
      final commonIPs = [
        '${networkBase}1',
        '${networkBase}100',
        '${networkBase}101',
        '${networkBase}102',
        '${networkBase}103',
        '${networkBase}104',
        '${networkBase}105',
        '${networkBase}200',
        '${networkBase}201',
        '${networkBase}202',
        '${networkBase}203',
        '${networkBase}204',
        '${networkBase}205',
      ];

      for (final ip in commonIPs) {
        try {
          final socket = await Socket.connect(ip, defaultPort,
              timeout: Duration(seconds: 1));
          socket.destroy();
          availablePrinters.add(ip);
        } catch (e) {
          // IP not available, continue
        }
      }

      return availablePrinters;
    } catch (e) {
      return [];
    }
  }

  /// Generate receipt data for thermal printer
  static Uint8List _generateReceiptData(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
  ) {
    final List<int> bytes = [];

    // Initialize printer
    bytes.addAll([0x1B, 0x40]); // ESC @ - Initialize printer

    // Business Header
    bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 - Center align
    bytes
        .addAll([0x1B, 0x21, 0x30]); // ESC ! 0x30 - Double height, double width
    bytes.addAll(_stringToBytes(businessName));
    bytes.addAll([0x0A]); // Line feed

    if (businessAddress.isNotEmpty) {
      bytes.addAll([0x1B, 0x21, 0x00]); // ESC ! 0x00 - Normal size
      bytes.addAll(_stringToBytes(businessAddress));
      bytes.addAll([0x0A]);
    }

    if (businessPhone.isNotEmpty) {
      bytes.addAll(_stringToBytes(businessPhone));
      bytes.addAll([0x0A]);
    }

    bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0 - Left align
    bytes.addAll([0x1B, 0x21, 0x00]); // ESC ! 0x00 - Normal size
    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A, 0x0A]);

    // Receipt Details
    bytes.addAll(_stringToBytes('Receipt #: ${sale.id}'));
    bytes.addAll([0x0A]);
    bytes.addAll(_stringToBytes('Date: ${_formatDate(sale.date)}'));
    bytes.addAll([0x0A]);
    bytes.addAll(_stringToBytes('Time: ${_formatTime(sale.date)}'));
    bytes.addAll([0x0A]);
    bytes.addAll(_stringToBytes('Status: ${sale.status.name.toUpperCase()}'));
    bytes.addAll([0x0A, 0x0A]);

    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A]);

    // Items Header
    bytes.addAll([0x1B, 0x61, 0x01]); // Center align
    bytes.addAll([0x1B, 0x21, 0x10]); // Bold
    bytes.addAll(_stringToBytes('ITEMS'));
    bytes.addAll([0x0A]);
    bytes.addAll([0x1B, 0x61, 0x00]); // Left align
    bytes.addAll([0x1B, 0x21, 0x00]); // Normal
    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A]);

    // Items Table Header
    bytes.addAll(_stringToBytes('Item'));
    bytes.addAll(_stringToBytes('Qty'));
    bytes.addAll(_stringToBytes('Price'));
    bytes.addAll(_stringToBytes('Total'));
    bytes.addAll([0x0A]);
    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A]);

    // Items
    for (final item in sale.items) {
      final itemName = item.product?.name ?? 'Unknown Product';
      final qty = QuantityFormatter.withUnit(item.qty, item.product?.unit);
      final price = '$currency${item.price.toStringAsFixed(2)}';
      final total = '$currency${item.subtotal.toStringAsFixed(2)}';

      // Split long item names
      final itemLines = _splitText(itemName, 20);
      for (int i = 0; i < itemLines.length; i++) {
        if (i == 0) {
          // First line with qty, price, total
          bytes.addAll(_stringToBytes('${itemLines[i]} x$qty $price $total'));
        } else {
          // Additional lines for long item names
          bytes.addAll(_stringToBytes(itemLines[i]));
        }
        bytes.addAll([0x0A]);
      }
    }

    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A]);

    // Totals
    bytes.addAll(
        _stringToBytes('Subtotal: $currency${sale.total.toStringAsFixed(2)}'));
    bytes.addAll([0x0A]);

    if (sale.discount > 0) {
      bytes.addAll(_stringToBytes(
          'Discount: -$currency${sale.discount.toStringAsFixed(2)}'));
      bytes.addAll([0x0A]);
    }

    bytes.addAll(_stringToBytes('================================'));
    bytes.addAll([0x0A]);

    bytes.addAll([0x1B, 0x21, 0x30]); // Double height, double width
    bytes.addAll(
        _stringToBytes('TOTAL: $currency${sale.total.toStringAsFixed(2)}'));
    bytes.addAll([0x0A]);

    bytes.addAll([0x1B, 0x21, 0x00]); // Normal size
    bytes.addAll(
        _stringToBytes('Paid: $currency${sale.paid.toStringAsFixed(2)}'));
    bytes.addAll([0x0A]);

    if (sale.due > 0) {
      bytes.addAll([0x1B, 0x21, 0x08]); // Bold
      bytes.addAll(
          _stringToBytes('Due: $currency${sale.due.toStringAsFixed(2)}'));
      bytes.addAll([0x0A]);
    }

    bytes.addAll([0x0A]);

    // Customer Info
    if (sale.customer != null) {
      bytes.addAll(_stringToBytes('--------------------------------'));
      bytes.addAll([0x0A]);
      bytes.addAll([0x1B, 0x61, 0x01]); // Center align
      bytes.addAll([0x1B, 0x21, 0x10]); // Bold
      bytes.addAll(_stringToBytes('CUSTOMER'));
      bytes.addAll([0x0A]);
      bytes.addAll([0x1B, 0x61, 0x00]); // Left align
      bytes.addAll([0x1B, 0x21, 0x00]); // Normal
      bytes.addAll(_stringToBytes('--------------------------------'));
      bytes.addAll([0x0A]);

      bytes.addAll(_stringToBytes('Name: ${sale.customer!.name}'));
      bytes.addAll([0x0A]);
      if (sale.customer!.phone.isNotEmpty) {
        bytes.addAll(_stringToBytes('Phone: ${sale.customer!.phone}'));
        bytes.addAll([0x0A]);
      }
      if (sale.customer!.address != null &&
          sale.customer!.address!.isNotEmpty) {
        bytes.addAll(_stringToBytes('Address: ${sale.customer!.address}'));
        bytes.addAll([0x0A]);
      }
      bytes.addAll([0x0A]);
    }

    // Footer
    bytes.addAll(_stringToBytes('--------------------------------'));
    bytes.addAll([0x0A]);
    bytes.addAll([0x1B, 0x61, 0x01]); // Center align
    bytes.addAll([0x1B, 0x21, 0x10]); // Bold
    bytes.addAll(_stringToBytes('Thank you for your business!'));
    bytes.addAll([0x0A, 0x0A]);
    bytes.addAll([0x1B, 0x61, 0x00]); // Left align
    bytes.addAll([0x1B, 0x21, 0x00]); // Normal
    bytes.addAll(
        _stringToBytes('Generated on ${_formatDateTime(DateTime.now())}'));
    bytes.addAll([0x0A, 0x0A, 0x0A]);

    // Cut paper
    bytes.addAll([0x1D, 0x56, 0x00]); // GS V 0 - Full cut

    return Uint8List.fromList(bytes);
  }

  /// Get printer IP from network
  static Future<String?> _getPrinterIp() async {
    try {
      final printers = await getAvailablePrinters();
      return printers.isNotEmpty ? printers.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Convert string to bytes
  static List<int> _stringToBytes(String text) {
    return text.codeUnits;
  }

  /// Split text into multiple lines
  static List<String> _splitText(String text, int maxLength) {
    if (text.length <= maxLength) return [text];

    final List<String> lines = [];
    for (int i = 0; i < text.length; i += maxLength) {
      final end = (i + maxLength < text.length) ? i + maxLength : text.length;
      lines.add(text.substring(i, end));
    }
    return lines;
  }

  /// Format date for receipt
  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Format time for receipt (12-hour format with AM/PM)
  static String _formatTime(DateTime date) {
    final hour12 =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  /// Format date and time for receipt
  static String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }
}
