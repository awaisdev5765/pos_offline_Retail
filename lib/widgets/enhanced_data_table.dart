import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_snack_bar.dart';

class EnhancedDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String? title;
  final List<Widget>? actions;
  final bool showSearch;
  final String? searchHint;
  final Function(String)? onSearch;
  final bool showPagination;
  final int currentPage;
  final int totalPages;
  final Function(int)? onPageChanged;
  final bool showSort;
  final Function(int, bool)? onSort;
  final int? sortColumnIndex;
  final bool sortAscending;

  const EnhancedDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.title,
    this.actions,
    this.showSearch = true,
    this.searchHint,
    this.onSearch,
    this.showPagination = false,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPageChanged,
    this.showSort = true,
    this.onSort,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  @override
  State<EnhancedDataTable> createState() => _EnhancedDataTableState();
}

class _EnhancedDataTableState extends State<EnhancedDataTable> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = cs.surface;
    final bandColor =
        isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow;
    final searchBandColor =
        isDark ? cs.surfaceContainerHighest : cs.surfaceContainerLow;
    final outline = cs.outlineVariant;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;
    final shadowColor =
        theme.shadowColor.withValues(alpha: isDark ? 0.28 : 0.06);

    final headingStyle = TextStyle(
      color: onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    );
    final cellStyle = TextStyle(
      color: onSurface,
      fontSize: 14,
    );

    final tableTheme = theme.copyWith(
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: headingStyle,
        dataTextStyle: cellStyle,
        headingRowColor: WidgetStateProperty.all(bandColor),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary.withValues(alpha: 0.18);
          }
          return null;
        }),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outline, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.title != null || widget.actions != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: bandColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(bottom: BorderSide(color: outline)),
              ),
              child: Row(
                children: [
                  if (widget.title != null)
                    Text(
                      widget.title!,
                      style: AppTypography.section.copyWith(
                        color: onSurface,
                      ),
                    ),
                  const Spacer(),
                  if (widget.actions != null) ...widget.actions!,
                ],
              ),
            ),

          if (widget.showSearch)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: searchBandColor,
                border: Border(bottom: BorderSide(color: outline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: onSurface),
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? 'Search...',
                        hintStyle: TextStyle(color: onSurfaceVariant),
                        prefixIcon: Icon(Icons.search, color: onSurfaceVariant),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: Icon(Icons.clear, color: onSurfaceVariant),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _isSearching = false);
                                  widget.onSearch?.call('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? cs.surfaceContainerHigh
                            : cs.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppColors.primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _isSearching = value.isNotEmpty);
                        widget.onSearch?.call(value);
                      },
                    ),
                  ),
                  if (widget.showSort) ...[
                    const SizedBox(width: AppSpacing.md),
                    IconButton(
                      icon: Icon(Icons.sort, color: onSurfaceVariant),
                      onPressed: _showSortOptions,
                      tooltip: 'Sort Options',
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: Icon(Icons.filter_list, color: onSurfaceVariant),
                    onPressed: _showFilterOptions,
                    tooltip: 'Filter Options',
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    icon: Icon(Icons.download, color: onSurfaceVariant),
                    onPressed: _exportData,
                    tooltip: 'Export Data',
                  ),
                ],
              ),
            ),

          Theme(
            data: tableTheme,
            child: ColoredBox(
              color: cardColor,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortAscending: widget.sortAscending,
                  sortColumnIndex: widget.sortColumnIndex,
                  columns: widget.columns.map((column) {
                    return DataColumn(
                      label: column.label,
                      onSort: widget.onSort != null
                          ? (columnIndex, ascending) {
                              widget.onSort!(columnIndex, ascending);
                            }
                          : null,
                    );
                  }).toList(),
                  rows: widget.rows,
                ),
              ),
            ),
          ),

          if (widget.showPagination && widget.totalPages > 1)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: bandColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: outline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${widget.currentPage} of ${widget.totalPages}',
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.currentPage > 1
                            ? () => widget.onPageChanged
                                ?.call(widget.currentPage - 1)
                            : null,
                        icon: Icon(Icons.chevron_left, color: onSurfaceVariant),
                      ),
                      ...List.generate(
                        widget.totalPages.clamp(0, 5),
                        (index) {
                          final page = index + 1;
                          final isCurrentPage = page == widget.currentPage;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: InkWell(
                              onTap: () => widget.onPageChanged?.call(page),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrentPage
                                      ? AppColors.primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$page',
                                  style: TextStyle(
                                    color: isCurrentPage
                                        ? Colors.white
                                        : onSurfaceVariant,
                                    fontWeight: isCurrentPage
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: widget.currentPage < widget.totalPages
                            ? () => widget.onPageChanged
                                ?.call(widget.currentPage + 1)
                            : null,
                        icon: Icon(Icons.chevron_right, color: onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.columns.asMap().entries.map((entry) {
            final index = entry.key;
            final column = entry.value;
            return ListTile(
              title: Text(column.label.toString()),
              trailing: widget.sortColumnIndex == index
                  ? Icon(
                      widget.sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      color: AppColors.primaryColor,
                    )
                  : null,
              onTap: () {
                Navigator.pop(context);
                widget.onSort?.call(index, !widget.sortAscending);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Options'),
        content: const Text(
            'Filter options will be implemented based on your data structure.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    // Show export options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export to Excel'),
              onTap: () {
                Navigator.pop(context);
                // Implement Excel export
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export to PDF'),
              onTap: () {
                Navigator.pop(context);
                // Implement PDF export
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('Export to CSV'),
              onTap: () {
                Navigator.pop(context);
                AppSnackBar.show(
                  context,
                  const SnackBar(
                      content: Text(
                          'CSV export is available in the Reports section')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }
}

// Enhanced table row with better styling
class EnhancedDataRow extends DataRow {
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const EnhancedDataRow({
    super.key,
    required super.cells,
    super.selected = false,
    super.onSelectChanged,
    this.isSelected = false,
    this.onTap,
    this.backgroundColor,
  });
}
