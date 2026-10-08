import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';

class WindowsBackupService {
  static const String _backupFolderName = 'posbackup';
  static const String _backupPrefix = 'pos_backup_';
  static const int _maxBackupDays = 30; // Keep backups for 30 days
  static const int _backupIntervalHours = 2; // Auto-backup every 2 hours
  static Timer? _backupTimer;
  static bool _isBackupInProgress = false;

  /// Initialize automatic backup system
  static Future<void> initializeAutoBackup(AppDatabase database) async {
    try {
      // Create primary backup directory (Documents)
      await _createBackupDirectory();

      // Create secondary backup directories (alternative drives)
      final secondaryLocations = await _createSecondaryBackupDirectories();
      if (secondaryLocations.isNotEmpty) {
        print(
            '✅ Created ${secondaryLocations.length} secondary backup location(s)');
      }

      // Check if auto backup is enabled
      final prefs = await SharedPreferences.getInstance();
      final isAutoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;

      if (isAutoBackupEnabled) {
        await _scheduleTwoHourlyBackup(database);
      }

      print('✅ Windows backup service initialized');
    } catch (e) {
      print('❌ Error initializing backup service: $e');
    }
  }

  /// Create backup directory in Documents (Primary location)
  static Future<String> _createBackupDirectory() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(documentsDir.path, _backupFolderName));

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        print('📁 Created primary backup directory: ${backupDir.path}');
      }

      return backupDir.path;
    } catch (e) {
      print('❌ Error creating primary backup directory: $e');
      rethrow;
    }
  }

  /// Get primary backup directory path (Documents folder)
  static Future<String> getBackupDirectory() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return p.join(documentsDir.path, _backupFolderName);
  }

  /// Get available secondary backup locations (different drives on Windows)
  static Future<List<String>> _getSecondaryBackupLocations() async {
    final locations = <String>[];

    if (Platform.isWindows) {
      // Check for D: and E: drives (and F:, G: as alternatives)
      // Priority order: D:, E:, F:, G:
      for (final drive in ['D:', 'E:', 'F:', 'G:']) {
        try {
          if (await _isDriveAccessible(drive)) {
            final drivePath = p.join(drive, _backupFolderName);
            locations.add(drivePath);
            print('✅ Found accessible secondary drive: $drive');
            // Use first two available drives for redundancy
            if (locations.length >= 2) {
              break;
            }
          }
        } catch (e) {
          // Drive not accessible, skip it
          print('⚠️ Drive $drive not accessible: $e');
        }
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      // For macOS/Linux, try to find alternative volumes/mounts
      try {
        // Check for /Volumes on macOS or /mnt on Linux
        final volumesPath = Platform.isMacOS ? '/Volumes' : '/mnt';
        final volumesDir = Directory(volumesPath);

        if (await volumesDir.exists()) {
          final volumes = await volumesDir.list().toList();
          for (final volume in volumes) {
            if (volume is Directory && locations.length < 2) {
              try {
                final volumePath = volume.path;
                // Check if we can write to this volume
                if (await _isDriveAccessible(volumePath)) {
                  final backupPath = p.join(volumePath, _backupFolderName);
                  locations.add(backupPath);
                  print('✅ Found accessible secondary volume: $volumePath');
                }
              } catch (e) {
                // Volume not writable, skip
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ Error checking secondary volumes: $e');
      }
    }

    return locations;
  }

  /// Check if a drive/volume is accessible and writable
  static Future<bool> _isDriveAccessible(String drivePath) async {
    try {
      final driveDir = Directory(drivePath);
      if (!await driveDir.exists()) {
        return false;
      }

      // Try to create a test file to verify write access
      final testFile = File(p.join(drivePath,
          '.pos_backup_test_${DateTime.now().millisecondsSinceEpoch}'));
      try {
        await testFile.writeAsString('test');
        await testFile.delete();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Create secondary backup directories
  static Future<List<String>> _createSecondaryBackupDirectories() async {
    final locations = await _getSecondaryBackupLocations();
    final createdLocations = <String>[];

    for (final location in locations) {
      try {
        final backupDir = Directory(location);
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
          print('📁 Created secondary backup directory: $location');
        }
        createdLocations.add(location);
      } catch (e) {
        print('⚠️ Error creating secondary backup directory $location: $e');
        // Continue with other locations
      }
    }

    return createdLocations;
  }

  /// Schedule backup to run every 2 hours
  static Future<void> _scheduleTwoHourlyBackup(AppDatabase database) async {
    try {
      // Cancel existing timer
      _backupTimer?.cancel();

      // Run immediately if last backup was more than interval ago
      final prefs = await SharedPreferences.getInstance();
      final lastBackupStr = prefs.getString('last_backup_time');
      final now = DateTime.now();
      DateTime? lastBackup =
          lastBackupStr != null ? DateTime.tryParse(lastBackupStr) : null;
      final needsImmediateRun = lastBackup == null ||
          now.difference(lastBackup).inHours >= _backupIntervalHours;

      if (needsImmediateRun) {
        // Fire and forget; timer will maintain cadence
        // Don't await to avoid blocking initialization
        // ignore: unawaited_futures
        _performScheduledBackup(database);
      }

      // Start periodic timer every 2 hours
      _backupTimer =
          Timer.periodic(const Duration(hours: _backupIntervalHours), (_) {
        _performScheduledBackup(database);
      });

      final nextBackupTime =
          now.add(const Duration(hours: _backupIntervalHours));
      print(
          '⏰ Automatic backup scheduled every ${_backupIntervalHours} hours. Next: ${nextBackupTime.toString()}');
    } catch (e) {
      print('❌ Error scheduling backup: $e');
    }
  }

  /// Perform scheduled backup
  static Future<void> _performScheduledBackup(AppDatabase database) async {
    if (_isBackupInProgress) return;

    try {
      _isBackupInProgress = true;
      print('🔄 Starting scheduled backup...');

      await createBackup(database, isAutomatic: true);
      await _cleanupOldBackups();

      // Update last backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());

      print('✅ Scheduled backup completed');
    } catch (e) {
      print('❌ Error in scheduled backup: $e');
    } finally {
      _isBackupInProgress = false;
    }
  }

  /// Create backup with enhanced Windows support
  static Future<String> createBackup(AppDatabase database,
      {bool isAutomatic = false}) async {
    try {
      if (_isBackupInProgress && !isAutomatic) {
        throw Exception('Backup is already in progress');
      }

      _isBackupInProgress = true;

      // Get all data from database
      final products = await database.select(database.products).get();
      final customers = await database.select(database.customers).get();
      final sales = await database.select(database.sales).get();
      final saleItems = await database.select(database.saleItems).get();
      final payments = await database.select(database.payments).get();
      final settings = await database.select(database.settings).get();
      final stockAdjustments =
          await database.select(database.stockAdjustments).get();
      final categories = await database.select(database.categories).get();
      final suppliers = await database.select(database.suppliers).get();
      final employees = await database.select(database.employees).get();
      final expenses = await database.select(database.expenses).get();
      final banks = await database.select(database.banks).get();
      final bankPayments = await database.select(database.bankPayments).get();
      final supplierPayments =
          await database.select(database.supplierPayments).get();
      final staffPerformances =
          await database.select(database.staffPerformances).get();
      final purchaseOrders =
          await database.select(database.purchaseOrders).get();
      final purchaseOrderItems =
          await database.select(database.purchaseOrderItems).get();
      final returns = await database.select(database.returns).get();
      final returnItems = await database.select(database.returnItems).get();

      // Create comprehensive backup data structure
      final backupData = {
        'version': '2.0.0',
        'createdAt': DateTime.now().toIso8601String(),
        'isAutomatic': isAutomatic,
        'platform': 'windows',
        'databaseVersion': 26,
        'data': {
          'products': products.map((p) => _productToMap(p)).toList(),
          'customers': customers.map((c) => _customerToMap(c)).toList(),
          'sales': sales.map((s) => _saleToMap(s)).toList(),
          'saleItems': saleItems.map((si) => _saleItemToMap(si)).toList(),
          'payments': payments.map((p) => _paymentToMap(p)).toList(),
          'settings': settings.map((s) => _settingToMap(s)).toList(),
          'stockAdjustments':
              stockAdjustments.map((sa) => _stockAdjustmentToMap(sa)).toList(),
          'categories': categories.map((c) => _categoryToMap(c)).toList(),
          'suppliers': suppliers.map((s) => _supplierToMap(s)).toList(),
          'employees': employees.map((e) => _employeeToMap(e)).toList(),
          'expenses': expenses.map((e) => _expenseToMap(e)).toList(),
          'banks': banks.map((b) => _bankToMap(b)).toList(),
          'bankPayments':
              bankPayments.map((bp) => _bankPaymentToMap(bp)).toList(),
          'supplierPayments':
              supplierPayments.map((sp) => _supplierPaymentToMap(sp)).toList(),
          'staffPerformances': staffPerformances
              .map((sp) => _staffPerformanceToMap(sp))
              .toList(),
          'purchaseOrders':
              purchaseOrders.map((po) => _purchaseOrderToMap(po)).toList(),
          'purchaseOrderItems': purchaseOrderItems
              .map((poi) => _purchaseOrderItemToMap(poi))
              .toList(),
          'returns': returns.map((r) => _returnToMap(r)).toList(),
          'returnItems': returnItems.map((ri) => _returnItemToMap(ri)).toList(),
        },
      };

      // Convert to JSON
      final jsonString = jsonEncode(backupData);
      final bytes = utf8.encode(jsonString);

      // Create primary backup directory (Documents)
      final primaryBackupDir = await _createBackupDirectory();

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timeStr = DateFormat('HH-mm-ss').format(DateTime.now());
      final prefix = isAutomatic ? 'auto_' : 'manual_';
      final fileName = '${prefix}${_backupPrefix}${dateStr}_${timeStr}.json';

      // Save to primary location (Documents)
      String primaryFilePath = '';
      try {
        primaryFilePath = p.join(primaryBackupDir, fileName);
        final primaryFile = File(primaryFilePath);
        await primaryFile.writeAsBytes(bytes);
        print('✅ Backup saved to primary location: $primaryFilePath');
      } catch (e) {
        print('❌ Error saving to primary location: $e');
        rethrow; // Re-throw if primary location fails
      }

      // Save to secondary locations (alternative drives) - non-blocking
      final secondaryLocations = await _createSecondaryBackupDirectories();
      int successCount = 0;
      for (final location in secondaryLocations) {
        try {
          final secondaryFilePath = p.join(location, fileName);
          final secondaryFile = File(secondaryFilePath);
          await secondaryFile.writeAsBytes(bytes);
          successCount++;
          print('✅ Backup saved to secondary location: $secondaryFilePath');
        } catch (e) {
          print('⚠️ Error saving to secondary location $location: $e');
          // Continue with other secondary locations even if one fails
        }
      }

      if (secondaryLocations.isNotEmpty) {
        print(
            '📦 Backed up to $successCount of ${secondaryLocations.length} secondary location(s)');
      }

      // Update last backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());
      await prefs.setString('last_backup_path', primaryFilePath);
      // Store secondary backup paths
      final secondaryPaths = <String>[];
      for (final location in secondaryLocations) {
        try {
          final secondaryFilePath = p.join(location, fileName);
          final secondaryFile = File(secondaryFilePath);
          if (await secondaryFile.exists()) {
            secondaryPaths.add(secondaryFilePath);
          }
        } catch (e) {
          // Skip if file doesn't exist or can't be accessed
        }
      }
      if (secondaryPaths.isNotEmpty) {
        await prefs.setStringList('secondary_backup_paths', secondaryPaths);
      }

      print('✅ Backup created: $fileName');
      print('📁 Primary Location: $primaryFilePath');
      print('📊 Size: ${(bytes.length / 1024).toStringAsFixed(2)} KB');

      return primaryFilePath;
    } catch (e) {
      print('❌ Error creating backup: $e');
      throw Exception('Error creating backup: $e');
    } finally {
      _isBackupInProgress = false;
    }
  }

  /// Restore backup with enhanced Windows support
  static Future<void> restoreBackup(
      AppDatabase database, String filePath) async {
    try {
      // Read backup file
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);

      // Validate backup format
      if (backupData['version'] == null || backupData['data'] == null) {
        throw Exception('Invalid backup file format');
      }

      print('🔄 Starting restore from: ${p.basename(filePath)}');

      // Clear existing data
      await _clearAllData(database);

      // Restore data in proper order
      await _restoreData(database, backupData['data']);

      print('✅ Restore completed successfully');
    } catch (e) {
      print('❌ Error restoring backup: $e');
      throw Exception('Error restoring backup: $e');
    }
  }

  /// Clear all data from database
  static Future<void> _clearAllData(AppDatabase database) async {
    // Clear child tables first
    await database.delete(database.returnItems).go();
    await database.delete(database.returns).go();
    await database.delete(database.staffPerformances).go();
    await database.delete(database.bankPayments).go();
    await database.delete(database.supplierPayments).go();
    await database.delete(database.expenses).go();
    await database.delete(database.purchaseOrderItems).go();
    await database.delete(database.purchaseOrders).go();
    await database.delete(database.stockAdjustments).go();
    await database.delete(database.payments).go();
    await database.delete(database.saleItems).go();
    await database.delete(database.sales).go();

    // Clear parent tables
    await database.delete(database.customers).go();
    await database.delete(database.products).go();
    await database.delete(database.suppliers).go();
    await database.delete(database.employees).go();
    await database.delete(database.banks).go();
    await database.delete(database.categories).go();
  }

  /// Restore data from backup
  static Future<void> _restoreData(
      AppDatabase database, Map<String, dynamic> data) async {
    // Restore in proper order
    await _restoreCategories(database, data['categories'] ?? []);
    await _restoreSuppliers(database, data['suppliers'] ?? []);
    await _restoreEmployees(database, data['employees'] ?? []);
    await _restoreBanks(database, data['banks'] ?? []);
    await _restoreProducts(database, data['products'] ?? []);
    await _restoreCustomers(database, data['customers'] ?? []);
    await _restoreSales(database, data['sales'] ?? []);
    await _restoreSaleItems(database, data['saleItems'] ?? []);
    await _restorePayments(database, data['payments'] ?? []);
    await _restoreSettings(database, data['settings'] ?? []);
    await _restoreStockAdjustments(database, data['stockAdjustments'] ?? []);
    await _restoreExpenses(database, data['expenses'] ?? []);
    await _restoreBankPayments(database, data['bankPayments'] ?? []);
    await _restoreSupplierPayments(database, data['supplierPayments'] ?? []);
    await _restoreStaffPerformances(database, data['staffPerformances'] ?? []);
    await _restorePurchaseOrders(database, data['purchaseOrders'] ?? []);
    await _restorePurchaseOrderItems(
        database, data['purchaseOrderItems'] ?? []);
    await _restoreReturns(database, data['returns'] ?? []);
    await _restoreReturnItems(database, data['returnItems'] ?? []);
  }

  /// Cleanup old backup files (keep last 30 days) from all backup locations
  static Future<void> _cleanupOldBackups() async {
    try {
      final allBackupDirs = <String>[];

      // Add primary backup directory
      allBackupDirs.add(await getBackupDirectory());

      // Add secondary backup directories
      final secondaryLocations = await _createSecondaryBackupDirectories();
      allBackupDirs.addAll(secondaryLocations);

      final now = DateTime.now();
      int totalDeletedCount = 0;

      for (final backupDirPath in allBackupDirs) {
        try {
          final backupDir = Directory(backupDirPath);
          if (!await backupDir.exists()) continue;

          final files = await backupDir.list().toList();
          int deletedCount = 0;

          for (final file in files) {
            if (file is File && file.path.endsWith('.json')) {
              try {
                final stat = await file.stat();
                final fileAge = now.difference(stat.modified);

                if (fileAge.inDays > _maxBackupDays) {
                  await file.delete();
                  deletedCount++;
                }
              } catch (e) {
                // Skip files that can't be accessed
              }
            }
          }

          if (deletedCount > 0) {
            print(
                '🗑️ Cleaned up $deletedCount old backup files from: $backupDirPath');
            totalDeletedCount += deletedCount;
          }
        } catch (e) {
          print('⚠️ Error cleaning up backups from $backupDirPath: $e');
          // Continue with other locations
        }
      }

      if (totalDeletedCount > 0) {
        print(
            '🗑️ Total cleaned up $totalDeletedCount old backup files from all locations');
      }
    } catch (e) {
      print('❌ Error cleaning up old backups: $e');
    }
  }

  /// Get list of available backups from all locations (primary and secondary)
  static Future<List<BackupFileInfo>> getAvailableBackups() async {
    try {
      final allBackupDirs = <String>[];
      final backupFiles = <BackupFileInfo>[];

      // Add primary backup directory
      allBackupDirs.add(await getBackupDirectory());

      // Add secondary backup directories
      final secondaryLocations = await _getSecondaryBackupLocations();
      allBackupDirs.addAll(secondaryLocations);

      // Collect backup files from all locations
      for (final backupDirPath in allBackupDirs) {
        try {
          final backupDir = Directory(backupDirPath);
          if (!await backupDir.exists()) continue;

          final files = await backupDir.list().toList();

          for (final file in files) {
            if (file is File && file.path.endsWith('.json')) {
              try {
                final stat = await file.stat();
                final fileName = p.basename(file.path);
                final isAutomatic = fileName.startsWith('auto_');

                // Check if we already have this file (avoid duplicates)
                final alreadyExists = backupFiles.any((bf) =>
                    bf.fileName == fileName &&
                    bf.created.difference(stat.modified).abs().inSeconds < 1);

                if (!alreadyExists) {
                  backupFiles.add(BackupFileInfo(
                    fileName: fileName,
                    filePath: file.path,
                    size: stat.size,
                    created: stat.modified,
                    isAutomatic: isAutomatic,
                  ));
                }
              } catch (e) {
                // Skip files that can't be accessed
              }
            }
          }
        } catch (e) {
          print('⚠️ Error reading backups from $backupDirPath: $e');
          // Continue with other locations
        }
      }

      // Sort by creation date (newest first)
      backupFiles.sort((a, b) => b.created.compareTo(a.created));

      return backupFiles;
    } catch (e) {
      print('❌ Error getting backup list: $e');
      return [];
    }
  }

  /// Enable/disable automatic backup
  static Future<void> setAutoBackupEnabled(
      bool enabled, AppDatabase database) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_enabled', enabled);

    if (enabled) {
      await _scheduleTwoHourlyBackup(database);
    } else {
      _backupTimer?.cancel();
      _backupTimer = null;
    }
  }

  /// Get backup status
  static Future<BackupStatus> getBackupStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackupTime = prefs.getString('last_backup_time');
    final isAutoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? true;
    final lastBackupPath = prefs.getString('last_backup_path');
    final secondaryBackupPaths =
        prefs.getStringList('secondary_backup_paths') ?? [];

    // Get all backup locations
    final primaryLocation = await getBackupDirectory();
    final secondaryLocations = await _getSecondaryBackupLocations();

    return BackupStatus(
      isAutoBackupEnabled: isAutoBackupEnabled,
      lastBackupTime:
          lastBackupTime != null ? DateTime.parse(lastBackupTime) : null,
      lastBackupPath: lastBackupPath,
      isBackupInProgress: _isBackupInProgress,
      primaryBackupLocation: primaryLocation,
      secondaryBackupLocations: secondaryLocations,
      lastSecondaryBackupPaths: secondaryBackupPaths,
    );
  }

  /// Get all backup locations (primary and secondary)
  static Future<Map<String, List<String>>> getAllBackupLocations() async {
    final primaryLocation = await getBackupDirectory();
    final secondaryLocations = await _getSecondaryBackupLocations();

    return {
      'primary': [primaryLocation],
      'secondary': secondaryLocations,
    };
  }

  /// Dispose resources
  static void dispose() {
    _backupTimer?.cancel();
    _backupTimer = null;
  }

  // Helper methods for data conversion
  static Map<String, dynamic> _productToMap(Product product) => {
        'id': product.id,
        'name': product.name,
        'category': product.category,
        'price': product.price,
        'cost': product.cost,
        'stock': product.stock,
        'barcode': product.barcode,
        'discount': product.discount,
        'tax': product.tax,
        'unit': product.unit,
        'description': product.description,
        'reorderLevel': product.reorderLevel,
        'reorderQuantity': product.reorderQuantity,
        'supplierId': product.supplierId,
        'expiryDate': product.expiryDate,
        'batchNumber': product.batchNumber,
        'createdAt': product.createdAt,
        'updatedAt': product.updatedAt,
      };

  static Map<String, dynamic> _customerToMap(Customer customer) => {
        'id': customer.id,
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'totalDue': customer.totalDue,
        'createdAt': customer.createdAt,
        'updatedAt': customer.updatedAt,
      };

  static Map<String, dynamic> _saleToMap(Sale sale) => {
        'id': sale.id,
        'customerId': sale.customerId,
        'cashierId': sale.cashierId,
        'total': sale.total,
        'discount': sale.discount,
        'paid': sale.paid,
        'due': sale.due,
        'status': sale.status,
        'paymentType': sale.paymentType,
        'date': sale.date,
        'dueDate': sale.dueDate,
        'notes': sale.notes,
        'createdAt': sale.createdAt,
      };

  static Map<String, dynamic> _saleItemToMap(SaleItem saleItem) => {
        'id': saleItem.id,
        'saleId': saleItem.saleId,
        'productId': saleItem.productId,
        'qty': saleItem.qty,
        'price': saleItem.price,
        'subtotal': saleItem.subtotal,
        'discount': saleItem.discount,
        'orderDiscountAllocation': saleItem.orderDiscountAllocation,
        'taxRate': saleItem.taxRate,
        'taxAmount': saleItem.taxAmount,
        'costAtSale': saleItem.costAtSale,
        'unit': saleItem.unit,
        'imei': saleItem.imei,
        'specialInstructions': saleItem.specialInstructions,
        'modifiers': saleItem.modifiers,
        'createdAt': saleItem.createdAt,
      };

  static Map<String, dynamic> _paymentToMap(Payment payment) => {
        'id': payment.id,
        'customerId': payment.customerId,
        'saleId': payment.saleId,
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'date': payment.date,
        'note': payment.note,
        'createdAt': payment.createdAt,
      };

  static Map<String, dynamic> _settingToMap(Setting setting) => {
        'key': setting.key,
        'value': setting.value,
      };

  static Map<String, dynamic> _stockAdjustmentToMap(
          StockAdjustment adjustment) =>
      {
        'id': adjustment.id,
        'productId': adjustment.productId,
        'quantity': adjustment.quantity,
        'reason': adjustment.reason,
        'reference': adjustment.reference,
        'date': adjustment.date,
        'createdAt': adjustment.createdAt,
      };

  static Map<String, dynamic> _categoryToMap(Category category) => {
        'id': category.id,
        'name': category.name,
        'description': category.description,
        'color': category.color,
        'icon': category.icon,
        'createdAt': category.createdAt,
        'updatedAt': category.updatedAt,
      };

  static Map<String, dynamic> _supplierToMap(Supplier supplier) => {
        'id': supplier.id,
        'name': supplier.name,
        'contactPerson': supplier.contactPerson,
        'phone': supplier.phone,
        'email': supplier.email,
        'address': supplier.address,
        'city': supplier.city,
        'state': supplier.state,
        'country': supplier.country,
        'zipCode': supplier.zipCode,
        'creditLimit': supplier.creditLimit,
        'currentBalance': supplier.currentBalance,
        'paymentTerms': supplier.paymentTerms,
        'notes': supplier.notes,
        'otherContact1': supplier.otherContact1,
        'otherContact2': supplier.otherContact2,
        'otherContact3': supplier.otherContact3,
        'isActive': supplier.isActive,
        'createdAt': supplier.createdAt,
        'updatedAt': supplier.updatedAt,
      };

  static Map<String, dynamic> _employeeToMap(Employee employee) => {
        'id': employee.id,
        'name': employee.name,
        'username': employee.username,
        'phone': employee.phone,
        'address': employee.address,
        'role': employee.role,
        'employeeId': employee.employeeId,
        'salary': employee.salary,
        'hireDate': employee.hireDate,
        'terminationDate': employee.terminationDate,
        'isActive': employee.isActive,
        'canLogin': employee.canLogin,
        'password': employee.password,
        'permissions': employee.permissions,
        'createdAt': employee.createdAt,
        'updatedAt': employee.updatedAt,
      };

  static Map<String, dynamic> _expenseToMap(Expense expense) => {
        'id': expense.id,
        'title': expense.title,
        'category': expense.category,
        'amount': expense.amount,
        'date': expense.date,
        'paymentMethod': expense.paymentMethod,
        'reference': expense.reference,
        'description': expense.description,
        'vendor': expense.vendor,
        'isRecurring': expense.isRecurring,
        'recurringPeriod': expense.recurringPeriod,
        'attachmentPath': expense.attachmentPath,
        'createdBy': expense.createdBy,
        'createdAt': expense.createdAt,
        'updatedAt': expense.updatedAt,
      };

  static Map<String, dynamic> _bankToMap(Bank bank) => {
        'id': bank.id,
        'name': bank.name,
        'code': bank.code,
        'accountNumber': bank.accountNumber,
        'branch': bank.branch,
        'address': bank.address,
        'phone': bank.phone,
        'email': bank.email,
        'currentBalance': bank.currentBalance,
        'isActive': bank.isActive,
        'createdAt': bank.createdAt,
        'updatedAt': bank.updatedAt,
      };

  static Map<String, dynamic> _bankPaymentToMap(BankPayment payment) => {
        'id': payment.id,
        'bankId': payment.bankId,
        'partyName': payment.partyName,
        'otherName': payment.otherName,
        'amount': payment.amount,
        'paymentType': payment.paymentType,
        'chequeNumber': payment.chequeNumber,
        'chequeDate': payment.chequeDate,
        'issueDate': payment.issueDate,
        'paidDate': payment.paidDate,
        'previousBalance': payment.previousBalance,
        'newBalance': payment.newBalance,
        'status': payment.status,
        'notes': payment.notes,
        'createdAt': payment.createdAt,
        'updatedAt': payment.updatedAt,
      };

  static Map<String, dynamic> _supplierPaymentToMap(SupplierPayment payment) =>
      {
        'id': payment.id,
        'supplierId': payment.supplierId,
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'paymentType': payment.paymentType,
        'date': payment.date,
        'reference': payment.reference,
        'chequeDate': payment.chequeDate,
        'issueDate': payment.issueDate,
        'note': payment.note,
        'otherName': payment.otherName,
        'status': payment.status,
        'createdAt': payment.createdAt,
        'updatedAt': payment.updatedAt,
      };

  static Map<String, dynamic> _staffPerformanceToMap(
          StaffPerformance performance) =>
      {
        'id': performance.id,
        'employeeId': performance.employeeId,
        'employeeName': performance.employeeName,
        'date': performance.date,
        'totalSales': performance.totalSales,
        'totalTransactions': performance.totalTransactions,
        'averageTransactionValue': performance.averageTransactionValue,
        'itemsSold': performance.itemsSold,
        'commission': performance.commission,
        'tips': performance.tips,
        'hoursWorked': performance.hoursWorked,
        'salesPerHour': performance.salesPerHour,
        'customerInteractions': performance.customerInteractions,
        'customerSatisfaction': performance.customerSatisfaction,
        'createdAt': performance.createdAt,
        'updatedAt': performance.updatedAt,
      };

  static Map<String, dynamic> _purchaseOrderToMap(PurchaseOrder order) => {
        'id': order.id,
        'orderNumber': order.orderNumber,
        'supplierId': order.supplierId,
        'orderDate': order.orderDate,
        'expectedDate': order.expectedDate,
        'receivedDate': order.receivedDate,
        'subtotal': order.subtotal,
        'tax': order.tax,
        'discount': order.discount,
        'total': order.total,
        'status': order.status,
        'notes': order.notes,
        'createdAt': order.createdAt,
        'updatedAt': order.updatedAt,
      };

  static Map<String, dynamic> _purchaseOrderItemToMap(PurchaseOrderItem item) =>
      {
        'id': item.id,
        'purchaseOrderId': item.purchaseOrderId,
        'productId': item.productId,
        'quantity': item.quantity,
        'unitCost': item.unitCost,
        'subtotal': item.subtotal,
        'discount': item.discount,
        'tax': item.tax,
        'total': item.total,
        'notes': item.notes,
        'createdAt': item.createdAt,
      };

  static Map<String, dynamic> _returnToMap(Return returnData) => {
        'id': returnData.id,
        'returnNumber': returnData.returnNumber,
        'originalSaleId': returnData.originalSaleId,
        'customerId': returnData.customerId,
        'returnDate': returnData.returnDate,
        'totalAmount': returnData.totalAmount,
        'reason': returnData.reason,
        'status': returnData.status,
        'notes': returnData.notes,
        'processedBy': returnData.processedBy,
        'createdAt': returnData.createdAt,
        'updatedAt': returnData.updatedAt,
      };

  static Map<String, dynamic> _returnItemToMap(ReturnItem item) => {
        'id': item.id,
        'returnId': item.returnId,
        'productId': item.productId,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'subtotal': item.subtotal,
        'reason': item.reason,
        'condition': item.condition,
        'action': item.action,
        'createdAt': item.createdAt,
      };

  // Restore methods
  static Future<void> _restoreCategories(
      AppDatabase database, List<dynamic> categories) async {
    for (final categoryData in categories) {
      await database.into(database.categories).insert(CategoriesCompanion(
            id: Value(categoryData['id']),
            name: Value(categoryData['name']),
            description: Value(categoryData['description']),
            color: Value(categoryData['color']),
            icon: Value(categoryData['icon']),
            createdAt: Value(categoryData['createdAt']),
            updatedAt: Value(categoryData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreSuppliers(
      AppDatabase database, List<dynamic> suppliers) async {
    for (final supplierData in suppliers) {
      await database.into(database.suppliers).insert(SuppliersCompanion(
            id: Value(supplierData['id']),
            name: Value(supplierData['name']),
            contactPerson: Value(supplierData['contactPerson']),
            phone: Value(supplierData['phone']),
            email: Value(supplierData['email']),
            address: Value(supplierData['address']),
            city: Value(supplierData['city']),
            state: Value(supplierData['state']),
            country: Value(supplierData['country']),
            zipCode: Value(supplierData['zipCode']),
            creditLimit: Value(supplierData['creditLimit']),
            currentBalance: Value(supplierData['currentBalance']),
            paymentTerms: Value(supplierData['paymentTerms']),
            notes: Value(supplierData['notes']),
            otherContact1: Value(supplierData['otherContact1']),
            otherContact2: Value(supplierData['otherContact2']),
            otherContact3: Value(supplierData['otherContact3']),
            isActive: Value(supplierData['isActive']),
            createdAt: Value(supplierData['createdAt']),
            updatedAt: Value(supplierData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreEmployees(
      AppDatabase database, List<dynamic> employees) async {
    for (final employeeData in employees) {
      await database.into(database.employees).insert(EmployeesCompanion(
            id: Value(employeeData['id']),
            name: Value(employeeData['name']),
            username: Value(employeeData['username']),
            phone: Value(employeeData['phone']),
            address: Value(employeeData['address']),
            role: Value(employeeData['role']),
            employeeId: Value(employeeData['employeeId']),
            salary: Value(employeeData['salary']),
            hireDate: Value(employeeData['hireDate']),
            terminationDate: Value(employeeData['terminationDate']),
            isActive: Value(employeeData['isActive']),
            password: Value(employeeData['password']),
            permissions: Value(employeeData['permissions']),
            createdAt: Value(employeeData['createdAt']),
            updatedAt: Value(employeeData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreBanks(
      AppDatabase database, List<dynamic> banks) async {
    for (final bankData in banks) {
      await database.into(database.banks).insert(BanksCompanion(
            id: Value(bankData['id']),
            name: Value(bankData['name']),
            code: Value(bankData['code']),
            accountNumber: Value(bankData['accountNumber']),
            branch: Value(bankData['branch']),
            address: Value(bankData['address']),
            phone: Value(bankData['phone']),
            email: Value(bankData['email']),
            currentBalance: Value(bankData['currentBalance']),
            isActive: Value(bankData['isActive']),
            createdAt: Value(bankData['createdAt']),
            updatedAt: Value(bankData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreProducts(
      AppDatabase database, List<dynamic> products) async {
    for (final productData in products) {
      await database.into(database.products).insert(ProductsCompanion(
            id: Value(productData['id']),
            name: Value(productData['name']),
            category: Value(productData['category']),
            price: Value(productData['price']),
            cost: Value(productData['cost']),
            stock: Value(productData['stock']),
            barcode: Value(productData['barcode']),
            discount: Value(productData['discount']),
            tax: Value(productData['tax']),
            unit: Value(productData['unit']),
            description: Value(productData['description']),
            reorderLevel: Value(productData['reorderLevel']),
            reorderQuantity: Value(productData['reorderQuantity']),
            supplierId: Value(productData['supplierId']),
            expiryDate: Value(productData['expiryDate']),
            batchNumber: Value(productData['batchNumber']),
            createdAt: Value(productData['createdAt']),
            updatedAt: Value(productData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreCustomers(
      AppDatabase database, List<dynamic> customers) async {
    for (final customerData in customers) {
      await database.into(database.customers).insert(CustomersCompanion(
            id: Value(customerData['id']),
            name: Value(customerData['name']),
            phone: Value(customerData['phone']),
            address: Value(customerData['address']),
            totalDue: Value(customerData['totalDue']),
            createdAt: Value(customerData['createdAt']),
            updatedAt: Value(customerData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreSales(
      AppDatabase database, List<dynamic> sales) async {
    for (final saleData in sales) {
      await database.into(database.sales).insert(SalesCompanion(
            id: Value(saleData['id']),
            customerId: Value(saleData['customerId']),
            cashierId: Value(saleData['cashierId']),
            total: Value(saleData['total']),
            discount: Value(saleData['discount']),
            paid: Value(saleData['paid']),
            due: Value(saleData['due']),
            status: Value(saleData['status']),
            paymentType: Value(saleData['paymentType']),
            date: Value(saleData['date']),
            dueDate: Value(saleData['dueDate']),
            notes: Value(saleData['notes']),
            createdAt: Value(saleData['createdAt']),
          ));
    }
  }

  static Future<void> _restoreSaleItems(
      AppDatabase database, List<dynamic> saleItems) async {
    for (final saleItemData in saleItems) {
      await database.into(database.saleItems).insert(SaleItemsCompanion(
            id: Value(saleItemData['id']),
            saleId: Value(saleItemData['saleId']),
            productId: Value(saleItemData['productId']),
            qty: Value(saleItemData['qty']),
            price: Value(saleItemData['price']),
            subtotal: Value(saleItemData['subtotal']),
            discount: Value(saleItemData['discount']),
            orderDiscountAllocation:
                Value(saleItemData['orderDiscountAllocation'] ?? 0.0),
            taxRate: Value(saleItemData['taxRate'] ?? 0.0),
            taxAmount: Value(saleItemData['taxAmount'] ?? 0.0),
            costAtSale: Value(saleItemData['costAtSale'] ?? 0.0),
            unit: Value(saleItemData['unit'] ?? 'pcs'),
            imei: Value(saleItemData['imei']),
            specialInstructions: Value(saleItemData['specialInstructions']),
            modifiers: Value(saleItemData['modifiers']),
            createdAt: Value(saleItemData['createdAt']),
          ));
    }
  }

  static Future<void> _restorePayments(
      AppDatabase database, List<dynamic> payments) async {
    for (final paymentData in payments) {
      await database.into(database.payments).insert(PaymentsCompanion(
            id: Value(paymentData['id']),
            customerId: Value(paymentData['customerId']),
            saleId: Value(paymentData['saleId']),
            amount: Value(paymentData['amount']),
            paymentMethod: Value(paymentData['paymentMethod']),
            date: Value(paymentData['date']),
            note: Value(paymentData['note']),
            createdAt: Value(paymentData['createdAt']),
          ));
    }
  }

  static Future<void> _restoreSettings(
      AppDatabase database, List<dynamic> settings) async {
    for (final settingData in settings) {
      await database.into(database.settings).insert(SettingsCompanion(
            key: Value(settingData['key']),
            value: Value(settingData['value']),
          ));
    }
  }

  static Future<void> _restoreStockAdjustments(
      AppDatabase database, List<dynamic> stockAdjustments) async {
    for (final adjustmentData in stockAdjustments) {
      await database
          .into(database.stockAdjustments)
          .insert(StockAdjustmentsCompanion(
            id: Value(adjustmentData['id']),
            productId: Value(adjustmentData['productId']),
            quantity: Value(adjustmentData['quantity']),
            reason: Value(adjustmentData['reason']),
            reference: Value(adjustmentData['reference']),
            date: Value(adjustmentData['date']),
            createdAt: Value(adjustmentData['createdAt']),
          ));
    }
  }

  static Future<void> _restoreExpenses(
      AppDatabase database, List<dynamic> expenses) async {
    for (final expenseData in expenses) {
      await database.into(database.expenses).insert(ExpensesCompanion(
            id: Value(expenseData['id']),
            title: Value(expenseData['title']),
            category: Value(expenseData['category']),
            amount: Value(expenseData['amount']),
            date: Value(expenseData['date']),
            paymentMethod: Value(expenseData['paymentMethod']),
            reference: Value(expenseData['reference']),
            description: Value(expenseData['description']),
            vendor: Value(expenseData['vendor']),
            isRecurring: Value(expenseData['isRecurring']),
            recurringPeriod: Value(expenseData['recurringPeriod']),
            attachmentPath: Value(expenseData['attachmentPath']),
            createdBy: Value(expenseData['createdBy']),
            createdAt: Value(expenseData['createdAt']),
            updatedAt: Value(expenseData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreBankPayments(
      AppDatabase database, List<dynamic> bankPayments) async {
    for (final paymentData in bankPayments) {
      await database.into(database.bankPayments).insert(BankPaymentsCompanion(
            id: Value(paymentData['id']),
            bankId: Value(paymentData['bankId']),
            partyName: Value(paymentData['partyName']),
            otherName: Value(paymentData['otherName']),
            amount: Value(paymentData['amount']),
            paymentType: Value(paymentData['paymentType']),
            chequeNumber: Value(paymentData['chequeNumber']),
            chequeDate: Value(paymentData['chequeDate']),
            issueDate: Value(paymentData['issueDate']),
            paidDate: Value(paymentData['paidDate']),
            previousBalance: Value(paymentData['previousBalance']),
            newBalance: Value(paymentData['newBalance']),
            status: Value(paymentData['status']),
            notes: Value(paymentData['notes']),
            createdAt: Value(paymentData['createdAt']),
            updatedAt: Value(paymentData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreSupplierPayments(
      AppDatabase database, List<dynamic> supplierPayments) async {
    for (final paymentData in supplierPayments) {
      await database
          .into(database.supplierPayments)
          .insert(SupplierPaymentsCompanion(
            id: Value(paymentData['id']),
            supplierId: Value(paymentData['supplierId']),
            amount: Value(paymentData['amount']),
            paymentMethod: Value(paymentData['paymentMethod']),
            paymentType: Value(paymentData['paymentType']),
            date: Value(paymentData['date']),
            reference: Value(paymentData['reference']),
            chequeDate: Value(paymentData['chequeDate']),
            issueDate: Value(paymentData['issueDate']),
            note: Value(paymentData['note']),
            otherName: Value(paymentData['otherName']),
            status: Value(paymentData['status']),
            createdAt: Value(paymentData['createdAt']),
            updatedAt: Value(paymentData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreStaffPerformances(
      AppDatabase database, List<dynamic> staffPerformances) async {
    for (final performanceData in staffPerformances) {
      await database
          .into(database.staffPerformances)
          .insert(StaffPerformancesCompanion(
            id: Value(performanceData['id']),
            employeeId: Value(performanceData['employeeId']),
            employeeName: Value(performanceData['employeeName']),
            date: Value(performanceData['date']),
            totalSales: Value(performanceData['totalSales']),
            totalTransactions: Value(performanceData['totalTransactions']),
            averageTransactionValue:
                Value(performanceData['averageTransactionValue']),
            itemsSold: Value(performanceData['itemsSold']),
            commission: Value(performanceData['commission']),
            tips: Value(performanceData['tips']),
            hoursWorked: Value(performanceData['hoursWorked']),
            salesPerHour: Value(performanceData['salesPerHour']),
            customerInteractions:
                Value(performanceData['customerInteractions']),
            customerSatisfaction:
                Value(performanceData['customerSatisfaction']),
            createdAt: Value(performanceData['createdAt']),
            updatedAt: Value(performanceData['updatedAt']),
          ));
    }
  }

  static Future<void> _restorePurchaseOrders(
      AppDatabase database, List<dynamic> purchaseOrders) async {
    for (final orderData in purchaseOrders) {
      await database
          .into(database.purchaseOrders)
          .insert(PurchaseOrdersCompanion(
            id: Value(orderData['id']),
            orderNumber: Value(orderData['orderNumber']),
            supplierId: Value(orderData['supplierId']),
            orderDate: Value(orderData['orderDate']),
            expectedDate: Value(orderData['expectedDate']),
            receivedDate: Value(orderData['receivedDate']),
            subtotal: Value(orderData['subtotal']),
            tax: Value(orderData['tax']),
            discount: Value(orderData['discount']),
            total: Value(orderData['total']),
            status: Value(orderData['status']),
            notes: Value(orderData['notes']),
            createdAt: Value(orderData['createdAt']),
            updatedAt: Value(orderData['updatedAt']),
          ));
    }
  }

  static Future<void> _restorePurchaseOrderItems(
      AppDatabase database, List<dynamic> purchaseOrderItems) async {
    for (final itemData in purchaseOrderItems) {
      await database
          .into(database.purchaseOrderItems)
          .insert(PurchaseOrderItemsCompanion(
            id: Value(itemData['id']),
            purchaseOrderId: Value(itemData['purchaseOrderId']),
            productId: Value(itemData['productId']),
            quantity: Value(itemData['quantity']),
            unitCost: Value(itemData['unitCost']),
            subtotal: Value(itemData['subtotal']),
            discount: Value(itemData['discount']),
            tax: Value(itemData['tax']),
            total: Value(itemData['total']),
            notes: Value(itemData['notes']),
            createdAt: Value(itemData['createdAt']),
          ));
    }
  }

  static Future<void> _restoreReturns(
      AppDatabase database, List<dynamic> returns) async {
    for (final returnData in returns) {
      await database.into(database.returns).insert(ReturnsCompanion(
            id: Value(returnData['id']),
            returnNumber: Value(returnData['returnNumber']),
            originalSaleId: Value(returnData['originalSaleId']),
            customerId: Value(returnData['customerId']),
            returnDate: Value(returnData['returnDate']),
            totalAmount: Value(returnData['totalAmount']),
            reason: Value(returnData['reason']),
            status: Value(returnData['status']),
            notes: Value(returnData['notes']),
            processedBy: Value(returnData['processedBy']),
            createdAt: Value(returnData['createdAt']),
            updatedAt: Value(returnData['updatedAt']),
          ));
    }
  }

  static Future<void> _restoreReturnItems(
      AppDatabase database, List<dynamic> returnItems) async {
    for (final itemData in returnItems) {
      await database.into(database.returnItems).insert(ReturnItemsCompanion(
            id: Value(itemData['id']),
            returnId: Value(itemData['returnId']),
            productId: Value(itemData['productId']),
            quantity: Value(itemData['quantity']),
            unitPrice: Value(itemData['unitPrice']),
            subtotal: Value(itemData['subtotal']),
            reason: Value(itemData['reason']),
            condition: Value(itemData['condition']),
            action: Value(itemData['action']),
            createdAt: Value(itemData['createdAt']),
          ));
    }
  }
}

// Data classes
class BackupFileInfo {
  final String fileName;
  final String filePath;
  final int size;
  final DateTime created;
  final bool isAutomatic;

  BackupFileInfo({
    required this.fileName,
    required this.filePath,
    required this.size,
    required this.created,
    required this.isAutomatic,
  });
}

class BackupStatus {
  final bool isAutoBackupEnabled;
  final DateTime? lastBackupTime;
  final String? lastBackupPath;
  final bool isBackupInProgress;
  final String primaryBackupLocation;
  final List<String> secondaryBackupLocations;
  final List<String> lastSecondaryBackupPaths;

  BackupStatus({
    required this.isAutoBackupEnabled,
    this.lastBackupTime,
    this.lastBackupPath,
    required this.isBackupInProgress,
    required this.primaryBackupLocation,
    this.secondaryBackupLocations = const [],
    this.lastSecondaryBackupPaths = const [],
  });
}
