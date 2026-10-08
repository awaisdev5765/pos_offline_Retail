import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/receipt_template.dart';
import '../providers/receipt_template_provider.dart';
import '../theme/app_theme.dart';
import '../services/unified_print_service.dart';
import '../services/print_settings_service.dart';
import '../services/windows_printer_detection_service.dart';
import '../services/database_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';
import '../widgets/app_snack_bar.dart';

class ReceiptCustomizationScreen extends ConsumerStatefulWidget {
  const ReceiptCustomizationScreen({super.key});

  @override
  ConsumerState<ReceiptCustomizationScreen> createState() =>
      _ReceiptCustomizationScreenState();
}

class _ReceiptCustomizationScreenState
    extends ConsumerState<ReceiptCustomizationScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _footerTextController = TextEditingController();
  final _customField1LabelController = TextEditingController();
  final _customField1ValueController = TextEditingController();
  final _customField2LabelController = TextEditingController();
  final _customField2ValueController = TextEditingController();
  final _customField3LabelController = TextEditingController();
  final _customField3ValueController = TextEditingController();

  // Template settings
  String? _logoPath;
  bool _showLogo = true;
  bool _showBusinessInfo = true;
  bool _showCustomerInfo = true;
  bool _showItemDetails = true;
  bool _showTaxBreakdown = true;
  bool _showPaymentInfo = true;
  bool _showFooter = true;
  bool _showQRCode = false;
  double _logoHeight = 60.0;
  double _logoWidth = 200.0;
  int _fontSize = 12;
  String _fontFamily = 'monospace';

  // Printer settings
  final _printerIpController = TextEditingController();
  final _printerPortController = TextEditingController(text: '9100');
  String? _selectedPrinter;
  List<String> _availablePrinters = [];
  List<WindowsPrinter> _windowsPrinters = [];
  List<NetworkPrinter> _networkPrinters = [];
  bool _isScanningPrinters = false;
  bool _isTestingPrinter = false;
  String? _printerTestResult;
  String _receiptType = 'thermal'; // thermal, a4, other
  PaperSize _thermalPaperSize = PaperSize.thermal80mm;
  String _detectionStatus = '';

  // Bluetooth printer settings
  List<BluetoothDevice> _bluetoothDevices = [];
  bool _isScanningBluetooth = false;
  BluetoothDevice? _connectedBluetoothDevice;
  bool _isConnectingBluetooth = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _detectionStatus = 'receipt_custom.detect_ready'.tr();
    _loadCurrentTemplate();
    _loadPrinterSettings();
    _scanForPrinters();
    _checkBluetoothConnection();

    // Add listeners to update preview in real-time
    _businessNameController.addListener(_updatePreview);
    _businessAddressController.addListener(_updatePreview);
    _businessPhoneController.addListener(_updatePreview);
    _businessEmailController.addListener(_updatePreview);
    _footerTextController.addListener(_updatePreview);
  }

  void _updatePreview() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _websiteController.dispose();
    _taxIdController.dispose();
    _licenseNumberController.dispose();
    _footerTextController.dispose();
    _customField1LabelController.dispose();
    _customField1ValueController.dispose();
    _customField2LabelController.dispose();
    _customField2ValueController.dispose();
    _customField3LabelController.dispose();
    _customField3ValueController.dispose();
    _printerIpController.dispose();
    _printerPortController.dispose();
    super.dispose();
  }

  void _loadCurrentTemplate() {
    final template = ref.read(currentReceiptTemplateProvider);
    _businessNameController.text = template.businessName;
    _businessAddressController.text = template.businessAddress;
    _businessPhoneController.text = template.businessPhone;
    _businessEmailController.text = template.businessEmail;
    _websiteController.text = template.website ?? '';
    _taxIdController.text = template.taxId ?? '';
    _licenseNumberController.text = template.licenseNumber ?? '';
    _footerTextController.text = template.footerText ?? '';
    _customField1LabelController.text = template.customField1Label ?? '';
    _customField1ValueController.text = template.customField1Value ?? '';
    _customField2LabelController.text = template.customField2Label ?? '';
    _customField2ValueController.text = template.customField2Value ?? '';
    _customField3LabelController.text = template.customField3Label ?? '';
    _customField3ValueController.text = template.customField3Value ?? '';

    _logoPath = template.logoUrl;
    _showLogo = template.showLogo;
    _showBusinessInfo = template.showBusinessInfo;
    _showCustomerInfo = template.showCustomerInfo;
    _showItemDetails = template.showItemDetails;
    _showTaxBreakdown = template.showTaxBreakdown;
    _showPaymentInfo = template.showPaymentInfo;
    _showFooter = template.showFooter;
    _showQRCode = template.showQRCode;
    _logoHeight = template.logoHeight;
    _logoWidth = template.logoWidth;
    _fontSize = template.fontSize;
    _fontFamily = template.fontFamily;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'receipt_custom.screen_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          TextButton.icon(
            onPressed: _saveTemplate,
            icon: const Icon(Icons.save, size: 18),
            label: Text('common.save'.tr()),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppColors.primaryColor,
          isScrollable: true,
          tabs: [
            Tab(
                text: 'receipt_custom.tab_business'.tr(),
                icon: const Icon(Icons.business, size: 20)),
            Tab(
                text: 'receipt_custom.tab_logo'.tr(),
                icon: const Icon(Icons.image, size: 20)),
            Tab(
                text: 'receipt_custom.tab_layout'.tr(),
                icon: const Icon(Icons.tune, size: 20)),
            Tab(
                text: 'receipt_custom.tab_printer'.tr(),
                icon: const Icon(Icons.print, size: 20)),
            Tab(
                text: 'receipt_custom.tab_preview'.tr(),
                icon: const Icon(Icons.visibility, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBusinessInfoTab(),
          _buildLogoBrandingTab(),
          _buildLayoutOptionsTab(),
          _buildPrinterSettingsTab(),
          _buildPreviewTab(),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              'receipt_custom.section_business'.tr(),
              Icons.business,
              [
                _buildTextField(
                  controller: _businessNameController,
                  label: 'receipt_custom.business_name'.tr(),
                  hint: 'receipt_custom.hint_business_name'.tr(),
                  icon: Icons.store,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _businessAddressController,
                  label: 'receipt_custom.business_address'.tr(),
                  hint: 'receipt_custom.hint_business_address'.tr(),
                  icon: Icons.location_on,
                  maxLines: 3,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _businessPhoneController,
                        label: 'receipt_custom.phone'.tr(),
                        hint: 'receipt_custom.hint_phone'.tr(),
                        icon: Icons.phone,
                        keyboardType: TextInputType.number,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _businessEmailController,
                        label: 'receipt_custom.email'.tr(),
                        hint: 'receipt_custom.hint_email'.tr(),
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _websiteController,
                  label: 'receipt_custom.website'.tr(),
                  hint: 'receipt_custom.hint_website'.tr(),
                  icon: Icons.language,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              'receipt_custom.section_legal'.tr(),
              Icons.gavel,
              [
                _buildTextField(
                  controller: _taxIdController,
                  label: 'receipt_custom.tax_id'.tr(),
                  hint: 'receipt_custom.hint_tax_id'.tr(),
                  icon: Icons.receipt_long,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _licenseNumberController,
                  label: 'receipt_custom.license_num'.tr(),
                  hint: 'receipt_custom.hint_license'.tr(),
                  icon: Icons.badge,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              'receipt_custom.section_custom'.tr(),
              Icons.edit_note,
              [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _customField1LabelController,
                        label: 'receipt_custom.cf1_label'.tr(),
                        hint: 'receipt_custom.cf1_label_hint'.tr(),
                        icon: Icons.label,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _customField1ValueController,
                        label: 'receipt_custom.cf1_value'.tr(),
                        hint: 'receipt_custom.hint_value'.tr(),
                        icon: Icons.text_fields,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _customField2LabelController,
                        label: 'receipt_custom.cf2_label'.tr(),
                        hint: 'receipt_custom.cf2_label_hint'.tr(),
                        icon: Icons.label,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _customField2ValueController,
                        label: 'receipt_custom.cf2_value'.tr(),
                        hint: 'receipt_custom.hint_value'.tr(),
                        icon: Icons.text_fields,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _customField3LabelController,
                        label: 'receipt_custom.cf3_label'.tr(),
                        hint: 'receipt_custom.cf3_label_hint'.tr(),
                        icon: Icons.label,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _customField3ValueController,
                        label: 'receipt_custom.cf3_value'.tr(),
                        hint: 'receipt_custom.hint_value'.tr(),
                        icon: Icons.text_fields,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionCard(
              'receipt_custom.section_footer'.tr(),
              Icons.text_fields,
              [
                _buildTextField(
                  controller: _footerTextController,
                  label: 'receipt_custom.footer_message'.tr(),
                  hint: 'receipt_custom.hint_footer'.tr(),
                  icon: Icons.message,
                  maxLines: 3,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoBrandingTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'receipt_custom.section_logo_settings'.tr(),
            Icons.image,
            [
              // Logo Preview
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? const Color(0xFF1E293B) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? const Color(0xFF374151)
                        : Colors.grey[300]!,
                  ),
                ),
                child: _logoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_logoPath!),
                          fit: BoxFit.contain,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 48,
                            color:
                                isDarkMode ? Colors.white70 : Colors.grey[600],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'receipt_custom.no_logo'.tr(),
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              // Logo Upload Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromGallery,
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: Text('receipt_custom.gallery'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImageFromCamera,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text('receipt_custom.camera'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              if (_logoPath != null) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _removeLogo,
                  icon: const Icon(Icons.delete, size: 18),
                  label: Text('receipt_custom.remove_logo'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            'receipt_custom.logo_display'.tr(),
            Icons.tune,
            [
              SwitchListTile(
                title: Text('receipt_custom.show_logo'.tr()),
                subtitle: Text('receipt_custom.show_logo_sub'.tr()),
                value: _showLogo,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showLogo = value);
                  }
                },
              ),
              if (_showLogo) ...[
                const Divider(),
                ListTile(
                  title: Text('receipt_custom.logo_size'.tr()),
                  subtitle: Text(
                      '${_logoWidth.toInt()} x ${_logoHeight.toInt()} pixels'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _logoWidth = (_logoWidth - 10).clamp(50.0, 400.0);
                              _logoHeight =
                                  (_logoHeight - 10).clamp(30.0, 200.0);
                            });
                          }
                        },
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      IconButton(
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _logoWidth = (_logoWidth + 10).clamp(50.0, 400.0);
                              _logoHeight =
                                  (_logoHeight + 10).clamp(30.0, 200.0);
                            });
                          }
                        },
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            'receipt_custom.section_typography'.tr(),
            Icons.text_fields,
            [
              ListTile(
                title: Text('receipt_custom.font_size'.tr()),
                subtitle: Text('$_fontSize pt'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (mounted) {
                          setState(
                              () => _fontSize = (_fontSize - 1).clamp(8, 20));
                        }
                      },
                      icon: const Icon(Icons.remove, size: 18),
                    ),
                    IconButton(
                      onPressed: () {
                        if (mounted) {
                          setState(
                              () => _fontSize = (_fontSize + 1).clamp(8, 20));
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                title: Text('receipt_custom.font_family'.tr()),
                subtitle: Text(_fontFamily),
                trailing: DropdownButton<String>(
                  value: _fontFamily,
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _fontFamily = value!);
                    }
                  },
                  items: [
                    DropdownMenuItem(
                        value: 'monospace',
                        child: Text('receipt_custom.font_mono'.tr())),
                    DropdownMenuItem(
                        value: 'serif',
                        child: Text('receipt_custom.font_serif'.tr())),
                    DropdownMenuItem(
                        value: 'sans-serif',
                        child: Text('receipt_custom.font_sans'.tr())),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutOptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'receipt_custom.section_sections'.tr(),
            Icons.list,
            [
              SwitchListTile(
                title: Text('receipt_custom.biz_on_receipt'.tr()),
                subtitle: Text('receipt_custom.biz_on_receipt_sub'.tr()),
                value: _showBusinessInfo,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showBusinessInfo = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.customer_on_receipt'.tr()),
                subtitle: Text('receipt_custom.customer_on_receipt_sub'.tr()),
                value: _showCustomerInfo,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showCustomerInfo = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.items_on_receipt'.tr()),
                subtitle: Text('receipt_custom.items_on_receipt_sub'.tr()),
                value: _showItemDetails,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showItemDetails = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.tax_on_receipt'.tr()),
                subtitle: Text('receipt_custom.tax_on_receipt_sub'.tr()),
                value: _showTaxBreakdown,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showTaxBreakdown = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.payment_on_receipt'.tr()),
                subtitle: Text('receipt_custom.payment_on_receipt_sub'.tr()),
                value: _showPaymentInfo,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showPaymentInfo = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.footer_on_receipt'.tr()),
                subtitle: Text('receipt_custom.footer_on_receipt_sub'.tr()),
                value: _showFooter,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showFooter = value);
                  }
                },
              ),
              const Divider(),
              SwitchListTile(
                title: Text('receipt_custom.qr_on_receipt'.tr()),
                subtitle: Text('receipt_custom.qr_on_receipt_sub'.tr()),
                value: _showQRCode,
                onChanged: (value) {
                  if (mounted) {
                    setState(() => _showQRCode = value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadPrinterSettings() async {
    final databaseService = ref.read(databaseServiceProvider);
    final savedPrintSettings = await PrintSettingsService.getDefaultSettings();
    final dbPrinterIp = await databaseService.getSetting('printer_ip');
    final dbPrinterPort = await databaseService.getSetting('printer_port');
    final dbReceiptType = await databaseService.getSetting('receipt_type');

    final effectivePrinterIp =
        (savedPrintSettings.printerIp ?? '').trim().isNotEmpty
            ? savedPrintSettings.printerIp!.trim()
            : (dbPrinterIp ?? '').trim();

    final effectivePrinterPort = (dbPrinterPort ?? '').trim().isNotEmpty
        ? dbPrinterPort!.trim()
        : '${savedPrintSettings.printerPort}';

    String effectiveReceiptType;
    if ((dbReceiptType ?? '').trim().isNotEmpty) {
      effectiveReceiptType = dbReceiptType!.trim();
    } else {
      effectiveReceiptType =
          savedPrintSettings.printerType == PrinterType.a4 ? 'a4' : 'thermal';
    }

    if (mounted) {
      setState(() {
        if (effectivePrinterIp.isNotEmpty)
          _printerIpController.text = effectivePrinterIp;
        if (effectivePrinterPort.isNotEmpty)
          _printerPortController.text = effectivePrinterPort;
        _receiptType = effectiveReceiptType;
        _thermalPaperSize =
            savedPrintSettings.paperSize == PaperSize.thermal58mm
                ? PaperSize.thermal58mm
                : PaperSize.thermal80mm;
      });
    }
  }

  Future<void> _scanForPrinters() async {
    setState(() {
      _isScanningPrinters = true;
      _availablePrinters.clear();
      _windowsPrinters.clear();
      _networkPrinters.clear();
      _detectionStatus = 'receipt_custom.detecting'.tr();
    });

    try {
      // Scan Windows printers if on Windows
      if (Platform.isWindows) {
        setState(() {
          _detectionStatus = 'receipt_custom.detecting_windows'.tr();
        });
        final windowsPrinters =
            await WindowsPrinterDetectionService.detectAllPrinters();

        setState(() {
          _detectionStatus = 'receipt_custom.detecting_network'.tr();
        });
        final networkPrinters =
            await WindowsPrinterDetectionService.detectNetworkPrinters();

        setState(() {
          _windowsPrinters = windowsPrinters;
          _networkPrinters = networkPrinters;
          _availablePrinters = [
            ...windowsPrinters.map((p) => p.name),
            ...networkPrinters.map((p) => p.ip),
          ];
          _detectionStatus = 'receipt_custom.found_win_net'.tr(namedArgs: {
            'w': '${windowsPrinters.length}',
            'n': '${networkPrinters.length}',
          });
        });
      } else {
        // Scan network printers for non-Windows
        final networkPrinters =
            await UnifiedPrintService.getAvailableNetworkPrinters();
        setState(() {
          _availablePrinters = networkPrinters;
          _detectionStatus = 'receipt_custom.found_net'
              .tr(namedArgs: {'count': '${networkPrinters.length}'});
        });
      }
    } catch (e) {
      setState(() {
        _detectionStatus =
            'receipt_custom.printer_scan_err'.tr(namedArgs: {'error': '$e'});
      });
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
              content: Text('receipt_custom.printer_scan_err'
                  .tr(namedArgs: {'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanningPrinters = false;
        });
      }
    }
  }

  Future<void> _testPrinterConnection() async {
    if (_printerIpController.text.isEmpty && _selectedPrinter == null) {
      AppSnackBar.show(
        context,
        SnackBar(content: Text('receipt_custom.select_printer_hint'.tr())),
      );
      return;
    }

    setState(() {
      _isTestingPrinter = true;
      _printerTestResult = null;
    });

    try {
      final printerIp = _selectedPrinter ?? _printerIpController.text;
      final port = int.tryParse(_printerPortController.text) ?? 9100;

      bool isConnected = false;

      // Test Windows printer connection
      if (Platform.isWindows &&
          _windowsPrinters.any((p) => p.name == printerIp)) {
        isConnected =
            await WindowsPrinterDetectionService.testPrinterConnection(
                printerIp);
      } else {
        // Test network printer connection using UnifiedPrintService
        final connectionResult =
            await UnifiedPrintService.testPrinterConnectionWithError(
          printerIp: printerIp,
          port: port,
        );
        isConnected = connectionResult.isConnected;

        if (!isConnected) {
          setState(() {
            _printerTestResult =
                connectionResult.errorMessage ?? 'Printer connection failed';
            _isTestingPrinter = false;
          });

          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(connectionResult.errorMessage ??
                    'Printer connection failed'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
      }

      if (isConnected) {
        // Try to print test page
        try {
          final isWindowsPrinter = Platform.isWindows &&
              _windowsPrinters.any((p) => p.name == printerIp);

          final printSuccess = await UnifiedPrintService.printTestPage(
            printerIp: isWindowsPrinter ? null : printerIp,
            printerName: isWindowsPrinter ? printerIp : null,
            port: port,
            businessName: _businessNameController.text.isNotEmpty
                ? _businessNameController.text
                : 'Test Business',
          );

          setState(() {
            _printerTestResult = printSuccess
                ? 'Printer test successful! Test page printed.'
                : 'Printer connected but test print failed.';
            _isTestingPrinter = false;
          });

          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(_printerTestResult!),
                backgroundColor: printSuccess ? Colors.green : Colors.orange,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _printerTestResult = 'Printer connected but test print failed: $e';
            _isTestingPrinter = false;
          });
        }
      } else {
        setState(() {
          _printerTestResult =
              'Printer connection failed. Please check IP/name and port.';
          _isTestingPrinter = false;
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Printer connection failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _printerTestResult = 'Error: $e';
        _isTestingPrinter = false;
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Bluetooth Printer Methods
  Future<void> _checkBluetoothConnection() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final connectedDevice = BluetoothPrinterService.getConnectedPrinter();
      if (mounted) {
        setState(() {
          _connectedBluetoothDevice = connectedDevice;
        });
      }
    } catch (e) {
      debugPrint('Error checking Bluetooth connection: $e');
    }
  }

  Future<void> _scanForBluetoothPrinters() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (mounted) {
      setState(() {
        _isScanningBluetooth = true;
        _bluetoothDevices = [];
      });
    }

    try {
      // Check if Bluetooth is available
      final isAvailable = await BluetoothPrinterService.isBluetoothAvailable();
      if (!isAvailable) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'Bluetooth is not available on this device. Please enable Bluetooth.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Request permissions
      final hasPermission = await BluetoothPrinterService.requestPermissions();
      if (!hasPermission) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'Bluetooth permissions are required. Please grant permissions in app settings.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Scan for printers
      final devices = await BluetoothPrinterService.scanForPrinters(
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _bluetoothDevices = devices;
          _isScanningBluetooth = false;
        });
      }

      if (devices.isEmpty && mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text(
                'No Bluetooth printers found. Make sure your printer is turned on and in pairing mode.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanningBluetooth = false;
        });
        AppSnackBar.show(
          context,
          SnackBar(
            content:
                Text('Error scanning for Bluetooth printers: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Error scanning Bluetooth printers: $e');
    }
  }

  Future<void> _connectToBluetoothPrinter(BluetoothDevice device) async {
    if (mounted) {
      setState(() {
        _isConnectingBluetooth = true;
      });
    }

    try {
      final connected = await BluetoothPrinterService.connect(device);

      if (mounted) {
        setState(() {
          _isConnectingBluetooth = false;
          if (connected) {
            _connectedBluetoothDevice = device;
          }
        });

        if (connected) {
          AppSnackBar.show(
            context,
            SnackBar(
              content:
                  Text('Connected to ${device.name ?? 'Bluetooth printer'}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Failed to connect to printer. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnectingBluetooth = false;
        });
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error connecting to printer: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Error connecting to Bluetooth printer: $e');
    }
  }

  Future<void> _disconnectBluetoothPrinter() async {
    try {
      await BluetoothPrinterService.disconnect();
      if (mounted) {
        setState(() {
          _connectedBluetoothDevice = null;
        });
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text('Bluetooth printer disconnected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting Bluetooth printer: $e');
    }
  }

  Future<void> _testBluetoothPrinter() async {
    if (_connectedBluetoothDevice == null) return;

    if (mounted) {
      setState(() {
        _isTestingPrinter = true;
        _printerTestResult = null;
      });
    }

    try {
      // Create a test sale for printing
      final testSuccess = await BluetoothPrinterService.printTestPage(
        businessName: _businessNameController.text.isNotEmpty
            ? _businessNameController.text
            : 'Test Business',
        paperWidthMm: _thermalPaperSize == PaperSize.thermal58mm ? 58 : 80,
      );

      if (mounted) {
        setState(() {
          _printerTestResult = testSuccess
              ? 'Bluetooth printer test successful! Test page printed.'
              : 'Bluetooth printer connected but test print failed.';
          _isTestingPrinter = false;
        });

        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(_printerTestResult!),
            backgroundColor: testSuccess ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _printerTestResult = 'Bluetooth printer test failed: $e';
          _isTestingPrinter = false;
        });
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Bluetooth printer test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      debugPrint('Error testing Bluetooth printer: $e');
    }
  }

  Widget _buildBluetoothDeviceCard(BluetoothDevice device) {
    final isConnected = _connectedBluetoothDevice?.address == device.address;
    final isConnecting = _isConnectingBluetooth &&
        _connectedBluetoothDevice?.address == device.address;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isConnected ? Colors.green.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
          color: isConnected ? Colors.green : Colors.blue,
        ),
        title: Text(device.name ?? 'Unknown Device'),
        subtitle: Text(device.address ?? 'No address'),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isConnected
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: () => _connectToBluetoothPrinter(device),
                    tooltip: 'Connect',
                  ),
        onTap: isConnected || isConnecting
            ? null
            : () => _connectToBluetoothPrinter(device),
      ),
    );
  }

  Widget _buildPrinterSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Receipt Type',
            Icons.description,
            [
              ListTile(
                title: Text('receipt_custom.receipt_type'.tr()),
                subtitle: Text('receipt_custom.receipt_type_sub'.tr()),
                trailing: DropdownButton<String>(
                  value: _receiptType,
                  items: const [
                    DropdownMenuItem(
                        value: 'thermal', child: Text('Thermal (58mm/80mm)')),
                    DropdownMenuItem(value: 'a4', child: Text('A4 Paper')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _receiptType = value!);
                    }
                  },
                ),
              ),
              if (_receiptType == 'thermal')
                ListTile(
                  title: const Text('Thermal paper width'),
                  subtitle: const Text(
                      'Choose the exact roll installed in the printer'),
                  trailing: DropdownButton<PaperSize>(
                    value: _thermalPaperSize,
                    items: const [
                      DropdownMenuItem(
                        value: PaperSize.thermal58mm,
                        child: Text('58mm'),
                      ),
                      DropdownMenuItem(
                        value: PaperSize.thermal80mm,
                        child: Text('80mm'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && mounted) {
                        setState(() => _thermalPaperSize = value);
                      }
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Detection Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                if (_isScanningPrinters)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _detectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  onPressed: _isScanningPrinters ? null : _scanForPrinters,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Windows Printers Section
          if (Platform.isWindows && _windowsPrinters.isNotEmpty)
            _buildSectionCard(
              'Windows Printers (${_windowsPrinters.length})',
              Icons.print,
              [
                ..._windowsPrinters
                    .map((printer) => _buildWindowsPrinterCard(printer)),
              ],
            ),
          if (Platform.isWindows && _windowsPrinters.isNotEmpty)
            const SizedBox(height: 24),
          // Network Printers Section
          if (_networkPrinters.isNotEmpty)
            _buildSectionCard(
              'Network Printers (${_networkPrinters.length})',
              Icons.wifi,
              [
                ..._networkPrinters
                    .map((printer) => _buildNetworkPrinterCard(printer)),
              ],
            ),
          if (_networkPrinters.isNotEmpty) const SizedBox(height: 24),
          // Bluetooth Printers Section (Mobile only)
          if (Platform.isAndroid || Platform.isIOS)
            _buildSectionCard(
              'Bluetooth Printers',
              Icons.bluetooth,
              [
                // Connection Status
                if (_connectedBluetoothDevice != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Connected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                _connectedBluetoothDevice!.name ??
                                    'Unknown Device',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: _disconnectBluetoothPrinter,
                          tooltip: 'Disconnect',
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bluetooth_disabled, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No Bluetooth printer connected',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Scan Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isScanningBluetooth ? null : _scanForBluetoothPrinters,
                    icon: _isScanningBluetooth
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanningBluetooth
                        ? 'Scanning...'
                        : 'Scan for Printers'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                // Bluetooth Devices List
                if (_bluetoothDevices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Available Printers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._bluetoothDevices
                      .map((device) => _buildBluetoothDeviceCard(device)),
                ],
                // Test Print Button for Bluetooth
                if (_connectedBluetoothDevice != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isTestingPrinter ? null : _testBluetoothPrinter,
                      icon: _isTestingPrinter
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print),
                      label:
                          Text(_isTestingPrinter ? 'Testing...' : 'Test Print'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          if (Platform.isAndroid || Platform.isIOS) const SizedBox(height: 24),
          // Manual Configuration
          _buildSectionCard(
            'Manual Printer Configuration',
            Icons.edit,
            [
              _buildTextField(
                controller: _printerIpController,
                label: 'Printer IP Address or Name',
                hint: '192.168.1.100 or Printer Name',
                icon: Icons.computer,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _printerPortController,
                label: 'Port',
                hint: '9100',
                icon: Icons.settings_ethernet,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            'Test Printer',
            Icons.print,
            [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isTestingPrinter ? null : _testPrinterConnection,
                  icon: _isTestingPrinter
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: Text(_isTestingPrinter ? 'Testing...' : 'Test Print'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (_printerTestResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _printerTestResult!.contains('successful')
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _printerTestResult!.contains('successful')
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _printerTestResult!.contains('successful')
                            ? Icons.check_circle
                            : Icons.error,
                        color: _printerTestResult!.contains('successful')
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _printerTestResult!,
                          style: TextStyle(
                            color: _printerTestResult!.contains('successful')
                                ? Colors.green[700]
                                : Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWindowsPrinterCard(WindowsPrinter printer) {
    final isSelected = _selectedPrinter == printer.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          printer.isThermal ? Icons.receipt : Icons.print,
          color: printer.isThermal ? Colors.orange : Colors.blue,
        ),
        title: Text(printer.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Port: ${printer.port} | Driver: ${printer.driver}'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (printer.isThermal)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'THERMAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: printer.isOffline ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    printer.isOffline ? 'OFFLINE' : 'ONLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _testWindowsPrinter(printer.name),
              tooltip: 'Test Print',
            ),
            Radio<String>(
              value: printer.name,
              groupValue: _selectedPrinter,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _selectedPrinter = value;
                    _printerIpController.text = value!;
                  });
                }
              },
            ),
          ],
        ),
        onTap: () {
          if (mounted) {
            setState(() {
              _selectedPrinter = printer.name;
              _printerIpController.text = printer.name;
            });
          }
        },
      ),
    );
  }

  Widget _buildNetworkPrinterCard(NetworkPrinter printer) {
    final isSelected = _selectedPrinter == printer.ip;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: const Icon(Icons.wifi, color: Colors.blue),
        title: Text(printer.name),
        subtitle: Text('IP: ${printer.ip}:${printer.port}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _testNetworkPrinter(printer.ip),
              tooltip: 'Test Print',
            ),
            Radio<String>(
              value: printer.ip,
              groupValue: _selectedPrinter,
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    _selectedPrinter = value;
                    _printerIpController.text = value!;
                    _printerPortController.text = printer.port.toString();
                  });
                }
              },
            ),
          ],
        ),
        onTap: () {
          if (mounted) {
            setState(() {
              _selectedPrinter = printer.ip;
              _printerIpController.text = printer.ip;
              _printerPortController.text = printer.port.toString();
            });
          }
        },
      ),
    );
  }

  Future<void> _testWindowsPrinter(String printerName) async {
    setState(() {
      _isTestingPrinter = true;
      _printerTestResult = null;
    });

    try {
      final isConnected =
          await WindowsPrinterDetectionService.testPrinterConnection(
              printerName);
      setState(() {
        _isTestingPrinter = false;
        _printerTestResult = isConnected
            ? 'Printer $printerName is connected and ready!'
            : 'Printer $printerName is not responding';
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(_printerTestResult!),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isTestingPrinter = false;
        _printerTestResult = 'Error testing printer: $e';
      });
    }
  }

  Future<void> _testNetworkPrinter(String ip) async {
    setState(() {
      _isTestingPrinter = true;
      _printerTestResult = null;
    });

    try {
      final port = int.tryParse(_printerPortController.text) ?? 9100;
      final connectionResult =
          await UnifiedPrintService.testPrinterConnectionWithError(
        printerIp: ip,
        port: port,
      );
      final isConnected = connectionResult.isConnected;

      if (!isConnected) {
        setState(() {
          _printerTestResult =
              connectionResult.errorMessage ?? 'Printer connection failed.';
          _isTestingPrinter = false;
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text(connectionResult.errorMessage ??
                  'Printer connection failed.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (isConnected) {
        try {
          final printSuccess = await UnifiedPrintService.printTestPage(
            printerIp: ip,
            port: port,
            businessName: _businessNameController.text.isNotEmpty
                ? _businessNameController.text
                : 'Test Business',
          );

          setState(() {
            _printerTestResult = printSuccess
                ? 'Network printer $ip is connected and test page printed!'
                : 'Network printer $ip is connected but test print failed.';
            _isTestingPrinter = false;
          });

          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text(_printerTestResult!),
                backgroundColor: printSuccess ? Colors.green : Colors.orange,
              ),
            );
          }
        } catch (e) {
          setState(() {
            _printerTestResult =
                'Network printer connected but test print failed: $e';
            _isTestingPrinter = false;
          });
        }
      } else {
        setState(() {
          _printerTestResult = 'Network printer $ip is not responding';
          _isTestingPrinter = false;
        });

        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Network printer connection failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _printerTestResult = 'Error: $e';
        _isTestingPrinter = false;
      });
    }
  }

  Widget _buildPreviewTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Changes update in real-time',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildReceiptPreview(),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: _saveTemplate,
              icon: const Icon(Icons.save),
              label: Text('receipt_custom.save_template'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo
        if (_showLogo && _logoPath != null)
          Container(
            height: _logoHeight,
            width: _logoWidth,
            margin: const EdgeInsets.only(bottom: 16),
            child: Image.file(
              File(_logoPath!),
              fit: BoxFit.contain,
            ),
          ),

        // Business Info
        if (_showBusinessInfo) ...[
          Text(
            _businessNameController.text.isNotEmpty
                ? _businessNameController.text
                : 'receipt_custom.preview_business_placeholder'.tr(),
            style: TextStyle(
              fontSize: _fontSize + 2,
              fontWeight: FontWeight.bold,
              fontFamily: _fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (_businessAddressController.text.isNotEmpty)
            Text(
              _businessAddressController.text,
              style: TextStyle(
                fontSize: _fontSize.toDouble(),
                fontFamily: _fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          if (_businessPhoneController.text.isNotEmpty)
            Text(
              _businessPhoneController.text,
              style: TextStyle(
                fontSize: _fontSize.toDouble(),
                fontFamily: _fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
        ],

        // Divider
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),

        // Sample Receipt Content
        Text(
          'receipt_custom.sample_receipt_no'.tr(),
          style: TextStyle(
            fontSize: _fontSize.toDouble(),
            fontWeight: FontWeight.bold,
            fontFamily: _fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'receipt_custom.sample_date'.tr(namedArgs: {
            'd': DateTime.now().toString().split(' ')[0],
          }),
          style: TextStyle(
            fontSize: _fontSize.toDouble(),
            fontFamily: _fontFamily,
          ),
        ),
        const SizedBox(height: 16),

        // Sample Items
        if (_showItemDetails) ...[
          Text('receipt_custom.preview_header'.tr()),
          Text('receipt_custom.preview_sep'.tr()),
          Text('receipt_custom.preview_line1'.tr()),
          Text('receipt_custom.preview_line2'.tr()),
          const SizedBox(height: 8),
        ],

        // Tax and Total
        if (_showTaxBreakdown) ...[
          Text('receipt_custom.preview_subtotal'.tr()),
          Text('receipt_custom.preview_tax'.tr()),
        ],
        Text('receipt_custom.preview_total'.tr()),
        const SizedBox(height: 16),

        // Payment Info
        if (_showPaymentInfo) Text('receipt_custom.preview_payment'.tr()),

        const SizedBox(height: 16),

        // Footer
        if (_showFooter && _footerTextController.text.isNotEmpty)
          Text(
            _footerTextController.text,
            style: TextStyle(
              fontSize: _fontSize.toDouble(),
              fontFamily: _fontFamily,
            ),
            textAlign: TextAlign.center,
          ),

        // Custom Fields
        if (_customField1LabelController.text.isNotEmpty)
          Text(
            '${_customField1LabelController.text}: ${_customField1ValueController.text}',
            style: TextStyle(
              fontSize: _fontSize.toDouble(),
              fontFamily: _fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF374151) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryColor),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF374151) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF4B5563) : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? const Color(0xFF4B5563) : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : const Color(0xFF64748B),
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white60 : Colors.grey[500],
        ),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field is required';
              }
              return null;
            }
          : null,
    );
  }

  Future<void> _pickImageFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      if (mounted) {
        setState(() => _logoPath = result.files.first.path);
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    // For now, use file picker as camera functionality requires image_picker
    // This can be enhanced later with proper camera integration
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      if (mounted) {
        setState(() => _logoPath = result.files.first.path);
      }
    }
  }

  void _removeLogo() {
    if (mounted) {
      setState(() => _logoPath = null);
    }
  }

  Future<void> _saveTemplate() async {
    if (_formKey.currentState?.validate() ?? false) {
      final template = ReceiptTemplate(
        id: 'current',
        name: 'Current Template',
        logoUrl: _logoPath,
        businessName: _businessNameController.text,
        businessAddress: _businessAddressController.text,
        businessPhone: _businessPhoneController.text,
        businessEmail: _businessEmailController.text,
        website:
            _websiteController.text.isNotEmpty ? _websiteController.text : null,
        taxId: _taxIdController.text.isNotEmpty ? _taxIdController.text : null,
        licenseNumber: _licenseNumberController.text.isNotEmpty
            ? _licenseNumberController.text
            : null,
        footerText: _footerTextController.text.isNotEmpty
            ? _footerTextController.text
            : null,
        showLogo: _showLogo,
        showBusinessInfo: _showBusinessInfo,
        showCustomerInfo: _showCustomerInfo,
        showItemDetails: _showItemDetails,
        showTaxBreakdown: _showTaxBreakdown,
        showPaymentInfo: _showPaymentInfo,
        showFooter: _showFooter,
        showQRCode: _showQRCode,
        customField1Label: _customField1LabelController.text.isNotEmpty
            ? _customField1LabelController.text
            : null,
        customField1Value: _customField1ValueController.text.isNotEmpty
            ? _customField1ValueController.text
            : null,
        customField2Label: _customField2LabelController.text.isNotEmpty
            ? _customField2LabelController.text
            : null,
        customField2Value: _customField2ValueController.text.isNotEmpty
            ? _customField2ValueController.text
            : null,
        customField3Label: _customField3LabelController.text.isNotEmpty
            ? _customField3LabelController.text
            : null,
        customField3Value: _customField3ValueController.text.isNotEmpty
            ? _customField3ValueController.text
            : null,
        logoHeight: _logoHeight,
        logoWidth: _logoWidth,
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(receiptTemplateProvider.notifier).updateTemplate(template);

      // Save printer settings to DB (legacy/compatibility path)
      final databaseService = ref.read(databaseServiceProvider);
      final printerIpOrName = _printerIpController.text.trim();
      final printerPort =
          int.tryParse(_printerPortController.text.trim()) ?? 9100;
      await databaseService.setSetting('printer_ip', printerIpOrName);
      await databaseService.setSetting('printer_port', '$printerPort');
      await databaseService.setSetting('receipt_type', _receiptType);

      // Save printer settings to runtime print profile (primary path used by print flow)
      final currentSettings = await PrintSettingsService.getDefaultSettings();
      final selected = (_selectedPrinter ?? '').trim();
      final isWindowsNamedPrinter = Platform.isWindows &&
          selected.isNotEmpty &&
          _windowsPrinters.any((p) => p.name == selected);
      final hasBluetoothPrinter = _connectedBluetoothDevice != null;

      final resolvedPrinterType = _receiptType == 'a4'
          ? PrinterType.a4
          : (hasBluetoothPrinter
              ? PrinterType.bluetooth
              : (isWindowsNamedPrinter
                  ? PrinterType.thermal
                  : PrinterType.networkThermal));
      final resolvedPaperSize =
          _receiptType == 'a4' ? PaperSize.a4 : _thermalPaperSize;

      final updatedPrintSettings = currentSettings.copyWith(
        printerType: resolvedPrinterType,
        printerName: hasBluetoothPrinter
            ? _connectedBluetoothDevice!.name
            : (isWindowsNamedPrinter ? selected : currentSettings.printerName),
        printerIp: isWindowsNamedPrinter
            ? currentSettings.printerIp
            : (printerIpOrName.isEmpty
                ? currentSettings.printerIp
                : printerIpOrName),
        printerPort: printerPort,
        paperSize: resolvedPaperSize,
        orientation: PrintOrientation.portrait,
      );
      await PrintSettingsService.saveSettings(updatedPrintSettings);

      if (mounted) {
        AppSnackBar.show(
          context,
          const SnackBar(
            content: Text(
                'Receipt template and printer settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
