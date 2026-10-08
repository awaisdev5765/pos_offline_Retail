import 'package:drift/drift.dart';
import '../database/database.dart';

class SupplierPaymentModel {
  final int? id;
  final int supplierId;
  final double amount;
  final String paymentMethod; // cash, bank_transfer, cheque
  final String paymentType; // payment, refund, adjustment
  final DateTime date;
  final String? reference; // Cheque number, transaction reference
  final DateTime? chequeDate;
  final DateTime? issueDate;
  final String? note;
  final String? otherName; // Name of person making payment
  final String status; // completed, pending, cancelled
  final String? createdBy; // Employee who created the payment
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplierPaymentModel({
    this.id,
    required this.supplierId,
    required this.amount,
    required this.paymentMethod,
    required this.paymentType,
    required this.date,
    this.reference,
    this.chequeDate,
    this.issueDate,
    this.note,
    this.otherName,
    this.status = 'completed',
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupplierPaymentModel.fromSupplierPayment(
      SupplierPayment supplierPayment) {
    return SupplierPaymentModel(
      id: supplierPayment.id,
      supplierId: supplierPayment.supplierId,
      amount: supplierPayment.amount,
      paymentMethod: supplierPayment.paymentMethod,
      paymentType: supplierPayment.paymentType,
      date: DateTime.parse(supplierPayment.date),
      reference: supplierPayment.reference,
      chequeDate: supplierPayment.chequeDate != null
          ? DateTime.parse(supplierPayment.chequeDate!)
          : null,
      issueDate: supplierPayment.issueDate != null
          ? DateTime.parse(supplierPayment.issueDate!)
          : null,
      note: supplierPayment.note,
      otherName: supplierPayment.otherName,
      status: supplierPayment.status,
      createdBy: supplierPayment.createdBy,
      createdAt: DateTime.parse(supplierPayment.createdAt),
      updatedAt: DateTime.parse(supplierPayment.updatedAt),
    );
  }

  SupplierPayment toSupplierPayment() {
    return SupplierPayment(
      id: id ?? 0,
      supplierId: supplierId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentType: paymentType,
      date: date.toIso8601String(),
      reference: reference,
      chequeDate: chequeDate?.toIso8601String(),
      issueDate: issueDate?.toIso8601String(),
      note: note,
      otherName: otherName,
      status: status,
      createdBy: createdBy,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  SupplierPaymentsCompanion toCompanion() {
    return SupplierPaymentsCompanion(
      supplierId: Value(supplierId),
      amount: Value(amount),
      paymentMethod: Value(paymentMethod),
      paymentType: Value(paymentType),
      date: Value(date.toIso8601String()),
      reference: Value(reference),
      chequeDate: Value(chequeDate?.toIso8601String()),
      issueDate: Value(issueDate?.toIso8601String()),
      note: Value(note),
      otherName: Value(otherName),
      status: Value(status),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  SupplierPaymentModel copyWith({
    int? id,
    int? supplierId,
    double? amount,
    String? paymentMethod,
    String? paymentType,
    DateTime? date,
    String? reference,
    DateTime? chequeDate,
    DateTime? issueDate,
    String? note,
    String? otherName,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierPaymentModel(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentType: paymentType ?? this.paymentType,
      date: date ?? this.date,
      reference: reference ?? this.reference,
      chequeDate: chequeDate ?? this.chequeDate,
      issueDate: issueDate ?? this.issueDate,
      note: note ?? this.note,
      otherName: otherName ?? this.otherName,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SupplierPaymentModel(id: $id, supplierId: $supplierId, amount: $amount, paymentMethod: $paymentMethod, paymentType: $paymentType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplierPaymentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
