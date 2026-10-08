import 'package:drift/drift.dart';
import '../database/database.dart';

class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.color = '3B82F6',
    this.icon = 'category',
    required this.createdAt,
    required this.updatedAt,
  });

  CategoryModel copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as String? ?? '3B82F6',
      icon: json['icon'] as String? ?? 'category',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  factory CategoryModel.fromCategory(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      description: category.description,
      color: category.color,
      icon: category.icon,
      createdAt: DateTime.parse(category.createdAt),
      updatedAt: DateTime.parse(category.updatedAt),
    );
  }

  Category toCategory() {
    return Category(
      id: id,
      name: name,
      description: description,
      color: color,
      icon: icon,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  CategoriesCompanion toCompanion() {
    return CategoriesCompanion(
      name: Value(name),
      description: Value(description),
      color: Value(color),
      icon: Value(icon),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }
}
