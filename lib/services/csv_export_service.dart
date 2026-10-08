import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sale.dart';
import '../models/customer.dart';
import '../models/product.dart';

class CsvExportService {
  /// Export sales data to CSV
  static Future<String> exportSalesToCsv(
    List<SaleModel> sales,
    String filename,
  ) async {
    try {
      final List<List<dynamic>> csvData = [];

      // Headers
      csvData.add([
        'Order ID',
        'Date',
        'Customer Name',
        'Customer Phone',
        'Items Count',
        'Total Amount',
        'Paid Amount',
        'Due Amount',
        'Payment Type',
        'Status',
        'Item Details',
      ]);

      // Data rows
      for (final sale in sales) {
        final itemDetails = sale.items.map((item) {
          final productName = item.product?.name ?? 'Unknown Product';
          final qty = item.qty.toStringAsFixed(0);
          final price = item.price.toStringAsFixed(2);
          final subtotal = item.subtotal.toStringAsFixed(2);
          return '$productName (Qty: $qty, Price: $price, Total: $subtotal)';
        }).join('; ');

        csvData.add([
          sale.id ?? 0,
          sale.date.toIso8601String(),
          sale.customer?.name ?? 'Walk-in',
          sale.customer?.phone ?? '',
          sale.items.length,
          sale.total.toStringAsFixed(2),
          sale.paid.toStringAsFixed(2),
          sale.due.toStringAsFixed(2),
          sale.paymentType.name.toUpperCase(),
          sale.status.name.toUpperCase(),
          itemDetails,
        ]);
      }

      // Convert to CSV string
      const converter = ListToCsvConverter();
      final csvString = converter.convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      return filePath;
    } catch (e) {
      throw Exception('Error exporting sales to CSV: $e');
    }
  }

  /// Export customer data to CSV
  static Future<String> exportCustomersToCsv(
    List<CustomerModel> customers,
    List<SaleModel> sales,
    String filename,
  ) async {
    try {
      final List<List<dynamic>> csvData = [];

      // Headers
      csvData.add([
        'Customer ID',
        'Name',
        'Phone',
        'Address',
        'Total Sales',
        'Total Amount',
        'Outstanding Balance',
        'Last Purchase Date',
        'Total Orders',
        'Average Order Value',
        'Status',
      ]);

      // Data rows
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

        csvData.add([
          customer.id ?? 0,
          customer.name,
          customer.phone,
          customer.address ?? '',
          totalSales,
          totalAmount.toStringAsFixed(2),
          outstandingBalance.toStringAsFixed(2),
          lastPurchaseDate?.toIso8601String() ?? 'Never',
          totalSales,
          averageOrderValue.toStringAsFixed(2),
          outstandingBalance > 0
              ? 'Outstanding'
              : (outstandingBalance < 0 ? 'Credit' : 'Current'),
        ]);
      }

      // Convert to CSV string
      const converter = ListToCsvConverter();
      final csvString = converter.convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      return filePath;
    } catch (e) {
      throw Exception('Error exporting customers to CSV: $e');
    }
  }

  /// Export products data to CSV
  static Future<String> exportProductsToCsv(
    List<ProductModel> products,
    String filename,
  ) async {
    try {
      final List<List<dynamic>> csvData = [];

      // Headers
      csvData.add([
        'Product ID',
        'Name',
        'Category',
        'Barcode',
        'Stock',
        'Unit',
        'Cost Price',
        'Sale Price',
        'Profit Margin',
        'Reorder Level',
        'Status',
        'Created Date',
      ]);

      // Data rows
      for (final product in products) {
        final profitMargin = product.price > 0 && product.cost > 0
            ? ((product.price - product.cost) / product.price * 100)
                .toStringAsFixed(2)
            : '0.00';

        csvData.add([
          product.id ?? 0,
          product.name,
          product.category,
          product.barcode ?? '',
          product.stock.toStringAsFixed(2),
          product.unit,
          product.cost.toStringAsFixed(2),
          product.price.toStringAsFixed(2),
          '$profitMargin%',
          product.reorderLevel.toStringAsFixed(2),
          product.stock <= 0 ? 'Out of Stock' : 'In Stock',
          product.createdAt.toIso8601String(),
        ]);
      }

      // Convert to CSV string
      const converter = ListToCsvConverter();
      final csvString = converter.convert(csvData);

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename.csv';
      final file = File(filePath);
      await file.writeAsString(csvString);

      return filePath;
    } catch (e) {
      throw Exception('Error exporting products to CSV: $e');
    }
  }

  /// Share CSV file
  static Future<void> shareCsvFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      throw Exception('Error sharing CSV file: $e');
    }
  }
}
