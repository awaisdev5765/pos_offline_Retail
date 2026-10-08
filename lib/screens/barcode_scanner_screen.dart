import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/sale_provider.dart';
import '../providers/audio_provider.dart';
import '../services/database_service.dart';
import '../widgets/app_snack_bar.dart';

class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  MobileScannerController? controller;
  bool _isScanning = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Only initialize mobile scanner on mobile platforms
    if (Platform.isAndroid || Platform.isIOS) {
      controller = MobileScannerController();
      _isScanning = true;
      _isInitialized = true;
    } else {
      _isInitialized = false;
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Windows/Linux/Desktop: Show manual entry interface
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('barcode_scr.enter_title'.tr()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/pos');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 24),
                Text(
                  'barcode_scr.windows_not_available'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'barcode_scr.enter_manually_below'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.keyboard),
                    label: Text('barcode_scr.enter_manually'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile: Show camera scanner
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('barcode_scr.scan_title'.tr()),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/pos');
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
                if (_isScanning) {
                  controller?.start();
                } else {
                  controller?.stop();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller?.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => controller?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          if (controller != null)
            MobileScanner(
              controller: controller!,
              onDetect: _onBarcodeDetected,
            ),

          // Scanning overlay
          _buildScanningOverlay(),

          // Manual entry button
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: _buildManualEntryButton(),
          ),

          // Recent scans
          if (_lastScannedCode != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: _buildRecentScanCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: Colors.white,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: 300,
        ),
      ),
    );
  }

  Widget _buildManualEntryButton() {
    return ElevatedButton.icon(
      onPressed: _showManualEntryDialog,
      icon: const Icon(Icons.keyboard),
      label: Text('barcode_scr.enter_manually'.tr()),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildRecentScanCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'barcode_scr.last_scanned'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  _lastScanTime != null
                      ? 'barcode_scr.seconds_ago'.tr(namedArgs: {
                          'seconds':
                              '${DateTime.now().difference(_lastScanTime!).inSeconds}',
                        })
                      : '',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _lastScannedCode!,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isScanning || controller == null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScannedCode) return;

    // Prevent duplicate scans within 2 seconds
    if (_lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    setState(() {
      _lastScannedCode = code;
      _lastScanTime = DateTime.now();
    });

    _handleBarcodeScanned(code);
  }

  Future<void> _handleBarcodeScanned(String barcode) async {
    try {
      // Stop scanning temporarily
      setState(() => _isScanning = false);
      controller?.stop();

      // Look up product by barcode
      final databaseService = ref.read(databaseServiceProvider);
      final product = await databaseService.getProductByBarcode(barcode);

      if (product != null) {
        final existingQuantity = ref
            .read(cartProvider)
            .where((item) => !item.isBundle && item.product?.id == product.id)
            .fold<double>(0, (sum, item) => sum + item.quantity);
        if (product.stock <= 0 || existingQuantity >= product.stock) {
          if (mounted) {
            AppSnackBar.show(
              context,
              SnackBar(
                content: Text('${product.name} is out of stock.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          ref.read(audioServiceProvider).playErrorSound();
          if (mounted && controller != null) {
            setState(() => _isScanning = true);
            controller?.start();
          }
          return;
        }

        // Add product to cart
        final cartNotifier = ref.read(cartProvider.notifier);
        cartNotifier.addProduct(product);

        // Show success feedback
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('barcode_scr.added_to_cart'
                  .tr(namedArgs: {'name': product.name})),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Play success sound
        final audioService = ref.read(audioServiceProvider);
        audioService.playSuccessSound();

        // Navigate back to POS after a short delay
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Product not found
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('barcode_scr.product_not_found'
                  .tr(namedArgs: {'barcode': barcode})),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'barcode_scr.add_product'.tr(),
                textColor: Colors.white,
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to add product screen with barcode pre-filled
                  // context.push('/add-product?barcode=$barcode');
                },
              ),
            ),
          );
        }

        // Play error sound
        final audioService = ref.read(audioServiceProvider);
        audioService.playErrorSound();

        // Resume scanning after delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted && controller != null) {
          setState(() => _isScanning = true);
          controller?.start();
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text(
                'barcode_scr.error_scanning'.tr(namedArgs: {'error': '$e'})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showManualEntryDialog() {
    final TextEditingController barcodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('barcode_scr.enter_title'.tr()),
        content: TextField(
          controller: barcodeController,
          decoration: InputDecoration(
            hintText: 'barcode_scr.hint_enter_barcode'.tr(),
            prefixIcon: const Icon(Icons.qr_code),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = barcodeController.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context);
                _handleBarcodeScanned(barcode);
              }
            },
            child: Text('barcode_scr.search'.tr()),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape for barcode scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
    this.cutOutBottomOffset = 0,
  }) : cutOutSize = cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;
  final double cutOutBottomOffset;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {ui.TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {ui.TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
            rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {ui.TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final cutOutWidth =
        cutOutSize < width ? cutOutSize : width - borderWidthSize;
    final cutOutHeight =
        cutOutSize < height ? cutOutSize : height - borderWidthSize;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - cutOutWidth / 2 + cutOutBottomOffset,
      rect.top + height / 2 - cutOutHeight / 2,
      cutOutWidth,
      cutOutHeight,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw border
    final path = Path()
      ..moveTo(cutOutRect.left - borderWidth / 2, cutOutRect.top + borderLength)
      ..lineTo(cutOutRect.left - borderWidth / 2, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
          cutOutRect.left - borderWidth / 2,
          cutOutRect.top - borderWidth / 2,
          cutOutRect.left + borderRadius,
          cutOutRect.top - borderWidth / 2)
      ..lineTo(cutOutRect.left + borderLength, cutOutRect.top - borderWidth / 2)
      ..moveTo(
          cutOutRect.right + borderWidth / 2, cutOutRect.top + borderLength)
      ..lineTo(
          cutOutRect.right + borderWidth / 2, cutOutRect.top + borderRadius)
      ..quadraticBezierTo(
          cutOutRect.right + borderWidth / 2,
          cutOutRect.top - borderWidth / 2,
          cutOutRect.right - borderRadius,
          cutOutRect.top - borderWidth / 2)
      ..lineTo(
          cutOutRect.right - borderLength, cutOutRect.top - borderWidth / 2)
      ..moveTo(
          cutOutRect.left - borderWidth / 2, cutOutRect.bottom - borderLength)
      ..lineTo(
          cutOutRect.left - borderWidth / 2, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
          cutOutRect.left - borderWidth / 2,
          cutOutRect.bottom + borderWidth / 2,
          cutOutRect.left + borderRadius,
          cutOutRect.bottom + borderWidth / 2)
      ..lineTo(
          cutOutRect.left + borderLength, cutOutRect.bottom + borderWidth / 2)
      ..moveTo(
          cutOutRect.right + borderWidth / 2, cutOutRect.bottom - borderLength)
      ..lineTo(
          cutOutRect.right + borderWidth / 2, cutOutRect.bottom - borderRadius)
      ..quadraticBezierTo(
          cutOutRect.right + borderWidth / 2,
          cutOutRect.bottom + borderWidth / 2,
          cutOutRect.right - borderRadius,
          cutOutRect.bottom + borderWidth / 2)
      ..lineTo(
          cutOutRect.right - borderLength, cutOutRect.bottom + borderWidth / 2);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
