import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pos_system/utils/quantity_formatter.dart';

void main() {
  group('QuantityFormatter', () {
    test('preserves fractional measured quantities and unit', () {
      expect(QuantityFormatter.withUnit(0.5, 'kg'), '0.5 kg');
      expect(QuantityFormatter.withUnit(1.375, 'kg'), '1.375 kg');
      expect(QuantityFormatter.withUnit(2, 'kg'), '2 kg');
    });

    test('keeps piece quantities compact', () {
      expect(QuantityFormatter.withUnit(1, 'pcs'), '1 pcs');
      expect(QuantityFormatter.withUnit(2.5, 'pcs'), '2.5 pcs');
    });

    test('handles invalid quantities safely', () {
      expect(QuantityFormatter.withUnit(double.nan, 'kg'), '0 kg');
      expect(QuantityFormatter.withUnit(double.infinity, 'kg'), '0 kg');
    });
  });
}
