import 'package:drift/drift.dart';
import '../database/database.dart';

class BankModel {
  final int? id;
  final String name;
  final String code;
  final String? accountNumber;
  final String? branch;
  final String? address;
  final String? phone;
  final String? email;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankModel({
    this.id,
    required this.name,
    required this.code,
    this.accountNumber,
    this.branch,
    this.address,
    this.phone,
    this.email,
    this.currentBalance = 0.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankModel.fromBank(Bank bank) {
    return BankModel(
      id: bank.id,
      name: bank.name,
      code: bank.code,
      accountNumber: bank.accountNumber,
      branch: bank.branch,
      address: bank.address,
      phone: bank.phone,
      email: bank.email,
      currentBalance: bank.currentBalance,
      isActive: bank.isActive,
      createdAt: DateTime.parse(bank.createdAt),
      updatedAt: DateTime.parse(bank.updatedAt),
    );
  }

  Bank toBank() {
    return Bank(
      id: id ?? 0,
      name: name,
      code: code,
      accountNumber: accountNumber,
      branch: branch,
      address: address,
      phone: phone,
      email: email,
      currentBalance: currentBalance,
      isActive: isActive,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  BanksCompanion toCompanion() {
    return BanksCompanion(
      name: Value(name),
      code: Value(code),
      accountNumber: Value(accountNumber),
      branch: Value(branch),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      currentBalance: Value(currentBalance),
      isActive: Value(isActive),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  BankModel copyWith({
    int? id,
    String? name,
    String? code,
    String? accountNumber,
    String? branch,
    String? address,
    String? phone,
    String? email,
    double? currentBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      accountNumber: accountNumber ?? this.accountNumber,
      branch: branch ?? this.branch,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BankModel(id: $id, name: $name, code: $code, currentBalance: $currentBalance)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BankModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
