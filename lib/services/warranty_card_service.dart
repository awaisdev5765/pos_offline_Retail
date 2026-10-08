import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr/qr.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import '../database/database.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/sale.dart';
import '../services/database_service.dart';

class WarrantyCardService {
  /// Generate and print warranty card for a sold phone
  static Future<void> generateAndPrintWarrantyCard({
    required ProductIMEI imei,
    required ProductModel product,
    CustomerModel? customer,
    SaleModel? sale,
    required DatabaseService databaseService,
  }) async {
    try {
      // Get business settings
      final businessName =
          await databaseService.getSetting('business_name') ?? 'My Business';
      final businessAddress =
          await databaseService.getSetting('business_address') ?? '';
      final businessPhone =
          await databaseService.getSetting('business_phone') ?? '';
      final businessEmail =
          await databaseService.getSetting('business_email') ?? '';

      // Generate QR code image bytes first
      final qrData = _generateQRCodeData(imei, product, customer, sale);
      final qrImageBytes = await _qrCodeToPdfImage(qrData);

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildWarrantyCardContent(
              imei: imei,
              product: product,
              customer: customer,
              sale: sale,
              businessName: businessName,
              businessAddress: businessAddress,
              businessPhone: businessPhone,
              businessEmail: businessEmail,
              qrImageBytes: qrImageBytes,
            );
          },
        ),
      );

      // Print the warranty card
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Warranty_Card_${imei.imei}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      throw Exception('Error generating warranty card: $e');
    }
  }

  /// Generate and share warranty card as PDF
  static Future<void> generateAndShareWarrantyCard({
    required ProductIMEI imei,
    required ProductModel product,
    CustomerModel? customer,
    SaleModel? sale,
    required DatabaseService databaseService,
  }) async {
    try {
      // Get business settings
      final businessName =
          await databaseService.getSetting('business_name') ?? 'My Business';
      final businessAddress =
          await databaseService.getSetting('business_address') ?? '';
      final businessPhone =
          await databaseService.getSetting('business_phone') ?? '';
      final businessEmail =
          await databaseService.getSetting('business_email') ?? '';

      // Generate QR code image bytes first
      final qrData = _generateQRCodeData(imei, product, customer, sale);
      final qrImageBytes = await _qrCodeToPdfImage(qrData);

      // Create PDF document
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildWarrantyCardContent(
              imei: imei,
              product: product,
              customer: customer,
              sale: sale,
              businessName: businessName,
              businessAddress: businessAddress,
              businessPhone: businessPhone,
              businessEmail: businessEmail,
              qrImageBytes: qrImageBytes,
            );
          },
        ),
      );

      // Save PDF to file
      final bytes = await pdf.save();
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/warranty_card_${imei.imei}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(bytes);

      // Share the file
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Warranty Card - ${product.name}',
          text: 'Warranty card for ${product.name} (IMEI: ${imei.imei})');
    } catch (e) {
      throw Exception('Error generating warranty card: $e');
    }
  }

  static pw.Widget _buildWarrantyCardContent({
    required ProductIMEI imei,
    required ProductModel product,
    CustomerModel? customer,
    SaleModel? sale,
    required String businessName,
    required String businessAddress,
    required String businessPhone,
    required String businessEmail,
    required Uint8List qrImageBytes,
  }) {

    // Calculate warranty end date
    DateTime? warrantyEndDate;
    if (sale != null && product.warrantyPeriod != null) {
      final saleDate = sale.date;
      final warrantyMonths = int.tryParse(product.warrantyPeriod ?? '0') ?? 0;
      warrantyEndDate = DateTime(
        saleDate.year,
        saleDate.month + warrantyMonths,
        saleDate.day,
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'WARRANTY CARD',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  width: 200,
                  height: 3,
                  color: PdfColors.black,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Business Info
          _buildSection(
            'Business Information',
            [
              _buildInfoRow('Name', businessName),
              if (businessAddress.isNotEmpty)
                _buildInfoRow('Address', businessAddress),
              if (businessPhone.isNotEmpty)
                _buildInfoRow('Phone', businessPhone),
              if (businessEmail.isNotEmpty)
                _buildInfoRow('Email', businessEmail),
            ],
          ),
          pw.SizedBox(height: 20),

          // Product Information
          _buildSection(
            'Product Information',
            [
              _buildInfoRow('Product Name', product.name),
              if (product.brand != null)
                _buildInfoRow('Brand', product.brand!),
              if (product.modelName != null)
                _buildInfoRow('Model', product.modelName!),
              _buildInfoRow('IMEI Number', imei.imei),
              if (product.storageCapacity != null)
                _buildInfoRow('Storage', '${product.storageCapacity}GB'),
              if (product.ram != null)
                _buildInfoRow('RAM', '${product.ram}GB'),
              if (product.color != null)
                _buildInfoRow('Color', product.color!),
              if (product.condition != null)
                _buildInfoRow('Condition', product.condition!),
            ],
          ),
          pw.SizedBox(height: 20),

          // Customer Information
          if (customer != null)
            _buildSection(
              'Customer Information',
              [
                _buildInfoRow('Name', customer.name),
                if (customer.phone != null)
                  _buildInfoRow('Phone', customer.phone!),
                if (customer.address != null)
                  _buildInfoRow('Address', customer.address!),
              ],
            ),
          if (customer != null) pw.SizedBox(height: 20),

          // Sale Information
          if (sale != null)
            _buildSection(
              'Sale Information',
              [
                _buildInfoRow('Sale ID', '#${sale.id}'),
                _buildInfoRow(
                  'Purchase Date',
                  '${sale.date.day}/${sale.date.month}/${sale.date.year}',
                ),
                if (warrantyEndDate != null)
                  _buildInfoRow(
                    'Warranty Valid Until',
                    '${warrantyEndDate.day}/${warrantyEndDate.month}/${warrantyEndDate.year}',
                  ),
                if (product.warrantyProvider != null)
                  _buildInfoRow('Warranty Provider', product.warrantyProvider!),
              ],
            ),
          if (sale != null) pw.SizedBox(height: 20),

          // Warranty Terms
          _buildSection(
            'Warranty Terms & Conditions',
            [
              pw.Text(
                '1. This warranty card is valid only for the device with the IMEI number mentioned above.',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '2. Warranty covers manufacturing defects only.',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '3. Warranty does not cover physical damage, water damage, or damage caused by misuse.',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '4. Please keep this warranty card safe and present it when claiming warranty service.',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '5. For warranty claims, please contact us at the provided business contact information.',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
          pw.SizedBox(height: 30),

          // QR Code and Footer
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // QR Code - will be passed as parameter
              pw.Container(
                width: 100,
                height: 100,
                child: pw.Image(
                  pw.MemoryImage(qrImageBytes),
                  fit: pw.BoxFit.contain,
                ),
              ),
              // Signature
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Authorized Signature',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 30),
                  pw.Container(
                    width: 150,
                    height: 1,
                    color: PdfColors.black,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Thank you for your purchase!',
              style: pw.TextStyle(
                fontSize: 12,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700, width: 1),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  static String _generateQRCodeData(
    ProductIMEI imei,
    ProductModel product,
    CustomerModel? customer,
    SaleModel? sale,
  ) {
    // Generate JSON data for QR code
    final data = {
      'imei': imei.imei,
      'product': product.name,
      'brand': product.brand,
      'model': product.modelName,
      'sale_id': sale?.id,
      'sale_date': sale?.date.toIso8601String(),
      'customer': customer?.name,
      'warranty_period': product.warrantyPeriod,
    };
    return data.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}:${e.value}')
        .join('|');
  }

  static Future<Uint8List> _qrCodeToPdfImage(String qrData) async {
    // Use qr_flutter's QrPainter to render QR code
    final size = 200;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // White background
    final whitePaint = ui.Paint()..color = ui.Color(0xFFFFFFFF);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      whitePaint,
    );
    
    // Use QrPainter to draw the QR code
    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: ui.Color(0xFF000000),
      emptyColor: ui.Color(0xFFFFFFFF),
    );
    
    qrPainter.paint(canvas, ui.Size(size.toDouble(), size.toDouble()));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

