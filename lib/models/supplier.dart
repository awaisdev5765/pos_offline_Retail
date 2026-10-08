import 'package:drift/drift.dart';
import '../database/database.dart';

class SupplierModel {
  final int? id;
  final String name;
  final String code;
  final String contactPerson;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final double creditLimit;
  final double currentBalance;
  final int creditDays;
  final double unclearCheque;
  final String paymentTerms;
  final String? notes;
  final String? otherContact1;
  final String? otherContact2;
  final String? otherContact3;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierModel({
    this.id,
    required this.name,
    required this.code,
    required this.contactPerson,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.creditDays = 0,
    this.unclearCheque = 0,
    this.paymentTerms = '30 days',
    this.notes,
    this.otherContact1,
    this.otherContact2,
    this.otherContact3,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierModel.fromSupplier(Supplier supplier) {
    return SupplierModel(
      id: supplier.id,
      name: supplier.name,
      code: supplier.code,
      contactPerson: supplier.contactPerson,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      city: supplier.city,
      state: supplier.state,
      country: supplier.country,
      zipCode: supplier.zipCode,
      creditLimit: supplier.creditLimit,
      currentBalance: supplier.currentBalance,
      creditDays: supplier.creditDays,
      unclearCheque: supplier.unclearCheque,
      paymentTerms: supplier.paymentTerms,
      notes: supplier.notes,
      otherContact1: supplier.otherContact1,
      otherContact2: supplier.otherContact2,
      otherContact3: supplier.otherContact3,
      isActive: supplier.isActive,
      createdAt: DateTime.parse(supplier.createdAt),
      updatedAt: DateTime.parse(supplier.updatedAt),
    );
  }

  Supplier toSupplier() {
    return Supplier(
      id: id ?? 0,
      name: name,
      code: code,
      contactPerson: contactPerson,
      phone: phone,
      email: email,
      address: address,
      city: city,
      state: state,
      country: country,
      zipCode: zipCode,
      creditLimit: creditLimit,
      currentBalance: currentBalance,
      creditDays: creditDays,
      unclearCheque: unclearCheque,
      paymentTerms: paymentTerms,
      notes: notes,
      otherContact1: otherContact1,
      otherContact2: otherContact2,
      otherContact3: otherContact3,
      isActive: isActive,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  SuppliersCompanion toCompanion() {
    return SuppliersCompanion(
      name: Value(name),
      contactPerson: Value(contactPerson),
      phone: Value(phone),
      email: Value(email),
      address: Value(address),
      city: Value(city),
      state: Value(state),
      country: Value(country),
      zipCode: Value(zipCode),
      creditLimit: Value(creditLimit),
      currentBalance: Value(currentBalance),
      creditDays: Value(creditDays),
      unclearCheque: Value(unclearCheque),
      paymentTerms: Value(paymentTerms),
      code: Value(code),
      notes: Value(notes),
      otherContact1: Value(otherContact1),
      otherContact2: Value(otherContact2),
      otherContact3: Value(otherContact3),
      isActive: Value(isActive),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  SupplierModel copyWith({
    int? id,
    String? name,
    String? code,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? country,
    String? zipCode,
    double? creditLimit,
    double? currentBalance,
    int? creditDays,
    double? unclearCheque,
    String? paymentTerms,
    String? notes,
    String? otherContact1,
    String? otherContact2,
    String? otherContact3,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      creditDays: creditDays ?? this.creditDays,
      unclearCheque: unclearCheque ?? this.unclearCheque,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      notes: notes ?? this.notes,
      otherContact1: otherContact1 ?? this.otherContact1,
      otherContact2: otherContact2 ?? this.otherContact2,
      otherContact3: otherContact3 ?? this.otherContact3,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    if (zipCode != null && zipCode!.isNotEmpty) parts.add(zipCode!);
    return parts.join(', ');
  }

  bool get hasOutstandingBalance => currentBalance > 0;
  bool get hasCredit => currentBalance < 0;
  bool get isOverCreditLimit => currentBalance > creditLimit;

  @override
  String toString() {
    return 'SupplierModel(id: $id, name: $name, phone: $phone, currentBalance: $currentBalance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplierModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
