import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/sale.dart';
import '../models/currency.dart';
import '../theme/app_theme.dart';
import 'app_snack_bar.dart';

class PrintPreviewDialog extends StatelessWidget {
  final SaleModel sale;
  final Currency currency;
  final VoidCallback? onPrint;
  final VoidCallback? onExportPdf;
  final VoidCallback? onExportExcel;
  final VoidCallback? onEmail;

  const PrintPreviewDialog({
    super.key,
    required this.sale,
    required this.currency,
    this.onPrint,
    this.onExportPdf,
    this.onExportExcel,
    this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final headerBg =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow;
    final borderColor = cs.outlineVariant;
    final iconFg = cs.onSurfaceVariant;

    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Text(
                    'Print Preview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print),
                    tooltip: 'Print',
                    style: IconButton.styleFrom(foregroundColor: iconFg),
                  ),
                  IconButton(
                    onPressed: onExportPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    tooltip: 'Export PDF',
                    style: IconButton.styleFrom(foregroundColor: iconFg),
                  ),
                  IconButton(
                    onPressed: onExportExcel,
                    icon: const Icon(Icons.table_chart),
                    tooltip: 'Export Excel',
                    style: IconButton.styleFrom(foregroundColor: iconFg),
                  ),
                  IconButton(
                    onPressed: onEmail,
                    icon: const Icon(Icons.email),
                    tooltip: 'Email',
                    style: IconButton.styleFrom(foregroundColor: iconFg),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(foregroundColor: iconFg),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: isDark ? cs.surfaceContainerLowest : cs.surface,
                child: PdfPreview(
                  build: (format) => _generatePdf(format),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  initialPageFormat: PdfPageFormat.a4,
                  pdfFileName: 'receipt_${sale.id}.pdf',
                  scrollViewDecoration: BoxDecoration(color: cs.surface),
                  pdfPreviewPageDecoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(
                          alpha: isDark ? 0.35 : 0.12,
                        ),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  actionBarTheme: PdfActionBarTheme(
                    backgroundColor: headerBg,
                    iconColor: iconFg,
                    textStyle: TextStyle(color: cs.onSurface, fontSize: 14),
                    elevation: 0,
                  ),
                  loadingWidget: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              pw.SizedBox(height: 20),

              // Sale Info
              _buildSaleInfo(),
              pw.SizedBox(height: 20),

              // Items
              _buildItemsTable(),
              pw.SizedBox(height: 20),

              // Totals
              _buildTotals(),
              pw.SizedBox(height: 20),

              // Footer
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader() {
    return pw.Column(
      children: [
        pw.Text(
          'RECEIPT',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Sale #${sale.id}',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Date: ${_formatDate(sale.createdAt)}',
          style: const pw.TextStyle(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Time: ${_formatTime(sale.createdAt)}',
          style: const pw.TextStyle(fontSize: 12),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _buildSaleInfo() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Sale Information',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Order Type:', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('DINE_IN', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Payment:', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('CASH', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
          if (sale.customer != null) ...[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer:', style: const pw.TextStyle(fontSize: 12)),
                pw.Text(sale.customer?.name ?? '',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _buildTableCell('Item', isHeader: true),
            _buildTableCell('Qty', isHeader: true),
            _buildTableCell('Price', isHeader: true),
            _buildTableCell('Total', isHeader: true),
          ],
        ),
        // Items
        ...sale.items.map((item) => pw.TableRow(
              children: [
                _buildTableCell(item.product?.name ?? 'Unknown Product'),
                _buildTableCell('${item.qty.toInt()}'),
                _buildTableCell(
                    '${currency.symbol}${(item.product?.price ?? 0).toStringAsFixed(2)}'),
                _buildTableCell(
                    '${currency.symbol}${((item.product?.price ?? 0) * item.qty).toStringAsFixed(2)}'),
              ],
            )),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildTotals() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _buildTotalRow('Subtotal', sale.total - sale.discount),
          _buildTotalRow('Tax', 0),
          _buildTotalRow('Discount', -sale.discount),
          pw.Divider(),
          _buildTotalRow('TOTAL', sale.total, isTotal: true),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, double amount,
      {bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            '${currency.symbol}${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Text(
          'Thank you for your business!',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Please keep this receipt for your records',
          style: const pw.TextStyle(fontSize: 10),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// Export Options Dialog
class ExportOptionsDialog extends StatelessWidget {
  final String title;
  final List<ExportOption> options;
  final VoidCallback? onCancel;

  const ExportOptionsDialog({
    super.key,
    required this.title,
    required this.options,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      title: Text(title, style: TextStyle(color: cs.onSurface)),
      content: SizedBox(
        width: 400,
        child: ListView(
          shrinkWrap: true,
          children: options
              .map((option) => _buildExportOption(context, option))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
      ],
    );
  }

  Widget _buildExportOption(BuildContext context, ExportOption option) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = option.color ?? cs.primary;
    return ListTile(
      leading: Icon(option.icon, color: iconColor),
      title: Text(option.title, style: TextStyle(color: cs.onSurface)),
      subtitle: option.subtitle != null
          ? Text(
              option.subtitle!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            )
          : null,
      onTap: option.onTap,
      enabled: option.enabled,
    );
  }
}

class ExportOption {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;
  final bool enabled;

  const ExportOption({
    required this.title,
    this.subtitle,
    required this.icon,
    this.color,
    this.onTap,
    this.enabled = true,
  });
}

// Export Service
class ExportService {
  static void showExportDialog(
      BuildContext context, String title, List<dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => ExportOptionsDialog(
        title: title,
        options: [
          ExportOption(
            title: 'Export to PDF',
            subtitle: 'Generate PDF report',
            icon: Icons.picture_as_pdf,
            color: AppColors.errorColor,
            onTap: () => _exportToPdf(context, data),
          ),
          ExportOption(
            title: 'Export to Excel',
            subtitle: 'Generate Excel spreadsheet',
            icon: Icons.table_chart,
            color: AppColors.successColor,
            onTap: () => _exportToExcel(context, data),
          ),
          ExportOption(
            title: 'Export to CSV',
            subtitle: 'Generate CSV file',
            icon: Icons.text_snippet,
            color: AppColors.primaryColor,
            onTap: () => _exportToCsv(context, data),
          ),
          ExportOption(
            title: 'Email Report',
            subtitle: 'Send via email',
            icon: Icons.email,
            color: AppColors.warningColor,
            onTap: () => _emailReport(context, data),
          ),
        ],
      ),
    );
  }

  static SnackBar _themedInfoSnackBar(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return SnackBar(
      content: Text(
        message,
        style: TextStyle(color: cs.onInverseSurface),
      ),
      backgroundColor: cs.inverseSurface,
      behavior: SnackBarBehavior.floating,
    );
  }

  static void _exportToPdf(BuildContext context, List<dynamic> data) {
    Navigator.of(context).pop();
    AppSnackBar.show(
      context,
      _themedInfoSnackBar(
        context,
        'PDF export is available in the Reports section',
      ),
    );
  }

  static void _exportToExcel(BuildContext context, List<dynamic> data) {
    Navigator.of(context).pop();
    AppSnackBar.show(
      context,
      _themedInfoSnackBar(
        context,
        'Excel export is available in the Reports section',
      ),
    );
  }

  static void _exportToCsv(BuildContext context, List<dynamic> data) {
    Navigator.of(context).pop();
    AppSnackBar.show(
      context,
      _themedInfoSnackBar(
        context,
        'CSV export is available in the Reports section',
      ),
    );
  }

  static void _emailReport(BuildContext context, List<dynamic> data) {
    Navigator.of(context).pop();
    AppSnackBar.show(
      context,
      _themedInfoSnackBar(
        context,
        'Email functionality will be implemented in future updates',
      ),
    );
  }
}
