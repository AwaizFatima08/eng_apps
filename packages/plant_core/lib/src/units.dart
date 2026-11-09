/// Unit handling layer. Every value inside a tool is SI (or the base unit
/// listed per [Quantity]); units only exist at the edges (input fields and
/// result display).
library;

import 'dart:math' as math;

/// Standard gravity (CGPM 1901, exact) — used for all head/pressure work.
const double gStd = 9.80665;

/// Conventional water density for "SG" and water-column units (4 °C, 1000 kg/m³).
const double rhoWaterConv = 1000.0;

enum UnitSystem { metric, imperial }

/// Physical quantities. The comment gives the internal base unit.
enum Quantity {
  dimensionless, // -
  percent, // fraction 0..1 shown as %
  pressure, // Pa (absolute or gauge as labelled by the input)
  pressureDiff, // Pa
  temperature, // °C (affine units convert to/from °C)
  length, // m
  volumeFlow, // m³/s (actual)
  stdGasFlow, // Nm³/s at 0 °C, 101.325 kPa
  massFlow, // kg/s
  density, // kg/m³
  viscosity, // Pa·s (dynamic)
  current, // mA
  voltage, // mV
  resistance, // Ω
}

class Unit {
  const Unit(this.id, this.symbol, this.factor, {this.offset = 0});

  /// Stable key (stored in preferences, used in tests).
  final String id;
  final String symbol;

  /// base = value * factor + offset
  final double factor;
  final double offset;

  double toBase(double v) => v * factor + offset;
  double fromBase(double b) => (b - offset) / factor;
}

const double _inH2O4C = 249.08891; // 1 inH2O at 4 °C (25.4 mm × 9.80665 Pa/mm)
const double _inH2O68F = 248.64; // 1 inH2O at 68 °F (ISA/Rosemount convention)
const double _psi = 6894.757293168361;
const double _usGal = 3.785411784e-3;
const double _bbl = 0.158987294928;
const double _lb = 0.45359237;
const double _ft = 0.3048;

final Map<Quantity, List<Unit>> _units = {
  Quantity.dimensionless: const [Unit('-', '', 1)],
  Quantity.percent: const [Unit('%', '%', 0.01)],
  Quantity.pressure: _pressureUnits,
  Quantity.pressureDiff: _pressureUnits,
  Quantity.temperature: const [
    Unit('C', '°C', 1),
    Unit('F', '°F', 5 / 9, offset: -32 * 5 / 9),
    Unit('K', 'K', 1, offset: -273.15),
    Unit('R', '°R', 5 / 9, offset: -273.15),
  ],
  Quantity.length: const [
    Unit('mm', 'mm', 1e-3),
    Unit('cm', 'cm', 1e-2),
    Unit('m', 'm', 1),
    Unit('in', 'in', 0.0254),
    Unit('ft', 'ft', _ft),
  ],
  Quantity.volumeFlow: const [
    Unit('m3/h', 'm³/h', 1 / 3600),
    Unit('L/min', 'L/min', 1e-3 / 60),
    Unit('L/s', 'L/s', 1e-3),
    Unit('m3/s', 'm³/s', 1),
    Unit('gpm', 'US gpm', _usGal / 60),
    Unit('bbl/d', 'bbl/d', _bbl / 86400),
    Unit('cfm', 'ft³/min', _ft * _ft * _ft / 60),
  ],
  Quantity.stdGasFlow: const [
    Unit('Nm3/h', 'Nm³/h', 1 / 3600),
    // 1 scf (60 °F, 14.696 psia) = 0.0268394 Nm³ (0 °C, 1 atm) for an ideal gas.
    Unit('scfh', 'SCFH', 0.0268394 / 3600),
    Unit('MMscfd', 'MMSCFD', 0.0268394e6 / 86400),
    Unit('Nm3/s', 'Nm³/s', 1),
  ],
  Quantity.massFlow: const [
    Unit('kg/h', 'kg/h', 1 / 3600),
    Unit('t/h', 't/h', 1000 / 3600),
    Unit('kg/s', 'kg/s', 1),
    Unit('lb/h', 'lb/h', _lb / 3600),
  ],
  Quantity.density: const [
    Unit('kg/m3', 'kg/m³', 1),
    Unit('g/cm3', 'g/cm³', 1000),
    Unit('lb/ft3', 'lb/ft³', _lb / (_ft * _ft * _ft)),
  ],
  Quantity.viscosity: const [Unit('cP', 'cP', 1e-3), Unit('Pa.s', 'Pa·s', 1)],
  Quantity.current: const [Unit('mA', 'mA', 1)],
  Quantity.voltage: const [Unit('mV', 'mV', 1), Unit('uV', 'µV', 1e-3)],
  Quantity.resistance: const [Unit('ohm', 'Ω', 1)],
};

