import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/currency.dart';
import '../services/database_service.dart';

// Provider to load the saved currency code from database
final savedCurrencyCodeProvider = FutureProvider<String>((ref) async {
  try {
    final databaseService = ref.watch(databaseServiceProvider);
    final currencyCode = await databaseService.getSetting('currency_code');
    return currencyCode ?? 'INR'; // Default to INR
  } catch (e) {
    return 'INR'; // Default to INR if loading fails
  }
});

class CurrencyNotifier extends StateNotifier<AsyncValue<Currency>> {
  CurrencyNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadCurrency();
  }

  final Ref _ref;

  Future<void> _loadCurrency() async {
    try {
      final currencyCode = await _ref.read(savedCurrencyCodeProvider.future);

      // Find the currency by code
      final currency = Currency.uniqueCurrencies.firstWhere(
        (c) => c.code == currencyCode,
        orElse: () => Currency.uniqueCurrencies.first,
      );

      state = AsyncValue.data(currency);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> changeCurrency(Currency currency) async {
    final previousState = state;
    state = AsyncValue.data(currency);

    // Save to database
    try {
      final databaseService = _ref.read(databaseServiceProvider);
      await databaseService.setSetting('currency_code', currency.code);
      await databaseService.setSetting('currency_symbol', currency.symbol);

      // Invalidate the saved currency code provider to refresh it
      _ref.invalidate(savedCurrencyCodeProvider);
    } catch (e, stack) {
      // Revert if save fails
      state = previousState;
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  void refresh() {
    _loadCurrency();
  }

  String formatAmount(double amount) {
    return state.when(
      data: (currency) => '${currency.symbol}${amount.toStringAsFixed(2)}',
      loading: () =>
          '${Currency.uniqueCurrencies.first.symbol}${amount.toStringAsFixed(2)}',
      error: (_, __) =>
          '${Currency.uniqueCurrencies.first.symbol}${amount.toStringAsFixed(2)}',
    );
  }

  double convertFromUSD(double usdAmount) {
    return state.when(
      data: (currency) => usdAmount * currency.rate,
      loading: () => usdAmount * Currency.uniqueCurrencies.first.rate,
      error: (_, __) => usdAmount * Currency.uniqueCurrencies.first.rate,
    );
  }

  double convertToUSD(double amount) {
    return state.when(
      data: (currency) => amount / currency.rate,
      loading: () => amount / Currency.uniqueCurrencies.first.rate,
      error: (_, __) => amount / Currency.uniqueCurrencies.first.rate,
    );
  }
}

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, AsyncValue<Currency>>((ref) {
  return CurrencyNotifier(ref);
});

// Convenience provider to get the currency value directly (for widgets that need non-async access)
final currentCurrencyProvider = Provider<Currency>((ref) {
  return ref.watch(currencyProvider).when(
        data: (currency) => currency,
        loading: () => Currency.uniqueCurrencies.first,
        error: (_, __) => Currency.uniqueCurrencies.first,
      );
});
