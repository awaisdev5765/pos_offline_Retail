import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/customer.dart';
import '../models/sale.dart';

class ExcelExportService {
  /// Export customer data to Excel with print option
  static Future<String> exportCustomerDataToExcel(
    List<CustomerModel> customers,
    List<SaleModel> sales,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      final sheet = excel['Customer Data'];

      // Remove default sheet
      excel.delete('Sheet1');

      // Add headers
      final headers = [
        'Customer ID',
        'Name',
        'Phone',
        'Notes',
        'Address',
        'Total Sales',
        'Total Amount',
        'Outstanding Balance',
        'Last Purchase Date',
        'Total Orders',
        'Average Order Value',
        'Status',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      // Style headers
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      // Add customer data
      int rowIndex = 1;
      for (final customer in customers) {
        final customerSales =
            sales.where((sale) => sale.customerId == customer.id).toList();
        final totalSales = customerSales.length;
        final totalAmount =
            customerSales.fold(0.0, (sum, sale) => sum + sale.total);
        final outstandingBalance =
            customerSales.fold(0.0, (sum, sale) => sum + sale.due);
        final lastPurchaseDate = customerSales.isNotEmpty
            ? customerSales
                .map((s) => s.date)
                .reduce((a, b) => a.isAfter(b) ? a : b)
            : null;
        final averageOrderValue =
            totalSales > 0 ? totalAmount / totalSales : 0.0;

        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = IntCellValue(customer.id ?? 0);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(customer.name);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(customer.phone);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(''); // No notes field in CustomerModel
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = TextCellValue(customer.address ?? '');
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = IntCellValue(totalSales);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = DoubleCellValue(totalAmount);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = DoubleCellValue(outstandingBalance);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex))
            .value = TextCellValue(lastPurchaseDate !=
                null
            ? _formatDate(lastPurchaseDate)
            : 'Never');
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex))
            .value = IntCellValue(totalSales);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex))
            .value = DoubleCellValue(averageOrderValue);
        sheet
            .cell(
                CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex))
            .value = TextCellValue(outstandingBalance >
                0
            ? 'Outstanding'
            : (outstandingBalance < 0 ? 'Credit' : 'Current'));

        rowIndex++;
      }

      // Auto-fit columns
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      // Save Excel file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting customer data: $e');
    }
  }

  /// Export customer data to PDF with print option
  static Future<String> exportCustomerDataToPDF(
    List<CustomerModel> customers,
    List<SaleModel> sales,
    String filename,
  ) async {
    try {
      final pdf = pw.Document();

      // Add customer data page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(),
              pw.SizedBox(height: 20),
              _buildCustomerDataTable(customers, sales, currencySymbol: '\$'),
            ];
          },
        ),
      );

      // Save PDF file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      return filePath;
    } catch (e) {
      throw Exception('Error exporting customer data to PDF: $e');
    }
  }

  /// Print Excel/PDF file
  static Future<void> printFile(String filePath) async {
    try {
      if (filePath.endsWith('.pdf')) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async {
            final file = File(filePath);
            final bytes = await file.readAsBytes();
            return bytes;
          },
        );
      } else {
        // For Excel files, we'll convert to PDF first
        await _printExcelAsPDF(filePath);
      }
    } catch (e) {
      throw Exception('Error printing file: $e');
    }
  }

  /// Share file
  static Future<void> shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      throw Exception('Error sharing file: $e');
    }
  }

  /// Build PDF header
  static pw.Widget _buildPDFHeader() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Customer Data Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on: ${_formatDate(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Build customer data table
  static pw.Widget _buildCustomerDataTable(
      List<CustomerModel> customers, List<SaleModel> sales,
      {String currencySymbol = '\$'}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      columnWidths: {
        0: const pw.FixedColumnWidth(60),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FixedColumnWidth(80),
        6: const pw.FixedColumnWidth(80),
        7: const pw.FixedColumnWidth(80),
        8: const pw.FixedColumnWidth(100),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('ID', isHeader: true),
            _buildTableCell('Name', isHeader: true),
            _buildTableCell('Phone', isHeader: true),
            _buildTableCell('Email', isHeader: true),
            _buildTableCell('Address', isHeader: true),
            _buildTableCell('Sales', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
            _buildTableCell('Balance', isHeader: true),
            _buildTableCell('Last Purchase', isHeader: true),
          ],
        ),
        // Data rows
        ...customers.map((customer) {
          final customerSales =
              sales.where((sale) => sale.customerId == customer.id).toList();
          final totalAmount =
              customerSales.fold(0.0, (sum, sale) => sum + sale.total);
          final outstandingBalance =
              customerSales.fold(0.0, (sum, sale) => sum + sale.due);
          final lastPurchaseDate = customerSales.isNotEmpty
              ? customerSales
                  .map((s) => s.date)
                  .reduce((a, b) => a.isAfter(b) ? a : b)
              : null;

          return pw.TableRow(
            children: [
              _buildTableCell('${customer.id}'),
              _buildTableCell(customer.name),
              _buildTableCell(customer.phone),
              _buildTableCell(''), // No notes field in CustomerModel
              _buildTableCell(customer.address ?? ''),
              _buildTableCell('${customerSales.length}'),
              _buildTableCell(
                  '$currencySymbol${totalAmount.toStringAsFixed(2)}'),
              _buildTableCell(
                  '$currencySymbol${outstandingBalance.toStringAsFixed(2)}'),
              _buildTableCell(lastPurchaseDate != null
                  ? _formatDate(lastPurchaseDate)
                  : 'Never'),
            ],
          );
        }).toList(),
      ],
    );
  }

  /// Build table cell
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Print Excel as PDF
  static Future<void> _printExcelAsPDF(String excelPath) async {
    // This would require additional implementation
    // For now, we'll just show a message
    print(
        'Excel printing not implemented yet. Please use PDF export for printing.');
  }

  /// Format date
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Export IMEI sales report to Excel
  static Future<String> exportIMEISalesReport(
    List<dynamic> imeis,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['IMEI Sales'];
      excel.delete('Sheet1');

      final headers = [
        'IMEI',
        'Product Name',
        'Customer Name',
        'Sale Date',
        'Sale Amount',
        'Status',
        'Notes',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      int rowIndex = 1;
      for (final imei in imeis) {
        final imeiData = imei as Map<String, dynamic>;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['imei']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['productName']?.toString() ?? 'Unknown');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['customerName']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['saleDate']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = DoubleCellValue((imeiData['saleTotal'] as num?)?.toDouble() ?? 0.0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['status']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = TextCellValue(imeiData['notes']?.toString() ?? '');
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting IMEI sales report: $e');
    }
  }

  /// Export phone sales report to Excel
  static Future<String> exportPhoneSalesReport(
    List<MapEntry<String, Map<String, dynamic>>> sales,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Phone Sales'];
      excel.delete('Sheet1');

      final headers = [
        'Brand',
        'Model',
        'Quantity',
        'Revenue',
        'Profit',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      int rowIndex = 1;
      for (final entry in sales) {
        final data = entry.value;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(data['brand']?.toString() ?? 'Unknown');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(data['model']?.toString() ?? 'Unknown');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = IntCellValue(data['qty'] as int? ?? 0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = DoubleCellValue((data['revenue'] as num?)?.toDouble() ?? 0.0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = DoubleCellValue((data['profit'] as num?)?.toDouble() ?? 0.0);
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting phone sales report: $e');
    }
  }

  /// Export accessory sales report to Excel
  static Future<String> exportAccessorySalesReport(
    List<MapEntry<String, Map<String, dynamic>>> sales,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Accessory Sales'];
      excel.delete('Sheet1');

      final headers = [
        'Product Name',
        'Category',
        'Quantity',
        'Revenue',
        'Profit',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      int rowIndex = 1;
      for (final entry in sales) {
        final data = entry.value;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(data['name']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(data['category']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = IntCellValue(data['qty'] as int? ?? 0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = DoubleCellValue((data['revenue'] as num?)?.toDouble() ?? 0.0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = DoubleCellValue((data['profit'] as num?)?.toDouble() ?? 0.0);
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting accessory sales report: $e');
    }
  }

  /// Export stock report to Excel
  static Future<String> exportStockReport(
    List<MapEntry<String, Map<String, dynamic>>> stock,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Stock Report'];
      excel.delete('Sheet1');

      final headers = [
        'Brand',
        'Model',
        'Storage',
        'Color',
        'RAM',
        'Condition',
        'Stock',
        'Value',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      int rowIndex = 1;
      for (final entry in stock) {
        final data = entry.value;
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(data['brand']?.toString() ?? 'Unknown');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(data['model']?.toString() ?? 'Unknown');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(data['storage']?.toString() ?? 'N/A');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = TextCellValue(data['color']?.toString() ?? 'N/A');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = TextCellValue(data['ram']?.toString() ?? 'N/A');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = TextCellValue(data['condition']?.toString() ?? 'N/A');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex))
            .value = DoubleCellValue((data['stock'] as num?)?.toDouble() ?? 0.0);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex))
            .value = DoubleCellValue((data['value'] as num?)?.toDouble() ?? 0.0);
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting stock report: $e');
    }
  }

  /// Export trade-in report to Excel
  static Future<String> exportTradeInReport(
    List<dynamic> products,
    String filename, {
    String currencySymbol = '\$',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Trade-in Report'];
      excel.delete('Sheet1');

      final headers = [
        'Product Name',
        'Brand',
        'Model',
        'Stock',
        'Trade-in Value (per unit)',
        'Total Trade-in Value',
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }

      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blue,
        fontColorHex: ExcelColor.white,
        horizontalAlign: HorizontalAlign.Center,
      );

      for (int i = 0; i < headers.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = headerStyle;
      }

      int rowIndex = 1;
      for (final product in products) {
        final productData = product as Map<String, dynamic>;
        final tradeInValue = (productData['tradeInValue'] as num?)?.toDouble() ?? 0.0;
        final stock = (productData['stock'] as num?)?.toDouble() ?? 0.0;
        final totalValue = tradeInValue * stock;

        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex))
            .value = TextCellValue(productData['name']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex))
            .value = TextCellValue(productData['brand']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex))
            .value = TextCellValue(productData['modelName']?.toString() ?? '');
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex))
            .value = DoubleCellValue(stock);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex))
            .value = DoubleCellValue(tradeInValue);
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex))
            .value = DoubleCellValue(totalValue);
        rowIndex++;
      }

      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 15);
      }

      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.xlsx';
      final file = File(filePath);
      final bytes = excel.save();
      if (bytes != null) {
        await file.writeAsBytes(bytes);
        return filePath;
      }

      throw Exception('Failed to save Excel file');
    } catch (e) {
      throw Exception('Error exporting trade-in report: $e');
    }
  }
}
