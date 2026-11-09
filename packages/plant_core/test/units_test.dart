import 'package:flutter_test/flutter_test.dart';
import 'package:plant_core/plant_core.dart';

void main() {
  test('pressure conversions match exact definitions', () {
    expect(Units.convert(Quantity.pressure, 1, 'bar', 'psi'), closeTo(14.503774, 1e-6));
    expect(Units.convert(Quantity.pressure, 1, 'kgf/cm2', 'bar'), closeTo(0.980665, 1e-9));
    expect(Units.convert(Quantity.pressure, 1000, 'mmH2O', 'kPa'), closeTo(9.80665, 1e-9));
    expect(Units.convert(Quantity.pressure, 760, 'mmHg', 'atm'), closeTo(1, 1e-6));
  });

  test('temperature is affine', () {
    expect(Units.convert(Quantity.temperature, 100, 'C', 'F'), closeTo(212, 1e-9));
    expect(Units.convert(Quantity.temperature, 32, 'F', 'K'), closeTo(273.15, 1e-9));
    expect(Units.convert(Quantity.temperature, 0, 'K', 'R'), closeTo(0, 1e-9));
  });

  test('flow conversions', () {
    expect(Units.convert(Quantity.volumeFlow, 1, 'm3/h', 'gpm'), closeTo(4.402868, 1e-6));
    expect(Units.convert(Quantity.massFlow, 1, 't/h', 'kg/s'), closeTo(0.277778, 1e-6));
  });

  test('number formatting', () {
    expect(formatNumber(12.30000), '12.3');
    expect(formatNumber(-0.0000001), '-1.0000e-7');
    expect(formatNumber(190.73477), '190.73');
    expect(formatNumber(0), '0');
    expect(formatNumber(double.nan), '—');
  });
}
