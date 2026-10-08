import '../models/category.dart';

class CategoryDefaultsService {
  static List<CategoryModel> getDefaultCategories() {
    final now = DateTime.now();
    return [
      CategoryModel(
        id: 0,
        name: 'Electronics',
        description: 'Electronic devices and accessories',
        color: '8B5CF6',
        icon: 'devices',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Clothing',
        description: 'Apparel and fashion',
        color: '10B981',
        icon: 'checkroom',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Food & Drinks',
        description: 'Food and beverage items',
        color: 'F59E0B',
        icon: 'restaurant',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Books',
        description: 'Books and publications',
        color: 'EF4444',
        icon: 'menu_book',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Beauty',
        description: 'Beauty and personal care',
        color: 'EC4899',
        icon: 'face',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Home & Garden',
        description: 'Home and garden items',
        color: '06B6D4',
        icon: 'home',
        createdAt: now,
        updatedAt: now,
      ),
      CategoryModel(
        id: 0,
        name: 'Sports',
        description: 'Sports and fitness equipment',
        color: '84CC16',
        icon: 'sports',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
