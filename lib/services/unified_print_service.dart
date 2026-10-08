import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../services/database_service.dart';
import '../services/windows_printer_detection_service.dart';
import '../services/enhanced_thermal_print_service_v2.dart';
import '../services/print_settings_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../utils/quantity_formatter.dart';

// Re-export PrinterConnectionStatus from enhanced_thermal_print_service_v2 for convenience
export '../services/enhanced_thermal_print_service_v2.dart'
    show PrinterConnectionStatus;

/// Internal class to hold business settings
class _BusinessSettings {
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String currency;

  _BusinessSettings({
    required this.businessName,
    required this.businessAddress,
    required this.businessPhone,
    required this.currency,
  });
}

// Print Settings Model
class PrintSettings {
  final PrinterType printerType;
  final String? printerName;
  final String? printerIp;
  final int printerPort;
  final PaperSize paperSize;
  final PrintOrientation orientation;
  final bool showLogo;
  final bool showBusinessInfo;
  final bool showCustomerInfo;
  final bool showItemDetails;
  final bool showTaxBreakdown;
  final bool showPaymentInfo;
  final bool showFooter;
  final bool showQRCode;
  final String? footerText;
  final int fontSize;
  final String fontFamily;
  final int copies;
  final bool autoCut;
  final bool openCashDrawer;
  final ReceiptStyle receiptStyle;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  PrintSettings({
    this.printerType = PrinterType.auto,
    this.printerName,
    this.printerIp,
    this.printerPort = 9100,
    this.paperSize = PaperSize.auto,
    this.orientation = PrintOrientation.portrait,
    this.showLogo = true,
    this.showBusinessInfo = true,
    this.showCustomerInfo = true,
    this.showItemDetails = true,
    this.showTaxBreakdown = true,
    this.showPaymentInfo = true,
    this.showFooter = true,
    this.showQRCode = false,
    this.footerText,
    this.fontSize = 12,
    this.fontFamily = 'Roboto',
    this.copies = 1,
    this.autoCut = true,
    this.openCashDrawer = false,
    this.receiptStyle = ReceiptStyle.modern,
    this.marginTop = 10.0,
    this.marginBottom = 10.0,
    this.marginLeft = 10.0,
    this.marginRight =
        15.0, // Increased right margin for better receipt spacing
  });

  PrintSettings copyWith({
    PrinterType? printerType,
    String? printerName,
    String? printerIp,
    int? printerPort,
    PaperSize? paperSize,
    PrintOrientation? orientation,
    bool? showLogo,
    bool? showBusinessInfo,
    bool? showCustomerInfo,
    bool? showItemDetails,
    bool? showTaxBreakdown,
    bool? showPaymentInfo,
    bool? showFooter,
    bool? showQRCode,
    String? footerText,
    int? fontSize,
    String? fontFamily,
    int? copies,
    bool? autoCut,
    bool? openCashDrawer,
    ReceiptStyle? receiptStyle,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
  }) {
    return PrintSettings(
      printerType: printerType ?? this.printerType,
      printerName: printerName ?? this.printerName,
      printerIp: printerIp ?? this.printerIp,
      printerPort: printerPort ?? this.printerPort,
      paperSize: paperSize ?? this.paperSize,
      orientation: orientation ?? this.orientation,
      showLogo: showLogo ?? this.showLogo,
      showBusinessInfo: showBusinessInfo ?? this.showBusinessInfo,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showItemDetails: showItemDetails ?? this.showItemDetails,
      showTaxBreakdown: showTaxBreakdown ?? this.showTaxBreakdown,
      showPaymentInfo: showPaymentInfo ?? this.showPaymentInfo,
      showFooter: showFooter ?? this.showFooter,
      showQRCode: showQRCode ?? this.showQRCode,
      footerText: footerText ?? this.footerText,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      copies: copies ?? this.copies,
      autoCut: autoCut ?? this.autoCut,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
      receiptStyle: receiptStyle ?? this.receiptStyle,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
    );
  }

  static PrintSettings getDefault() {
    return PrintSettings();
  }
}

enum PrinterType {
  auto,
  thermal,
  a4,
  networkThermal,
  bluetooth,
}

enum PaperSize {
  auto,
  thermal58mm,
  thermal80mm,
  a4,
  letter,
}

enum PrintOrientation {
  portrait,
  landscape,
}

enum ReceiptStyle {
  modern,
  classic,
  minimal,
  detailed,
}

class PrintTestResult {
  final bool success;
  final String message;

  const PrintTestResult(this.success, this.message);
}

/// Printer error types for better error handling
enum PrinterErrorType {
  offline,
  noPaper,
  paperJam,
  coverOpen,
  disconnected,
  notConfigured,
  timeout,
  unknown,
}

/// Printer status information
class PrinterStatus {
  final bool isReady;
  final PrinterErrorType? errorType;
  final String message;

  const PrinterStatus({
    required this.isReady,
    this.errorType,
    required this.message,
  });

  static const ready =
      PrinterStatus(isReady: true, message: 'Printer is ready');
}

