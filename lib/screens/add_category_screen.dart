import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/category_provider.dart';
import '../services/database_service.dart';
import '../models/category.dart';
import '../widgets/app_snack_bar.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  final int? categoryId;

  const AddCategoryScreen({super.key, this.categoryId});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // FocusNodes for Enter key navigation (Windows-style)
  final _nameFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  String _selectedColor = '3B82F6';
  String _selectedIcon = 'category';
  bool _isLoading = false;
  DateTime? _originalCreatedAt;

  final List<Map<String, String>> _colorOptions = [
    {'name': 'Blue', 'value': '3B82F6'},
    {'name': 'Green', 'value': '10B981'},
    {'name': 'Orange', 'value': 'F59E0B'},
    {'name': 'Red', 'value': 'EF4444'},
    {'name': 'Purple', 'value': '8B5CF6'},
    {'name': 'Pink', 'value': 'EC4899'},
    {'name': 'Teal', 'value': '14B8A6'},
    {'name': 'Indigo', 'value': '6366F1'},
  ];

  final List<Map<String, String>> _iconOptions = [
    {'name': 'Category', 'value': 'category'},
    {'name': 'Electronics', 'value': 'electronics'},
    {'name': 'Clothing', 'value': 'clothing'},
    {'name': 'Food', 'value': 'food'},
    {'name': 'Books', 'value': 'books'},
    {'name': 'Beauty', 'value': 'beauty'},
    {'name': 'Sports', 'value': 'sports'},
    {'name': 'Home', 'value': 'home'},
    {'name': 'Automotive', 'value': 'automotive'},
    {'name': 'Health', 'value': 'health'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _loadCategory();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategory() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = ref.read(databaseServiceProvider);
      final category = await databaseService.getCategoryById(widget.categoryId!);
      if (category != null && mounted) {
        setState(() {
          _nameController.text = category.name;
          _descriptionController.text = category.description ?? '';
          _selectedColor = category.color;
          _selectedIcon = category.icon;
          _originalCreatedAt = category.createdAt;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Failed to load category: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trimmedName = _nameController.text.trim();
      final existingCategories =
          ref.read(categoryNotifierProvider).valueOrNull ?? [];
      final isDuplicate = existingCategories.any((c) =>
          c.name.trim().toLowerCase() == trimmedName.toLowerCase() &&
          c.id != widget.categoryId);
      if (isDuplicate) {
        if (mounted) {
          setState(() => _isLoading = false);
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text(
                  'A category with this name already exists. Please use a different name.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final category = CategoryModel(
        id: widget.categoryId ?? 0,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        color: _selectedColor,
        icon: _selectedIcon,
        createdAt: _originalCreatedAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final categoryNotifier = ref.read(categoryNotifierProvider.notifier);

      if (widget.categoryId != null) {
        await categoryNotifier.updateCategory(category);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Category updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      } else {
        await categoryNotifier.addCategory(category);
        if (mounted) {
          AppSnackBar.show(
            context,
            const SnackBar(
              content: Text('Category added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          );
        }
      }

      // Navigate back after a short delay to show the toast
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/categories');
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(
          context,
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title:
            Text(widget.categoryId != null ? 'Edit Category' : 'Add Category'),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Preview Card
              _buildPreviewCard(),
              const SizedBox(height: 24),

              // Category Name
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'Enter category name',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _descriptionFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a category name';
                  }
                  if (value.trim().length < 2) {
                    return 'Category name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                focusNode: _descriptionFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter category description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Color Selection
              _buildColorSelection(),
              const SizedBox(height: 24),

              // Icon Selection
              _buildIconSelection(),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.categoryId != null
                            ? 'Update Category'
                            : 'Add Category',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Color(int.parse('FF${_selectedColor}', radix: 16)),
              Color(int.parse('FF${_selectedColor}', radix: 16))
                  .withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconData(_selectedIcon),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.isEmpty
                        ? 'Category Name'
                        : _nameController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_descriptionController.text.isNotEmpty)
                    Text(
                      _descriptionController.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colorOptions.map((color) {
            final isSelected = _selectedColor == color['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color['value']!;
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(int.parse('FF${color['value']}', radix: 16)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(int.parse('FF${color['value']}', radix: 16))
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIconSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Icon',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _iconOptions.map((icon) {
            final isSelected = _selectedIcon == icon['value'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedIcon = icon['value']!;
                });
              },
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconData(icon['value']!),
                      color:
                          isSelected ? Colors.white : const Color(0xFF64748B),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      icon['name']!,
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isSelected ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'electronics':
        return Icons.devices;
      case 'clothing':
        return Icons.checkroom;
      case 'food':
        return Icons.restaurant;
      case 'books':
        return Icons.menu_book;
      case 'beauty':
        return Icons.face;
      case 'sports':
        return Icons.sports_soccer;
      case 'home':
        return Icons.home;
      case 'automotive':
        return Icons.directions_car;
      case 'health':
        return Icons.health_and_safety;
      default:
        return Icons.category;
    }
  }
}
