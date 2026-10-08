import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/bundle_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/product_bundle.dart';
import '../theme/app_theme.dart';
import '../utils/modern_dialog_builder.dart';
import '../widgets/app_snack_bar.dart';
import 'add_bundle_screen.dart';

class BundlesScreen extends ConsumerStatefulWidget {
  const BundlesScreen({super.key});

  @override
  ConsumerState<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends ConsumerState<BundlesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final currency = ref.read(currentCurrencyProvider);
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final bundlesAsync = ref.watch(bundlesProvider);
    final bundleNotifier = ref.watch(bundleNotifierProvider.notifier);
    final currency = ref.watch(currentCurrencyProvider);
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authProvider);
    final currentUser = authState.currentUser;
    final canManageBundles = currentUser?.canManageProducts() ?? false;

    return Scaffold(
      backgroundColor:
          isDarkMode ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('bundles.title'.tr()),
        automaticallyImplyLeading: true,
        actions: [
          if (canManageBundles)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/add-bundle'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDarkMode ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? AppColors.borderColor.withValues(alpha: 0.3)
                      : AppColors.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search bundles...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkMode
                    ? AppColors.surfaceDark
                    : Colors.grey.shade50,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // Bundles List
          Expanded(
            child: bundlesAsync.when(
              data: (bundles) {
                if (bundles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bundles found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first product bundle',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (canManageBundles) ...[
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/add-bundle'),
                            icon: const Icon(Icons.add),
                            label: Text('misc.create_bundle'.tr()),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final filteredBundles = bundles.where((bundle) {
                  final matchesSearch = _searchQuery.isEmpty ||
                      bundle.name.toLowerCase().contains(_searchQuery) ||
                      (bundle.description?.toLowerCase().contains(_searchQuery) ??
                          false);
                  final matchesCategory = _selectedCategory == null ||
                      bundle.category == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList();

                if (filteredBundles.isEmpty) {
                  return Center(
                    child: Text(
                      'No bundles match your search',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredBundles.length,
                  itemBuilder: (context, index) {
                    final bundle = filteredBundles[index];
                    return _buildBundleCard(bundle, canManageBundles, bundleNotifier);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error loading bundles: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(bundlesProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleCard(
    ProductBundleModel bundle,
    bool canManage,
    BundleNotifier notifier,
  ) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final currency = ref.watch(currentCurrencyProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/edit-bundle?id=${bundle.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bundle.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (bundle.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            bundle.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (bundle.discountPercentage > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${bundle.discountPercentage.toStringAsFixed(0)}% OFF',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Bundle Items Preview
              if (bundle.items.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: bundle.items.take(3).map((item) {
                    return Chip(
                      label: Text(
                        '${item.product.name} (${item.quantity}x)',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      padding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
                if (bundle.items.length > 3)
                  Text(
                    '... and ${bundle.items.length - 3} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              // Price and Actions
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bundle Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${currency.symbol}${bundle.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                        if (bundle.items.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Regular: ${currency.symbol}${bundle.items.fold(0.0, (sum, item) => sum + (item.effectivePrice * item.quantity)).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canManage) ...[
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                      onPressed: () =>
                          context.push('/edit-bundle?id=${bundle.id}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteBundle(bundle, notifier),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBundle(
      ProductBundleModel bundle, BundleNotifier notifier) async {
    final confirmed = await ModernDialogBuilder.showConfirmDialog(
      context: context,
      title: 'Delete Bundle',
      message: 'Are you sure you want to delete "${bundle.name}"?',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      try {
        await notifier.deleteBundle(bundle.id!);
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Bundle "${bundle.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.show(
            context,
            SnackBar(
              content: Text('Error deleting bundle: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

