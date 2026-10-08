import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart' show Value;

import '../services/database_service.dart';
import '../database/database.dart';
import '../models/customer.dart';
import '../models/bank_payment.dart';
import '../models/bank.dart';
import '../models/payment.dart';
import '../models/supplier_payment.dart';
import '../models/sale.dart';
import '../models/product.dart';

class BulkImportResult {
  final int inserted;
  final int updated;
  final int skipped;
  final List<String> errors;

  const BulkImportResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.errors,
  });
}

class BulkImportService {
  static const List<String> productHeaders = [
    'Name',
    'Category',
    'Retail Cash',
    'Cost Price',
    'Stock',
    'Barcode',
    'Unit',
    'Reorder Level',
    'Reorder Quantity',
    'Discount',
    'Tax',
    'Description'
  ];

  static const List<String> customerHeaders = [
    'Name',
    'Phone',
    'Address',
    'Opening Due'
  ];

  static const List<String> supplierHeaders = [
    'Name',
    'Phone',
    'Address',
    'Contact Person',
    'Email',
    'City',
    'State',
    'Country',
    'Zip Code',
    'Credit Limit',
    'Credit Days',
    'Payment Terms',
    'Notes'
  ];

  static const List<String> bankLedgerHeaders = [
    'Bank Name',
    'Date',
    'Payment Type',
    'Party Name',
    'Cheque Number',
    'Amount',
    'Description',
    'Status'
  ];

  static const List<String> customerLedgerHeaders = [
    'Customer Phone',
    'Date',
    'Amount',
    'Payment Method',
    'Note'
  ];

  static const List<String> supplierLedgerHeaders = [
    'Supplier Name',
    'Date',
    'Amount',
    'Payment Method',
    'Payment Type',
    'Reference',
    'Note',
    'Status'
  ];

