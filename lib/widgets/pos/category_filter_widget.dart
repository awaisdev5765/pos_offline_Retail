import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';
import '../../theme/app_theme.dart';

/// Category filter widget for POS screen
/// Extracted from pos_screen.dart for better code organization
class CategoryFilterWidget extends ConsumerStatefulWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;
  final bool isMobile;

  const CategoryFilterWidget({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.isMobile = false,
  });

  @override
  ConsumerState<CategoryFilterWidget> createState() =>
      _CategoryFilterWidgetState();
}

class _CategoryFilterWidgetState extends ConsumerState<CategoryFilterWidget> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return categoriesAsync.when(
      data: (categories) {
        final allCategories = [
          'all',
          ...categories.map((c) => c.name),
        ];

        if (widget.isMobile) {
          return _buildMobileFilter(allCategories);
        } else {
          return _buildDesktopFilter(allCategories);
        }
      },
      loading: () => const SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildMobileFilter(List<String> categories) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = widget.selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                category == 'all' ? 'All' : category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  widget.onCategorySelected(category);
                }
              },
              selectedColor: AppColors.primaryColor,
              checkmarkColor: Colors.white,
              backgroundColor: AppColors.surfaceLight,
              side: BorderSide(
                color:
                    isSelected ? AppColors.primaryColor : AppColors.borderColor,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopFilter(List<String> categories) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          _buildArrowButton(
            icon: Icons.chevron_left,
            onTap: () => _scrollBy(-180),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = widget.selectedCategory == category;
                return FilterChip(
                  label: Text(
                    category == 'all' ? 'All' : category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      widget.onCategorySelected(category);
                    }
                  },
                  selectedColor: AppColors.primaryColor,
                  checkmarkColor: Colors.white,
                  backgroundColor: AppColors.surfaceLight,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryColor
                        : AppColors.borderColor,
                    width: 1.5,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          _buildArrowButton(
            icon: Icons.chevron_right,
            onTap: () => _scrollBy(180),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.backgroundLight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
