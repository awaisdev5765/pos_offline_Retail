import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pos_system/utils/money_math.dart';

void main() {
  test('rounds persisted currency to minor units', () {
    expect(MoneyMath.round(10.005), 10.01);
    expect(MoneyMath.round(10.004), 10.00);
  });

  test('fractional quantity line totals are deterministic', () {
    expect(MoneyMath.lineTotal(100, 2 / 3), 66.67);
    expect(MoneyMath.lineTotal(200, 0.375), 75.00);
  });

  test('percentage amounts use currency rounding', () {
    expect(MoneyMath.percentage(99.99, 17), 17.00);
  });

  test('customer amount converts to fractional sale quantity', () {
    expect(MoneyMath.quantityForAmount(200, 400), 0.5);
    expect(MoneyMath.quantityForAmount(200, 330), 0.606061);
    expect(
      MoneyMath.lineTotal(330, MoneyMath.quantityForAmount(200, 330)),
      200,
    );
  });

  test('amount conversion rejects invalid values', () {
    expect(() => MoneyMath.quantityForAmount(0, 400), throwsArgumentError);
    expect(() => MoneyMath.quantityForAmount(200, 0), throwsArgumentError);
  });
}
