import 'package:drift/drift.dart';
import '../database/database.dart';

class StaffPerformanceModel {
  final int? id;
  final int employeeId;
  final String employeeName;
  final DateTime date;
  final double totalSales;
  final int totalTransactions;
  final double averageTransactionValue;
  final int itemsSold;
  final double commission;
  final double tips;
  final int hoursWorked;
  final double salesPerHour;
  final int customerInteractions;
  final double customerSatisfaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffPerformanceModel({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.itemsSold,
    required this.commission,
    required this.tips,
    required this.hoursWorked,
    required this.salesPerHour,
    required this.customerInteractions,
    required this.customerSatisfaction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffPerformanceModel.fromStaffPerformance(
      StaffPerformance staffPerformance) {
    return StaffPerformanceModel(
      id: staffPerformance.id,
      employeeId: staffPerformance.employeeId,
      employeeName: staffPerformance.employeeName,
      date: DateTime.parse(staffPerformance.date),
      totalSales: staffPerformance.totalSales,
      totalTransactions: staffPerformance.totalTransactions,
      averageTransactionValue: staffPerformance.averageTransactionValue,
      itemsSold: staffPerformance.itemsSold,
      commission: staffPerformance.commission,
      tips: staffPerformance.tips,
      hoursWorked: staffPerformance.hoursWorked,
      salesPerHour: staffPerformance.salesPerHour,
      customerInteractions: staffPerformance.customerInteractions,
      customerSatisfaction: staffPerformance.customerSatisfaction,
      createdAt: DateTime.parse(staffPerformance.createdAt),
      updatedAt: DateTime.parse(staffPerformance.updatedAt),
    );
  }

  StaffPerformance toStaffPerformance() {
    return StaffPerformance(
      id: id ?? 0,
      employeeId: employeeId,
      employeeName: employeeName,
      date: date.toIso8601String(),
      totalSales: totalSales,
      totalTransactions: totalTransactions,
      averageTransactionValue: averageTransactionValue,
      itemsSold: itemsSold,
      commission: commission,
      tips: tips,
      hoursWorked: hoursWorked,
      salesPerHour: salesPerHour,
      customerInteractions: customerInteractions,
      customerSatisfaction: customerSatisfaction,
      createdAt: createdAt.toIso8601String(),
      updatedAt: updatedAt.toIso8601String(),
    );
  }

  StaffPerformancesCompanion toCompanion() {
    return StaffPerformancesCompanion(
      employeeId: Value(employeeId),
      employeeName: Value(employeeName),
      date: Value(date.toIso8601String()),
      totalSales: Value(totalSales),
      totalTransactions: Value(totalTransactions),
      averageTransactionValue: Value(averageTransactionValue),
      itemsSold: Value(itemsSold),
      commission: Value(commission),
      tips: Value(tips),
      hoursWorked: Value(hoursWorked),
      salesPerHour: Value(salesPerHour),
      customerInteractions: Value(customerInteractions),
      customerSatisfaction: Value(customerSatisfaction),
      createdAt: Value(createdAt.toIso8601String()),
      updatedAt: Value(updatedAt.toIso8601String()),
    );
  }
}

class StaffPerformanceSummary {
  final int employeeId;
  final String employeeName;
  final double totalSales;
  final int totalTransactions;
  final double averageTransactionValue;
  final int totalItemsSold;
  final double totalCommission;
  final double totalTips;
  final int totalHoursWorked;
  final double averageSalesPerHour;
  final int totalCustomerInteractions;
  final double averageCustomerSatisfaction;
  final int rank;
  final double performanceScore;

  StaffPerformanceSummary({
    required this.employeeId,
    required this.employeeName,
    required this.totalSales,
    required this.totalTransactions,
    required this.averageTransactionValue,
    required this.totalItemsSold,
    required this.totalCommission,
    required this.totalTips,
    required this.totalHoursWorked,
    required this.averageSalesPerHour,
    required this.totalCustomerInteractions,
    required this.averageCustomerSatisfaction,
    required this.rank,
    required this.performanceScore,
  });
}
