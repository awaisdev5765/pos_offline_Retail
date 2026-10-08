import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/currency.dart';
import '../models/employee.dart';
import '../providers/currency_provider.dart';
import '../providers/auth_provider.dart';

/// Helper functions for POS screen
/// Extracted from pos_screen.dart for better code organization

/// Format currency amount
String formatCurrency(double amount, Currency currency) {
  return '${currency.symbol}${amount.toStringAsFixed(2)}';
}

/// Format currency amount using provider
String formatCurrencyWithProvider(double amount, WidgetRef ref) {
  final currency = ref.read(currentCurrencyProvider);
  return formatCurrency(amount, currency);
}

/// Format employee name with fallback
String formatEmployeeName(EmployeeModel? employee, int? fallbackId, WidgetRef ref) {
  if (employee != null) {
    final trimmed = employee.name.trim();
    // Check if name is valid (not empty, not "unknown", not just whitespace)
    if (trimmed.isNotEmpty && 
        trimmed.toLowerCase() != 'unknown' &&
        trimmed.toLowerCase() != 'unknown user') {
      return trimmed;
    }
  }
  // If we have a cashierId but no employee, try to show a better message
  if (fallbackId != null) {
    // Try to get employee name from current user if it matches
    final currentUser = ref.read(authProvider).currentUser;
    if (currentUser?.id == fallbackId) {
      final name = currentUser?.name.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return 'Employee #$fallbackId';
  }
  return 'Unknown User';
}

/// Format employee role label
String formatEmployeeRoleLabel(EmployeeRole? role) {
  if (role == null) return '';
  final normalized = role.name.replaceAll('_', ' ');
  final words = normalized.split(' ');
  return words
      .map((word) =>
          word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ')
      .trim();
}

/// Get product icon based on category
String getProductIconName(String category) {
  switch (category.toLowerCase()) {
    case 'electronics':
      return 'devices';
    case 'clothing':
      return 'checkroom';
    case 'food':
      return 'restaurant';
    case 'books':
      return 'menu_book';
    case 'beauty':
      return 'face';
    default:
      return 'inventory';
  }
}

/// Check if unit is weight-based
bool isWeightBasedUnit(String? unit) {
  if (unit == null) return false;
  final unitLower = unit.toLowerCase();
  return unitLower == 'kg' ||
      unitLower == 'gm' ||
      unitLower == 'g' ||
      unitLower == 'gram' ||
      unitLower == 'grams' ||
      unitLower == 'kilogram' ||
      unitLower == 'kilograms';
}

/// Format quantity display
String formatQuantityDisplay(double quantity) {
  if (quantity.isNaN || quantity.isInfinite) {
    return '0';
  }
  // Remove trailing zeros for whole numbers
  if (quantity == quantity.toInt()) {
    return quantity.toInt().toString();
  }
  return quantity.toStringAsFixed(2);
}

/// Format price display
String formatPriceDisplay(double price) {
  if (price.isNaN || price.isInfinite) {
    return '0.00';
  }
  return price.toStringAsFixed(2);
}

/// Format date for display
String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}






