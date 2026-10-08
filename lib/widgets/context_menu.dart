import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ContextMenu extends StatefulWidget {
  final Widget child;
  final List<ContextMenuItem> items;
  final bool enabled;
  final Offset? offset;
  final String? title;

  const ContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.enabled = true,
    this.offset,
    this.title,
  });

  @override
  State<ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<ContextMenu> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTap: widget.enabled ? _showContextMenu : null,
      onLongPress: widget.enabled ? _showContextMenu : null,
      child: widget.child,
    );
  }

  void _showContextMenu() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = widget.offset ?? renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant, width: 1),
      ),
      items: widget.items.map((item) => _buildMenuItem(context, item)).toList(),
    );
  }

  PopupMenuItem<dynamic> _buildMenuItem(BuildContext context, ContextMenuItem item) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    if (item.isDivider) {
      return PopupMenuItem(
        enabled: false,
        child: Divider(height: 1, color: cs.outlineVariant),
      );
    }

    final titleColor = item.color ??
        (item.isDestructive ? cs.error : onSurface);
    final iconColor = item.color ??
        (item.isDestructive ? cs.error : onSurfaceVariant);

    return PopupMenuItem<dynamic>(
      value: item.value,
      enabled: item.enabled,
      onTap: item.onTap,
      child: ListTile(
        leading: item.icon != null
            ? Icon(item.icon, size: 20, color: iconColor)
            : null,
        title: Text(
          item.label,
          style: TextStyle(
            color: titleColor,
            fontWeight:
                item.isDestructive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: item.subtitle != null
            ? Text(
                item.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: onSurfaceVariant,
                ),
              )
            : null,
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }
}

class ContextMenuItem {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDestructive;
  final bool isDivider;

  const ContextMenuItem({
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
    this.value,
    this.onTap,
    this.enabled = true,
    this.isDestructive = false,
    this.isDivider = false,
  });

  const ContextMenuItem.divider()
      : label = '',
        subtitle = null,
        icon = null,
        color = null,
        value = null,
        onTap = null,
        enabled = false,
        isDestructive = false,
        isDivider = true;
}

// Specialized context menus for different data types
class CustomerContextMenu extends StatelessWidget {
  final Widget child;
  final String customerId;
  final String customerName;
  final bool hasOutstandingBalance;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onRecordPayment;
  final VoidCallback? onViewLedger;
  final VoidCallback? onDelete;

  const CustomerContextMenu({
    super.key,
    required this.child,
    required this.customerId,
    required this.customerName,
    this.hasOutstandingBalance = false,
    this.onViewDetails,
    this.onEdit,
    this.onRecordPayment,
    this.onViewLedger,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      title: customerName,
      items: [
        ContextMenuItem(
          label: 'View Details',
          icon: Icons.visibility,
          onTap: onViewDetails,
        ),
        ContextMenuItem(
          label: 'Edit Customer',
          icon: Icons.edit,
          onTap: onEdit,
        ),
        ContextMenuItem(
          label: 'View Ledger',
          icon: Icons.account_balance_wallet,
          onTap: onViewLedger,
        ),
        if (hasOutstandingBalance)
          ContextMenuItem(
            label: 'Record Payment',
            icon: Icons.payment,
            color: AppColors.successColor,
            onTap: onRecordPayment,
          ),
        const ContextMenuItem.divider(),
        ContextMenuItem(
          label: 'Delete Customer',
          icon: Icons.delete,
          color: AppColors.errorColor,
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
      child: child,
    );
  }
}

class ProductContextMenu extends StatelessWidget {
  final Widget child;
  final String productId;
  final String productName;
  final bool isInStock;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEdit;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onViewHistory;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const ProductContextMenu({
    super.key,
    required this.child,
    required this.productId,
    required this.productName,
    this.isInStock = true,
    this.onViewDetails,
    this.onEdit,
    this.onAdjustStock,
    this.onViewHistory,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      title: productName,
      items: [
        ContextMenuItem(
          label: 'View Details',
          icon: Icons.visibility,
          onTap: onViewDetails,
        ),
        ContextMenuItem(
          label: 'Edit Product',
          icon: Icons.edit,
          onTap: onEdit,
        ),
        ContextMenuItem(
          label: 'Adjust Stock',
          icon: Icons.inventory,
          onTap: onAdjustStock,
        ),
        ContextMenuItem(
          label: 'View History',
          icon: Icons.history,
          onTap: onViewHistory,
        ),
        ContextMenuItem(
          label: 'Duplicate Product',
          icon: Icons.copy,
          onTap: onDuplicate,
        ),
        const ContextMenuItem.divider(),
        ContextMenuItem(
          label: 'Delete Product',
          icon: Icons.delete,
          color: AppColors.errorColor,
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
      child: child,
    );
  }
}

class SaleContextMenu extends StatelessWidget {
  final Widget child;
  final String saleId;
  final double total;
  final String status;
  final VoidCallback? onViewDetails;
  final VoidCallback? onPrintReceipt;
  final VoidCallback? onRefund;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const SaleContextMenu({
    super.key,
    required this.child,
    required this.saleId,
    required this.total,
    required this.status,
    this.onViewDetails,
    this.onPrintReceipt,
    this.onRefund,
    this.onDuplicate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      title: 'Sale #$saleId',
      items: [
        ContextMenuItem(
          label: 'View Details',
          icon: Icons.visibility,
          onTap: onViewDetails,
        ),
        ContextMenuItem(
          label: 'Print Receipt',
          icon: Icons.print,
          onTap: onPrintReceipt,
        ),
        if (status == 'completed')
          ContextMenuItem(
            label: 'Process Refund',
            icon: Icons.undo,
            color: AppColors.warningColor,
            onTap: onRefund,
          ),
        ContextMenuItem(
          label: 'Duplicate Sale',
          icon: Icons.copy,
          onTap: onDuplicate,
        ),
        const ContextMenuItem.divider(),
        ContextMenuItem(
          label: 'Delete Sale',
          icon: Icons.delete,
          color: AppColors.errorColor,
          isDestructive: true,
          onTap: onDelete,
        ),
      ],
      child: child,
    );
  }
}

// Generic table row context menu
class TableRowContextMenu extends StatelessWidget {
  final Widget child;
  final List<ContextMenuItem> items;
  final String? title;

  const TableRowContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      title: title,
      items: items,
      child: child,
    );
  }
}

// Bulk actions context menu
class BulkActionsContextMenu extends StatelessWidget {
  final Widget child;
  final int selectedCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback? onExportSelected;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onBulkEdit;

  const BulkActionsContextMenu({
    super.key,
    required this.child,
    required this.selectedCount,
    this.onSelectAll,
    this.onClearSelection,
    this.onExportSelected,
    this.onDeleteSelected,
    this.onBulkEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      title: '$selectedCount items selected',
      items: [
        ContextMenuItem(
          label: 'Select All',
          icon: Icons.select_all,
          onTap: onSelectAll,
        ),
        ContextMenuItem(
          label: 'Clear Selection',
          icon: Icons.clear,
          onTap: onClearSelection,
        ),
        const ContextMenuItem.divider(),
        ContextMenuItem(
          label: 'Export Selected',
          icon: Icons.download,
          onTap: onExportSelected,
        ),
        ContextMenuItem(
          label: 'Bulk Edit',
          icon: Icons.edit,
          onTap: onBulkEdit,
        ),
        ContextMenuItem(
          label: 'Delete Selected',
          icon: Icons.delete,
          color: AppColors.errorColor,
          isDestructive: true,
          onTap: onDeleteSelected,
        ),
      ],
      child: child,
    );
  }
}

// Context menu for navigation items
class NavigationContextMenu extends StatelessWidget {
  final Widget child;
  final String route;
  final VoidCallback? onOpenInNewTab;
  final VoidCallback? onBookmark;
  final VoidCallback? onPin;

  const NavigationContextMenu({
    super.key,
    required this.child,
    required this.route,
    this.onOpenInNewTab,
    this.onBookmark,
    this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    return ContextMenu(
      items: [
        ContextMenuItem(
          label: 'Open in New Tab',
          icon: Icons.open_in_new,
          onTap: onOpenInNewTab,
        ),
        ContextMenuItem(
          label: 'Bookmark',
          icon: Icons.bookmark_border,
          onTap: onBookmark,
        ),
        ContextMenuItem(
          label: 'Pin to Sidebar',
          icon: Icons.push_pin,
          onTap: onPin,
        ),
      ],
      child: child,
    );
  }
}
