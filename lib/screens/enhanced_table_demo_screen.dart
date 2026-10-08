import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../widgets/enhanced_data_table.dart';
import '../theme/app_theme.dart';

class EnhancedTableDemoScreen extends StatefulWidget {
  const EnhancedTableDemoScreen({super.key});

  @override
  State<EnhancedTableDemoScreen> createState() =>
      _EnhancedTableDemoScreenState();
}

class _EnhancedTableDemoScreenState extends State<EnhancedTableDemoScreen> {
  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _searchQuery = '';
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _generateSampleData();
    _filteredData = List.from(_data);
  }

  void _generateSampleData() {
    _data = List.generate(50, (index) {
      return {
        'id': index + 1,
        'name': 'Customer ${index + 1}',
        'email': 'customer${index + 1}@example.com',
        'amount': (100 + (index * 25.5)).toStringAsFixed(2),
        'date':
            DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'status': ['Active', 'Inactive', 'Pending'][index % 3],
        'category': ['Premium', 'Standard', 'Basic'][index % 3],
      };
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredData = _data.where((item) {
        return item['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            item['email']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ||
            item['status']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase());
      }).toList();
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;

      _filteredData.sort((a, b) {
        String key = '';
        switch (columnIndex) {
          case 0:
            key = 'name';
            break;
          case 1:
            key = 'email';
            break;
          case 2:
            key = 'amount';
            break;
          case 3:
            key = 'date';
            break;
          case 4:
            key = 'status';
            break;
        }

        var aValue = a[key];
        var bValue = b[key];

        if (key == 'amount') {
          double aNum = double.tryParse(aValue.toString()) ?? 0;
          double bNum = double.tryParse(bValue.toString()) ?? 0;
          return ascending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
        } else if (key == 'date') {
          DateTime aDate =
              DateTime.tryParse(aValue.toString()) ?? DateTime.now();
          DateTime bDate =
              DateTime.tryParse(bValue.toString()) ?? DateTime.now();
          return ascending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
        } else {
          return ascending
              ? aValue.toString().compareTo(bValue.toString())
              : bValue.toString().compareTo(aValue.toString());
        }
      });
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  List<DataColumn> _buildColumns() {
    return [
      DataColumn(
        label: Text('misc.demo_col_name'.tr()),
      ),
      DataColumn(
        label: Text('misc.demo_col_email'.tr()),
      ),
      DataColumn(
        label: Text('misc.demo_col_amount'.tr()),
      ),
      DataColumn(
        label: Text('misc.demo_col_date'.tr()),
      ),
      DataColumn(
        label: Text('misc.demo_col_status'.tr()),
      ),
      DataColumn(
        label: Text('misc.demo_col_actions'.tr()),
      ),
    ];
  }

  List<DataRow> _buildRows() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, _filteredData.length);
    final pageData = _filteredData.sublist(startIndex, endIndex);

    return pageData.map((item) {
      return DataRow(
        cells: [
          DataCell(Text(item['name'])),
          DataCell(Text(item['email'])),
          DataCell(Text('\$${item['amount']}')),
          DataCell(Text(_formatDate(item['date']))),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(item['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _getStatusColor(item['status']).withOpacity(0.3)),
              ),
              child: Text(
                item['status'],
                style: TextStyle(
                  color: _getStatusColor(item['status']),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => _editItem(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 16),
                  onPressed: () => _deleteItem(item),
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _editItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('misc.demo_edit_item'.tr()),
        content: Text('misc.demo_edit_body'
            .tr(namedArgs: {'name': '${item['name']}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('misc.demo_delete_item'.tr()),
        content: Text('misc.demo_delete_confirm'
            .tr(namedArgs: {'name': '${item['name']}'})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _data.removeWhere((data) => data['id'] == item['id']);
                _onSearch(_searchQuery); // Refresh filtered data
              });
              Navigator.pop(context);
            },
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredData.length / _itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: Text('misc.demo_table_title'.tr()),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EnhancedDataTable(
          title: 'misc.demo_customer_data'.tr(),
          columns: _buildColumns(),
          rows: _buildRows(),
          showSearch: true,
          searchHint: 'misc.demo_search_hint'.tr(),
          onSearch: _onSearch,
          showPagination: true,
          currentPage: _currentPage,
          totalPages: totalPages,
          onPageChanged: _onPageChanged,
          showSort: true,
          onSort: _onSort,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('misc.demo_add_item'.tr()),
                    content: Text('misc.demo_add_hint'.tr()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('common.close'.tr()),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _generateSampleData();
                  _onSearch(_searchQuery);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
