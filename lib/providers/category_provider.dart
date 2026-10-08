import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/category_defaults_service.dart';

final categoryNotifierProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<CategoryModel>>>(
        (ref) {
  return CategoryNotifier(ref.read(databaseServiceProvider));
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<CategoryModel>>> {
  final DatabaseService _databaseService;
  bool _disposed = false;

  CategoryNotifier(this._databaseService) : super(const AsyncValue.loading()) {
    loadCategories();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadCategories() async {
    try {
      state = const AsyncValue.loading();
      final categories = await _databaseService.getAllCategories();

      // If no categories exist, initialize with default categories
      if (categories.isEmpty) {
        final defaultCategories = CategoryDefaultsService.getDefaultCategories();

        // Insert default categories
        for (final category in defaultCategories) {
          await _databaseService.insertCategory(category);
        }

        // Reload categories
        final updatedCategories = await _databaseService.getAllCategories();
        if (!_disposed) {
          state = AsyncValue.data(updatedCategories);
        }
      } else {
        if (!_disposed) {
          state = AsyncValue.data(categories);
        }
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    try {
      final newCategory = category.copyWith(
        id: 0, // Will be set by database
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _databaseService.insertCategory(newCategory);
      await loadCategories(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    try {
      final updatedCategory = category.copyWith(updatedAt: DateTime.now());
      await _databaseService.updateCategory(updatedCategory);
      await loadCategories(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _databaseService.deleteCategory(id);
      await loadCategories(); // Refresh the list
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