const List<Unit> _pressureUnits = [
  Unit('bar', 'bar', 1e5),
  Unit('mbar', 'mbar', 100),
  Unit('kPa', 'kPa', 1000),
  Unit('MPa', 'MPa', 1e6),
  Unit('Pa', 'Pa', 1),
  Unit('psi', 'psi', _psi),
  Unit('kgf/cm2', 'kgf/cm²', 98066.5),
  Unit('mmH2O', 'mmH₂O', 9.80665),
  Unit('mH2O', 'mH₂O', 9806.65),
  Unit('inH2O', 'inH₂O (4 °C)', _inH2O4C),
  Unit('inH2O68', 'inH₂O (68 °F)', _inH2O68F),
  Unit('mmHg', 'mmHg', 133.322387415),
  Unit('inHg', 'inHg (32 °F)', 3386.389),
  Unit('atm', 'atm', 101325),
];

const Map<Quantity, (String, String)> _defaults = {
  // (metric, imperial)
  Quantity.dimensionless: ('-', '-'),
  Quantity.percent: ('%', '%'),
  Quantity.pressure: ('bar', 'psi'),
  Quantity.pressureDiff: ('mbar', 'inH2O68'),
  Quantity.temperature: ('C', 'F'),
  Quantity.length: ('mm', 'in'),
  Quantity.volumeFlow: ('m3/h', 'gpm'),
  Quantity.stdGasFlow: ('Nm3/h', 'scfh'),
  Quantity.massFlow: ('kg/h', 'lb/h'),
  Quantity.density: ('kg/m3', 'lb/ft3'),
  Quantity.viscosity: ('cP', 'cP'),
  Quantity.current: ('mA', 'mA'),
  Quantity.voltage: ('mV', 'mV'),
  Quantity.resistance: ('ohm', 'ohm'),
};

abstract final class Units {
  static List<Unit> of(Quantity q) => _units[q]!;

  static Unit byId(Quantity q, String id) =>
      of(q).firstWhere((u) => u.id == id, orElse: () => of(q).first);

  static Unit defaultFor(Quantity q, UnitSystem s) {
    final d = _defaults[q]!;
    return byId(q, s == UnitSystem.metric ? d.$1 : d.$2);
  }

  /// Convert a value between two units of the same quantity.
  static double convert(Quantity q, double v, String fromId, String toId) =>
      byId(q, toId).fromBase(byId(q, fromId).toBase(v));
}

/// Formats a number to [sig] significant figures without exponent noise for
/// everyday magnitudes.
String formatNumber(double v, {int sig = 5}) {
  if (v.isNaN) return '—';
  if (v.isInfinite) return v > 0 ? '∞' : '-∞';
  if (v == 0) return '0';
  final a = v.abs();
  if (a >= 1e9 || a < 1e-4) {
    return v.toStringAsExponential(sig - 1);
  }
  final digits = (sig - 1 - (math.log(a) / math.ln10).floor()).clamp(0, 10);
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  if (s == '-0') s = '0';
  return s;
}
