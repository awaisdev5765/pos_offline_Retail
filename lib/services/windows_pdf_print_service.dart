import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale.dart';
import '../services/database_service.dart';

/// Windows PDF Print Service - Generates PDF receipts with preview for Windows
class WindowsPdfPrintService {
  /// Generate PDF and send to print directly (no in-app dialogs)
  static Future<bool> printReceiptDirectly(
      SaleModel sale, {
        DatabaseService? databaseService,
        String? customBusinessName,
        String? customBusinessAddress,
        String? customBusinessPhone,
      }) async {
    try {
      final pdfBytes = await generateReceiptPdfBytes(
        sale,
        databaseService: databaseService,
        customBusinessName: customBusinessName,
        customBusinessAddress: customBusinessAddress,
        customBusinessPhone: customBusinessPhone,
      );

      final idPart = sale.id != null && sale.id! > 0
          ? '${sale.id}'
          : 'draft';
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Receipt_${idPart}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      return true;
    } catch (e) {
      debugPrint('Error printing receipt directly: $e');
      return false;
    }
  }

  /// Generate PDF bytes for receipt - OPTIMIZED FOR SPEED
  static Future<Uint8List> generateReceiptPdfBytes(
      SaleModel sale, {
        DatabaseService? databaseService,
        String? customBusinessName,
        String? customBusinessAddress,
        String? customBusinessPhone,
      }) async {
    // Get business settings - optimize by fetching all at once
    final settingsFuture = databaseService != null
        ? Future.wait([
      databaseService.getSetting('business_name'),
      databaseService.getSetting('business_address'),
      databaseService.getSetting('business_phone'),
      databaseService.getSetting('currency_symbol'),
    ])
        : Future.value([null, null, null, null]);

    final settings = await settingsFuture;

    String businessName = customBusinessName ?? settings[0] as String? ?? 'Sales Receipt';
    String businessAddress = customBusinessAddress ?? settings[1] as String? ?? '';
    String businessPhone = customBusinessPhone ?? settings[2] as String? ?? '';
    String currency = settings[3] as String? ?? 'Rs.';

    // Debug: Print fetched values
    debugPrint('Windows PDF Receipt - Business Name: $businessName');
    debugPrint('Windows PDF Receipt - Business Address: $businessAddress');
    debugPrint('Windows PDF Receipt - Business Phone: $businessPhone');
    debugPrint('Windows PDF Receipt - Currency: $currency');

    // Create PDF document - 80mm thermal paper size with proper margins
    final pdf = pw.Document();

    // Pre-build all items to avoid repeated calculations
    final itemsList = sale.items.map((item) {
      final product = item.product;
      final productName = product?.name ?? 'Unknown Product';
      final mobileInfo = product != null ? _buildMobileInfo(product, item) : null;

      return {
        'name': productName,
        'qty': item.qty.toStringAsFixed(0),
        'price': item.price,
        'total': item.subtotal,
        'mobileInfo': mobileInfo,
      };
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(73 * PdfPageFormat.mm, double.infinity),
        margin: const pw.EdgeInsets.fromLTRB(5, 8, 5, 8),
        build: (pw.Context context) {
          return _buildReceiptContent(
            sale,
            businessName,
            businessAddress,
            businessPhone,
            currency,
            itemsList,
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Build 80mm receipt content close to thermal style sample.
  static pw.Widget _buildReceiptContent(
      SaleModel sale,
      String businessName,
      String businessAddress,
      String businessPhone,
      String currency,
      List<Map<String, dynamic>> itemsList,
      ) {
    final subTotal = sale.items.fold<double>(
      0.0,
          (sum, item) => sum + (item.price * item.qty),
    );
    final tax = (sale.total - subTotal + sale.discount).clamp(0.0, double.infinity).toDouble();
    final saleId = sale.id;
    final orderNo =
        (saleId != null && saleId > 0) ? saleId.toString() : 'Draft';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // SALE RECEIPT title at the very top
        pw.Center(
          child: pw.Text(
            'SALE RECEIPT',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 0.7),
          ),
        ),
        pw.SizedBox(height: 4),
        
        // Order Number
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.2),
          ),
          child: pw.Center(
            child: pw.Text(
              'Order # $orderNo',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1),
        
        // Business Header - Name, Address, Phone(s) below Order #
        pw.Center(
          child: pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (businessAddress.isNotEmpty)
          pw.Center(
            child: pw.Text(
              businessAddress,
              style: const pw.TextStyle(fontSize: 8.5),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (businessPhone.isNotEmpty)
          pw.Center(
            child: pw.Text(
              businessPhone,
              style: const pw.TextStyle(fontSize: 8.5),
              textAlign: pw.TextAlign.center,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1),
        _kvRow('Payment Type', sale.paymentType.name.toUpperCase()),
        _kvRow('Date & Time', _formatDateTime(sale.date)),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 2),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 35,
              child: pw.Text('Name', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Expanded(
              flex: 10,
              child: pw.Text('Qty', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
            ),
            pw.Expanded(
              flex: 25,
              child: pw.Text('U.Price', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
            pw.Expanded(
              flex: 30,
              child: pw.Text('Total', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
            ),
          ],
        ),
        pw.Divider(thickness: 1),
        ...itemsList.map((itemData) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 35,
                    child: pw.Text(
                      itemData['name'] as String,
                      style: const pw.TextStyle(fontSize: 9),
                      maxLines: 2,
                    ),
                  ),
                  pw.Expanded(
                    flex: 10,
                    child: pw.Text(
                      itemData['qty'] as String,
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 25,
                    child: pw.Text(
                      _formatMoney('', itemData['price'] as double),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Expanded(
                    flex: 30,
                    child: pw.Text(
                      _formatMoney('', itemData['total'] as double),
                      style: const pw.TextStyle(fontSize: 9),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              if (itemData['mobileInfo'] != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 8, top: 1),
                  child: pw.Text(
                    itemData['mobileInfo'] as String,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                  ),
                ),
              pw.SizedBox(height: 2),
            ],
          );
        }).toList(),
        pw.Divider(thickness: 1),
        _kvRow('Sub Total', _formatMoney("", subTotal)),
        if (sale.discount > 0) _kvRow('Discount', '-${_formatMoney("", sale.discount)}'),
        if (tax > 0) _kvRow('Total VAT', _formatMoney("", tax)),
        if (sale.serviceCharge != null && sale.serviceCharge! > 0)
          _kvRow('Service Charges', _formatMoney("", sale.serviceCharge!)),
        if (sale.tip != null && sale.tip! > 0) _kvRow('Tip', _formatMoney("", sale.tip!)),
        pw.Divider(thickness: 2),
        _kvRow(
          'Grand Total',
          _formatMoney(currency, sale.total),
          labelBold: true,
          valueBold: true,
          fontSize: 12,
        ),
        pw.Divider(thickness: 1),
        _kvRow('Received', _formatMoney("", sale.paid)),
        if (sale.due > 0)
          _kvRow('Due', _formatMoney("", sale.due), valueBold: true)
        else
          _kvRow('Cash Back', _formatMoney("", 0)),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1),
        pw.Center(
          child: pw.Text(
            'THANK YOU...',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            'Printed on ${_formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  static pw.Widget _kvRow(
      String key,
      String value, {
        bool valueBold = false,
        bool labelBold = false,
        double fontSize = 9,
      }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$key:',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: labelBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: valueBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Build mobile product info string
  static String _buildMobileInfo(dynamic product, dynamic item) {
    final info = <String>[];

    if (product.brand != null && product.modelName != null) {
      info.add('${product.brand} ${product.modelName}');
    }
    if (product.storageCapacity != null) {
      info.add(product.storageCapacity!);
    }
    if (product.color != null) {
      info.add(product.color!);
    }
    if (item.imei != null && item.imei!.isNotEmpty) {
      info.add('IMEI: ${item.imei}');
    }
    if (product.condition != null) {
      info.add('Condition: ${product.condition!.toUpperCase()}');
    }
    if (product.warrantyPeriod != null) {
      info.add('Warranty: ${product.warrantyPeriod}');
    }

    return info.join(' • ');
  }

  /// Format date and time
  static String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String _formatMoney(String currency, double amount) {
    if (currency.trim().isEmpty) {
      return amount.toStringAsFixed(3);
    }
    final safeCurrency = _normalizeCurrencySymbol(currency.trim());
    return '$safeCurrency ${amount.toStringAsFixed(3)}';
  }

  /// Normalize Unicode currency symbols to ASCII for PDF compatibility
  static String _normalizeCurrencySymbol(String symbol) {
    // Map of Unicode currency symbols to ASCII equivalents
    const Map<String, String> currencyMap = {
      '₨': 'Rs.',       // Pakistani/Indian Rupee
      '₹': 'Rs.',       // Indian Rupee
      '¥': 'Yen',       // Yen/Yuan
      '€': 'EUR',       // Euro
      '£': 'GBP',       // British Pound
      '₽': 'RUB',       // Russian Ruble
      '₿': 'BTC',       // Bitcoin
      '₫': 'VND',       // Vietnamese Dong
      '₴': 'UAH',       // Ukrainian Hryvnia
      '₸': 'KZT',       // Kazakhstani Tenge
      '₺': 'TRY',       // Turkish Lira
      '₼': 'AZN',       // Azerbaijani Manat
      '₾': 'GEL',       // Georgian Lari
      r'$': 'Rs.',      // Dollar (default to Rs. for this system)
    };

    // Return mapped value or the original symbol if not in map
    return currencyMap[symbol] ?? symbol;
  }
}
