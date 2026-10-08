import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/quantity_formatter.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../services/database_service.dart';
import 'unified_print_service.dart';

class PdfService {
  static Future<void> generateAndShareReceipt(
      SaleModel sale, DatabaseService databaseService) async {
    try {
      // Settings
      final businessName =
          await databaseService.getSetting('business_name') ?? 'My Business';
      final businessAddress =
          await databaseService.getSetting('business_address') ?? '';
      final businessPhone =
          await databaseService.getSetting('business_phone') ?? '';

      String currency = 'Rs.';
      final currencySymbol =
          await databaseService.getSetting('currency_symbol');
      if (currencySymbol != null && currencySymbol.isNotEmpty) {
        currency = currencySymbol; // keep original (font will fix rendering)
      }

      // ✅ LOAD FONT (FIXES CURRENCY ISSUE)
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginLeft: 15,
            marginRight: 25, // FIXED RIGHT CUT ISSUE
            marginTop: 15,
            marginBottom: 15,
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(businessName, businessAddress, businessPhone),
                pw.SizedBox(height: 10),
                pw.Divider(),
                _buildReceiptDetails(sale),
                pw.Divider(),
                pw.SizedBox(height: 5),
                _buildItemsTable(sale.items, currency),
                pw.SizedBox(height: 10),
                pw.Divider(),
                _buildTotals(sale, currency),
                if (sale.customer != null) _buildCustomerInfo(sale.customer!),
                pw.SizedBox(height: 10),
                pw.Divider(),
                _buildFooter(),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/receipt_${sale.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)],
          text: 'Receipt from $businessName');
    } catch (e) {
      throw Exception('Error generating receipt: $e');
    }
  }

  // ================= HEADER =================
  static pw.Widget _buildHeader(String name, String address, String phone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Center(
          child: pw.Text(
            name,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (address.isNotEmpty)
          pw.Center(child: pw.Text(address, style: pw.TextStyle(fontSize: 10))),
        if (phone.isNotEmpty)
          pw.Center(child: pw.Text(phone, style: pw.TextStyle(fontSize: 10))),
      ],
    );
  }

  // ================= DETAILS =================
  static pw.Widget _buildReceiptDetails(SaleModel sale) {
    return pw.Column(
      children: [
        _row('Receipt #', '${sale.id}'),
        _row('Date', _formatDate(sale.date)),
        _row('Time', _formatTime(sale.date)),
        _row('Status', sale.status.name.toUpperCase()),
        _row('Payment', sale.paymentType.name.toUpperCase()),
        _row('Cashier', sale.cashier?.name ?? 'Unknown'),
        if (sale.tableNumber != null) _row('Table', '${sale.tableNumber}'),
        if (sale.orderType != null)
          _row(
              'Order Type', sale.orderType!.replaceAll('_', ' ').toUpperCase()),
      ],
    );
  }

  // ================= ITEMS =================
  static pw.Widget _buildItemsTable(
      List<SaleItemModel> items, String currency) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          children: [
            _tableHeader('Item'),
            _tableHeader('Qty'),
            _tableHeader('Price'),
            _tableHeader('Total'),
          ],
        ),
        ...items.map((item) {
          return pw.TableRow(
            children: [
              pw.Text(item.product?.name ?? '',
                  style: pw.TextStyle(fontSize: 9)),
              pw.Text(
                  QuantityFormatter.withUnit(item.qty,
                      item.unit.isNotEmpty ? item.unit : item.product?.unit),
                  style: pw.TextStyle(fontSize: 9)),
              pw.Text('$currency${item.price.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9)),
              pw.Text('$currency${item.subtotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 9)),
            ],
          );
        })
      ],
    );
  }

  static pw.Widget _tableHeader(String text) {
    return pw.Text(text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10));
  }

  // ================= TOTALS =================
  static pw.Widget _buildTotals(SaleModel sale, String currency) {
    final subtotal = sale.total - (sale.serviceCharge ?? 0) - (sale.tip ?? 0);

    return pw.Column(
      children: [
        _row('Subtotal', '$currency${subtotal.toStringAsFixed(2)}'),
        if (sale.discount > 0)
          _row('Discount', '-$currency${sale.discount.toStringAsFixed(2)}'),
        if (sale.serviceCharge != null && sale.serviceCharge! > 0)
          _row('Service Charge',
              '$currency${sale.serviceCharge!.toStringAsFixed(2)}'),
        if (sale.tip != null && sale.tip! > 0)
          _row('Tip', '$currency${sale.tip!.toStringAsFixed(2)}'),
        pw.Divider(),
        _row('TOTAL', '$currency${sale.total.toStringAsFixed(2)}', bold: true),
        _row('Paid', '$currency${sale.paid.toStringAsFixed(2)}'),
        if (sale.due > 0)
          _row('Due', '$currency${sale.due.toStringAsFixed(2)}', bold: true),
      ],
    );
  }

  // ================= CUSTOMER =================
  static pw.Widget _buildCustomerInfo(CustomerModel c) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 5),
        pw.Text('Customer',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(c.name),
        if (c.phone.isNotEmpty) pw.Text('Phone: ${c.phone}'),
      ],
    );
  }

  // ================= FOOTER =================
  static pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text('Thank you!',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            'Visit Again',
            style: pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  // ================= COMMON ROW =================
  static pw.Widget _row(String left, String right, {bool bold = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(left,
              style: pw.TextStyle(
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
        pw.Expanded(
          child: pw.Text(
            right,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ),
      ],
    );
  }

  // ================= FORMAT =================
  static String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static String _formatTime(DateTime d) =>
      '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
