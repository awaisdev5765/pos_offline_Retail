import 'package:drift/drift.dart';
import '../database/database.dart';
import 'sale.dart';

class CustomerModel {
  final int? id;
  final String name;
  final String phone;
  final String? address;
  final double totalDue;
  final double creditLimit;
  final int creditDays;
  final double unclearCheque;
  final bool isRetailCustomer;
  final bool isWholesaleCustomer;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    this.id,
    required this.name,
    required this.phone,
    this.address,
    this.totalDue = 0,
    this.creditLimit = 0,
    this.creditDays = 0,
    this.unclearCheque = 0,
    this.isRetailCustomer = true,
    this.isWholesaleCustomer = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromCustomer(Customer customer) {
    DateTime parseDate(String dateString) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        print('Error parsing date: $dateString - $e');
        return DateTime.now();
      }
    }

    return CustomerModel(
      id: customer.id,
      name: customer.name.isEmpty ? 'Unknown' : customer.name,
      phone: customer.phone.isEmpty ? '0000000' : customer.phone,
      address: customer.address,
      totalDue: customer.totalDue.isNaN ? 0 : customer.totalDue,
      creditLimit: customer.creditLimit.isNaN ? 0 : customer.creditLimit,
      creditDays: customer.creditDays,
      unclearCheque: customer.unclearCheque.isNaN ? 0 : customer.unclearCheque,
      isRetailCustomer: customer.isRetailCustomer,
      isWholesaleCustomer: customer.isWholesaleCustomer,
      isActive: customer.isActive,
      createdAt: parseDate(customer.createdAt),
      updatedAt: parseDate(customer.updatedAt),
    );
  }

  Customer toCustomer() {
    return Customer(
      id: id ?? 0,
      name: name,
      phone: phone,
      address: address,
      totalDue: totalDue,
      creditLimit: creditLimit,
      creditDays: creditDays,
      unclearCheque: unclearCheque,
      isRetailCustomer: isRetailCustomer,
      isWholesaleCustomer: isWholesaleCustomer,
      isActive: isActive,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  CustomersCompanion toCompanion() {
    return CustomersCompanion(
      name: Value(name),
      phone: Value(phone),
      address: Value(address),
      totalDue: Value(totalDue),
      creditLimit: Value(creditLimit),
      creditDays: Value(creditDays),
      unclearCheque: Value(unclearCheque),
      isRetailCustomer: Value(isRetailCustomer),
      isWholesaleCustomer: Value(isWholesaleCustomer),
      isActive: Value(isActive),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  CustomerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    double? totalDue,
    double? creditLimit,
    int? creditDays,
    double? unclearCheque,
    bool? isRetailCustomer,
    bool? isWholesaleCustomer,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      totalDue: totalDue ?? this.totalDue,
      creditLimit: creditLimit ?? this.creditLimit,
      creditDays: creditDays ?? this.creditDays,
      unclearCheque: unclearCheque ?? this.unclearCheque,
      isRetailCustomer: isRetailCustomer ?? this.isRetailCustomer,
      isWholesaleCustomer: isWholesaleCustomer ?? this.isWholesaleCustomer,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasOutstandingBalance => totalDue > 0;
  bool get hasCredit => totalDue < 0;

  @override
  String toString() {
    return 'CustomerModel(id: $id, name: $name, phone: $phone, totalDue: $totalDue)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'totalDue': totalDue,
      'creditLimit': creditLimit,
      'creditDays': creditDays,
      'unclearCheque': unclearCheque,
      'isRetailCustomer': isRetailCustomer,
      'isWholesaleCustomer': isWholesaleCustomer,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      phone: json['phone'] ?? '0000000',
      address: json['address'],
      totalDue: (json['totalDue'] as num?)?.toDouble() ?? 0.0,
      creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
      creditDays: (json['creditDays'] as int?) ?? 0,
      unclearCheque: (json['unclearCheque'] as num?)?.toDouble() ?? 0.0,
      isRetailCustomer: json['isRetailCustomer'] as bool? ?? true,
      isWholesaleCustomer: json['isWholesaleCustomer'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class CustomerWithSales {
  final CustomerModel customer;
  final List<SaleModel> sales;

  CustomerWithSales({
    required this.customer,
    required this.sales,
  });
}
