import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/sale.dart';
import '../services/unified_print_service.dart';
import '../services/database_service.dart';
import '../services/print_settings_service.dart';
import 'app_snack_bar.dart';

class EnhancedPrintPreview extends StatefulWidget {
  final SaleModel sale;
  final DatabaseService? databaseService;
  final PrintSettings? initialSettings;

  const EnhancedPrintPreview({
    super.key,
    required this.sale,
    this.databaseService,
    this.initialSettings,
  });

  @override
  State<EnhancedPrintPreview> createState() => _EnhancedPrintPreviewState();
}

class _EnhancedPrintPreviewState extends State<EnhancedPrintPreview> {
  PrintSettings? _settings;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      PrintSettings settings;
      if (widget.initialSettings != null) {
        settings = widget.initialSettings!;
      } else {
        // Load saved settings from preferences
        settings = await PrintSettingsService.getDefaultSettings();
      }

      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _settings = PrintSettings.getDefault();
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    if (_settings == null) {
      throw Exception('Settings not loaded');
    }

    try {
      return await UnifiedPrintService.generateReceiptPdf(
        widget.sale,
        settings: _settings!,
        databaseService: widget.databaseService,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
      rethrow;
    }
  }

  Future<void> _handlePrint() async {
    if (_settings == null) {
      AppSnackBar.show(
        context,
        const SnackBar(
          content: Text('Settings not loaded. Please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final success = await UnifiedPrintService.printReceipt(
        widget.sale,
        settings: _settings!,
        databaseService: widget.databaseService,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Receipt printed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'Failed to print receipt. Please check printer connection.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSettingsDialog() {
    if (_settings == null) return;

    showDialog(
      context: context,
      builder: (context) => _PrintSettingsDialog(
        settings: _settings!,
        onSave: (newSettings) {
          setState(() {
            _settings = newSettings;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Preview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Print Settings',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isLoading ? null : _handlePrint,
            tooltip: 'Print',
          ),
        ],
      ),
      body: _isLoading || _settings == null
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error generating preview',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          _loadSettings();
                        },
                        child: Text('common.retry'.tr()),
                      ),
                    ],
                  ),
                )
              : PdfPreview(
                  build: _generatePdf,
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: true,
                  canChangeOrientation: true,
                  canDebug: false,
                  pdfFileName: 'receipt_${widget.sale.id}.pdf',
                ),
    );
  }
}

class _PrintSettingsDialog extends StatefulWidget {
  final PrintSettings settings;
  final Function(PrintSettings) onSave;

  const _PrintSettingsDialog({
    required this.settings,
    required this.onSave,
  });

  @override
  State<_PrintSettingsDialog> createState() => _PrintSettingsDialogState();
}

class _PrintSettingsDialogState extends State<_PrintSettingsDialog> {
  late PrintSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    return Dialog(
      child: Container(
        width: isMobile ? screenSize.width * 0.95 : 600,
        height: isMobile ? screenSize.height * 0.9 : 700,
        constraints: BoxConstraints(
          maxWidth: isMobile ? screenSize.width * 0.95 : 600,
          maxHeight: isMobile ? screenSize.height * 0.9 : 700,
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Print Settings',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Printer Type
                    _buildSectionTitle('Printer Type'),
                    _buildDropdown<PrinterType>(
                      value: _settings.printerType,
                      items: PrinterType.values,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(printerType: value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Paper Size
                    _buildSectionTitle('Paper Size'),
                    _buildDropdown<PaperSize>(
                      value: _settings.paperSize,
                      items: PaperSize.values,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(paperSize: value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Receipt Style
                    _buildSectionTitle('Receipt Style'),
                    _buildDropdown<ReceiptStyle>(
                      value: _settings.receiptStyle,
                      items: ReceiptStyle.values,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(receiptStyle: value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Orientation
                    _buildSectionTitle('Orientation'),
                    _buildDropdown<PrintOrientation>(
                      value: _settings.orientation,
                      items: PrintOrientation.values,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(orientation: value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Display Options
                    _buildSectionTitle('Display Options'),
                    _buildCheckbox(
                      'Show Business Info',
                      _settings.showBusinessInfo,
                      (value) {
                        setState(() {
                          _settings =
                              _settings.copyWith(showBusinessInfo: value);
                        });
                      },
                    ),
                    _buildCheckbox(
                      'Show Customer Info',
                      _settings.showCustomerInfo,
                      (value) {
                        setState(() {
                          _settings =
                              _settings.copyWith(showCustomerInfo: value);
                        });
                      },
                    ),
                    _buildCheckbox(
                      'Show Item Details',
                      _settings.showItemDetails,
                      (value) {
                        setState(() {
                          _settings =
                              _settings.copyWith(showItemDetails: value);
                        });
                      },
                    ),
                    _buildCheckbox(
                      'Show Tax Breakdown',
                      _settings.showTaxBreakdown,
                      (value) {
                        setState(() {
                          _settings =
                              _settings.copyWith(showTaxBreakdown: value);
                        });
                      },
                    ),
                    _buildCheckbox(
                      'Show Payment Info',
                      _settings.showPaymentInfo,
                      (value) {
                        setState(() {
                          _settings =
                              _settings.copyWith(showPaymentInfo: value);
                        });
                      },
                    ),
                    _buildCheckbox(
                      'Show Footer',
                      _settings.showFooter,
                      (value) {
                        setState(() {
                          _settings = _settings.copyWith(showFooter: value);
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Font Settings
                    _buildSectionTitle('Font Settings'),
                    Row(
                      children: [
                        const Text('Font Size: '),
                        Expanded(
                          child: Slider(
                            value: _settings.fontSize.toDouble(),
                            min: 8,
                            max: 20,
                            divisions: 12,
                            label: _settings.fontSize.toString(),
                            onChanged: (value) {
                              setState(() {
                                _settings =
                                    _settings.copyWith(fontSize: value.toInt());
                              });
                            },
                          ),
                        ),
                        Text('${_settings.fontSize}'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Copies
                    _buildSectionTitle('Copies'),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _settings.copies > 1
                              ? () {
                                  setState(() {
                                    _settings = _settings.copyWith(
                                        copies: _settings.copies - 1);
                                  });
                                }
                              : null,
                        ),
                        Text('${_settings.copies}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _settings = _settings.copyWith(
                                  copies: _settings.copies + 1);
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Footer Text
                    _buildSectionTitle('Footer Text'),
                    TextField(
                      controller: TextEditingController(
                          text: _settings.footerText ?? ''),
                      decoration: const InputDecoration(
                        hintText: 'Enter custom footer text',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _settings = _settings.copyWith(
                            footerText: value.isEmpty ? null : value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('common.cancel'.tr()),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_settings);
                    Navigator.of(context).pop();
                  },
                  child: Text('common.save'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(_formatEnumName(item.toString())),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildCheckbox(String label, bool value, Function(bool) onChanged) {
    return CheckboxListTile(
      title: Text(label),
      value: value,
      onChanged: (newValue) => onChanged(newValue ?? false),
      dense: true,
    );
  }

  String _formatEnumName(String enumString) {
    return enumString
        .split('.')
        .last
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim();
  }
}
