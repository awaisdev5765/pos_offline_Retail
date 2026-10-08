import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import '../models/customer.dart';

// Held order item model
class HeldOrderItem {
  final ProductModel product;
  final double quantity;
  final double subtotal;
  final double? customPrice; // Custom price if edited
  final double discount; // Item-level discount

  HeldOrderItem({
    required this.product,
    required this.quantity,
    required this.subtotal,
    this.customPrice,
    this.discount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'subtotal': subtotal,
      'customPrice': customPrice,
      'discount': discount,
    };
  }

  factory HeldOrderItem.fromJson(Map<String, dynamic> json) {
    return HeldOrderItem(
      product: ProductModel.fromJson(json['product']),
      quantity: json['quantity']?.toDouble() ?? 0.0,
      subtotal: json['subtotal']?.toDouble() ?? 0.0,
      customPrice: json['customPrice']?.toDouble(),
      discount: json['discount']?.toDouble() ?? 0.0,
    );
  }
}

// Held order model
class HeldOrder {
  final String id;
  final DateTime timestamp;
  final CustomerModel? customer;
  final String orderType;
  final List<HeldOrderItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentType;
  final bool isSplitPayment;
  final double cashAmount;
  final double cardAmount;
  final bool isWholesale;

  HeldOrder({
    required this.id,
    required this.timestamp,
    this.customer,
    required this.orderType,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentType,
    required this.isSplitPayment,
    required this.cashAmount,
    required this.cardAmount,
    this.isWholesale = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'customer': customer?.toJson(),
      'orderType': orderType,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'total': total,
      'paymentType': paymentType,
      'isSplitPayment': isSplitPayment,
      'cashAmount': cashAmount,
      'cardAmount': cardAmount,
      'isWholesale': isWholesale,
    };
  }

  factory HeldOrder.fromJson(Map<String, dynamic> json) {
    return HeldOrder(
      id: json['id'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      customer: json['customer'] != null
          ? CustomerModel.fromJson(json['customer'])
          : null,
      orderType: json['orderType'] ?? 'dine_in',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => HeldOrderItem.fromJson(item))
              .toList() ??
          [],
      subtotal: json['subtotal']?.toDouble() ?? 0.0,
      discount: json['discount']?.toDouble() ?? 0.0,
      total: json['total']?.toDouble() ?? 0.0,
      paymentType: json['paymentType'] ?? 'cash',
      isSplitPayment: json['isSplitPayment'] ?? false,
      cashAmount: json['cashAmount']?.toDouble() ?? 0.0,
      cardAmount: json['cardAmount']?.toDouble() ?? 0.0,
      isWholesale: json['isWholesale'] ?? false,
    );
  }
}

// Held orders state notifier
class HeldOrdersNotifier extends StateNotifier<List<HeldOrder>> {
  HeldOrdersNotifier() : super([]);

  static const String _storageKey = 'held_orders';

  Future<void> loadHeldOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final orders =
            jsonList.map((json) => HeldOrder.fromJson(json)).toList();
        state = orders;
        print('Loaded ${orders.length} held orders from storage');
      }
    } catch (e) {
      print('Error loading held orders: $e');
      state = [];
    }
  }

  Future<void> _saveHeldOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.map((order) => order.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      print('Error saving held orders: $e');
    }
  }

  void addHeldOrder(HeldOrder order) {
    state = [...state, order];
    _saveHeldOrders();
  }

  void removeHeldOrder(String orderId) {
    state = state.where((order) => order.id != orderId).toList();
    _saveHeldOrders();
  }

  void removeHeldOrderByIndex(int index) {
    if (index >= 0 && index < state.length) {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
      _saveHeldOrders();
    }
  }

  void clearAllHeldOrders() {
    state = [];
    _saveHeldOrders();
  }

  HeldOrder? getHeldOrderById(String orderId) {
    try {
      return state.firstWhere(
        (order) => order.id == orderId,
        orElse: () => throw StateError('Order not found'),
      );
    } catch (e) {
      return null;
    }
  }

  int get heldOrdersCount => state.length;
}

// Provider for held orders
final heldOrdersProvider =
    StateNotifierProvider<HeldOrdersNotifier, List<HeldOrder>>((ref) {
  final notifier = HeldOrdersNotifier();
  // Load held orders after notifier is created
  notifier.loadHeldOrders();
  return notifier;
});

// Provider for held orders count
final heldOrdersCountProvider = Provider<int>((ref) {
  return ref.watch(heldOrdersProvider).length;
});
