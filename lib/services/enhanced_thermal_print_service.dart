import 'package:flutter/services.dart';
import '../models/sale.dart';
import '../models/receipt_template.dart';
import '../services/database_service.dart';
import 'thermal_print_service.dart';

class EnhancedThermalPrintService {
  static const MethodChannel _channel = MethodChannel('thermal_print');

  /// Automatically print receipt after payment completion
  static Future<bool> autoPrintReceipt(
      SaleModel sale, DatabaseService databaseService) async {
    try {
      // Get receipt template settings
      final template = await _getReceiptTemplate();

      // Generate thermal receipt content
      final receiptContent =
          await _generateThermalReceiptContent(sale, template, databaseService);

      // Print to default thermal printer
      final success = await _printToThermalPrinter(receiptContent);

      if (success) {
        print('✅ Thermal receipt printed successfully for Sale #${sale.id}');
        return true;
      } else {
        print('❌ Failed to print thermal receipt for Sale #${sale.id}');
        return false;
      }
    } catch (e) {
      print('❌ Error in auto print receipt: $e');
      return false;
    }
  }

  /// Get available thermal printers
  static Future<List<ThermalPrinter>> getAvailablePrinters() async {
    try {
      final List<dynamic> printers =
          await _channel.invokeMethod('getAvailablePrinters');
      return printers.map((p) => ThermalPrinter.fromMap(p)).toList();
    } catch (e) {
      print('Error getting printers: $e');
      // Return empty list if method channel fails
      return [];
    }
  }

  /// Print to specific thermal printer
  static Future<bool> printToSpecificPrinter(String printerName, SaleModel sale,
      DatabaseService databaseService) async {
    try {
      final template = await _getReceiptTemplate();
      final receiptContent =
          await _generateThermalReceiptContent(sale, template, databaseService);

      final success = await _channel.invokeMethod('printToPrinter', {
        'printerName': printerName,
        'content': receiptContent,
      });

      return success == true;
    } catch (e) {
      print('Error printing to specific printer: $e');
      // Fallback to basic thermal print service
      return await ThermalPrintService.printReceipt(sale);
    }
  }

