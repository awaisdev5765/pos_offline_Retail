import 'package:drift/drift.dart';
import '../database/database.dart';
import 'customer.dart';
import 'employee.dart';

enum PaymentMethod { cash, card, bankTransfer, cheque }

class PaymentModel {
  final int? id;
  final int customerId;
  final double amount;
  final DateTime date;
  final String? note;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final CustomerModel? customer;
  final int? processedByEmployeeId;
  final EmployeeModel? processedBy;

  PaymentModel({
    this.id,
    required this.customerId,
    required this.amount,
    required this.date,
    this.note,
    this.paymentMethod = PaymentMethod.cash,
    required this.createdAt,
    this.customer,
    this.processedByEmployeeId,
    this.processedBy,
  });

  factory PaymentModel.fromPayment(
    Payment payment, {
    CustomerModel? customer,
    EmployeeModel? processedBy,
  }) {
    DateTime parseDate(String dateString) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        print('Error parsing date: $dateString - $e');
        return DateTime.now();
      }
    }

    return PaymentModel(
      id: payment.id,
      customerId: payment.customerId,
      amount: payment.amount.isNaN ? 0 : payment.amount,
      date: parseDate(payment.date),
      note: payment.note,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == payment.paymentMethod,
        orElse: () => PaymentMethod.cash,
      ),
      createdAt: parseDate(payment.createdAt),
      customer: customer,
      processedByEmployeeId: payment.processedByEmployeeId,
      processedBy: processedBy,
    );
  }

  Payment toPayment() {
    return Payment(
      id: id ?? 0,
      customerId: customerId,
      amount: amount,
      date: date.toIso8601String(),
      note: note,
      paymentMethod: paymentMethod.name,
      processedByEmployeeId: processedByEmployeeId,
      createdAt: createdAt.toIso8601String(),
    );
  }

  PaymentsCompanion toCompanion() {
    return PaymentsCompanion(
      customerId: Value(customerId),
      amount: Value(amount),
      date: Value(date.toIso8601String()),
      note: Value(note),
      paymentMethod: Value(paymentMethod.name),
      processedByEmployeeId: Value(processedByEmployeeId),
      createdAt: Value(createdAt.toIso8601String()),
    );
  }

  PaymentModel copyWith({
    int? id,
    int? customerId,
    double? amount,
    DateTime? date,
    String? note,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    CustomerModel? customer,
    int? processedByEmployeeId,
    EmployeeModel? processedBy,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      customer: customer ?? this.customer,
      processedByEmployeeId:
          processedByEmployeeId ?? this.processedByEmployeeId,
      processedBy: processedBy ?? this.processedBy,
    );
  }

  @override
  String toString() {
    return 'PaymentModel(id: $id, customerId: $customerId, amount: $amount, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PaymentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
