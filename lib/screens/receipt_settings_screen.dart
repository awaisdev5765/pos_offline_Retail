import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../services/unified_print_service.dart';
import '../services/print_settings_service.dart';
import '../services/windows_printer_detection_service.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';

/// Simplified Receipt & Printer Settings Screen
/// Only essential settings - clean and easy to use
class ReceiptSettingsScreen extends ConsumerStatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  ConsumerState<ReceiptSettingsScreen> createState() =>
      _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends ConsumerState<ReceiptSettingsScreen> {
  final _printerIpController = TextEditingController();
  final _printerPortController = TextEditingController(text: '9100');
  final _footerTextController = TextEditingController();
  final _phone1Controller = TextEditingController();
  final _phone2Controller = TextEditingController();
  final _phone3Controller = TextEditingController();

  String _receiptType = 'thermal'; // thermal or a4
  PaperSize _thermalPaperSize = PaperSize.thermal80mm;
  String? _selectedWindowsPrinter;
  List<WindowsPrinter> _windowsPrinters = [];
  bool _isLoading = false;
  bool _isTestingPrinter = false;

  // Logo and settings
  String? _logoPath;
  bool _showLogo = true;
  bool _showBusinessInfo = true;
  bool _openCashDrawer = false;
  bool _autoCut = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _detectWindowsPrinters();
  }

  @override
  void dispose() {
    _printerIpController.dispose();
    _printerPortController.dispose();
    _footerTextController.dispose();
    _phone1Controller.dispose();
    _phone2Controller.dispose();
    _phone3Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final databaseService = ref.read(databaseServiceProvider);
    final savedSettings = await PrintSettingsService.getDefaultSettings();

    final dbPrinterIp = await databaseService.getSetting('printer_ip');
    final dbPrinterPort = await databaseService.getSetting('printer_port');
    final dbReceiptType = await databaseService.getSetting('receipt_type');
    final dbPrinterName = await databaseService.getSetting('printer_name');

    // Load business phones
    final dbPhone1 = await databaseService.getSetting('business_phone');
    final dbPhone2 = await databaseService.getSetting('business_phone_2');
    final dbPhone3 = await databaseService.getSetting('business_phone_3');

    // Load receipt customization
    final dbFooterText =
        await databaseService.getSetting('receipt_footer_text');
    final dbLogoPath = await databaseService.getSetting('receipt_logo_path');
    final dbShowLogo = await databaseService.getSetting('receipt_show_logo');
    final dbShowBusinessInfo =
        await databaseService.getSetting('receipt_show_business_info');
    final dbOpenCashDrawer =
        await databaseService.getSetting('receipt_open_cash_drawer');
    final dbAutoCut = await databaseService.getSetting('receipt_auto_cut');

    debugPrint('=== LOAD SETTINGS DEBUG ===');
    debugPrint('DB Printer Name: $dbPrinterName');
    debugPrint('DB Printer IP: $dbPrinterIp');
    debugPrint('Saved Settings Printer Name: ${savedSettings.printerName}');
    debugPrint('Saved Settings Printer IP: ${savedSettings.printerIp}');

    setState(() {
      // Check if we have a Windows printer saved
      if (dbPrinterName != null && dbPrinterName.isNotEmpty) {
        _selectedWindowsPrinter = dbPrinterName;
        _printerIpController.text = ''; // Clear IP field for Windows printer
        debugPrint('✓ Loaded Windows printer: $dbPrinterName');
      } else {
        // Network printer
        _printerIpController.text = (savedSettings.printerIp ?? '').isNotEmpty
            ? savedSettings.printerIp!
            : (dbPrinterIp ?? '');
        debugPrint('✓ Loaded network printer: ${_printerIpController.text}');
      }

      _printerPortController.text = (dbPrinterPort ?? '').isNotEmpty
          ? dbPrinterPort!
          : '${savedSettings.printerPort}';
      _receiptType = (dbReceiptType ?? 'thermal');
      _thermalPaperSize = savedSettings.paperSize == PaperSize.thermal58mm
          ? PaperSize.thermal58mm
          : PaperSize.thermal80mm;

      // Load phones
      _phone1Controller.text = dbPhone1 ?? '';
      _phone2Controller.text = dbPhone2 ?? '';
      _phone3Controller.text = dbPhone3 ?? '';

      // Load receipt customization
      _footerTextController.text = dbFooterText ?? '';
      _logoPath = dbLogoPath;
      _showLogo = dbShowLogo != 'false'; // Default true
      _showBusinessInfo = dbShowBusinessInfo != 'false'; // Default true
      _openCashDrawer = dbOpenCashDrawer == 'true'; // Default false
      _autoCut = dbAutoCut != 'false'; // Default true
    });
    debugPrint('===========================');
  }

  Future<void> _detectWindowsPrinters() async {
    if (!Platform.isWindows) return;

    try {
      final printers = await WindowsPrinterDetectionService.detectAllPrinters();
      setState(() {
        _windowsPrinters = printers;
      });
    } catch (e) {
      debugPrint('Error detecting printers: $e');
    }
  }

  Future<void> _uploadLogo() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 300,
        maxHeight: 100,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final logoDir = Directory('${appDir.path}/logos');
        if (!await logoDir.exists()) {
          await logoDir.create(recursive: true);
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newLogoPath = '${logoDir.path}/logo_$timestamp.png';
        final savedFile = File(pickedFile.path);
        await savedFile.copy(newLogoPath);

        setState(() {
          _logoPath = newLogoPath;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Logo uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _logoPath = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Logo removed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final databaseService = ref.read(databaseServiceProvider);
      final printerIpOrName = _printerIpController.text.trim();
      final printerPort =
          int.tryParse(_printerPortController.text.trim()) ?? 9100;
      final isWindowsPrinter = _selectedWindowsPrinter != null;

      debugPrint('=== SAVE SETTINGS DEBUG ===');
      debugPrint('Selected Windows Printer: $_selectedWindowsPrinter');
      debugPrint('IP Controller Text: ${_printerIpController.text}');
      debugPrint('Is Windows Printer: $isWindowsPrinter');
      debugPrint('Receipt Type: $_receiptType');

      // Save to database - store Windows printer name separately
      if (isWindowsPrinter) {
        // Windows printer - save name to printer_name
        await databaseService.setSetting(
            'printer_name', _selectedWindowsPrinter!);
        await databaseService.setSetting('printer_ip', ''); // Clear IP
        debugPrint('✓ Saved Windows printer name: ${_selectedWindowsPrinter!}');

        // Verify it was saved
        final verifyName = await databaseService.getSetting('printer_name');
        debugPrint('Verified printer_name from DB: $verifyName');
      } else {
        // Network printer - save IP to printer_ip
        await databaseService.setSetting('printer_ip', printerIpOrName);
        await databaseService.setSetting('printer_name', ''); // Clear name
        debugPrint('✓ Saved network printer IP: $printerIpOrName');
      }
      await databaseService.setSetting('printer_port', '$printerPort');
      await databaseService.setSetting('receipt_type', _receiptType);

      // Save business phones
      await databaseService.setSetting(
          'business_phone', _phone1Controller.text.trim());
      await databaseService.setSetting(
          'business_phone_2', _phone2Controller.text.trim());
      await databaseService.setSetting(
          'business_phone_3', _phone3Controller.text.trim());

      // Save receipt customization
      await databaseService.setSetting(
          'receipt_footer_text', _footerTextController.text.trim());
      if (_logoPath != null) {
        await databaseService.setSetting('receipt_logo_path', _logoPath!);
      }
      await databaseService.setSetting(
          'receipt_show_logo', _showLogo.toString());
      await databaseService.setSetting(
          'receipt_show_business_info', _showBusinessInfo.toString());
      await databaseService.setSetting(
          'receipt_open_cash_drawer', _openCashDrawer.toString());
      await databaseService.setSetting('receipt_auto_cut', _autoCut.toString());

      // Save to print settings
      final currentSettings = await PrintSettingsService.getDefaultSettings();

      final updatedSettings = currentSettings.copyWith(
        printerType: _receiptType == 'a4'
            ? PrinterType.a4
            : (isWindowsPrinter
                ? PrinterType.thermal
                : PrinterType.networkThermal),
        printerName: isWindowsPrinter ? _selectedWindowsPrinter : null,
        printerIp: isWindowsPrinter
            ? null
            : (printerIpOrName.isEmpty ? null : printerIpOrName),
        printerPort: printerPort,
        paperSize: _receiptType == 'a4' ? PaperSize.a4 : _thermalPaperSize,
        footerText: _footerTextController.text.trim().isEmpty
            ? null
            : _footerTextController.text.trim(),
        showLogo: _showLogo,
        showBusinessInfo: _showBusinessInfo,
        openCashDrawer: _openCashDrawer,
        autoCut: _autoCut,
      );

      await PrintSettingsService.saveSettings(updatedSettings);
      debugPrint('✓ PrintSettingsService saved successfully');
      debugPrint('===========================');

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
                '✓ Printer saved: ${isWindowsPrinter ? _selectedWindowsPrinter : printerIpOrName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving settings: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testPrinter() async {
    if (_printerIpController.text.isEmpty && _selectedWindowsPrinter == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Please select or enter a printer first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTestingPrinter = true);

    try {
      final isWindowsPrinter = _selectedWindowsPrinter != null;
      final databaseService = ref.read(databaseServiceProvider);
      final businessName =
          await databaseService.getSetting('business_name') ?? 'Test Business';

      final success = await UnifiedPrintService.printTestPage(
        printerIp: isWindowsPrinter ? null : _printerIpController.text.trim(),
        printerName: isWindowsPrinter ? _selectedWindowsPrinter : null,
        port: int.tryParse(_printerPortController.text.trim()) ?? 9100,
        businessName: businessName,
      );

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(success
                ? '✓ Test page printed successfully!'
                : '✗ Test print failed. Check printer connection.'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingPrinter = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Receipt & Printer Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor:
            isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReceiptTypeCard(isDarkMode),
            const SizedBox(height: 16),
            _buildPrinterSelectionCard(isDarkMode),
            const SizedBox(height: 16),
            _buildBusinessPhonesCard(isDarkMode),
            const SizedBox(height: 16),
            _buildLogoCard(isDarkMode),
            const SizedBox(height: 16),
            _buildFooterCard(isDarkMode),
            const SizedBox(height: 16),
            _buildPrintingOptionsCard(isDarkMode),
            const SizedBox(height: 16),
            _buildTestPrinterCard(isDarkMode),
            const SizedBox(height: 16),
            _buildInfoCard(isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptTypeCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long,
                    color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Receipt Type',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            if (_receiptType == 'thermal') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<PaperSize>(
                value: _thermalPaperSize,
                decoration: InputDecoration(
                  labelText: 'Thermal paper width',
                  helperText: 'Match the roll installed in your printer',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PaperSize.thermal58mm,
                    child: Text('58mm receipt'),
                  ),
                  DropdownMenuItem(
                    value: PaperSize.thermal80mm,
                    child: Text('80mm receipt'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _thermalPaperSize = value);
                  }
                },
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildReceiptTypeOption(
                    'thermal',
                    'Thermal (58/80mm)',
                    Icons.qr_code_scanner,
                    isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReceiptTypeOption(
                    'a4',
                    'A4 Paper',
                    Icons.print,
                    isDarkMode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptTypeOption(
      String type, String label, IconData icon, bool isDarkMode) {
    final isSelected = _receiptType == type;
    return InkWell(
      onTap: () => setState(() => _receiptType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryColor.withValues(alpha: 0.1)
              : (isDarkMode ? AppColors.backgroundDark : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryColor
                : (isDarkMode ? AppColors.borderColor : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.primaryColor
                    : (isDarkMode ? Colors.white70 : Colors.grey[600]),
                size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? AppColors.primaryColor
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSelectionCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.print, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Printer Connection',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),

            // Windows Printers (if available)
            if (Platform.isWindows && _windowsPrinters.isNotEmpty) ...[
              const Text('Windows Printers:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedWindowsPrinter,
                decoration: InputDecoration(
                  hintText: 'Select Windows Printer',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor:
                      isDarkMode ? AppColors.backgroundDark : Colors.white,
                ),
                items: _windowsPrinters.map((p) {
                  final status = p.isOffline ? ' (Offline)' : '';
                  return DropdownMenuItem(
                    value: p.name,
                    child: Text('${p.name}$status',
                        style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedWindowsPrinter = value;
                    if (value != null) {
                      _printerIpController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('OR use IP address:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
            ],

            // IP Address
            TextField(
              controller: _printerIpController,
              decoration: InputDecoration(
                labelText: 'Printer IP Address',
                hintText: '192.168.1.100',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _printerIpController.clear(),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() => _selectedWindowsPrinter = null);
                }
              },
            ),
            const SizedBox(height: 12),

            // Port
            TextField(
              controller: _printerPortController,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: '9100',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessPhonesCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.phone, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Business Phone Numbers',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add up to 3 phone numbers (optional)',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone1Controller,
              decoration: InputDecoration(
                labelText: 'Phone Number 1 (Primary)',
                hintText: '+1 234 567 8900',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone2Controller,
              decoration: InputDecoration(
                labelText: 'Phone Number 2 (Optional)',
                hintText: '+1 234 567 8901',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone3Controller,
              decoration: InputDecoration(
                labelText: 'Phone Number 3 (Optional)',
                hintText: '+1 234 567 8902',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Receipt Logo',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadLogo,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Logo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_logoPath != null) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _removeLogo,
                    icon: const Icon(Icons.delete),
                    label: const Text('Remove'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
            if (_logoPath != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('✓ Logo uploaded and ready to print'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Show Logo on Receipt'),
              subtitle: const Text('Display logo at top of receipt'),
              value: _showLogo,
              onChanged: (value) => setState(() => _showLogo = value),
              activeColor: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notes, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Custom Footer Message',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Add custom text at bottom of receipt (use \\n for new lines)',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _footerTextController,
              decoration: InputDecoration(
                labelText: 'Footer Text',
                hintText: 'Thank you!\\nVisit again\\nWarranty: 1 year',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDarkMode ? AppColors.backgroundDark : Colors.white,
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.blue[900]!.withValues(alpha: 0.2)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Text('Preview:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _footerTextController.text.isEmpty
                        ? 'Thank you for your business!\\nPlease visit again'
                        : _footerTextController.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintingOptionsCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Printing Options',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show Business Info'),
              subtitle: const Text('Display business name, address, and phone'),
              value: _showBusinessInfo,
              onChanged: (value) => setState(() => _showBusinessInfo = value),
              activeColor: AppColors.primaryColor,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Auto Cut Paper'),
              subtitle: const Text('Automatically cut paper after printing'),
              value: _autoCut,
              onChanged: (value) => setState(() => _autoCut = value),
              activeColor: AppColors.primaryColor,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Open Cash Drawer'),
              subtitle:
                  const Text('Automatically open cash drawer after print'),
              value: _openCashDrawer,
              onChanged: (value) => setState(() => _openCashDrawer = value),
              activeColor: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestPrinterCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.print, color: AppColors.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text('Test Printer',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isTestingPrinter ? null : _testPrinter,
                icon: _isTestingPrinter
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.print),
                label:
                    Text(_isTestingPrinter ? 'Testing...' : 'Print Test Page'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDarkMode) {
    return Card(
      elevation: 2,
      color: isDarkMode
          ? Colors.blue[900]!.withValues(alpha: 0.2)
          : Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                const Text('Quick Guide',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('✓', 'Select receipt type (Thermal or A4)'),
            _buildInfoItem('✓', 'Choose Windows printer OR enter IP address'),
            _buildInfoItem('✓', 'Click "Print Test Page" to verify'),
            _buildInfoItem('✓', 'Click Save icon (top-right) to save'),
            const SizedBox(height: 8),
            Text(
              'Note: Business info (name, address, phone) is edited from Settings → Business Information',
              style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
