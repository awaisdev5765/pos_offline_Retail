/// Consistent quantity and unit formatting for POS, reports, exports and
/// every receipt transport (PDF, network, USB and Bluetooth).
class QuantityFormatter {
  const QuantityFormatter._();

  static const _measuredUnits = <String>{
    'kg',
    'kgs',
    'kilogram',
    'kilograms',
    'g',
    'gm',
    'gms',
    'gram',
    'grams',
    'lb',
    'lbs',
    'pound',
    'pounds',
    'l',
    'ltr',
    'ltrs',
    'liter',
    'liters',
    'litre',
    'litres',
    'ml',
    'millilitre',
    'millilitres',
    'milliliter',
    'milliliters',
  };

  static bool isMeasuredUnit(String? unit) {
    return _measuredUnits.contains(unit?.trim().toLowerCase());
  }

  static String number(double quantity, {String? unit}) {
    if (!quantity.isFinite) return '0';
    final decimals = isMeasuredUnit(unit) ? 3 : 2;
    var value = quantity.toStringAsFixed(decimals);
    value = value.replaceFirst(RegExp(r'\.?0+$'), '');
    return value == '-0' ? '0' : value;
  }

  static String withUnit(double quantity, String? unit) {
    final value = number(quantity, unit: unit);
    final normalizedUnit = unit?.trim() ?? '';
    return normalizedUnit.isEmpty ? value : '$value $normalizedUnit';
  }
}
