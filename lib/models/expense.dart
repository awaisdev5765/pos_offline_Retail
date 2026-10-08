import 'package:drift/drift.dart';
import '../database/database.dart';

class ExpenseModel {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String paymentMethod;
  final String? reference;
  final String? description;
  final String? vendor;
  final bool isRecurring;
  final String? recurringPeriod;
  final String? attachmentPath;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExpenseModel({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    this.reference,
    this.description,
    this.vendor,
    this.isRecurring = false,
    this.recurringPeriod,
    this.attachmentPath,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ExpenseModel.fromExpense(Expense expense) {
    return ExpenseModel(
      id: expense.id,
      title: expense.title,
      category: expense.category,
      amount: expense.amount,
      date: DateTime.parse(expense.date),
      paymentMethod: expense.paymentMethod,
      reference: expense.reference,
      description: expense.description,
      vendor: expense.vendor,
      isRecurring: expense.isRecurring,
      recurringPeriod: expense.recurringPeriod,
      attachmentPath: expense.attachmentPath,
      createdBy: expense.createdBy,
      createdAt: DateTime.parse(expense.createdAt),
      updatedAt: DateTime.parse(expense.updatedAt),
    );
  }

  Expense toExpense() {
    return Expense(
      id: id ?? 0,
      title: title,
      category: category,
      amount: amount,
      date: date.toIso8601String(),
      paymentMethod: paymentMethod,
      reference: reference,
      description: description,
      vendor: vendor,
      isRecurring: isRecurring,
      recurringPeriod: recurringPeriod,
      attachmentPath: attachmentPath,
      createdBy: createdBy,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  ExpensesCompanion toCompanion() {
    return ExpensesCompanion(
      title: Value(title),
      category: Value(category),
      amount: Value(amount),
      date: Value(date.toIso8601String()),
      paymentMethod: Value(paymentMethod),
      reference: Value(reference),
      description: Value(description),
      vendor: Value(vendor),
      isRecurring: Value(isRecurring),
      recurringPeriod: Value(recurringPeriod),
      attachmentPath: Value(attachmentPath),
      createdBy: Value(createdBy),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }

  ExpenseModel copyWith({
    int? id,
    String? title,
    String? category,
    double? amount,
    DateTime? date,
    String? paymentMethod,
    String? reference,
    String? description,
    String? vendor,
    bool? isRecurring,
    String? recurringPeriod,
    String? attachmentPath,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      reference: reference ?? this.reference,
      description: description ?? this.description,
      vendor: vendor ?? this.vendor,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPeriod: recurringPeriod ?? this.recurringPeriod,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'ExpenseModel(id: $id, title: $title, category: $category, amount: $amount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExpenseModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Expense categories
class ExpenseCategory {
  static const String rent = 'Rent';
  static const String utilities = 'Utilities';
  static const String salaries = 'Salaries & Wages';
  static const String marketing = 'Marketing & Advertising';
  static const String supplies = 'Office Supplies';
  static const String maintenance = 'Maintenance & Repairs';
  static const String transport = 'Transport & Fuel';
  static const String insurance = 'Insurance';
  static const String taxes = 'Taxes & Fees';
  static const String inventory = 'Inventory Purchase';
  static const String professional = 'Professional Services';
  static const String communication = 'Phone & Internet';
  static const String equipment = 'Equipment';
  static const String licenses = 'Licenses & Permits';
  static const String travel = 'Travel & Accommodation';
  static const String meals = 'Meals & Entertainment';
  static const String bankCharges = 'Bank Charges';
  static const String miscellaneous = 'Miscellaneous';

  static List<String> get all => [
        rent,
        utilities,
        salaries,
        marketing,
        supplies,
        maintenance,
        transport,
        insurance,
        taxes,
        inventory,
        professional,
        communication,
        equipment,
        licenses,
        travel,
        meals,
        bankCharges,
        miscellaneous,
      ];
}

// Payment methods
class ExpensePaymentMethod {
  static const String cash = 'Cash';
  static const String card = 'Card';
  static const String bankTransfer = 'Bank Transfer';
  static const String cheque = 'Cheque';
  static const String mobilePayment = 'Mobile Payment';
  static const String other = 'Other';

  static List<String> get all => [
        cash,
        card,
        bankTransfer,
        cheque,
        mobilePayment,
        other,
      ];
}

// Recurring periods
class RecurringPeriod {
  static const String daily = 'Daily';
  static const String weekly = 'Weekly';
  static const String monthly = 'Monthly';
  static const String yearly = 'Yearly';

  static List<String> get all => [
        daily,
        weekly,
        monthly,
        yearly,
      ];
}