  static Future<File?> pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      // Fallback: some desktop environments ignore custom filters; retry with FileType.any
      result ??= await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return null;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) return null;
      return File(path);
    } catch (_) {
      // Final fallback attempt without filters
      try {
        final res = await FilePicker.platform.pickFiles(allowMultiple: false);
        if (res == null || res.files.isEmpty) return null;
        final p = res.files.single.path;
        if (p == null || p.isEmpty) return null;
        return File(p);
      } catch (e) {
        return null;
      }
    }
  }

  static Future<BulkImportResult> importCustomersFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    int inserted = 0;
    int updated = 0;
    int skipped = 0;
    final errors = <String>[];

    // Validate headers
    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }
    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < customerHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() != customerHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${customerHeaders.join(', ')}'
        ]);
      }
    }

    // Rows
    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }
        final name = (row.elementAtOrNull(0)?.value?.toString() ?? '').trim();
        final phone = (row.elementAtOrNull(1)?.value?.toString() ?? '').trim();
        final address =
            (row.elementAtOrNull(2)?.value?.toString() ?? '').trim();
        final openingDueStr =
            (row.elementAtOrNull(3)?.value?.toString() ?? '0').trim();

        if (name.isEmpty) {
          skipped++;
          continue;
        }

        final openingDue =
            double.tryParse(openingDueStr.replaceAll(',', '')) ?? 0.0;

        // Check if customer exists by phone (primary unique heuristic here)
        final existing = await databaseService.getCustomerByPhone(phone);
        if (existing == null) {
          final newCustomer = CustomerModel(
            id: null,
            name: name,
            phone: phone.isEmpty ? '-' : phone,
            address: address.isEmpty ? null : address,
            creditLimit: 0,
            creditDays: 0,
            totalDue: openingDue,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await databaseService.insertCustomer(newCustomer);
          inserted++;
        } else {
          final updatedCustomer = existing.copyWith(
            name: name,
            phone: phone.isEmpty ? '-' : phone,
            address: address.isEmpty ? null : address,
            totalDue: openingDue > 0 ? openingDue : existing.totalDue,
            updatedAt: DateTime.now(),
          );
          await databaseService.updateCustomer(updatedCustomer);
          updated++;
        }
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: updated, skipped: skipped, errors: errors);
  }

  static Future<BulkImportResult> importSuppliersFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    int inserted = 0;
    int updated = 0;
    int skipped = 0;
    final errors = <String>[];

    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }
    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < supplierHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() != supplierHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${supplierHeaders.join(', ')}'
        ]);
      }
    }

    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }
        String val(int idx) =>
            (row.elementAtOrNull(idx)?.value?.toString() ?? '').trim();

        final name = val(0);
        final phone = val(1);
        final address = val(2);
        final contactPerson = val(3);
        final email = val(4);
        final city = val(5);
        final state = val(6);
        final country = val(7);
        final zip = val(8);
        final creditLimit = double.tryParse(val(9)) ?? 0.0;
        final creditDays = int.tryParse(val(10)) ?? 0;
        final paymentTerms = val(11);
        final notes = val(12);

        if (name.isEmpty) {
          skipped++;
          continue;
        }

        // No direct supplier lookup by phone; fetch all and match
        final all = await databaseService.getAllSuppliers();
        Supplier? existing;
        for (final s in all) {
          if (s.name.toLowerCase() == name.toLowerCase() ||
              s.phone.trim() == phone) {
            existing = s;
            break;
          }
        }

        final contactPersonSafe = contactPerson.isEmpty ? '-' : contactPerson;
        final phoneSafe = phone.isEmpty ? '-' : phone;
        final paymentTermsSafe = paymentTerms.isEmpty ? '' : paymentTerms;

        if (existing == null) {
          final comp = SuppliersCompanion(
            name: Value(name),
            contactPerson: Value(contactPersonSafe),
            phone: Value(phoneSafe),
            email: Value(email.isEmpty ? null : email),
            address: Value(address.isEmpty ? null : address),
            city: Value(city.isEmpty ? null : city),
            state: Value(state.isEmpty ? null : state),
            country: Value(country.isEmpty ? null : country),
            zipCode: Value(zip.isEmpty ? null : zip),
            creditLimit: Value(creditLimit),
            currentBalance: const Value(0.0),
            creditDays: Value(creditDays),
            unclearCheque: const Value(0.0),
            paymentTerms: Value(paymentTermsSafe),
            notes: Value(notes.isEmpty ? null : notes),
            isActive: const Value(true),
            createdAt: Value(DateTime.now().toIso8601String()),
            updatedAt: Value(DateTime.now().toIso8601String()),
          );
          await databaseService.insertSupplier(comp);
          inserted++;
        } else {
          final updatedSupplier = existing.copyWith(
            name: name,
            contactPerson: contactPersonSafe,
            phone: phoneSafe,
            email: email.isEmpty ? const Value.absent() : Value(email),
            address: address.isEmpty ? const Value.absent() : Value(address),
            city: city.isEmpty ? const Value.absent() : Value(city),
            state: state.isEmpty ? const Value.absent() : Value(state),
            country: country.isEmpty ? const Value.absent() : Value(country),
            zipCode: zip.isEmpty ? const Value.absent() : Value(zip),
            creditLimit: creditLimit,
            creditDays: creditDays,
            paymentTerms: paymentTermsSafe,
            notes: notes.isEmpty ? const Value.absent() : Value(notes),
            updatedAt: DateTime.now().toIso8601String(),
          );
          await databaseService.updateSupplier(updatedSupplier);
          updated++;
        }
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: updated, skipped: skipped, errors: errors);
  }

  static Future<BulkImportResult> importProductsFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    int inserted = 0;
    int updated = 0;
    int skipped = 0;
    final errors = <String>[];

    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }

    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < productHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() != productHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${productHeaders.join(', ')}'
        ]);
      }
    }

    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }

        String val(int idx) =>
            (row.elementAtOrNull(idx)?.value?.toString() ?? '').trim();

        final name = val(0);
        final category = val(1);
        final price = double.tryParse(val(2).replaceAll(',', '')) ?? 0.0;
        final cost = double.tryParse(val(3).replaceAll(',', '')) ?? 0.0;
        final stock = double.tryParse(val(4).replaceAll(',', '')) ?? 0.0;
        final barcode = val(5);
        final unit = val(6).isEmpty ? 'pcs' : val(6);
        final reorderLevel = double.tryParse(val(7).replaceAll(',', '')) ?? 10.0;
        final reorderQuantity =
            double.tryParse(val(8).replaceAll(',', '')) ?? 50.0;
        final discount = double.tryParse(val(9).replaceAll(',', '')) ?? 0.0;
        final tax = double.tryParse(val(10).replaceAll(',', '')) ?? 0.0;
        final description = val(11);

        if (name.isEmpty) {
          errors.add('Row ${r + 1}: skipped - Name is required');
          skipped++;
          continue;
        }
        if (category.isEmpty) {
          errors.add('Row ${r + 1}: skipped - Category is required ("$name")');
          skipped++;
          continue;
        }
        if (price < 0 || cost < 0) {
          errors.add(
              'Row ${r + 1}: skipped - Retail Cash/Cost Price cannot be negative ("$name")');
          skipped++;
          continue;
        }

        ProductModel? existing;
        ProductModel? barcodeMatch;
        if (barcode.isNotEmpty) {
          barcodeMatch = await databaseService.getProductByBarcode(barcode);
        }
        if (barcodeMatch != null) {
          // Only trust the barcode match if it's plausibly the same product
          // (same name). Otherwise this barcode is a duplicate/typo pointing
          // at an unrelated product — importing must never silently
          // overwrite that unrelated product's data.
          if (barcodeMatch.name.trim().toLowerCase() ==
              name.trim().toLowerCase()) {
            existing = barcodeMatch;
          } else {
            errors.add(
                'Row ${r + 1}: skipped - Barcode "$barcode" is already used by a different product ("${barcodeMatch.name}"). Fix the barcode or leave it blank.');
            skipped++;
            continue;
          }
        } else {
          existing = await databaseService.getProductByName(name);
          if (existing != null &&
              existing.category.toLowerCase() != category.toLowerCase()) {
            existing = null;
          }
        }

        if (existing == null) {
          final product = ProductModel(
            id: null,
            name: name,
            category: category,
            price: price,
            cost: cost,
            stock: stock,
            barcode: barcode.isEmpty ? null : barcode,
            unit: unit,
            discount: discount,
            tax: tax,
            reorderLevel: reorderLevel,
            reorderQuantity: reorderQuantity,
            description: description.isEmpty ? null : description,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await databaseService.insertProduct(product);
          inserted++;
        } else {
          final updatedProduct = existing.copyWith(
            name: name,
            category: category,
            price: price,
            cost: cost,
            stock: stock,
            barcode: barcode.isEmpty ? null : barcode,
            unit: unit,
            discount: discount,
            tax: tax,
            reorderLevel: reorderLevel,
            reorderQuantity: reorderQuantity,
            description: description.isEmpty ? null : description,
            updatedAt: DateTime.now(),
          );
          await databaseService.updateProduct(updatedProduct);
          updated++;
        }
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: updated, skipped: skipped, errors: errors);
  }

  /// Export all products to an Excel file using the same column layout as
  /// [productHeaders]/[importProductsFromExcel], so the exported file can be
  /// edited and re-imported directly.
  static Future<String> exportProductsToExcel(
      List<ProductModel> products, String filename) async {
    final excel = Excel.createExcel();
    final sheet = excel['Products'];
    excel.delete('Sheet1');

    for (int i = 0; i < productHeaders.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(productHeaders[i]);
    }
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );
    for (int i = 0; i < productHeaders.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    int rowIndex = 1;
    for (final product in products) {
      final values = [
        product.name,
        product.category,
        product.price.toString(),
        product.cost.toString(),
        product.stock.toString(),
        product.barcode ?? '',
        product.unit,
        product.reorderLevel.toString(),
        product.reorderQuantity.toString(),
        product.discount.toString(),
        product.tax.toString(),
        product.description ?? '',
      ];
      for (int i = 0; i < values.length; i++) {
        sheet
            .cell(CellIndex.indexByColumnRow(
                columnIndex: i, rowIndex: rowIndex))
            .value = TextCellValue(values[i]);
      }
      rowIndex++;
    }

    for (int i = 0; i < productHeaders.length; i++) {
      sheet.setColumnWidth(i, 16);
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename.xlsx';
    final file = File(filePath);
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file');
    }
    await file.writeAsBytes(bytes);
    return filePath;
  }

  static Future<BulkImportResult> importBankLedgerFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    int inserted = 0;
    int skipped = 0;
    final errors = <String>[];

    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }
    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < bankLedgerHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() != bankLedgerHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${bankLedgerHeaders.join(', ')}'
        ]);
      }
    }

    final banks = await databaseService.getAllBanks();

    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }
        String val(int idx) =>
            (row.elementAtOrNull(idx)?.value?.toString() ?? '').trim();

        final bankName = val(0);
        final dateStr = val(1);
        final paymentType = val(2).toLowerCase(); // deposit, withdraw, cheque
        final partyName = val(3);
        final chequeNumber = val(4);
        final amount = double.tryParse(val(5).replaceAll(',', '')) ?? 0.0;
        final description = val(6);
        final status = (val(7).isEmpty ? 'cleared' : val(7))
            .toLowerCase(); // cleared|unclear|cancelled

        if (bankName.isEmpty || amount <= 0) {
          skipped++;
          continue;
        }
        final bank = banks.firstWhere(
          (b) => b.name.toLowerCase() == bankName.toLowerCase(),
          orElse: () => BankModel(
            id: null,
            name: '',
            code: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (bank.id == null) {
          errors.add('Row ${r + 1}: Bank "$bankName" not found');
          continue;
        }

        DateTime? date;
        try {
          date = DateTime.tryParse(dateStr);
          date ??= _excelDateToDateTime(row.elementAtOrNull(1)?.value);
        } catch (_) {}
        date ??= DateTime.now();

        final typeNormalized =
            paymentType == 'deposit' || paymentType == 'cheque'
                ? paymentType
                : 'withdraw';
        final statusNormalized =
            ['cleared', 'unclear', 'cancelled'].contains(status)
                ? status
                : 'cleared';

        final prev = bank.currentBalance;
        final delta = typeNormalized == 'withdraw' ? -amount : amount;
        final model = BankPaymentModel(
          id: null,
          bankId: bank.id!,
          partyName: partyName.isEmpty ? 'N/A' : partyName,
          amount: amount,
          chequeNumber: chequeNumber.isEmpty ? null : chequeNumber,
          notes: description.isEmpty ? null : description,
          paymentType: typeNormalized,
          status: statusNormalized,
          issueDate: date,
          paidDate: date,
          previousBalance: prev,
          newBalance: prev + delta,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await databaseService.insertBankPayment(model);
        inserted++;
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: 0, skipped: skipped, errors: errors);
  }

  static DateTime? _excelDateToDateTime(dynamic value) {
    if (value is num) {
      final epoch = DateTime(1899, 12, 30);
      return epoch.add(Duration(
          days: value.floor(),
          milliseconds: (((value % 1) * 86400000)).round()));
    }
    return null;
  }

  static Future<BulkImportResult> importCustomerLedgerFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    // Use service methods to fetch customers via existing APIs
    final allCustomers = await databaseService.getAllCustomers();

    int inserted = 0;
    int skipped = 0;
    final errors = <String>[];

    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }
    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < customerLedgerHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() !=
              customerLedgerHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${customerLedgerHeaders.join(', ')}'
        ]);
      }
    }

    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }
        String val(int idx) =>
            (row.elementAtOrNull(idx)?.value?.toString() ?? '').trim();

        final phone = val(0);
        final dateStr = val(1);
        final amount = double.tryParse(val(2).replaceAll(',', '')) ?? 0.0;
        final methodStr = val(3).toLowerCase();
        final note = val(4);

        if (phone.isEmpty || amount <= 0) {
          skipped++;
          continue;
        }
        final customer = allCustomers.firstWhere(
          (c) => c.phone.trim() == phone,
          orElse: () => CustomerModel(
              id: null,
              name: '',
              phone: '',
              address: null,
              creditLimit: 0,
              creditDays: 0,
              totalDue: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now()),
        );
        if (customer.id == null) {
          errors.add('Row ${r + 1}: Customer with phone "$phone" not found');
          continue;
        }

        DateTime? date;
        date = DateTime.tryParse(dateStr) ??
            _excelDateToDateTime(row.elementAtOrNull(1)?.value) ??
            DateTime.now();

        final method = [
          'cash',
          'card',
          'banktransfer',
          'bank_transfer',
          'cheque'
        ].contains(methodStr)
            ? (methodStr == 'banktransfer'
                ? 'bankTransfer'
                : methodStr.replaceAll('_', ''))
            : 'cash';

        final model = PaymentModel(
          id: null,
          customerId: customer.id!,
          amount: amount,
          date: date,
          note: note.isEmpty ? null : note,
          paymentMethod: PaymentMethod.values.firstWhere(
            (m) => m.name.toLowerCase() == method.toLowerCase(),
            orElse: () => PaymentMethod.cash,
          ),
          createdAt: DateTime.now(),
        );
        await databaseService.insertPayment(model);
        inserted++;
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: 0, skipped: skipped, errors: errors);
  }

  static Future<BulkImportResult> importSupplierLedgerFromExcel(
      DatabaseService databaseService, File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet =
        excel.tables.values.isNotEmpty ? excel.tables.values.first : null;
    if (sheet == null) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['No sheet found']);
    }

    final suppliers = await databaseService.getAllSuppliers();

    int inserted = 0;
    int skipped = 0;
    final errors = <String>[];

    if (sheet.maxRows == 0) {
      return const BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: ['Empty sheet']);
    }
    final headerRow =
        sheet.row(0).map((c) => (c?.value?.toString() ?? '').trim()).toList();
    for (int i = 0; i < supplierLedgerHeaders.length; i++) {
      if (i >= headerRow.length ||
          headerRow[i].toLowerCase() !=
              supplierLedgerHeaders[i].toLowerCase()) {
        return BulkImportResult(inserted: 0, updated: 0, skipped: 0, errors: [
          'Invalid headers. Expected: ${supplierLedgerHeaders.join(', ')}'
        ]);
      }
    }

    for (int r = 1; r < sheet.maxRows; r++) {
      try {
        final row = sheet.row(r);
        if (row.isEmpty) {
          skipped++;
          continue;
        }
        String val(int idx) =>
            (row.elementAtOrNull(idx)?.value?.toString() ?? '').trim();

        final supplierName = val(0);
        final dateStr = val(1);
        final amount = double.tryParse(val(2).replaceAll(',', '')) ?? 0.0;
        final paymentMethod =
            val(3).toLowerCase(); // cash, bank_transfer, cheque
        final paymentType = val(4).toLowerCase(); // payment, refund, adjustment
        final reference = val(5);
        final note = val(6);
        final status = (val(7).isEmpty ? 'completed' : val(7)).toLowerCase();

        if (supplierName.isEmpty || amount <= 0) {
          skipped++;
          continue;
        }
        Supplier? supplier;
        for (final s in suppliers) {
          if (s.name.toLowerCase() == supplierName.toLowerCase()) {
            supplier = s;
            break;
          }
        }
        if (supplier == null) {
          errors.add('Row ${r + 1}: Supplier "$supplierName" not found');
          continue;
        }

        DateTime date = DateTime.tryParse(dateStr) ??
            _excelDateToDateTime(row.elementAtOrNull(1)?.value) ??
            DateTime.now();
        final normalizedMethod =
            paymentMethod == 'banktransfer' ? 'bank_transfer' : paymentMethod;
        final normalizedType =
            ['payment', 'refund', 'adjustment'].contains(paymentType)
                ? paymentType
                : 'payment';
        final normalizedStatus =
            ['completed', 'pending', 'cancelled'].contains(status)
                ? status
                : 'completed';

        final model = SupplierPaymentModel(
          id: null,
          supplierId: supplier.id,
          amount: amount,
          paymentMethod: normalizedMethod,
          paymentType: normalizedType,
          date: date,
          reference: reference.isEmpty ? null : reference,
          note: note.isEmpty ? null : note,
          status: normalizedStatus,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await databaseService.insertSupplierPayment(model);
        inserted++;
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: inserted, updated: 0, skipped: skipped, errors: errors);
  }

  /// Import customer ledger from text/CSV format
  /// Format: CUSTOMER | Customer Name | Date | Invoice Number | Type | Debit | Credit
  static Future<BulkImportResult> importCustomerLedgerFromText(
      DatabaseService databaseService, String textData) async {
    int salesInserted = 0;
    int paymentsInserted = 0;
    int skipped = 0;
    final errors = <String>[];

    // Get or create a dummy product for sales (if needed)
    // Using a very specific name that won't interfere with normal operations
    ProductModel? dummyProduct;
    try {
      dummyProduct = await databaseService.getProductByName('LEGACY-IMPORT-ITEM-DO-NOT-USE');
      if (dummyProduct == null) {
        // Create a dummy product for legacy sales with very specific naming
        // This product is only used internally for legacy data migration
        dummyProduct = ProductModel(
          id: null,
          name: 'LEGACY-IMPORT-ITEM-DO-NOT-USE',
          barcode: 'LEGACY-IMPORT-SYSTEM-ONLY',
          category: 'SYSTEM-LEGACY-IMPORT',
          price: 0.0,
          cost: 0.0,
          stock: 999999.0,
          unit: 'pcs',
          description: 'System product for legacy data import only. Do not use in sales.',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final productId = await databaseService.insertProduct(dummyProduct);
        dummyProduct = dummyProduct.copyWith(id: productId);
      }
    } catch (e) {
      errors.add('Failed to get/create dummy product: $e');
      return BulkImportResult(
          inserted: 0, updated: 0, skipped: 0, errors: errors);
    }

    final allCustomers = await databaseService.getAllCustomers();
    final lines = textData.split('\n').where((l) => l.trim().isNotEmpty).toList();

    for (int r = 0; r < lines.length; r++) {
      try {
        final line = lines[r].trim();
        if (line.isEmpty || line.startsWith('CUSTOMER') && r == 0) {
          // Skip header or empty lines
          continue;
        }

        // Parse tab or space-separated values (handle multiple spaces/tabs)
        // First try splitting by tab, then by multiple spaces
        List<String> parts;
        if (line.contains('\t')) {
          parts = line.split('\t').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        } else {
          parts = line.split(RegExp(r'\s{2,}')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
        }
        
        if (parts.length < 6) {
          skipped++;
          continue;
        }

        // Format: CUSTOMER | Customer Name | Date | Invoice Number | Type | Debit | Credit
        // Skip first column if it's "CUSTOMER"
        int startIdx = parts[0].toUpperCase() == 'CUSTOMER' ? 1 : 0;
        if (parts.length - startIdx < 6) {
          skipped++;
          continue;
        }

        final customerName = parts.length > startIdx ? parts[startIdx].trim() : '';
        final dateStr = parts.length > startIdx + 1 ? parts[startIdx + 1].trim() : '';
        final invoiceNumber = parts.length > startIdx + 2 ? parts[startIdx + 2].trim() : '';
        final type = parts.length > startIdx + 3 ? parts[startIdx + 3].trim().toUpperCase() : '';
        final debitStr = parts.length > startIdx + 4 ? parts[startIdx + 4].trim().replaceAll(',', '').replaceAll(' ', '') : '0';
        final creditStr = parts.length > startIdx + 5 ? parts[startIdx + 5].trim().replaceAll(',', '').replaceAll(' ', '') : '0';

        if (customerName.isEmpty || invoiceNumber.isEmpty) {
          skipped++;
          continue;
        }

        // Find or create customer
        CustomerModel? customer = allCustomers.firstWhere(
          (c) => c.name.trim().toLowerCase() == customerName.trim().toLowerCase(),
          orElse: () => CustomerModel(
            id: null,
            name: '',
            phone: '',
            address: null,
            creditLimit: 0,
            creditDays: 0,
            totalDue: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (customer.id == null) {
          // Create customer
          final newCustomer = CustomerModel(
            id: null,
            name: customerName,
            phone: '0000000', // Default phone
            address: null,
            creditLimit: 0,
            creditDays: 0,
            totalDue: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          final customerId = await databaseService.insertCustomer(newCustomer);
          customer = newCustomer.copyWith(id: customerId);
          allCustomers.add(customer);
        }

        // Parse date (handle multiple formats: 05/01/2023, 13-05-2023)
        DateTime? date = _parseFlexibleDate(dateStr);
        if (date == null) {
          errors.add('Row ${r + 1}: Invalid date format: $dateStr');
          skipped++;
          continue;
        }

        // Parse amounts (handle "-", parentheses for negative, and commas)
        // Handle parentheses as negative: (58,250.00) = -58250.00
        bool isDebitNegative = debitStr.trim().startsWith('(') && debitStr.trim().endsWith(')');
        bool isCreditNegative = creditStr.trim().startsWith('(') && creditStr.trim().endsWith(')');
        
        final cleanDebitStr = debitStr
            .replaceAll(',', '')
            .replaceAll('(', '')
            .replaceAll(')', '')
            .replaceAll('-', '')
            .trim();
        final cleanCreditStr = creditStr
            .replaceAll(',', '')
            .replaceAll('(', '')
            .replaceAll(')', '')
            .replaceAll('-', '')
            .trim();
        
        double debit = cleanDebitStr.isEmpty || cleanDebitStr == '-' ? 0.0 : (double.tryParse(cleanDebitStr) ?? 0.0);
        double credit = cleanCreditStr.isEmpty || cleanCreditStr == '-' ? 0.0 : (double.tryParse(cleanCreditStr) ?? 0.0);
        
        // Apply negative sign if parentheses were present
        if (isDebitNegative) debit = -debit;
        if (isCreditNegative) credit = -credit;
        
        // Determine amount and type
        // If credit is negative, it's actually a debit (reversal/adjustment)
        // If debit is negative, it's actually a credit (reversal/adjustment)
        double amount = 0.0;
        bool isReversal = false;
        
        if (debit > 0) {
          amount = debit;
        } else if (credit > 0) {
          amount = credit;
        } else if (debit < 0) {
          // Negative debit = credit entry (reversal)
          amount = debit.abs();
          isReversal = true;
        } else if (credit < 0) {
          // Negative credit = debit entry (reversal)
          amount = credit.abs();
          isReversal = true;
        }

        if (amount <= 0) {
          skipped++;
          continue;
        }

        final normalizedType = type.replaceAll('_', ' ').trim().toUpperCase();
        final normalizedInvoice = invoiceNumber.trim().toUpperCase();

        final bool isSaleType =
            normalizedType == 'SALES' || normalizedType == 'SALE' || normalizedInvoice.startsWith('SI-');
        final bool isGeneralVoucher =
            normalizedType.contains('GENERAL VOUCHER') || normalizedInvoice.startsWith('JV-');
        final bool isCashReceipt =
            normalizedType.contains('CASH RECEIPT') || normalizedInvoice.startsWith('CRV-');
        final bool isBankBook =
            normalizedType.contains('BANK BOOK') || normalizedInvoice.startsWith('BV-');
        final bool isPaymentTransfer =
            normalizedType.contains('PAYMENT TRANSFER') || normalizedInvoice.startsWith('PV-');
        final bool isPurchaseProduct =
            normalizedType.contains('PURCHASES-PRODUCT') || normalizedInvoice.startsWith('PI/');
        final bool isPaymentType = isGeneralVoucher || isCashReceipt || isBankBook || isPaymentTransfer;

        // Handle different transaction types
        if (isSaleType) {
          // Create a sale record (or reversal if amount is negative)
          if (isReversal && amount > 0) {
            // Negative entry in sales = payment/adjustment
            PaymentMethod paymentMethod = PaymentMethod.cash;
            final payment = PaymentModel(
              id: null,
              customerId: customer.id!,
              amount: amount,
              date: date,
              note: 'Legacy Import (Reversal): $invoiceNumber ($type)',
              paymentMethod: paymentMethod,
              createdAt: date,
            );
            await databaseService.insertPayment(payment);
            paymentsInserted++;
          } else {
            final sale = SaleModel(
              id: null,
              date: date,
              total: amount,
              discount: 0,
              paid: 0, // Will be updated by payments
              due: amount,
              customerId: customer.id,
              cashierId: null,
              paymentType: PaymentType.credit, // Legacy sales are typically credit
              status: SaleStatus.unpaid,
              dueDate: null,
              isWholesale: false,
              notes: 'Legacy Import: $invoiceNumber',
              createdAt: date,
              items: [
                SaleItemModel(
                  saleId: 0,
                  productId: dummyProduct.id!,
                  qty: 1.0,
                  price: amount,
                  subtotal: amount,
                  discount: 0,
                  createdAt: date,
                ),
              ],
            );
            await databaseService.insertSale(sale);
            salesInserted++;
          }
        } else if (isPaymentType) {
          // Create a payment record
          // If credit is negative (in parentheses), it's a reversal - create a sale instead
          if (isReversal && credit < 0 && debit == 0) {
            // Negative credit = debit entry = sale/adjustment (reversal of payment)
            final sale = SaleModel(
              id: null,
              date: date,
              total: amount,
              discount: 0,
              paid: 0,
              due: amount,
              customerId: customer.id,
              cashierId: null,
              paymentType: PaymentType.credit,
              status: SaleStatus.unpaid,
              dueDate: null,
              isWholesale: false,
              notes: 'Legacy Import (Reversal): $invoiceNumber ($type)',
              createdAt: date,
              items: [
                SaleItemModel(
                  saleId: 0,
                  productId: dummyProduct.id!,
                  qty: 1.0,
                  price: amount,
                  subtotal: amount,
                  discount: 0,
                  createdAt: date,
                ),
              ],
            );
            await databaseService.insertSale(sale);
            salesInserted++;
          } else {
            PaymentMethod paymentMethod;
            if (isCashReceipt) {
              paymentMethod = PaymentMethod.cash;
            } else if (isBankBook || isPaymentTransfer || isGeneralVoucher) {
              paymentMethod = PaymentMethod.bankTransfer;
            } else {
              paymentMethod = PaymentMethod.cash;
            }

            final payment = PaymentModel(
              id: null,
              customerId: customer.id!,
              amount: amount,
              date: date,
              note: 'Legacy Import: $invoiceNumber ($type)',
              paymentMethod: paymentMethod,
              createdAt: date,
            );
            await databaseService.insertPayment(payment);
            paymentsInserted++;
          }
        } else if (isPurchaseProduct) {
          // Skip purchase orders for now - would need supplier info
          skipped++;
        } else {
          // Unknown type - skip
          skipped++;
        }
      } catch (e) {
        errors.add('Row ${r + 1}: $e');
      }
    }

    return BulkImportResult(
        inserted: salesInserted + paymentsInserted,
        updated: 0,
        skipped: skipped,
        errors: errors);
  }

  /// Parse date from multiple formats: 05/01/2023, 13-05-2023, etc.
  static DateTime? _parseFlexibleDate(String dateStr) {
    if (dateStr.isEmpty) return null;

    // Try ISO format first
    DateTime? date = DateTime.tryParse(dateStr);
    if (date != null) return date;

    // Try DD/MM/YYYY (most common in the data)
    final slashParts = dateStr.split('/');
    if (slashParts.length == 3) {
      try {
        final day = int.parse(slashParts[0].trim());
        final month = int.parse(slashParts[1].trim());
        final year = int.parse(slashParts[2].trim());
        // Assume DD/MM/YYYY format (e.g., 05/01/2023 = 5th Jan 2023)
        if (year > 1900 && year < 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    // Try DD-MM-YYYY (e.g., 13-05-2023 = 13th May 2023)
    final dashParts = dateStr.split('-');
    if (dashParts.length == 3) {
      try {
        final day = int.parse(dashParts[0].trim());
        final month = int.parse(dashParts[1].trim());
        final year = int.parse(dashParts[2].trim());
        if (year > 1900 && year < 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          return DateTime(year, month, day);
        }
      } catch (_) {}
    }

    return null;
  }
}

extension _SafeElementAt<T> on List<T?> {
  T? elementAtOrNull(int index) =>
      index >= 0 && index < length ? this[index] : null;
}
