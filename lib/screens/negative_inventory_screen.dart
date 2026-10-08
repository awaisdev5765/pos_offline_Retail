import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/product.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_snack_bar.dart';

class NegativeInventoryScreen extends ConsumerStatefulWidget {
  const NegativeInventoryScreen({super.key});

  @override
  ConsumerState<NegativeInventoryScreen> createState() =>
      _NegativeInventoryScreenState();
}

class _NegativeInventoryScreenState
    extends ConsumerState<NegativeInventoryScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final databaseService = ref.watch(databaseServiceProvider);

    return FutureBuilder<Map<String, String>>(
      future: databaseService.getSettings(),
      builder: (context, settingsSnap) {
        final businessName =
            settingsSnap.data?['business_name'] ?? 'NEW AL M SUPER STORE';
        final businessAddress =
            settingsSnap.data?['business_address'] ?? 'Address';
        return Scaffold(
          backgroundColor:
              isDarkMode ? const Color(0xFF1C2128) : const Color(0xFFF5F7FB),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(businessName, businessAddress),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: FutureBuilder<List<ProductModel>>(
                      future: databaseService.getAllProducts(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final all = snapshot.data ?? [];
                        // Only show products where:
                        // 1. Purchase rate (cost) is greater than retail cash (price)
                        // 2. Stock quantity is negative (in minus)
                        final productsToShow = all
                            .where((p) => p.stock < 0 && p.cost > p.price)
                            .toList()
                          ..sort((a, b) => a.name.compareTo(b.name));
                        if (productsToShow.isEmpty) {
                          return Center(
                            child: Text(
                              'negative_inv.empty'.tr(),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return _buildReportTable(
                            context, productsToShow, databaseService);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(String businessName, String address) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              businessName.toUpperCase(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'negative_inv.address_label'.tr(namedArgs: {'address': address}),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'negative_inv.report_title'.tr(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTable(BuildContext context, List<ProductModel> products,
      DatabaseService databaseService) {
    // Column widths approximated to match reference
    const double srWidth = 60;
    const double codeWidth = 90;
    const double nameWidth = 320;
    const double purWidth = 120;
    const double retailWidth = 120;
    const double unitWidth = 80;
    const double stockWidth = 100;

    final headerStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF1F2937),
    );

    final cellStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF111827),
    );

    Widget buildHeaderCell(String text, double width,
        {TextAlign align = TextAlign.center}) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE5EEF8),
          border: Border.all(color: const Color(0xFFD0D7E2)),
        ),
        child: Text(text, style: headerStyle, textAlign: align),
      );
    }

    Widget buildCell(String text, double width,
        {Color? bg, TextAlign align = TextAlign.center}) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          border: Border(
            left: const BorderSide(color: Color(0xFFE5E7EB)),
            right: const BorderSide(color: Color(0xFFE5E7EB)),
            bottom: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(text,
            style: cellStyle,
            textAlign: align,
            overflow: TextOverflow.ellipsis),
      );
    }

    // Editable stock cell
    Widget buildEditableStockCell(ProductModel product, double width,
        {Color? bg}) {
      final controller = TextEditingController(text: _fmt(product.stock));
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          border: const Border(
            left: BorderSide(color: Color(0xFFE5E7EB)),
            right: BorderSide(color: Color(0xFFE5E7EB)),
            bottom: BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: TextFormField(
          controller: controller,
          textAlign: TextAlign.center,
          style: cellStyle,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,4}')),
          ],
          onFieldSubmitted: (value) async {
            final newQty = double.tryParse(value.trim()) ?? product.stock;
            // If unchanged or product has no id, skip
            if ((newQty - product.stock).abs() < 0.0001 || product.id == null)
              return;
            final delta = newQty - product.stock;
            try {
              await databaseService.adjustStock(
                product.id!,
                delta,
                'Manual Adjustment (Negative Inventory)',
                reference: 'NegativeInventoryScreen',
              );
              if (mounted) {
                AppSnackBar.show(
                  context,
                  SnackBar(
                    content: Text(
                        'Stock updated for "${product.name}" to ${_fmt(newQty)}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {}); // refresh
              }
            } catch (e) {
              if (mounted) {
                AppSnackBar.show(
                  context,
                  SnackBar(
                    content: Text('Failed to update stock: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
      );
    }

    final totalWidth = srWidth +
        codeWidth +
        nameWidth +
        purWidth +
        retailWidth +
        unitWidth +
        stockWidth;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                children: [
                  buildHeaderCell('Sr. No', srWidth),
                  buildHeaderCell('Code', codeWidth),
                  buildHeaderCell('Item Name', nameWidth,
                      align: TextAlign.left),
                  buildHeaderCell('Pur Price', purWidth),
                  buildHeaderCell('Retail Cash', retailWidth),
                  buildHeaderCell('Unit', unitWidth),
                  buildHeaderCell('Stock Qty', stockWidth),
                ],
              ),
              ...List.generate(products.length, (index) {
                final p = products[index];
                final sr = (index + 1).toString();
                final code = (p.id ?? 0).toString();
                final name = p.name;
                final pur = _fmt(p.cost);
                final retail = _fmt(p.price);
                final unit = p.unit;
                final stock = _fmt(p.stock);

                // Highlight rules (yellow) similar to reference:
                // - Negative stock
                // - Retail cash <= 0 or retail < purchase (cost > price)
                // - Cost price > retail cash price (negative inventory item)
                final isNegativeInventoryItem = p.cost > p.price;
                final highlightRetail = (p.price <= 0) ||
                    (p.price < p.cost) ||
                    isNegativeInventoryItem;
                final highlightStock = p.stock < 0;
                final yellow = const Color(0xFFFFF59D); // light yellow

                return Row(
                  children: [
                    buildCell(sr, srWidth),
                    buildCell(code, codeWidth),
                    buildCell(name, nameWidth, align: TextAlign.left),
                    buildCell(pur, purWidth),
                    buildCell(retail, retailWidth,
                        bg: highlightRetail ? yellow : null),
                    buildCell(unit, unitWidth),
                    buildEditableStockCell(p, stockWidth,
                        bg: highlightStock ? yellow : null),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(num value) {
    if (value is int) return value.toString();
    final v = value.toDouble();
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
  }
}
