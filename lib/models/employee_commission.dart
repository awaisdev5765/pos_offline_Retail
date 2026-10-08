import 'package:drift/drift.dart';
import '../database/database.dart' as db;

enum CommissionTransactionType { earning, withdrawal }

class EmployeeCommissionModel {
  final int? id;
  final int employeeId;
  final CommissionTransactionType transactionType;
  final int? saleId; // Reference to sale for earnings
  final double amount; // Positive for earnings, negative for withdrawals
  final double? commissionPercentage; // Commission rate at time of transaction
  final double? saleAmount; // Sale amount that generated this commission
  final double? balanceAfter; // Balance after this transaction
  final DateTime date;
  final String? notes;
  final String? processedBy; // Employee who processed withdrawal
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeCommissionModel({
    this.id,
    required this.employeeId,
    required this.transactionType,
    this.saleId,
    required this.amount,
    this.commissionPercentage,
    this.saleAmount,
    this.balanceAfter,
    required this.date,
    this.notes,
    this.processedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeCommissionModel.fromEmployeeCommission(
      db.EmployeeCommission employeeCommission) {
    return EmployeeCommissionModel(
      id: employeeCommission.id,
      employeeId: employeeCommission.employeeId,
      transactionType: employeeCommission.transactionType == 'earning'
          ? CommissionTransactionType.earning
          : CommissionTransactionType.withdrawal,
      saleId: employeeCommission.saleId,
      amount: employeeCommission.amount,
      commissionPercentage: employeeCommission.commissionPercentage,
      saleAmount: employeeCommission.saleAmount,
      balanceAfter: employeeCommission.balanceAfter,
      date: DateTime.parse(employeeCommission.date),
      notes: employeeCommission.notes,
      processedBy: employeeCommission.processedBy,
      createdAt: DateTime.parse(employeeCommission.createdAt),
      updatedAt: DateTime.parse(employeeCommission.updatedAt),
    );
  }

  db.EmployeeCommissionsCompanion toCompanion() {
    return db.EmployeeCommissionsCompanion(
      employeeId: Value(employeeId),
      transactionType: Value(transactionType == CommissionTransactionType.earning
          ? 'earning'
          : 'withdrawal'),
      saleId: saleId != null ? Value(saleId!) : const Value.absent(),
      amount: Value(amount),
      commissionPercentage: commissionPercentage != null
          ? Value(commissionPercentage!)
          : const Value.absent(),
      saleAmount:
          saleAmount != null ? Value(saleAmount!) : const Value.absent(),
      balanceAfter:
          balanceAfter != null ? Value(balanceAfter!) : const Value.absent(),
      date: Value(date.toIso8601String()),
      notes: notes != null ? Value(notes!) : const Value.absent(),
      processedBy:
          processedBy != null ? Value(processedBy!) : const Value.absent(),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  EmployeeCommissionModel copyWith({
    int? id,
    int? employeeId,
    CommissionTransactionType? transactionType,
    int? saleId,
    double? amount,
    double? commissionPercentage,
    double? saleAmount,
    double? balanceAfter,
    DateTime? date,
    String? notes,
    String? processedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeCommissionModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      transactionType: transactionType ?? this.transactionType,
      saleId: saleId ?? this.saleId,
      amount: amount ?? this.amount,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      saleAmount: saleAmount ?? this.saleAmount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      processedBy: processedBy ?? this.processedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EmployeeCommissionSummary {
  final int employeeId;
  final String employeeName;
  final double totalEarnings;
  final double totalWithdrawals;
  final double currentBalance;
  final int totalSales;
  final double totalSalesAmount;

  EmployeeCommissionSummary({
    required this.employeeId,
    required this.employeeName,
    required this.totalEarnings,
    required this.totalWithdrawals,
    required this.currentBalance,
    required this.totalSales,
    required this.totalSalesAmount,
  });
}

