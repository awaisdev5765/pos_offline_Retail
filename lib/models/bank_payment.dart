import 'package:drift/drift.dart';
import '../database/database.dart';

class BankPaymentModel {
  final int? id;
  final int bankId;
  final String partyName;
  final String? otherName;
  final double amount;
  final String paymentType; // cheque, transfer, deposit, withdrawal
  final String? chequeNumber;
  final DateTime? chequeDate;
  final DateTime issueDate;
  final DateTime paidDate;
  final double previousBalance;
  final double newBalance;
  final String status; // pending, cleared, cancelled
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankPaymentModel({
    this.id,
    required this.bankId,
    required this.partyName,
    this.otherName,
    required this.amount,
    required this.paymentType,
    this.chequeNumber,
    this.chequeDate,
    required this.issueDate,
    required this.paidDate,
    this.previousBalance = 0.0,
    this.newBalance = 0.0,
    this.status = 'pending',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankPaymentModel.fromBankPayment(BankPayment bankPayment) {
    return BankPaymentModel(
      id: bankPayment.id,
      bankId: bankPayment.bankId,
      partyName: bankPayment.partyName,
      otherName: bankPayment.otherName,
      amount: bankPayment.amount,
      paymentType: bankPayment.paymentType,
      chequeNumber: bankPayment.chequeNumber,
      chequeDate: bankPayment.chequeDate != null
          ? DateTime.parse(bankPayment.chequeDate!)
          : null,
      issueDate: DateTime.parse(bankPayment.issueDate),
      paidDate: DateTime.parse(bankPayment.paidDate),
      previousBalance: bankPayment.previousBalance,
      newBalance: bankPayment.newBalance,
      status: bankPayment.status,
      notes: bankPayment.notes,
      createdAt: DateTime.parse(bankPayment.createdAt),
      updatedAt: DateTime.parse(bankPayment.updatedAt),
    );
  }

  BankPayment toBankPayment() {
    return BankPayment(
      id: id ?? 0,
      bankId: bankId,
      partyName: partyName,
      otherName: otherName,
      amount: amount,
      paymentType: paymentType,
      chequeNumber: chequeNumber,
      chequeDate: chequeDate?.toIso8601String(),
      issueDate: issueDate.toIso8601String(),
      paidDate: paidDate.toIso8601String(),
      previousBalance: previousBalance,
      newBalance: newBalance,
      status: status,
      notes: notes,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  BankPaymentsCompanion toCompanion() {
    return BankPaymentsCompanion(
      bankId: Value(bankId),
      partyName: Value(partyName),
      otherName: Value(otherName),
      amount: Value(amount),
      paymentType: Value(paymentType),
      chequeNumber: Value(chequeNumber),
      chequeDate: Value(chequeDate?.toIso8601String()),
      issueDate: Value(issueDate.toIso8601String()),
      paidDate: Value(paidDate.toIso8601String()),
      previousBalance: Value(previousBalance),
      newBalance: Value(newBalance),
      status: Value(status),
      notes: Value(notes),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  BankPaymentModel copyWith({
    int? id,
    int? bankId,
    String? partyName,
    String? otherName,
    double? amount,
    String? paymentType,
    String? chequeNumber,
    DateTime? chequeDate,
    DateTime? issueDate,
    DateTime? paidDate,
    double? previousBalance,
    double? newBalance,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankPaymentModel(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      partyName: partyName ?? this.partyName,
      otherName: otherName ?? this.otherName,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      chequeNumber: chequeNumber ?? this.chequeNumber,
      chequeDate: chequeDate ?? this.chequeDate,
      issueDate: issueDate ?? this.issueDate,
      paidDate: paidDate ?? this.paidDate,
      previousBalance: previousBalance ?? this.previousBalance,
      newBalance: newBalance ?? this.newBalance,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BankPaymentModel(id: $id, bankId: $bankId, partyName: $partyName, amount: $amount, paymentType: $paymentType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BankPaymentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