  /// Generate thermal receipt content using template
  static Future<String> _generateThermalReceiptContent(SaleModel sale,
      ReceiptTemplate template, DatabaseService databaseService) async {
    final buffer = StringBuffer();
    
    // Fetch currency from database settings
    String currencySymbol = 'Rs.'; // Default fallback
    try {
      final currency = await databaseService.getSetting('currency_symbol');
      if (currency != null && currency.isNotEmpty) {
        currencySymbol = _normalizeCurrencySymbol(currency);
      }
    } catch (e) {
      print('Warning: Could not fetch currency symbol, using default: $e');
    }

    // Add logo if enabled and available
    if (template.showLogo && template.logoUrl != null) {
      buffer.writeln('LOGO:${template.logoUrl}');
    }

    // Business information
    if (template.showBusinessInfo) {
      buffer.writeln('CENTER:${template.businessName}');
      if (template.businessAddress.isNotEmpty) {
        buffer.writeln('CENTER:${template.businessAddress}');
      }
      if (template.businessPhone.isNotEmpty) {
        buffer.writeln('CENTER:${template.businessPhone}');
      }
      if (template.businessEmail.isNotEmpty) {
        buffer.writeln('CENTER:${template.businessEmail}');
      }
      if (template.website != null && template.website!.isNotEmpty) {
        buffer.writeln('CENTER:${template.website}');
      }
      buffer.writeln('SEPARATOR');
    }

    // Receipt header
    buffer.writeln('CENTER:RECEIPT #${sale.id}');
    buffer.writeln('CENTER:${_formatDateTime(sale.date)}');
    buffer.writeln('SEPARATOR');

    // Customer information
    if (template.showCustomerInfo && sale.customer != null) {
      buffer.writeln('LEFT:Customer: ${sale.customer?.name ?? 'N/A'}');
      if (sale.customer?.phone.isNotEmpty == true) {
        buffer.writeln('LEFT:Phone: ${sale.customer!.phone}');
      }
      buffer.writeln('SEPARATOR');
    }

    // Items
    if (template.showItemDetails) {
      buffer.writeln('LEFT:Item Name          Qty    Price    Total');
      buffer.writeln('LEFT:----------------------------------------');

      for (final item in sale.items) {
        final productName = item.product?.name ?? 'Unknown Product';
        final itemName = productName.length > 15
            ? '${productName.substring(0, 15)}...'
            : productName;
        buffer.writeln(
            'LEFT:$itemName          ${item.qty}    ${_formatCurrency(item.price, currencySymbol: currencySymbol)}    ${_formatCurrency(item.subtotal, currencySymbol: currencySymbol)}');
      }
      buffer.writeln('SEPARATOR');
    }

    // Totals
    buffer.writeln(
        'LEFT:Subtotal: ${_formatCurrency(sale.total - (sale.total * 0.08), currencySymbol: currencySymbol)}');
    if (template.showTaxBreakdown) {
      buffer.writeln('LEFT:Tax (8%): ${_formatCurrency(sale.total * 0.08, currencySymbol: currencySymbol)}');
    }
    buffer.writeln('BOLD:Total: ${_formatCurrency(sale.total, currencySymbol: currencySymbol)}');
    buffer.writeln('SEPARATOR');

    // Payment information
    if (template.showPaymentInfo) {
      buffer.writeln(
          'LEFT:Payment Method: ${sale.paymentType.name.toUpperCase()}');
      buffer.writeln('LEFT:Paid: ${_formatCurrency(sale.paid, currencySymbol: currencySymbol)}');
      if (sale.due > 0) {
        buffer.writeln('LEFT:Due: ${_formatCurrency(sale.due, currencySymbol: currencySymbol)}');
      }
      buffer.writeln('SEPARATOR');
    }

    // Custom fields
    if (template.customField1Label != null &&
        template.customField1Value != null) {
      buffer.writeln(
          'LEFT:${template.customField1Label}: ${template.customField1Value}');
    }
    if (template.customField2Label != null &&
        template.customField2Value != null) {
      buffer.writeln(
          'LEFT:${template.customField2Label}: ${template.customField2Value}');
    }
    if (template.customField3Label != null &&
        template.customField3Value != null) {
      buffer.writeln(
          'LEFT:${template.customField3Label}: ${template.customField3Value}');
    }

    // Footer
    if (template.showFooter && template.footerText != null) {
      buffer.writeln('SEPARATOR');
      buffer.writeln('CENTER:${template.footerText}');
    }

    // QR Code for receipt verification
    if (template.showQRCode) {
      buffer.writeln('SEPARATOR');
      buffer.writeln(
          'QRCODE:Receipt #${sale.id} - ${_formatDateTime(sale.date)}');
    }

    // Legal information
    if (template.taxId != null && template.taxId!.isNotEmpty) {
      buffer.writeln('CENTER:Tax ID: ${template.taxId}');
    }
    if (template.licenseNumber != null && template.licenseNumber!.isNotEmpty) {
      buffer.writeln('CENTER:License: ${template.licenseNumber}');
    }

    buffer.writeln('SEPARATOR');
    buffer.writeln('CENTER:Thank you for your business!');
    buffer.writeln('CENTER:${DateTime.now().year}');

    return buffer.toString();
  }

  /// Print to thermal printer
  static Future<bool> _printToThermalPrinter(String content) async {
    try {
      final result = await _channel.invokeMethod('printReceipt', {
        'content': content,
        'printerName': 'default', // Use default printer
      });
      return result == true;
    } catch (e) {
      print('Error printing to thermal printer: $e');
      // Method channel not implemented, return false
      // In a real implementation, you would add native code
      return false;
    }
  }

  /// Get receipt template
  static Future<ReceiptTemplate> _getReceiptTemplate() async {
    // This would typically come from the provider
    // For now, return a default template
    return ReceiptTemplate.getDefault();
  }

  /// Format currency - Note: This should receive currency from provider when called
  static String _formatCurrency(double amount, {String currencySymbol = 'Rs.'}) {
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }
  
  /// Normalize currency symbol to ASCII for thermal printers
  static String _normalizeCurrencySymbol(String currency) {
    final trimmed = currency.trim();
    if (trimmed.isEmpty) return 'Rs.';
    
    // Map Unicode symbols to ASCII equivalents
    if (trimmed == '₨' || trimmed == '₹') return 'Rs.';
    if (trimmed == '¥') return 'Yen';
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
    
    return trimmed;
  }

  /// Format date time (12-hour format with AM/PM)
  static String _formatDateTime(DateTime dateTime) {
    final hour12 = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${hour12.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $amPm';
  }
}

class ThermalPrinter {
  final String name;
  final String address;
  final bool isConnected;
  final String type;

  ThermalPrinter({
    required this.name,
    required this.address,
    required this.isConnected,
    required this.type,
  });

  factory ThermalPrinter.fromMap(Map<String, dynamic> map) {
    return ThermalPrinter(
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      isConnected: map['isConnected'] ?? false,
      type: map['type'] ?? 'thermal',
    );
  }
}
