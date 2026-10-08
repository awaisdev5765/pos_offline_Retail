import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/currency_provider.dart';
import '../providers/product_provider.dart';
import '../models/currency.dart';
import '../models/product.dart';
import '../widgets/app_snack_bar.dart';

class AdvancedInventoryReportsScreen extends ConsumerStatefulWidget {
  const AdvancedInventoryReportsScreen({super.key});

  @override
  ConsumerState<AdvancedInventoryReportsScreen> createState() =>
      _AdvancedInventoryReportsScreenState();
}

class _AdvancedInventoryReportsScreenState
    extends ConsumerState<AdvancedInventoryReportsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'month';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currentCurrencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'inventory.reports_title'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF3B82F6),
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Stock Levels', icon: Icon(Icons.inventory)),
            Tab(text: 'Turnover', icon: Icon(Icons.trending_up)),
            Tab(text: 'Valuation', icon: Icon(Icons.monetization_on)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showDateRangeDialog(),
            icon: const Icon(Icons.date_range, color: Color(0xFF3B82F6)),
            tooltip: 'Select Date Range',
          ),
          IconButton(
            onPressed: () => _exportReport(),
            icon: const Icon(Icons.download, color: Color(0xFF3B82F6)),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(currency),
          _buildStockLevelsTab(currency),
          _buildTurnoverTab(currency),
          _buildValuationTab(currency),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Currency currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildMetricsGrid(currency),
          const SizedBox(height: 24),

          // Inventory Value Chart
          _buildInventoryValueChart(currency),
          const SizedBox(height: 24),

          // Top Products by Value
          _buildTopProductsCard(currency),
          const SizedBox(height: 24),

          // Low Stock Alerts
          _buildLowStockAlertsCard(currency),
        ],
      ),
    );
  }

  Widget _buildStockLevelsTab(Currency currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stock Level Chart
          _buildStockLevelChart(currency),
          const SizedBox(height: 24),

          // Stock Level Table
          _buildStockLevelTable(currency),
        ],
      ),
    );
  }

  Widget _buildTurnoverTab(Currency currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turnover Rate Chart
          _buildTurnoverRateChart(currency),
          const SizedBox(height: 24),

          // Fast/Slow Moving Items
          _buildMovementAnalysisCard(currency),
        ],
      ),
    );
  }

  Widget _buildValuationTab(Currency currency) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inventory Valuation Methods
          _buildValuationMethodsCard(currency),
          const SizedBox(height: 24),

          // Cost Analysis
          _buildCostAnalysisCard(currency),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Currency currency) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Inventory Value',
          '${currency.symbol}125,450.00',
          Icons.inventory,
          const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        _buildMetricCard(
          'Total Products',
          '1,234',
          Icons.category,
          const [Color(0xFF10B981), Color(0xFF059669)],
        ),
        _buildMetricCard(
          'Low Stock Items',
          '23',
          Icons.warning,
          const [Color(0xFFF59E0B), Color(0xFFD97706)],
        ),
        _buildMetricCard(
          'Out of Stock',
          '5',
          Icons.error,
          const [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, List<Color> gradient) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryValueChart(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Inventory Value Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 3),
                      const FlSpot(1, 1),
                      const FlSpot(2, 4),
                      const FlSpot(3, 2),
                      const FlSpot(4, 5),
                      const FlSpot(5, 3),
                      const FlSpot(6, 4),
                    ],
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Products by Value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) => _buildProductRow(currency, index)),
        ],
      ),
    );
  }

  Widget _buildProductRow(currency, int index) {
    final products = [
      {'name': 'Product A', 'value': 15000.0},
      {'name': 'Product B', 'value': 12000.0},
      {'name': 'Product C', 'value': 10000.0},
      {'name': 'Product D', 'value': 8000.0},
      {'name': 'Product E', 'value': 6000.0},
    ];

    final product = products[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              product['name'] as String,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            '${currency.symbol}${(product['value'] as double).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockAlertsCard(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Low Stock Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => _buildLowStockItem(currency, index)),
        ],
      ),
    );
  }

  Widget _buildLowStockItem(currency, int index) {
    final items = [
      {'name': 'Product X', 'stock': 5, 'min': 10},
      {'name': 'Product Y', 'stock': 2, 'min': 15},
      {'name': 'Product Z', 'stock': 8, 'min': 20},
    ];

    final item = items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Stock: ${item['stock']} / Min: ${item['min']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: Text('inventory.reorder'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildStockLevelChart(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Level Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Text('Stock level chart will be implemented here'),
        ],
      ),
    );
  }

  Widget _buildStockLevelTable(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Level Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 16),
          Text('Stock level table will be implemented here'),
        ],
      ),
    );
  }

  Widget _buildTurnoverRateChart(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Turnover Rate',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Text('Turnover rate chart will be implemented here'),
        ],
      ),
    );
  }

  Widget _buildMovementAnalysisCard(Currency currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fast/Slow Moving Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 16),
          Text('Movement analysis will be implemented here'),
        ],
      ),
    );
  }

  Widget _buildValuationMethodsCard(Currency currency) {
    return ref.watch(productsProvider).when(
      data: (products) {
        // Calculate inventory value using different methods
        // Using Cost Price (Weighted Average Cost method)
        final totalValueAtCost = products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stock * p.cost),
        );
        
        // Using Selling Price (Retail Price method)
        final totalValueAtRetail = products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stock * p.price),
        );
        
        // Using Market Price if available, otherwise retail price
        final totalValueAtMarket = products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stock * (p.marketPrice ?? p.price)),
        );
        
        // Calculate potential profit margin
        final potentialProfit = totalValueAtRetail - totalValueAtCost;
        final profitMargin = totalValueAtCost > 0
            ? (potentialProfit / totalValueAtCost) * 100
            : 0.0;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inventory Valuation Methods',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _buildValuationMethodItem(
                'Cost Price (Weighted Average)',
                '${currency.symbol}${totalValueAtCost.toStringAsFixed(2)}',
                Icons.attach_money,
                const Color(0xFF3B82F6),
                'Inventory value at purchase cost',
              ),
              const SizedBox(height: 12),
              _buildValuationMethodItem(
                'Retail Price',
                '${currency.symbol}${totalValueAtRetail.toStringAsFixed(2)}',
                Icons.sell,
                const Color(0xFF10B981),
                'Inventory value at selling price',
              ),
              const SizedBox(height: 12),
              _buildValuationMethodItem(
                'Market Price',
                '${currency.symbol}${totalValueAtMarket.toStringAsFixed(2)}',
                Icons.trending_up,
                const Color(0xFFF59E0B),
                'Inventory value at market price',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Potential Profit Margin: ${profitMargin.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(20),
        child: Text('Error loading data: $error'),
      ),
    );
  }
  
  Widget _buildValuationMethodItem(
    String title,
    String value,
    IconData icon,
    Color color,
    String description,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostAnalysisCard(Currency currency) {
    return ref.watch(productsProvider).when(
      data: (products) {
        if (products.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cost Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 16),
                Text('No products available for cost analysis'),
              ],
            ),
          );
        }
        
        // Calculate cost metrics
        final totalCost = products.fold<double>(
          0.0,
          (sum, p) => sum + (p.stock * p.cost),
        );
        
        final averageCost = products.fold<double>(
          0.0,
          (sum, p) => sum + p.cost,
        ) / products.length;
        
        final highestCostProduct = products.reduce(
          (a, b) => a.cost > b.cost ? a : b,
        );
        
        final lowestCostProduct = products.reduce(
          (a, b) => a.cost < b.cost ? a : b,
        );
        
        final totalStockUnits = products.fold<double>(
          0.0,
          (sum, p) => sum + p.stock,
        );
        
        final averageCostPerUnit = totalStockUnits > 0
            ? totalCost / totalStockUnits
            : 0.0;
        
        // Calculate products by cost range
        final highCostProducts = products.where((p) => p.cost > averageCost * 1.5).length;
        final mediumCostProducts = products.where((p) => 
          p.cost <= averageCost * 1.5 && p.cost >= averageCost * 0.5
        ).length;
        final lowCostProducts = products.where((p) => p.cost < averageCost * 0.5).length;
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cost Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              
              // Key Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildCostMetricCard(
                      'Total Cost Value',
                      '${currency.symbol}${totalCost.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCostMetricCard(
                      'Avg Cost/Unit',
                      '${currency.symbol}${averageCostPerUnit.toStringAsFixed(2)}',
                      Icons.calculate,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCostMetricCard(
                      'Avg Product Cost',
                      '${currency.symbol}${averageCost.toStringAsFixed(2)}',
                      Icons.analytics,
                      const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCostMetricCard(
                      'Total Units',
                      totalStockUnits.toStringAsFixed(0),
                      Icons.inventory_2,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              
              // Cost Range Distribution
              const Text(
                'Cost Range Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              _buildCostRangeItem(
                'High Cost',
                highCostProducts,
                products.length,
                const Color(0xFFEF4444),
              ),
              const SizedBox(height: 6),
              _buildCostRangeItem(
                'Medium Cost',
                mediumCostProducts,
                products.length,
                const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 6),
              _buildCostRangeItem(
                'Low Cost',
                lowCostProducts,
                products.length,
                const Color(0xFF10B981),
              ),
              
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              
              // Highest/Lowest Cost Products
              Row(
                children: [
                  Expanded(
                    child: _buildProductCostItem(
                      'Highest Cost',
                      highestCostProduct.name,
                      '${currency.symbol}${highestCostProduct.cost.toStringAsFixed(2)}',
                      Icons.trending_up,
                      const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildProductCostItem(
                      'Lowest Cost',
                      lowestCostProduct.name,
                      '${currency.symbol}${lowestCostProduct.cost.toStringAsFixed(2)}',
                      Icons.trending_down,
                      const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(20),
        child: Text('Error loading data: $error'),
      ),
    );
  }
  
  Widget _buildCostMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCostRangeItem(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        Text(
          '$count (${percentage.toStringAsFixed(1)}%)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildProductCostItem(
    String label,
    String productName,
    String cost,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            productName.length > 15 
                ? '${productName.substring(0, 15)}...'
                : productName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            cost,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showDateRangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('inventory.select_date_range'.tr()),
        content: Text('inventory.date_range_placeholder'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    AppSnackBar.show(
      context,
      SnackBar(
        content: Text('inventory.exporting_report'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