class UnifiedPrintService {
  static String _pdfSafeCurrency(String currency) {
    // Built-in PDF Helvetica font does not support some Unicode symbols.
    // Use ASCII-safe fallback when generating PDF.
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

  static String _thermalSafeCurrency(String currency) {
    final trimmed = currency.trim();
    if (trimmed.isEmpty) return 'Rs.';
    // Many thermal printers fail on Unicode currency symbols.
    // Convert problematic Unicode symbols to ASCII equivalents
    if (trimmed == '₨' || trimmed == '₹') return 'Rs.';
    if (trimmed == '¥') return 'Yen'; // Chinese/Japanese Yen
    if (trimmed == '€') return 'EUR'; // Euro
    if (trimmed == '£') return 'GBP'; // British Pound
    if (trimmed == '₽') return 'RUB'; // Russian Ruble
    if (trimmed == '₺') return 'TRY'; // Turkish Lira
    if (trimmed == '₦') return 'NGN'; // Nigerian Naira
    if (trimmed == '₵') return 'GHS'; // Ghanaian Cedi
    if (trimmed == '₱') return 'PHP'; // Philippine Peso
    if (trimmed == '₫') return 'VND'; // Vietnamese Dong
    if (trimmed == '฿') return 'THB'; // Thai Baht
    if (trimmed == '₩') return 'KRW'; // Korean Won
    if (trimmed == '₪') return 'ILS'; // Israeli Shekel
    // If it's a simple ASCII symbol or code, use as-is
    if (trimmed.length <= 4 && trimmed.codeUnits.every((c) => c < 128)) {
      return trimmed;
    }
    // For any other Unicode symbols, use the currency code or fallback
    return trimmed.length <= 3 ? trimmed : 'Rs.';
  }

  /// Build simple text receipt for Windows printing
  /// Build simple text receipt for Windows printing
  static Future<String> _buildTextReceipt(
    SaleModel sale,
    String? customBusinessName,
    PrintSettings settings,
    DatabaseService? dbService,
  ) async {
    const int width =
        42; // Windows Out-Printer safe width (avoids right-side cutoff)
    final buffer = StringBuffer();
    final businessName = (customBusinessName?.trim().isNotEmpty ?? false)
        ? customBusinessName!.trim()
        : 'SALES RECEIPT';

    // Get actual currency from database settings
    String safeCurrency = 'Rs.';
    if (dbService != null) {
      final currencySymbol = await dbService.getSetting('currency_symbol');
      if (currencySymbol != null && currencySymbol.isNotEmpty) {
        safeCurrency = _thermalSafeCurrency(currencySymbol);
      }
    }
    // Strip any remaining non-ASCII bytes that Windows Out-Printer / CP850 cannot render
    safeCurrency = safeCurrency.replaceAll(RegExp(r'[^\x00-\x7F]'), 'Rs.');

    final date = sale.date;
    final dateStr = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    // Truncate + pad a string to exactly [len] characters
    String fit(String value, int len) {
      final cleaned = value.replaceAll('\n', ' ').trim();
      if (cleaned.length >= len) return cleaned.substring(0, len);
      return cleaned.padRight(len);
    }

    // Right-align an amount label+value pair across the full width
    String amtLine(String label, String amount) {
      final gap = width - label.length - amount.length;
      return '$label${' ' * (gap < 1 ? 1 : gap)}$amount';
    }

    // ── Header ──────────────────────────────────────────────────────────────
    buffer.writeln('*' * width);
    buffer.writeln('=' * width);
    buffer.writeln('*' * width);
    buffer.writeln('');
    // Centre the business name
    final bnPadded = businessName.toUpperCase().length >= width
        ? businessName.toUpperCase()
        : businessName
            .toUpperCase()
            .padLeft(((width + businessName.length) / 2).round());
    buffer.writeln(bnPadded);
    buffer.writeln('');
    buffer.writeln('*' * width);
    buffer.writeln('=' * width);
    buffer.writeln('*' * width);
    buffer.writeln('');

    // ── Receipt meta ────────────────────────────────────────────────────────
    buffer.writeln('SALES RECEIPT');
    buffer.writeln('');
    buffer.writeln('Receipt # : ${sale.id ?? "N/A"}');
    buffer.writeln('Date      : $dateStr');
    if (sale.customer != null) {
      buffer.writeln('Customer  : ${sale.customer!.name}');
    }
    if (sale.cashier != null) {
      buffer.writeln('Cashier   : ${sale.cashier!.name}');
    }
    buffer.writeln('');

    // ── Items table ─────────────────────────────────────────────────────────
    // Columns: name(14) + qty(5) + price(11) + total(12) = 42
    buffer.writeln('=' * width);
    buffer.writeln('Item           Qty    Price      Total');
    buffer.writeln('-' * width);

    double itemsTotal = 0.0;
    for (final item in sale.items) {
      final productName = item.product?.name ?? 'Product #${item.productId}';
      final nameCol = fit(productName, 14);
      final qtyCol = QuantityFormatter.number(
        item.qty,
        unit: item.product?.unit,
      ).padLeft(5);
      final priceCol =
          '$safeCurrency${item.price.toStringAsFixed(2)}'.padLeft(11);
      final totalCol =
          '$safeCurrency${item.subtotal.toStringAsFixed(2)}'.padLeft(12);
      buffer.writeln('$nameCol$qtyCol$priceCol$totalCol');

      // Optional mobile/IMEI sub-line
      final product = item.product;
      if (product != null &&
          (product.brand != null ||
              product.modelName != null ||
              item.imei != null)) {
        final details = <String>[];
        if (product.brand != null && product.modelName != null) {
          details.add('${product.brand} ${product.modelName}');
        }
        if (product.storageCapacity != null)
          details.add(product.storageCapacity!);
        if (product.ram != null) details.add('${product.ram} RAM');
        if (product.color != null) details.add(product.color!);
        if (item.imei != null && item.imei!.isNotEmpty) {
          details.add('IMEI: ${item.imei}');
        }
        if (product.condition != null) {
          details.add('Cond: ${product.condition!.toUpperCase()}');
        }
        if (details.isNotEmpty) {
          // Indent sub-line, truncate to width
          final subLine = '  ${details.join(' | ')}';
          buffer.writeln(
              subLine.length > width ? subLine.substring(0, width) : subLine);
        }
      }

      itemsTotal += item.subtotal;
    }

    buffer.writeln('-' * width);
    buffer.writeln('');

    // ── Totals ───────────────────────────────────────────────────────────────
    buffer.writeln(
        amtLine('Subtotal :', '$safeCurrency${itemsTotal.toStringAsFixed(2)}'));
    if (sale.discount > 0) {
      buffer.writeln(amtLine(
          'Discount :', '-$safeCurrency${sale.discount.toStringAsFixed(2)}'));
    }
    if (sale.paid > 0) {
      buffer.writeln(amtLine(
          'Paid     :', '$safeCurrency${sale.paid.toStringAsFixed(2)}'));
    }
    if (sale.due > 0) {
      buffer.writeln(
          amtLine('Due      :', '$safeCurrency${sale.due.toStringAsFixed(2)}'));
    }
    buffer.writeln('=' * width);
    buffer.writeln(
        amtLine('TOTAL    :', '$safeCurrency${sale.total.toStringAsFixed(2)}'));
    buffer.writeln('=' * width);
    buffer.writeln('');

    // ── Payment / Status ─────────────────────────────────────────────────────
    buffer.writeln(
        'Payment  : ${sale.paymentType.toString().split('.').last.toUpperCase()}');
    buffer.writeln(
        'Status   : ${sale.status.toString().split('.').last.toUpperCase()}');
    buffer.writeln('');

    // ── Footer ───────────────────────────────────────────────────────────────
    buffer.writeln('*' * width);
    buffer.writeln('  Thank you for your business!');
    buffer.writeln('       Please visit again');
    buffer.writeln('');
    buffer.writeln('     Powered by Offline POS');
    buffer.writeln('*' * width);

    return buffer.toString();
  }

  /// Get business settings from database service
  static Future<_BusinessSettings> _getBusinessSettings(
    DatabaseService? dbService,
  ) async {
    String businessName = 'My Business';
    String businessAddress = '';
    String businessPhone = '';
    String currency = 'PKR'; // Default to PKR instead of $

    if (dbService != null) {
      businessName =
          await dbService.getSetting('business_name') ?? businessName;
      businessAddress =
          await dbService.getSetting('business_address') ?? businessAddress;
      businessPhone =
          await dbService.getSetting('business_phone') ?? businessPhone;
      currency = await dbService.getSetting('currency_symbol') ?? currency;
    }

    return _BusinessSettings(
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      currency: currency,
    );
  }

  /// Get logo path from settings
  static String? _getLogoPath(DatabaseService? dbService) {
    // Logo path would be stored in settings
    // For now, return null (logo support is ready but needs logo upload feature)
    // TODO: Implement logo storage and retrieval
    return null;
  }

  /// Resolve print settings from multiple sources with priority:
  /// explicit settings > saved print settings > database printer settings.
  static Future<PrintSettings> _resolvePrintSettings(
    PrintSettings? settings,
    DatabaseService? databaseService,
  ) async {
    PrintSettings resolved;
    if (settings != null) {
      resolved = settings;
    } else {
      try {
        resolved = await PrintSettingsService.getDefaultSettings();
      } catch (_) {
        resolved = PrintSettings.getDefault();
      }
    }

    // Backfill printer network config from DB if missing in print profile.
    if (databaseService != null) {
      final dbReceiptType = (await databaseService.getSetting('receipt_type'))
          ?.trim()
          .toLowerCase();
      final hasIp = (resolved.printerIp ?? '').trim().isNotEmpty;
      if (!hasIp) {
        final dbIp = (await databaseService.getSetting('printer_ip'))?.trim();
        final dbPortRaw =
            (await databaseService.getSetting('printer_port'))?.trim();
        final dbPort = int.tryParse(dbPortRaw ?? '');

        if (dbIp != null && dbIp.isNotEmpty) {
          resolved = resolved.copyWith(
            printerIp: dbIp,
            printerPort: dbPort ?? resolved.printerPort,
            printerType: resolved.printerType == PrinterType.a4
                ? PrinterType.networkThermal
                : resolved.printerType,
          );
        }
      }

      // Enforce thermal profile when receipt type is configured as thermal.
      final effectiveHasIp = (resolved.printerIp ?? '').trim().isNotEmpty;
      if (dbReceiptType == 'thermal' &&
          effectiveHasIp &&
          resolved.printerType != PrinterType.bluetooth) {
        resolved = resolved.copyWith(
          printerType: PrinterType.networkThermal,
          paperSize: resolved.paperSize == PaperSize.thermal58mm
              ? PaperSize.thermal58mm
              : PaperSize.thermal80mm,
          orientation: PrintOrientation.portrait,
        );
      } else if (dbReceiptType == 'a4') {
        resolved = resolved.copyWith(
          printerType: PrinterType.a4,
          paperSize: PaperSize.a4,
        );
      } else if (effectiveHasIp && resolved.printerType == PrinterType.auto) {
        // Strong default for production: if printer IP exists, prefer network thermal.
        resolved = resolved.copyWith(
          printerType: PrinterType.networkThermal,
          paperSize: resolved.paperSize == PaperSize.thermal58mm
              ? PaperSize.thermal58mm
              : PaperSize.thermal80mm,
          orientation: PrintOrientation.portrait,
        );
      }
    }

    return resolved;
  }

  /// Print receipt with unified service supporting thermal and A4
  static Future<bool> printReceipt(
    SaleModel sale, {
    PrintSettings? settings,
    DatabaseService? databaseService,
  }) async {
    final printSettings =
        await _resolvePrintSettings(settings, databaseService);
    final dbService = databaseService;
    final hasNetworkThermalConfig =
        (printSettings.printerIp ?? '').trim().isNotEmpty &&
            (printSettings.printerType == PrinterType.networkThermal ||
                printSettings.printerType == PrinterType.thermal ||
                printSettings.printerType == PrinterType.auto ||
                printSettings.paperSize == PaperSize.thermal58mm ||
                printSettings.paperSize == PaperSize.thermal80mm);

    try {
      // Validate printer configuration
      if (printSettings.printerType == PrinterType.thermal &&
          (printSettings.printerName == null ||
              printSettings.printerName!.isEmpty)) {
        throw Exception(
            'Printer not configured. Please select a printer in settings.');
      }

      if (printSettings.printerType == PrinterType.networkThermal &&
          (printSettings.printerIp == null ||
              printSettings.printerIp!.isEmpty)) {
        throw Exception(
            'Printer IP not configured. Please set printer IP in settings.');
      }

      // Determine printer type
      PrinterType printerType = printSettings.printerType;
      if (printerType == PrinterType.auto) {
        printerType = await _detectPrinterType(printSettings);
      }

      // Print based on type
      switch (printerType) {
        case PrinterType.thermal:
          // For Windows, try direct Windows printer first, then fallback to network
          if (Platform.isWindows && printSettings.printerName != null) {
            try {
              return await _printToWindowsPrinter(sale,
                  settingsOverride: printSettings, dbService: dbService);
            } catch (e) {
              // Fallback to network thermal
              return await _printThermal(sale, printSettings, dbService);
            }
          } else {
            return await _printThermal(sale, printSettings, dbService);
          }
        case PrinterType.networkThermal:
          try {
            return await _printThermal(sale, printSettings, dbService);
          } catch (networkError) {
            debugPrint('Network thermal print failed: $networkError');
            // On Windows, gracefully fallback to configured Windows printer.
            if (Platform.isWindows &&
                printSettings.printerName != null &&
                printSettings.printerName!.trim().isNotEmpty) {
              try {
                return await _printToWindowsPrinter(
                  sale,
                  printerName: printSettings.printerName,
                  settingsOverride: printSettings,
                  dbService: dbService,
                );
              } catch (windowsError) {
                debugPrint('Windows fallback print failed: $windowsError');
              }
            }
            rethrow;
          }
        case PrinterType.bluetooth:
          return await _printBluetooth(sale, printSettings, dbService);
        case PrinterType.a4:
          return await _printA4(sale, printSettings, dbService);
        case PrinterType.auto:
          // Auto-detect: Try Bluetooth first on mobile, then thermal on Windows, then A4
          if (Platform.isAndroid || Platform.isIOS) {
            // On mobile, try Bluetooth first
            if (await BluetoothPrinterService.isBluetoothAvailable()) {
              final isConnected =
                  await BluetoothPrinterService.verifyConnection();
              if (isConnected) {
                try {
                  return await _printBluetooth(sale, printSettings, dbService);
                } catch (e) {
                  debugPrint('Bluetooth printing failed: $e');
                  // Continue to network thermal or A4 fallback
                }
              } else {
                debugPrint(
                    'No Bluetooth printer connected, checking for network thermal...');
              }
            }

            // On mobile, also check for network thermal if IP is configured
            if (printSettings.printerIp != null &&
                printSettings.printerIp!.isNotEmpty) {
              try {
                return await _printThermal(sale, printSettings, dbService);
              } catch (e) {
                debugPrint('Network thermal printing on mobile failed: $e');
              }
            }
          } else if (Platform.isWindows) {
            // On Windows, prefer network thermal first when IP is configured.
            if (printSettings.printerIp != null &&
                printSettings.printerIp!.isNotEmpty) {
              try {
                return await _printThermal(sale, printSettings, dbService);
              } catch (e) {
                debugPrint('Network thermal print failed in auto mode: $e');
              }
            }

            // Then try detected Windows thermal printer
            final windowsPrinters =
                await WindowsPrinterDetectionService.detectThermalPrinters();
            if (windowsPrinters.isNotEmpty &&
                printSettings.printerName == null) {
              final newSettings = printSettings.copyWith(
                printerName: windowsPrinters.first.name,
                printerType: PrinterType.thermal,
              );
              return await _printToWindowsPrinter(sale,
                  settingsOverride: newSettings, dbService: dbService);
            }
          } else {
            // macOS/Linux desktop: prefer network thermal if printer IP is configured.
            if (printSettings.printerIp != null &&
                printSettings.printerIp!.isNotEmpty) {
              try {
                return await _printThermal(sale, printSettings, dbService);
              } catch (e) {
                debugPrint(
                    'Desktop network thermal print failed in auto mode: $e');
              }
            }
          }
          // For configured thermal setups, never silently fallback to A4/PDF.
          if (hasNetworkThermalConfig) {
            debugPrint(
                'Thermal printer configured; skipping A4 fallback in auto mode.');
            return false;
          }
          // Fallback to A4 only when no thermal config exists.
          return await _printA4(sale, printSettings, dbService);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Print error: $e');
      debugPrint('Stack trace: $stackTrace');

      // Provide user-friendly error messages
      String userMessage = 'Print failed: ';

      if (e.toString().contains('Printer IP not configured') ||
          e.toString().contains('not configured')) {
        userMessage += 'Printer is not configured. Please check settings.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('timed out')) {
        userMessage += 'Printer timeout. Check connection and try again.';
      } else if (e.toString().contains('offline') ||
          e.toString().contains('not reachable')) {
        userMessage += 'Printer is offline. Check power and connection.';
      } else if (e.toString().contains('refused') ||
          e.toString().contains('connection')) {
        userMessage += 'Connection refused. Check printer network settings.';
      } else {
        userMessage += e.toString();
      }

      throw Exception(userMessage);
    }
  }

  /// Generate PDF for preview or printing
  static Future<Uint8List> generateReceiptPdf(
    SaleModel sale, {
    PrintSettings? settings,
    DatabaseService? databaseService,
    String? customBusinessName,
    String? customBusinessAddress,
    String? customBusinessPhone,
  }) async {
    final printSettings = settings ?? PrintSettings.getDefault();

    // Get business settings
    final businessSettings = await _getBusinessSettings(databaseService);

    // Use custom values if provided (for test pages), otherwise use database settings
    final finalBusinessName =
        customBusinessName ?? businessSettings.businessName;
    final finalBusinessAddress =
        customBusinessAddress ?? businessSettings.businessAddress;
    final finalBusinessPhone =
        customBusinessPhone ?? businessSettings.businessPhone;

    // Determine page format
    PdfPageFormat pageFormat;
    if (printSettings.paperSize == PaperSize.a4) {
      pageFormat = PdfPageFormat.a4;
    } else if (printSettings.paperSize == PaperSize.letter) {
      pageFormat = PdfPageFormat.letter;
    } else if (printSettings.paperSize == PaperSize.thermal80mm) {
      pageFormat = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity);
    } else {
      // Default thermal 58mm
      pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity);
    }

    // Adjust margins
    pageFormat = pageFormat.copyWith(
      marginTop: printSettings.marginTop,
      marginBottom: printSettings.marginBottom,
      marginLeft: printSettings.marginLeft,
      marginRight: printSettings.marginRight,
    );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        orientation: printSettings.orientation == PrintOrientation.landscape
            ? pw.PageOrientation.landscape
            : pw.PageOrientation.portrait,
        build: (pw.Context context) {
          return _buildReceiptContent(
            sale,
            finalBusinessName,
            finalBusinessAddress,
            finalBusinessPhone,
            _pdfSafeCurrency(businessSettings.currency),
            printSettings,
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build receipt content based on style
  static pw.Widget _buildReceiptContent(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    PrintSettings settings,
  ) {
    switch (settings.receiptStyle) {
      case ReceiptStyle.modern:
        return _buildModernReceipt(sale, businessName, businessAddress,
            businessPhone, currency, settings);
      case ReceiptStyle.classic:
        return _buildClassicReceipt(sale, businessName, businessAddress,
            businessPhone, currency, settings);
      case ReceiptStyle.minimal:
        return _buildMinimalReceipt(sale, businessName, businessAddress,
            businessPhone, currency, settings);
      case ReceiptStyle.detailed:
        return _buildDetailedReceipt(sale, businessName, businessAddress,
            businessPhone, currency, settings);
    }
  }

  /// Modern receipt style with beautiful design
  static pw.Widget _buildModernReceipt(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    PrintSettings settings,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header with gradient effect simulation
        if (settings.showBusinessInfo) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: (settings.fontSize + 6).toDouble(),
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (businessAddress.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    businessAddress,
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 2).toDouble()),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
                if (businessPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    businessPhone,
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 2).toDouble()),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],

        // Receipt details
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt #:',
                      style: pw.TextStyle(
                          fontSize: (settings.fontSize - 1).toDouble())),
                  pw.Text(
                    sale.id.toString(),
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 1).toDouble(),
                        fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date:',
                      style: pw.TextStyle(
                          fontSize: (settings.fontSize - 1).toDouble())),
                  pw.Text(
                    _formatDate(sale.date),
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 1).toDouble()),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Time:',
                      style: pw.TextStyle(
                          fontSize: (settings.fontSize - 1).toDouble())),
                  pw.Text(
                    _formatTime(sale.date),
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 1).toDouble()),
                  ),
                ],
              ),
              // Restaurant specific fields
              if (sale.tableNumber != null || sale.orderType != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (sale.tableNumber != null)
                      pw.Text('Table: ${sale.tableNumber}',
                          style: pw.TextStyle(
                              fontSize: (settings.fontSize - 1).toDouble())),
                    if (sale.orderType != null)
                      pw.Text(
                          'Order: ${sale.orderType!.replaceAll('_', ' ').toUpperCase()}',
                          style: pw.TextStyle(
                              fontSize: (settings.fontSize - 1).toDouble())),
                  ],
                ),
              ],
              if (sale.numberOfGuests != null) ...[
                pw.SizedBox(height: 4),
                pw.Text('Guests: ${sale.numberOfGuests}',
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 1).toDouble())),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Items table
        if (settings.showItemDetails) ...[
          pw.Table(
            border: pw.TableBorder(
              verticalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              horizontalInside:
                  pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              top: pw.BorderSide(color: PdfColors.grey400, width: 1),
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
              left: pw.BorderSide(color: PdfColors.grey400, width: 1),
              right: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('Item', settings, isHeader: true),
                  _buildTableCell('Qty', settings, isHeader: true),
                  _buildTableCell('Price', settings, isHeader: true),
                  _buildTableCell('Total', settings, isHeader: true),
                ],
              ),
              // Items
              ...sale.items.expand((item) {
                final product = item.product;
                final productName = product?.name ?? 'Unknown Product';
                final displayName = product?.isActive == false
                    ? '$productName (Deleted Item)'
                    : productName;
                final rows = <pw.TableRow>[
                  pw.TableRow(
                    children: [
                      _buildTableCell(displayName, settings),
                      _buildTableCell(
                          QuantityFormatter.withUnit(item.qty, product?.unit),
                          settings),
                      _buildTableCell(
                          '$currency${item.price.toStringAsFixed(2)}',
                          settings),
                      _buildTableCell(
                          '$currency${item.subtotal.toStringAsFixed(2)}',
                          settings),
                    ],
                  ),
                ];

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
                  if (mobileInfo.isNotEmpty ||
                      item.imei != null ||
                      product.condition != null) {
                    final details = <String>[];
                    if (mobileInfo.isNotEmpty) {
                      details.add(mobileInfo.join(' • '));
                    }
                    if (item.imei != null && item.imei!.isNotEmpty) {
                      details.add('IMEI: ${item.imei}');
                    }
                    if (product.condition != null) {
                      details.add(
                          'Condition: ${product.condition!.toUpperCase()}');
                    }
                    if (product.warrantyPeriod != null) {
                      details.add('Warranty: ${product.warrantyPeriod}');
                    }
                    final warrantyExpiry =
                        _getWarrantyExpiryLabel(product, sale.date);
                    if (warrantyExpiry != null) {
                      details.add('Warranty Ends: $warrantyExpiry');
                    }
                    if (product.tradeInValue != null) {
                      details.add(
                          'Trade-in Value: $currency${product.tradeInValue!.toStringAsFixed(2)}');
                    }
                    if (details.isNotEmpty) {
                      rows.add(
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(
                                  left: 12, top: 2, bottom: 2),
                              child: pw.Text(
                                details.join(' | '),
                                style: pw.TextStyle(
                                  fontSize: (settings.fontSize - 2).toDouble(),
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ),
                            _buildTableCell('', settings),
                            _buildTableCell('', settings),
                            _buildTableCell('', settings),
                          ],
                        ),
                      );
                    }
                  }
                }
                return rows;
              }),
            ],
          ),
          pw.SizedBox(height: 12),
        ],

        // Totals
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
          ),
          child: pw.Column(
            children: [
              _buildTotalRow(
                  'Subtotal',
                  sale.total - (sale.serviceCharge ?? 0) - (sale.tip ?? 0),
                  currency,
                  settings),
              if (sale.discount > 0)
                _buildTotalRow('Discount', -sale.discount, currency, settings),
              // Restaurant charges
              if (sale.serviceCharge != null && sale.serviceCharge! > 0)
                _buildTotalRow(
                    'Service Charge', sale.serviceCharge!, currency, settings),
              if (sale.tip != null && sale.tip! > 0)
                _buildTotalRow('Tip', sale.tip!, currency, settings),
              pw.Divider(color: PdfColors.grey400),
              _buildTotalRow('TOTAL', sale.total, currency, settings,
                  isTotal: true),
              pw.SizedBox(height: 4),
              _buildTotalRow('Paid', sale.paid, currency, settings),
              if (sale.due > 0)
                _buildTotalRow('Due', sale.due, currency, settings,
                    isBold: true),
            ],
          ),
        ),
        pw.SizedBox(height: 12),

        // Customer info
        if (settings.showCustomerInfo && sale.customer != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Customer Information',
                  style: pw.TextStyle(
                    fontSize: settings.fontSize.toDouble(),
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Name: ${sale.customer!.name}',
                    style: pw.TextStyle(
                        fontSize: (settings.fontSize - 1).toDouble())),
                if (sale.customer!.phone.isNotEmpty)
                  pw.Text('Phone: ${sale.customer!.phone}',
                      style: pw.TextStyle(
                          fontSize: (settings.fontSize - 1).toDouble())),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],

        // Footer
        if (settings.showFooter) ...[
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text(
            settings.footerText ?? 'Thank you for your business!',
            style: pw.TextStyle(
              fontSize: settings.fontSize.toDouble(),
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_formatDateTime(DateTime.now())}',
            style: pw.TextStyle(fontSize: (settings.fontSize - 2).toDouble()),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Classic receipt style
  static pw.Widget _buildClassicReceipt(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    PrintSettings settings,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (settings.showBusinessInfo) ...[
          pw.Text(
            businessName,
            style: pw.TextStyle(
                fontSize: (settings.fontSize + 4).toDouble(),
                fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          if (businessAddress.isNotEmpty)
            pw.Text(businessAddress, textAlign: pw.TextAlign.center),
          if (businessPhone.isNotEmpty)
            pw.Text(businessPhone, textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
        pw.Text('Receipt #${sale.id}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('Date: ${_formatDate(sale.date)}'),
        pw.Text('Time: ${_formatTime(sale.date)}'),
        pw.SizedBox(height: 8),
        pw.Divider(),
        if (settings.showItemDetails) ...[
          ...sale.items.expand((item) {
            final product = item.product;
            final productName = product?.name ?? 'Unknown';
            final displayName = product?.isActive == false
                ? '$productName (Deleted Item)'
                : productName;
            final rows = <pw.Widget>[
              pw.Text(
                '$displayName x ${QuantityFormatter.withUnit(item.qty, product?.unit)} = $currency${item.subtotal.toStringAsFixed(2)}',
              ),
            ];

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
              if (mobileInfo.isNotEmpty ||
                  item.imei != null ||
                  product.condition != null) {
                final details = <String>[];
                if (mobileInfo.isNotEmpty) {
                  details.add(mobileInfo.join(' • '));
                }
                if (item.imei != null && item.imei!.isNotEmpty) {
                  details.add('IMEI: ${item.imei}');
                }
                if (product.condition != null) {
                  details.add('Condition: ${product.condition!.toUpperCase()}');
                }
                if (product.warrantyPeriod != null) {
                  details.add('Warranty: ${product.warrantyPeriod}');
                }
                final warrantyExpiry =
                    _getWarrantyExpiryLabel(product, sale.date);
                if (warrantyExpiry != null) {
                  details.add('Warranty Ends: $warrantyExpiry');
                }
                if (product.tradeInValue != null) {
                  details.add(
                      'Trade-in Value: $currency${product.tradeInValue!.toStringAsFixed(2)}');
                }
                if (details.isNotEmpty) {
                  rows.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8),
                      child: pw.Text(
                        details.join(' | '),
                        style: pw.TextStyle(
                            fontSize: (settings.fontSize - 2).toDouble()),
                      ),
                    ),
                  );
                }
              }
            }
            return rows;
          }),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
        pw.Text('Total: $currency${sale.total.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (settings.showFooter) ...[
          pw.SizedBox(height: 8),
          pw.Text(settings.footerText ?? 'Thank you!',
              textAlign: pw.TextAlign.center),
        ],
      ],
    );
  }

  /// Minimal receipt style
  static pw.Widget _buildMinimalReceipt(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    PrintSettings settings,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (settings.showBusinessInfo)
          pw.Text(businessName,
              style: pw.TextStyle(
                  fontSize: (settings.fontSize + 2).toDouble(),
                  fontWeight: pw.FontWeight.bold)),
        pw.Text('${_formatDate(sale.date)} ${_formatTime(sale.date)}'),
        pw.SizedBox(height: 8),
        if (settings.showItemDetails)
          ...sale.items.expand((item) {
            final product = item.product;
            final productName = product?.name ?? 'Unknown';
            final displayName = product?.isActive == false
                ? '$productName (Deleted Item)'
                : productName;
            final rows = <pw.Widget>[
              pw.Text(
                  '$displayName $currency${item.subtotal.toStringAsFixed(2)}'),
            ];

            // Add mobile phone details if available
            if (product != null &&
                (product.brand != null ||
                    product.modelName != null ||
                    item.imei != null)) {
              final mobileInfo = <String>[];
              if (product.brand != null && product.modelName != null) {
                mobileInfo.add('${product.brand} ${product.modelName}');
              }
              if (item.imei != null && item.imei!.isNotEmpty) {
                mobileInfo.add('IMEI: ${item.imei}');
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
              if (product.warrantyPeriod != null) {
                mobileInfo.add('Warranty: ${product.warrantyPeriod}');
              }
              final warrantyExpiry =
                  _getWarrantyExpiryLabel(product, sale.date);
              if (warrantyExpiry != null) {
                mobileInfo.add('Warranty Ends: $warrantyExpiry');
              }
              if (product.tradeInValue != null) {
                mobileInfo.add(
                    'Trade-in Value: $currency${product.tradeInValue!.toStringAsFixed(2)}');
              }
              if (mobileInfo.isNotEmpty) {
                rows.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8),
                    child: pw.Text(
                      mobileInfo.join(' | '),
                      style: pw.TextStyle(
                          fontSize: (settings.fontSize - 2).toDouble()),
                    ),
                  ),
                );
              }
            }
            return rows;
          }),
        pw.SizedBox(height: 8),
        pw.Text('Total: $currency${sale.total.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  /// Detailed receipt style
  static pw.Widget _buildDetailedReceipt(
    SaleModel sale,
    String businessName,
    String businessAddress,
    String businessPhone,
    String currency,
    PrintSettings settings,
  ) {
    return _buildModernReceipt(
        sale, businessName, businessAddress, businessPhone, currency, settings);
  }

  static pw.Widget _buildTableCell(String text, PrintSettings settings,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize:
              (isHeader ? settings.fontSize : settings.fontSize - 1).toDouble(),
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(
      String label, double amount, String currency, PrintSettings settings,
      {bool isTotal = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: (isTotal ? settings.fontSize + 2 : settings.fontSize)
                  .toDouble(),
              fontWeight: (isTotal || isBold)
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '$currency${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: (isTotal ? settings.fontSize + 2 : settings.fontSize)
                  .toDouble(),
              fontWeight: (isTotal || isBold)
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Print to Bluetooth printer
  static Future<bool> _printBluetooth(
    SaleModel sale,
    PrintSettings settings,
    DatabaseService? dbService,
  ) async {
    try {
      // Get business settings
      final businessSettings = await _getBusinessSettings(dbService);

      // Check if Bluetooth is available and connected
      if (!await BluetoothPrinterService.isBluetoothAvailable()) {
        throw Exception(
            'Bluetooth is not available on this device. Please enable Bluetooth and try again.');
      }

      // Verify actual connection status
      final isConnected = await BluetoothPrinterService.verifyConnection();
      if (!isConnected) {
        throw Exception(
            'No Bluetooth printer connected. Please connect a printer from the printer settings and try again.');
      }

      // Print using Bluetooth service
      return await BluetoothPrinterService.printReceipt(
        sale,
        businessName: businessSettings.businessName,
        businessAddress: businessSettings.businessAddress,
        businessPhone: businessSettings.businessPhone,
        currency: businessSettings.currency,
        copies: settings.copies,
        paperWidthMm: settings.paperSize == PaperSize.thermal58mm ? 58 : 80,
      );
    } catch (e) {
      throw Exception('Bluetooth print error: $e');
    }
  }

  /// Print to thermal printer
  static Future<bool> _printThermal(
    SaleModel sale,
    PrintSettings settings,
    DatabaseService? dbService,
  ) async {
    try {
      // Get business settings
      final businessSettings = await _getBusinessSettings(dbService);

      // Use unified ESC/POS generator so all thermal routes share one layout.
      final escPosData = await _generateEscPosReceipt(
        sale,
        businessName: businessSettings.businessName,
        businessAddress: businessSettings.businessAddress,
        businessPhone: businessSettings.businessPhone,
        currency: businessSettings.currency,
        logoPath: settings.showLogo ? _getLogoPath(dbService) : null,
        customFooterText: settings.footerText,
        openCashDrawer: settings.openCashDrawer,
        paperSize: settings.paperSize,
      );

      return await EnhancedThermalPrintServiceV2.printRawData(
        sale,
        escPosData,
        printerIp: settings.printerIp,
        port: settings.printerPort,
        copies: settings.copies,
      );
    } catch (e) {
      throw Exception('Thermal print error: $e');
    }
  }

  /// Print to thermal printer with enhanced settings
  static Future<bool> _printThermalEnhanced(
    SaleModel sale,
    PrintSettings settings,
    DatabaseService? dbService,
  ) async {
    try {
      // Get business settings
      final businessSettings = await _getBusinessSettings(dbService);

      // Generate ESC/POS receipt with all features
      final escPosData = await _generateEscPosReceipt(
        sale,
        businessName: businessSettings.businessName,
        businessAddress: businessSettings.businessAddress,
        businessPhone: businessSettings.businessPhone,
        currency: businessSettings.currency,
        logoPath: settings.showLogo ? _getLogoPath(dbService) : null,
        customFooterText: settings.footerText,
        openCashDrawer: settings.openCashDrawer,
        paperSize: settings.paperSize,
      );

      // Send to network printer
      return await EnhancedThermalPrintServiceV2.printRawData(
        sale,
        escPosData,
        printerIp: settings.printerIp,
        port: settings.printerPort,
        copies: settings.copies,
      );
    } catch (e) {
      throw Exception('Thermal print error: $e');
    }
  }

  /// Print to A4 printer
  static Future<bool> _printA4(
    SaleModel sale,
    PrintSettings settings,
    DatabaseService? dbService,
  ) async {
    try {
      final pdfBytes = await generateReceiptPdf(sale,
          settings: settings, databaseService: dbService);

      // Use printing package to print
      // On Windows, this will use the system print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Receipt_${sale.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      return true;
    } catch (e) {
      throw Exception('A4 print error: $e');
    }
  }

  /// Print to Windows printer directly (for thermal printers)
  /// Uses direct ESC/POS commands for thermal printers, PDF for others
  static Future<bool> _printToWindowsPrinter(
    SaleModel sale, {
    String? printerName,
    PrintSettings? settingsOverride,
    DatabaseService? dbService,
    bool isTestPage = false,
    String? testBusinessName,
  }) async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      final settings = settingsOverride ?? PrintSettings.getDefault();
      final targetPrinterName = printerName ?? settings.printerName;

      // Detect all printers to check if thermal
      final printers = await WindowsPrinterDetectionService.detectAllPrinters();
      bool isThermalPrinter = false;

      // Check if printer is thermal - use direct ESC/POS if available
      if (targetPrinterName != null) {
        final printer = printers.firstWhere(
          (p) => p.name == targetPrinterName,
          orElse: () => WindowsPrinter(
              name: '',
              port: '',
              driver: '',
              isOffline: false,
              status: '',
              isThermal: false),
        );

        isThermalPrinter = printer.isThermal;

        // If thermal printer, try direct ESC/POS printing first
        if (printer.isThermal) {
          try {
            // Get print settings for footer and drawer
            final printSettings =
                await _resolvePrintSettings(settings, dbService);

            // Generate ESC/POS data
            final businessSettings = await _getBusinessSettings(dbService);
            final escPosData = await _generateEscPosReceipt(
              sale,
              businessName: isTestPage && testBusinessName != null
                  ? testBusinessName
                  : businessSettings.businessName,
              businessAddress: businessSettings.businessAddress,
              businessPhone: businessSettings.businessPhone,
              currency: businessSettings.currency,
              logoPath: printSettings.showLogo ? _getLogoPath(dbService) : null,
              customFooterText: printSettings.footerText,
              openCashDrawer: printSettings.openCashDrawer,
              paperSize: printSettings.paperSize,
            );

            // Send ESC/POS data to Windows printer as RAW
            final success = await _printRawToWindowsPrinter(
              targetPrinterName!,
              escPosData,
            );

            if (success) {
              debugPrint('Successfully printed ESC/POS via Windows RAW print');
              return true;
            } else {
              debugPrint('RAW ESC/POS print failed, trying network thermal');
            }
          } catch (e) {
            debugPrint('ESC/POS printing failed: $e');
          }

          // Fallback to network thermal if IP is configured
          if (settings.printerIp != null && settings.printerIp!.isNotEmpty) {
            try {
              debugPrint('Trying network thermal printing');
              return await _printThermal(sale, settings, dbService);
            } catch (thermalError) {
              debugPrint('Network thermal printing also failed: $thermalError');
            }
          }
        }
      }

      // Fallback to PDF printing for non-thermal or if direct printing failed
      // NOTE: PDF printing for thermal printers will not format correctly
      // It's better to use network thermal printing if IP is available
      if (settings.printerIp != null &&
          settings.printerIp!.isNotEmpty &&
          isThermalPrinter) {
        debugPrint(
            'Thermal printer detected, trying network thermal printing before PDF fallback');
        try {
          final networkSuccess = await _printThermal(sale, settings, dbService);
          if (networkSuccess) {
            return true;
          }
        } catch (e) {
          debugPrint('Network thermal printing failed: $e');
        }
      }

      // Generate PDF for A4 printers or as last resort
      final pdfBytes = await generateReceiptPdf(sale,
          settings: settings,
          databaseService: dbService,
          customBusinessName: isTestPage ? testBusinessName : null);

      // For Windows printing, create a simple text file and use PrintTo
      // This is more reliable than PDF for thermal printers
      final tempDir = await getTemporaryDirectory();

      // Create simple text receipt for Windows printing
      final receiptText = await _buildTextReceipt(
          sale, isTestPage ? testBusinessName : null, settings, dbService);
      final textFile = File(
          '${tempDir.path}/receipt_${sale.id}_${DateTime.now().millisecondsSinceEpoch}.txt');
// Write as Latin-1 (Windows ANSI) so Out-Printer / CP850 renders Rs. correctly.
// dart:convert's latin1 codec silently replaces any stray non-Latin-1 bytes.
      await textFile.writeAsString(receiptText, encoding: latin1);
      // Try PowerShell Out-Printer (works for most Windows printers)
      if (settings.printerName != null) {
        try {
          final result = await Process.run(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              'Get-Content -Path "' +
                  textFile.path +
                  '" | Out-Printer -Name "' +
                  settings.printerName! +
                  '"',
            ],
            runInShell: true,
          );

          if (result.exitCode == 0 || result.exitCode == 1) {
            debugPrint('Successfully printed using Out-Printer');
            // Clean up temp file after a delay
            Future.delayed(const Duration(seconds: 5), () {
              try {
                textFile.deleteSync();
              } catch (e) {
                debugPrint('Error deleting temp file: $e');
              }
            });
            return true;
          } else {
            debugPrint('Out-Printer failed (exitCode=${result.exitCode})');
            debugPrint('STDERR: ${result.stderr}');
          }
        } catch (e) {
          debugPrint('Out-Printer method failed: $e');
        }

        return false;
      } else {
        // Use default printer
        try {
          final result = await Process.run(
            'powershell',
            [
              '-NoProfile',
              '-Command',
              'Start-Process -FilePath "' +
                  textFile.path.replaceAll('"', '""') +
                  '" -Verb Print -WindowStyle Hidden',
            ],
            runInShell: true,
          );

          if (result.exitCode != 0) {
            debugPrint(
                'Windows Print command failed (exitCode=${result.exitCode}).');
            debugPrint('STDOUT: ${result.stdout}');
            debugPrint('STDERR: ${result.stderr}');
          }

          // Clean up temp file after a delay
          Future.delayed(const Duration(seconds: 5), () {
            try {
              textFile.deleteSync();
            } catch (e) {
              debugPrint('Error deleting temp file: $e');
            }
          });

          return result.exitCode == 0;
        } catch (e) {
          debugPrint('Default printer print failed: $e');
          // Clean up temp file
          try {
            textFile.deleteSync();
          } catch (e) {
            debugPrint('Error deleting temp file: $e');
          }
          return false;
        }
      }
    } catch (e) {
      throw Exception('Windows print error: $e');
    }
  }

  /// Print RAW ESC/POS data to Windows printer - ULTRA FAST (< 0.5 seconds)
  /// Uses Windows copy command for maximum reliability
  static Future<bool> _printRawToWindowsPrinter(
    String printerName,
    Uint8List escPosData,
  ) async {
    try {
      final startTime = DateTime.now();
      debugPrint('=== ULTRA-FAST WINDOWS PRINT ===');
      debugPrint('Printer: $printerName');
      debugPrint('Data size: ${escPosData.length} bytes');

      // Create temp file with ESC/POS data
      final tempDir = await getTemporaryDirectory();
      final rawFile = File(
          '${tempDir.path}\\print_${DateTime.now().millisecondsSinceEpoch}.bin');
      await rawFile.writeAsBytes(escPosData);

      debugPrint('Temp file: ${rawFile.path}');

      // Use Windows copy command - MOST RELIABLE for thermal printers
      // /b = binary mode (critical for ESC/POS data)
      final result = await Process.run(
        'cmd.exe',
        ['/c', 'copy', '/b', '"${rawFile.path}"', '"$printerName"'],
        runInShell: false,
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () => ProcessResult(0, 1, '', 'Timeout'),
      );

      final duration = DateTime.now().difference(startTime);
      debugPrint('Print completed in ${duration.inMilliseconds}ms');
      debugPrint('Exit code: ${result.exitCode}');

      if (result.stdout.toString().isNotEmpty) {
        debugPrint('Output: ${result.stdout}');
      }
      if (result.stderr.toString().isNotEmpty) {
        debugPrint('Error: ${result.stderr}');
      }

      // Clean up temp file (async, don't wait)
      rawFile.delete().catchError((_) => {});

      final success = result.exitCode == 0;
      debugPrint(success ? '✓ SUCCESS' : '✗ FAILED');
      debugPrint('===========================');

      return success;
    } catch (e) {
      debugPrint('✗ Print error: $e');
      return false;
    }
  }

  /// Direct ESC/POS printing for Windows thermal printers
  static Future<bool> _printDirectEscPos(
    SaleModel sale,
    PrintSettings settings,
    DatabaseService? dbService,
    String printerPort,
  ) async {
    try {
      // Get business settings
      final businessSettings = await _getBusinessSettings(dbService);

      // Use existing thermal print service for ESC/POS generation
      // But send directly to Windows printer port instead of network
      final receiptData = await _generateEscPosReceipt(
        sale,
        businessName: businessSettings.businessName,
        businessAddress: businessSettings.businessAddress,
        businessPhone: businessSettings.businessPhone,
        currency: businessSettings.currency,
        paperSize: settings.paperSize,
      );

      // Try to send to printer port directly
      // Windows printer ports are typically LPT1, COM1, USB, or network ports
      if (printerPort.startsWith('COM') ||
          printerPort.startsWith('LPT') ||
          printerPort.startsWith('USB')) {
        // Serial/Parallel/USB port - Windows doesn't allow direct file writes to these
        // Instead, we need to use the printer name through Windows printing
        debugPrint(
            'Cannot write directly to port $printerPort, using Windows print queue instead');

        // For COM/LPT/USB ports, we should use the printer name, not the port
        // The port write will fail, so we'll fall through to network or PDF printing
        debugPrint(
            'Direct port access not supported for $printerPort, trying network thermal or PDF fallback');
      }

      // Network printer or fallback
      if (settings.printerIp != null && settings.printerIp!.isNotEmpty) {
        // Network printer - use existing network printing
        return await EnhancedThermalPrintServiceV2.printReceipt(
          sale,
          printerIp: settings.printerIp,
          port: settings.printerPort,
          businessName: businessSettings.businessName,
          businessAddress: businessSettings.businessAddress,
          businessPhone: businessSettings.businessPhone,
          currency: businessSettings.currency,
          copies: settings.copies,
        );
      }

      return false;
    } catch (e) {
      debugPrint('Direct ESC/POS printing error: $e');
      return false;
    }
  }

  /// Generate ESC/POS receipt data - OPTIMIZED for SPEED
  static Future<Uint8List> _generateEscPosReceipt(
    SaleModel sale, {
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String currency,
    String? logoPath,
    String? customFooterText,
    bool openCashDrawer = false,
    PaperSize paperSize = PaperSize.thermal80mm,
  }) async {
    // Debug print business info
    debugPrint('=== RECEIPT GENERATION ===');
    debugPrint('Business Name: "$businessName"');
    debugPrint('Business Address: "$businessAddress"');
    debugPrint('Business Phone: "$businessPhone"');
    debugPrint('Currency: "$currency"');
    debugPrint('Items count: ${sale.items.length}');
    debugPrint('Total: ${sale.total}');
    debugPrint('========================');

    // Pre-allocate buffer for speed (avoid multiple List grows)
    final commands = <int>[];
    const String ESC = '\x1B';
    const String GS = '\x1D';
    const String LF = '\x0A';

    final safeCurrency = _thermalSafeCurrency(currency);
    // Common ESC/POS font-A capacities: 58mm ≈ 32 chars, 80mm ≈ 48.
    final int width = paperSize == PaperSize.thermal58mm ? 32 : 48;

    String money(double value) => '$safeCurrency ${value.toStringAsFixed(2)}';

    String amountLine(String label, String value) {
      final gap = width - label.length - value.length;
      return '$label${' ' * (gap < 1 ? 1 : gap)}$value';
    }

    String _fit(String value, int len) {
      final clean = value.replaceAll('\n', ' ').trim();
      if (clean.length > len) {
        return '${clean.substring(0, len - 3)}...';
      }
      return clean.padRight(len);
    }

    // Initialize printer
    commands.addAll([0x1B, 0x40]); // ESC @ - Reset
    commands.addAll([0x1B, 0x61, 0x00]); // Left align for compact printing

    // Print logo if available
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          commands.addAll(await _encodeImageToEscPos(logoFile));
          commands.add(0x0A);
        }
      } catch (e) {
        // Skip logo on error
      }
    }

    // Compact, simple header
    commands.addAll(utf8.encode('${ESC}E\x01')); // Bold
    commands.addAll(utf8.encode('${businessName.trim()}$LF'));
    commands.addAll(utf8.encode('${ESC}E\x00'));
    if (businessAddress.isNotEmpty) {
      commands.addAll(utf8.encode('${businessAddress.trim()}$LF'));
    }
    if (businessPhone.isNotEmpty) {
      commands.addAll(utf8.encode('Tel: ${businessPhone.trim()}$LF'));
    }
    commands.addAll(utf8.encode('-' * width + '$LF'));

    // Receipt info
    final infoBuffer = StringBuffer();
    infoBuffer.write('Receipt #: ${sale.id}$LF');

    final d = sale.date;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    infoBuffer.write('Date: $dateStr$LF');

    if (sale.customer != null) {
      infoBuffer.write('Customer: ${sale.customer!.name}$LF');
    }

    if (sale.cashier != null) {
      infoBuffer.write('Cashier: ${sale.cashier!.name}$LF');
    }

    commands.addAll(utf8.encode(infoBuffer.toString()));
    commands.addAll(utf8.encode('-' * width + '$LF'));

    // Items table header - simple and compact
    commands.addAll(utf8.encode('${ESC}E\x01')); // Bold
    commands.addAll(utf8.encode(width == 32
        ? 'ITEM / QTY / PRICE$LF'
        : 'Item             Qty    Price      Total$LF'));
    commands.addAll(utf8.encode('${ESC}E\x00')); // Bold off
    commands.addAll(utf8.encode('-' * width + '$LF'));

    // Items list
    double itemsTotal = 0.0;
    for (final item in sale.items) {
      final product = item.product;
      final productName = product?.name ?? 'Unknown';
      final displayName =
          (product?.isActive == false) ? '$productName (Deleted)' : productName;

      final qtyValue = QuantityFormatter.number(item.qty, unit: product?.unit);

      itemsTotal += item.subtotal;

      if (width == 32) {
        commands.addAll(utf8.encode('${_fit(displayName, width)}$LF'));
        commands.addAll(utf8.encode(
            '${amountLine('  $qtyValue x ${money(item.price)}', money(item.price * item.qty))}$LF'));
      } else {
        final nameTrunc = _fit(displayName, 16);
        final qty = qtyValue.padLeft(6);
        final price = money(item.price).padLeft(10);
        final total = money(item.price * item.qty).padLeft(11);
        commands.addAll(utf8.encode('$nameTrunc$qty  $price$total$LF'));
      }
    }

    commands.addAll(utf8.encode('-' * width + '$LF'));

    // Totals section
    commands.addAll(utf8.encode('${ESC}a\x00')); // Left align

    final totalsBuf = StringBuffer();
    totalsBuf.write('${amountLine('Subtotal', money(itemsTotal))}$LF');

    if (sale.discount > 0) {
      totalsBuf
          .write('${amountLine('Discount', '-${money(sale.discount)}')}$LF');
    }

    if (sale.paid > 0) {
      totalsBuf.write('${amountLine('Paid', money(sale.paid))}$LF');
    }
    if (sale.due > 0) {
      totalsBuf.write('${amountLine('Due', money(sale.due))}$LF');
    }

    totalsBuf.write('-' * width + '$LF');
    totalsBuf.write('${ESC}E\x01'); // Bold
    totalsBuf.write('${amountLine('TOTAL', money(sale.total))}$LF');
    totalsBuf.write('${ESC}E\x00'); // Normal
    totalsBuf.write('-' * width + '$LF');

    commands.addAll(utf8.encode(totalsBuf.toString()));

    // Payment details
    commands.addAll(utf8.encode('${ESC}a\x00'));
    commands.addAll(
        utf8.encode('Payment: ${sale.paymentType.name.toUpperCase()}$LF'));

    String statusText = sale.status.name.toUpperCase().replaceAll('_', ' ');
    commands.addAll(utf8.encode('Status: $statusText$LF'));
    commands.addAll(utf8.encode('-' * width + '$LF'));

    // Footer
    commands.addAll(utf8.encode('${ESC}a\x00'));
    if (customFooterText != null && customFooterText.isNotEmpty) {
      final footerLines = customFooterText.split('\n');
      for (final line in footerLines) {
        if (line.trim().isNotEmpty) {
          commands.addAll(utf8.encode('${line.trim()}$LF'));
        }
      }
    } else {
      commands.addAll(utf8.encode('Thank you for your business!$LF'));
      commands.addAll(utf8.encode('Please visit again.$LF'));
    }
    commands.addAll(utf8.encode('Powered by Offline POS$LF'));

    // Cash drawer (before final feed)
    if (openCashDrawer) {
      commands.addAll([0x1B, 0x70, 0x00, 0x32, 0xFA]); // Open cash drawer
    }

    // Keep end compact; final cut/feed is sent by print service finalize step.
    commands.addAll([0x0A, 0x0A, 0x0A]);

    return Uint8List.fromList(commands);
  }

  /// Encode image to ESC/POS format for thermal printer
  static Future<List<int>> _encodeImageToEscPos(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // For now, return empty - full image encoding requires image package
      // This is a placeholder for logo support
      // In production, you would:
      // 1. Load image using image package
      // 2. Convert to bitmap
      // 3. Convert to ESC/POS raster format
      // 4. Return the encoded bytes

      // Placeholder: Return empty list (logo will be skipped)
      // TODO: Implement full image encoding
      return [];
    } catch (e) {
      debugPrint('Error encoding image: $e');
      return [];
    }
  }

  /// Detect printer type automatically
  static Future<PrinterType> _detectPrinterType(PrintSettings settings) async {
    // Check for Bluetooth printer on mobile
    if (Platform.isAndroid || Platform.isIOS) {
      if (await BluetoothPrinterService.isBluetoothAvailable()) {
        if (BluetoothPrinterService.isConnected()) {
          return PrinterType.bluetooth;
        }
      }
    }

    if (Platform.isWindows) {
      // Check for Windows printers
      final printers = await WindowsPrinterDetectionService.detectAllPrinters();
      if (printers.isNotEmpty) {
        final thermalPrinters = printers.where((p) => p.isThermal).toList();
        if (thermalPrinters.isNotEmpty) {
          return PrinterType.thermal;
        }
        return PrinterType.a4;
      }
    }

    // Check for network thermal printer
    if (settings.printerIp != null && settings.printerIp!.trim().isNotEmpty) {
      final isConnected =
          await EnhancedThermalPrintServiceV2.testPrinterConnection(
        settings.printerIp!.trim(),
        port: settings.printerPort,
      );
      if (isConnected) {
        return PrinterType.networkThermal;
      }
    }

    // Default to A4
    return PrinterType.a4;
  }

  /// Get printer connection status
  static Future<PrinterConnectionStatus> getPrinterStatus({
    PrintSettings? settings,
    DatabaseService? databaseService,
  }) async {
    try {
      final printSettings =
          await _resolvePrintSettings(settings, databaseService);
      PrinterType printerType = printSettings.printerType;

      if (printerType == PrinterType.auto) {
        printerType = await _detectPrinterType(printSettings);
      }

      switch (printerType) {
        case PrinterType.bluetooth:
          final available =
              await BluetoothPrinterService.isBluetoothAvailable();
          if (!available) {
            return PrinterConnectionStatus.notConfigured;
          }
          final isConnected = await BluetoothPrinterService.verifyConnection();
          return isConnected
              ? PrinterConnectionStatus.connected
              : PrinterConnectionStatus.disconnected;

        case PrinterType.networkThermal:
        case PrinterType.thermal:
          final ip = printSettings.printerIp;
          if (ip == null || ip.isEmpty) {
            return PrinterConnectionStatus.notConfigured;
          }
          final ok = await EnhancedThermalPrintServiceV2.testPrinterConnection(
            ip,
            port: printSettings.printerPort,
          );
          return ok
              ? PrinterConnectionStatus.connected
              : PrinterConnectionStatus.disconnected;

        case PrinterType.a4:
          return PrinterConnectionStatus
              .connected; // A4 always available via system dialog

        case PrinterType.auto:
          return PrinterConnectionStatus.notConfigured;
      }
    } catch (e) {
      debugPrint('Error getting printer status: $e');
      return PrinterConnectionStatus.error;
    }
  }

  /// Get available network printers
  static Future<List<String>> getAvailableNetworkPrinters() async {
    try {
      return await EnhancedThermalPrintServiceV2.getAvailablePrinters();
    } catch (e) {
      debugPrint('Error getting available printers: $e');
      return [];
    }
  }

  /// Test printer connection
  static Future<bool> testPrinterConnection({
    String? printerIp,
    int? port,
    PrintSettings? settings,
  }) async {
    final result = await testPrinterConnectionWithError(
      printerIp: printerIp,
      port: port,
      settings: settings,
    );
    return result.isConnected;
  }

  /// Test printer connection with detailed error message
  static Future<({bool isConnected, String? errorMessage})>
      testPrinterConnectionWithError({
    String? printerIp,
    int? port,
    PrintSettings? settings,
    DatabaseService? databaseService,
  }) async {
    try {
      final printSettings =
          await _resolvePrintSettings(settings, databaseService);
      final ip = printerIp ?? printSettings.printerIp;
      final printerPort = port ?? printSettings.printerPort;

      if (ip == null || ip.isEmpty) {
        return (
          isConnected: false,
          errorMessage:
              'Printer IP address is not configured. Please set the printer IP in settings.'
        );
      }

      return await EnhancedThermalPrintServiceV2.testPrinterConnectionWithError(
        ip,
        port: printerPort,
      );
    } catch (e) {
      debugPrint('Error testing printer connection: $e');
      return (
        isConnected: false,
        errorMessage: 'Error testing connection: ${e.toString()}'
      );
    }
  }

  /// Print test page
  static Future<bool> printTestPage({
    String? printerIp,
    int? port,
    String? businessName,
    String? printerName, // Windows printer name
    PrintSettings? settings,
    DatabaseService? databaseService,
  }) async {
    try {
      final printSettings =
          await _resolvePrintSettings(settings, databaseService);

      // Check if this is a Windows printer
      final isWindowsPrinter = printerName != null ||
          (Platform.isWindows && printerIp != null && !printerIp.contains('.'));

      if (isWindowsPrinter) {
        // Use Windows printing for Windows printers
        final targetPrinterName =
            printerName ?? printerIp ?? printSettings.printerName;
        if (targetPrinterName == null || targetPrinterName.isEmpty) {
          throw Exception('Windows printer name not configured');
        }

        // Get business settings
        final businessSettings = await _getBusinessSettings(databaseService);
        final business = businessName ?? businessSettings.businessName;

        // Create a test sale with sample items for better testing
        final testSale = SaleModel(
          id: 999999,
          date: DateTime.now(),
          total: 1500.00,
          discount: 0,
          paid: 1500.00,
          due: 0,
          paymentType: PaymentType.cash,
          status: SaleStatus.paid,
          createdAt: DateTime.now(),
          items: [
            SaleItemModel(
              id: 1,
              saleId: 999999,
              productId: 1,
              qty: 2.0,
              price: 250.00,
              subtotal: 500.00,
              discount: 0,
              createdAt: DateTime.now(),
              product: ProductModel(
                id: 1,
                name: 'Test Product 1',
                category: 'General',
                price: 250.00,
                cost: 200.00,
                stock: 100,
                unit: 'pcs',
                discount: 0,
                tax: 0,
                reorderLevel: 10,
                reorderQuantity: 50,
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
            SaleItemModel(
              id: 2,
              saleId: 999999,
              productId: 2,
              qty: 1.0,
              price: 1000.00,
              subtotal: 1000.00,
              discount: 0,
              createdAt: DateTime.now(),
              product: ProductModel(
                id: 2,
                name: 'Test Product 2',
                category: 'General',
                price: 1000.00,
                cost: 800.00,
                stock: 50,
                unit: 'pcs',
                discount: 0,
                tax: 0,
                reorderLevel: 5,
                reorderQuantity: 25,
                isActive: true,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ),
          ],
          customer: CustomerModel(
            id: 1,
            name: 'Test Customer',
            phone: '1234567890',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          cashier: EmployeeModel(
            id: 1,
            name: 'Test Cashier',
            username: 'test',
            phone: '0000000000',
            employeeId: 'EMP001',
            hireDate: DateTime.now(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        return await _printToWindowsPrinter(
          testSale,
          printerName: targetPrinterName,
          isTestPage: true,
          testBusinessName: business,
        );
      }

      // Network printer
      final ip = printerIp ?? printSettings.printerIp;
      final printerPort = port ?? printSettings.printerPort;

      if (ip == null || ip.isEmpty) {
        throw Exception('Printer IP not configured');
      }

      // Get business settings
      final businessSettings = await _getBusinessSettings(databaseService);
      final business = businessName ?? businessSettings.businessName;

      try {
        return await EnhancedThermalPrintServiceV2.printTestPage(
          printerIp: ip,
          port: printerPort,
          businessName: business,
        );
      } catch (networkError) {
        debugPrint('Network test page failed: $networkError');
        // Fallback to Windows printer test when configured.
        final windowsPrinterName = printSettings.printerName;
        if (Platform.isWindows &&
            windowsPrinterName != null &&
            windowsPrinterName.trim().isNotEmpty) {
          final fallbackTestSale = SaleModel(
            id: 999998,
            date: DateTime.now(),
            total: 0,
            discount: 0,
            paid: 0,
            due: 0,
            paymentType: PaymentType.cash,
            status: SaleStatus.paid,
            createdAt: DateTime.now(),
            items: const [],
          );
          return await _printToWindowsPrinter(
            fallbackTestSale,
            printerName: windowsPrinterName,
            settingsOverride: printSettings,
            dbService: databaseService,
            isTestPage: true,
            testBusinessName: business,
          );
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error printing test page: $e');
      return false;
    }
  }

  /// Lightweight printer test for UI "Test printer" button.
  /// Returns a [PrintTestResult] with success flag and user-facing message.
  static Future<PrintTestResult> testPrinter({
    PrintSettings? settings,
    DatabaseService? databaseService,
  }) async {
    try {
      final printSettings =
          await _resolvePrintSettings(settings, databaseService);
      PrinterType printerType = printSettings.printerType;

      if (printerType == PrinterType.auto) {
        printerType = await _detectPrinterType(printSettings);
      }

      switch (printerType) {
        case PrinterType.bluetooth:
          final available =
              await BluetoothPrinterService.isBluetoothAvailable();
          if (!available) {
            return const PrintTestResult(false,
                'Bluetooth not available on this device. Please enable Bluetooth.');
          }
          final isConnected = await BluetoothPrinterService.verifyConnection();
          if (!isConnected) {
            return const PrintTestResult(false,
                'No Bluetooth printer connected. Please pair and connect a printer from the printer settings.');
          }
          return const PrintTestResult(
              true, 'Bluetooth printer is connected and ready.');

        case PrinterType.networkThermal:
        case PrinterType.thermal:
          final ip = printSettings.printerIp;
          if (ip == null || ip.isEmpty) {
            return const PrintTestResult(
                false, 'Thermal printer IP not configured.');
          }
          final ok = await EnhancedThermalPrintServiceV2.testPrinterConnection(
            ip,
            port: printSettings.printerPort,
          );
          return ok
              ? PrintTestResult(true,
                  'Thermal printer reachable at $ip:${printSettings.printerPort}.')
              : PrintTestResult(false,
                  'Cannot reach thermal printer at $ip:${printSettings.printerPort}.');

        case PrinterType.a4:
          return const PrintTestResult(
              true, 'A4 printing uses the system dialog and is available.');

        case PrinterType.auto:
          return const PrintTestResult(
              false, 'Could not determine printer type automatically.');
      }
    } catch (e) {
      return PrintTestResult(false, 'Printer test failed: $e');
    }
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

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour12 =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final amPm = date.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
  }

  static String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${_formatTime(date)}';
  }
}
