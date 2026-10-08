import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../services/windows_printer_detection_service.dart';
import '../services/unified_print_service.dart' show UnifiedPrintService;
import '../widgets/universal_app_bar.dart';
import '../widgets/app_snack_bar.dart';

class WindowsPrinterDetectionScreen extends ConsumerStatefulWidget {
  const WindowsPrinterDetectionScreen({super.key});

  @override
  ConsumerState<WindowsPrinterDetectionScreen> createState() =>
      _WindowsPrinterDetectionScreenState();
}

class _WindowsPrinterDetectionScreenState
    extends ConsumerState<WindowsPrinterDetectionScreen> {
  List<WindowsPrinter> _windowsPrinters = [];
  List<NetworkPrinter> _networkPrinters = [];
  bool _isDetecting = false;
  String _detectionStatus = 'Ready to detect printers';
  String? _selectedPrinter;
  PrinterStatus? _printerStatus;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _detectAllPrinters();
    }
  }

  Future<void> _detectAllPrinters() async {
    if (!Platform.isWindows) {
      setState(() {
        _detectionStatus = 'printer_win.windows_only'.tr();
      });
      return;
    }

    setState(() {
      _isDetecting = true;
      _detectionStatus = 'printer_win.detecting_win'.tr();
    });

    try {
      // Detect Windows printers
      final windowsPrinters =
          await WindowsPrinterDetectionService.detectAllPrinters();

      setState(() {
        _detectionStatus = 'printer_win.detecting_net'.tr();
      });

      // Detect network printers
      final networkPrinters =
          await WindowsPrinterDetectionService.detectNetworkPrinters();

      setState(() {
        _windowsPrinters = windowsPrinters;
        _networkPrinters = networkPrinters;
        _isDetecting = false;
        _detectionStatus = 'printer_win.detection_complete'.tr(namedArgs: {
          'win': '${windowsPrinters.length}',
          'net': '${networkPrinters.length}',
        });
      });
    } catch (e) {
      setState(() {
        _isDetecting = false;
        _detectionStatus = 'printer_win.error_detecting'
            .tr(namedArgs: {'error': '$e'});
      });
    }
  }

  Future<void> _testPrinter(String printerName) async {
    setState(() {
      _detectionStatus = 'printer_win.testing_printer'
          .tr(namedArgs: {'name': printerName});
    });

    try {
      final isConnected =
          await WindowsPrinterDetectionService.testPrinterConnection(
              printerName);
      final status =
          await WindowsPrinterDetectionService.getPrinterStatus(printerName);

      setState(() {
        _printerStatus = status;
        _detectionStatus = isConnected
            ? 'printer_win.printer_ready'.tr(namedArgs: {'name': printerName})
            : 'printer_win.printer_not_responding'
                .tr(namedArgs: {'name': printerName});
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(isConnected
                ? 'printer_win.test_success'.tr()
                : 'printer_win.test_failed'.tr()),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _detectionStatus = 'printer_win.error_testing_printer'
            .tr(namedArgs: {'error': '$e'});
      });
    }
  }

  Future<void> _testNetworkPrinter(String ip) async {
    setState(() {
      _detectionStatus =
          'printer_win.testing_network'.tr(namedArgs: {'ip': ip});
    });

    try {
      final isConnected = await UnifiedPrintService.testPrinterConnection(
        printerIp: ip,
      );

      setState(() {
        _detectionStatus = isConnected
            ? 'printer_win.network_ready'.tr(namedArgs: {'ip': ip})
            : 'printer_win.network_not_responding'.tr(namedArgs: {'ip': ip});
      });

      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(isConnected
                ? 'printer_win.network_test_success'.tr()
                : 'printer_win.network_test_failed'.tr()),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _detectionStatus = 'printer_win.error_testing_network'
            .tr(namedArgs: {'error': '$e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return Scaffold(
        appBar: UniversalAppBar(title: 'misc.printer_detection'.tr()),
        body: Center(
          child: Text('printer_win.windows_only'.tr()),
        ),
      );
    }

    return Scaffold(
      appBar: UniversalAppBar(title: 'printer_win.title_detection'.tr()),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                if (_isDetecting)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _detectionStatus.isEmpty
                        ? 'printer_win.ready'.tr()
                        : _detectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  onPressed: _isDetecting ? null : _detectAllPrinters,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'printer_win.refresh'.tr(),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Windows Printers Section
                  _buildSectionCard(
                    title: 'printer_win.section_windows'.tr(namedArgs: {
                      'count': '${_windowsPrinters.length}',
                    }),
                    icon: Icons.print,
                    children: [
                      if (_windowsPrinters.isEmpty)
                        Text('printer_win.no_win'.tr()),
                      ..._windowsPrinters.map((printer) => _buildPrinterCard(
                            title: printer.name,
                            subtitle: 'printer_win.port_driver'.tr(namedArgs: {
                              'port': printer.port,
                              'driver': printer.driver,
                            }),
                            isThermal: printer.isThermal,
                            isOffline: printer.isOffline,
                            status: printer.status,
                            onTest: () => _testPrinter(printer.name),
                            onSelect: () {
                              setState(() {
                                _selectedPrinter = printer.name;
                              });
                            },
                            isSelected: _selectedPrinter == printer.name,
                          )),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Network Printers Section
                  _buildSectionCard(
                    title: 'printer_win.section_network'.tr(namedArgs: {
                      'count': '${_networkPrinters.length}',
                    }),
                    icon: Icons.wifi,
                    children: [
                      if (_networkPrinters.isEmpty)
                        Text('printer_win.no_net'.tr()),
                      ..._networkPrinters
                          .map((printer) => _buildNetworkPrinterCard(
                                ip: printer.ip,
                                port: printer.port,
                                name: printer.name,
                                onTest: () => _testNetworkPrinter(printer.ip),
                                onSelect: () {
                                  setState(() {
                                    _selectedPrinter = printer.ip;
                                  });
                                },
                                isSelected: _selectedPrinter == printer.ip,
                              )),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Manual IP Entry
                  _buildSectionCard(
                    title: 'printer_win.manual_ip'.tr(),
                    icon: Icons.edit,
                    children: [
                      Text('printer_win.enter_ip'.tr()),
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'printer_win.label_printer_ip'.tr(),
                          hintText: '192.168.1.100',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.computer),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedPrinter = value;
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Selected Printer Info
                  if (_selectedPrinter != null)
                    _buildSectionCard(
                      title: 'printer_win.selected_printer'.tr(),
                      icon: Icons.check_circle,
                      children: [
                        Text('printer_win.printer_line'
                            .tr(namedArgs: {'name': _selectedPrinter!})),
                        if (_printerStatus != null)
                          Text('printer_win.status_line'.tr(namedArgs: {
                            'status': _printerStatus!.name,
                          })),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // Navigate back with selected printer
                              Navigator.pop(context, _selectedPrinter);
                            },
                            icon: const Icon(Icons.check),
                            label: Text('printer_win.use_printer'.tr()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
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

  Widget _buildPrinterCard({
    required String title,
    required String subtitle,
    required bool isThermal,
    required bool isOffline,
    required String status,
    required VoidCallback onTest,
    required VoidCallback onSelect,
    required bool isSelected,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(
          isThermal ? Icons.receipt : Icons.print,
          color: isThermal ? Colors.orange : Colors.blue,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            const SizedBox(height: 4),
            Row(
              children: [
                if (isThermal)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'printer_win.badge_thermal'.tr(),
                      style: const TextStyle(
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
                    color: isOffline ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOffline
                        ? 'printer_win.badge_offline'.tr()
                        : 'printer_win.badge_online'.tr(),
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
              onPressed: onTest,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'printer_win.test_printer'.tr(),
            ),
            IconButton(
              onPressed: onSelect,
              icon: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Colors.blue : null,
              ),
              tooltip: 'printer_win.select_printer'.tr(),
            ),
          ],
        ),
        onTap: onSelect,
      ),
    );
  }

  Widget _buildNetworkPrinterCard({
    required String ip,
    required int port,
    required String name,
    required VoidCallback onTest,
    required VoidCallback onSelect,
    required bool isSelected,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Colors.green.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: const Icon(Icons.wifi, color: Colors.green),
        title: Text(name),
        subtitle: Text('printer_win.ip_port_subtitle'
            .tr(namedArgs: {'ip': ip, 'port': '$port'})),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onTest,
              icon: const Icon(Icons.play_arrow),
              tooltip: 'printer_win.test_connection'.tr(),
            ),
            IconButton(
              onPressed: onSelect,
              icon: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected ? Colors.green : null,
              ),
              tooltip: 'printer_win.select_printer'.tr(),
            ),
          ],
        ),
        onTap: onSelect,
      ),
    );
  }
}
