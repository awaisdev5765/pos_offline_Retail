import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';

// Provider to get the tax rate from database
final taxRateProvider = FutureProvider<double>((ref) async {
  try {
    final databaseService = ref.watch(databaseServiceProvider);
    final taxRateString = await databaseService.getSetting('tax_rate');
    final taxRate = double.tryParse(taxRateString ?? '0') ?? 0.0;
    return taxRate;
  } catch (e) {
    return 0.0; // Default to 0% tax if loading fails
  }
});

// Provider to get the current tax rate synchronously (for calculations)
final currentTaxRateProvider = Provider<double>((ref) {
  return ref.watch(taxRateProvider).when(
        data: (rate) => rate,
        loading: () => 0.0,
        error: (_, __) => 0.0,
      );
});

// Tax calculation helper
class TaxCalculator {
  static double calculateTax(double amount, double taxRate) {
    return amount * (taxRate / 100);
  }

  static double calculateTotalWithTax(double amount, double taxRate) {
    return amount + calculateTax(amount, taxRate);
  }

  static double calculateAmountWithoutTax(double totalWithTax, double taxRate) {
    return totalWithTax / (1 + (taxRate / 100));
  }
}
