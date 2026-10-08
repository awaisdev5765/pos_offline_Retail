/// Centralized fixed-minor-unit arithmetic for persisted monetary totals.
///
/// Product quantities may remain fractional, but every monetary result is
/// rounded to the configured currency precision before it is accumulated.
class MoneyMath {
  static const int scale = 100;

  static int toMinor(num amount) {
    final value = amount.toDouble();
    if (!value.isFinite) throw ArgumentError('Money amount must be finite.');
    return (value * scale).round();
  }

  static double fromMinor(int amount) => amount / scale;

  static double round(num amount) => fromMinor(toMinor(amount));

  static double lineTotal(num unitPrice, num quantity) =>
      round(unitPrice.toDouble() * quantity.toDouble());

  /// Converts a requested sale amount into a fractional quantity.
  static double quantityForAmount(num amount, num unitPrice) {
    final safeAmount = amount.toDouble();
    final safeUnitPrice = unitPrice.toDouble();
    if (!safeAmount.isFinite || safeAmount <= 0) {
      throw ArgumentError('Amount must be a positive finite number.');
    }
    if (!safeUnitPrice.isFinite || safeUnitPrice <= 0) {
      throw ArgumentError('Unit price must be a positive finite number.');
    }
    return (safeAmount / safeUnitPrice * 1000000).roundToDouble() / 1000000;
  }

  static double percentage(num base, num rate) =>
      round(base.toDouble() * rate.toDouble() / 100);
}
