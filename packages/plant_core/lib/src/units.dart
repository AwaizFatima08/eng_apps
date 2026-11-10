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
  tempDiff, // K (temperature difference, no offset)
  mass, // kg
  volume, // m³
  area, // m²
  velocity, // m/s
  time, // s
  power, // W
  energy, // J
  force, // N
  torque, // N·m (also bending moment)
  stress, // Pa (stress, strength, bearing pressure)
  specEnergy, // J/kg (enthalpy)
  specEntropy, // J/(kg·K)
  specVolume, // m³/kg
  heatTransfer, // W/(m²·K)
  voltageV, // V
  currentA, // A
  apparentPower, // VA
  reactivePower, // var
  frequency, // Hz
  rotSpeed, // rpm
  capacitance, // F
  conductivity, // S/m
  massConc, // kg/m³ (= g/L)
  molarConc, // mol/m³ (= mmol/L)
  soundLevel, // dB(A)
  linearDensity, // kg/m
  lineLoad, // N/m
  secondMoment, // m⁴
  resistivity, // Ω·m
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
const double _lbf = 4.4482216152605;
const double _btu = 1055.05585262; // International Table BTU

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
    Unit('km', 'km', 1000),
    Unit('um', 'µm', 1e-6),
    Unit('mil', 'mil', 25.4e-6),
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
    Unit('lb/gal', 'lb/US gal', _lb / _usGal),
  ],
  Quantity.viscosity: const [Unit('cP', 'cP', 1e-3), Unit('Pa.s', 'Pa·s', 1)],
  Quantity.current: const [Unit('mA', 'mA', 1)],
  Quantity.voltage: const [Unit('mV', 'mV', 1), Unit('uV', 'µV', 1e-3)],
  Quantity.resistance: const [
    Unit('ohm', 'Ω', 1),
    Unit('mohm', 'mΩ', 1e-3),
    Unit('kohm', 'kΩ', 1e3),
  ],
  Quantity.tempDiff: const [Unit('K', 'K', 1), Unit('dF', '°F', 5 / 9)],
  Quantity.mass: const [
    Unit('mg', 'mg', 1e-6),
    Unit('g', 'g', 1e-3),
    Unit('kg', 'kg', 1),
    Unit('t', 't', 1000),
    Unit('lb', 'lb', _lb),
  ],
  Quantity.volume: const [
    Unit('mL', 'mL', 1e-6),
    Unit('L', 'L', 1e-3),
    Unit('m3', 'm³', 1),
    Unit('gal', 'US gal', _usGal),
    Unit('ft3', 'ft³', _ft * _ft * _ft),
    Unit('yd3', 'yd³', 27 * _ft * _ft * _ft),
    Unit('bbl', 'bbl', _bbl),
  ],
  Quantity.area: const [
    Unit('mm2', 'mm²', 1e-6),
    Unit('cm2', 'cm²', 1e-4),
    Unit('m2', 'm²', 1),
    Unit('in2', 'in²', 0.0254 * 0.0254),
    Unit('ft2', 'ft²', _ft * _ft),
  ],
  Quantity.velocity: const [
    Unit('m/s', 'm/s', 1),
    Unit('km/h', 'km/h', 1 / 3.6),
    Unit('ft/s', 'ft/s', _ft),
    Unit('ft/min', 'ft/min', _ft / 60),
  ],
  Quantity.time: const [
    Unit('s', 's', 1),
    Unit('min', 'min', 60),
    Unit('h', 'h', 3600),
    Unit('d', 'day', 86400),
  ],
  Quantity.power: const [
    Unit('W', 'W', 1),
    Unit('kW', 'kW', 1000),
    Unit('MW', 'MW', 1e6),
    Unit('hp', 'hp', 745.69987158227022),
    Unit('BTU/h', 'BTU/h', _btu / 3600),
    Unit('TR', 'TR', 3516.8528420667),
  ],
  Quantity.energy: const [
    Unit('J', 'J', 1),
    Unit('kJ', 'kJ', 1000),
    Unit('MJ', 'MJ', 1e6),
    Unit('kWh', 'kWh', 3.6e6),
    Unit('Wh', 'Wh', 3600),
    Unit('BTU', 'BTU', _btu),
    Unit('kcal', 'kcal', 4186.8),
  ],
  Quantity.force: const [
    Unit('N', 'N', 1),
    Unit('kN', 'kN', 1000),
    Unit('kgf', 'kgf', gStd),
    Unit('tf', 'tf', 1000 * gStd),
    Unit('lbf', 'lbf', _lbf),
    Unit('kip', 'kip', 1000 * _lbf),
  ],
  Quantity.torque: const [
    Unit('N.m', 'N·m', 1),
    Unit('kN.m', 'kN·m', 1000),
    Unit('kgf.m', 'kgf·m', gStd),
    Unit('lbf.ft', 'lbf·ft', _lbf * _ft),
    Unit('lbf.in', 'lbf·in', _lbf * 0.0254),
    Unit('kip.ft', 'kip·ft', 1000 * _lbf * _ft),
  ],
  Quantity.stress: const [
    Unit('MPa', 'MPa', 1e6),
    Unit('kPa', 'kPa', 1000),
    Unit('GPa', 'GPa', 1e9),
    Unit('psi', 'psi', _psi),
    Unit('ksi', 'ksi', 1000 * _psi),
    Unit('psf', 'psf', _lbf / (_ft * _ft)),
    Unit('kgf/cm2', 'kgf/cm²', 98066.5),
  ],
  Quantity.specEnergy: const [
    Unit('kJ/kg', 'kJ/kg', 1000),
    Unit('BTU/lb', 'BTU/lb', 2326),
  ],
  Quantity.specEntropy: const [
    Unit('kJ/kgK', 'kJ/(kg·K)', 1000),
    Unit('BTU/lbF', 'BTU/(lb·°F)', 4186.8),
  ],
  Quantity.specVolume: const [
    Unit('m3/kg', 'm³/kg', 1),
    Unit('ft3/lb', 'ft³/lb', _ft * _ft * _ft / _lb),
  ],
  Quantity.heatTransfer: const [
    Unit('W/m2K', 'W/(m²·K)', 1),
    Unit('BTU/hft2F', 'BTU/(h·ft²·°F)', 5.678263341),
  ],
  Quantity.voltageV: const [Unit('V', 'V', 1), Unit('kV', 'kV', 1000)],
  Quantity.currentA: const [Unit('A', 'A', 1), Unit('kA', 'kA', 1000)],
  Quantity.apparentPower: const [
    Unit('kVA', 'kVA', 1000),
    Unit('VA', 'VA', 1),
    Unit('MVA', 'MVA', 1e6),
  ],
  Quantity.reactivePower: const [
    Unit('kvar', 'kvar', 1000),
    Unit('var', 'var', 1),
    Unit('Mvar', 'Mvar', 1e6),
  ],
  Quantity.frequency: const [Unit('Hz', 'Hz', 1)],
  Quantity.rotSpeed: const [
    Unit('rpm', 'rpm', 1),
    Unit('rad/s', 'rad/s', 30 / 3.141592653589793),
  ],
  Quantity.capacitance: const [Unit('uF', 'µF', 1e-6), Unit('F', 'F', 1)],
  Quantity.conductivity: const [
    Unit('uS/cm', 'µS/cm', 1e-4),
    Unit('mS/cm', 'mS/cm', 0.1),
    Unit('S/m', 'S/m', 1),
  ],
  Quantity.massConc: const [
    Unit('mg/L', 'mg/L', 1e-3),
    Unit('g/L', 'g/L', 1),
    Unit('mg/m3', 'mg/m³', 1e-6),
    Unit('kg/m3', 'kg/m³', 1),
  ],
  Quantity.molarConc: const [
    Unit('mol/L', 'mol/L', 1000),
    Unit('mmol/L', 'mmol/L', 1),
  ],
  Quantity.soundLevel: const [Unit('dBA', 'dB(A)', 1)],
  Quantity.linearDensity: const [
    Unit('kg/m', 'kg/m', 1),
    Unit('lb/ft', 'lb/ft', _lb / _ft),
  ],
  Quantity.lineLoad: const [
    Unit('kN/m', 'kN/m', 1000),
    Unit('N/m', 'N/m', 1),
    Unit('kgf/m', 'kgf/m', gStd),
    Unit('lbf/ft', 'lbf/ft', _lbf / _ft),
    Unit('kip/ft', 'kip/ft', 1000 * _lbf / _ft),
  ],
  Quantity.secondMoment: const [
    Unit('cm4', 'cm⁴', 1e-8),
    Unit('mm4', 'mm⁴', 1e-12),
    Unit('m4', 'm⁴', 1),
    Unit('in4', 'in⁴', 0.0254 * 0.0254 * 0.0254 * 0.0254),
  ],
  Quantity.resistivity: const [
    Unit('ohm.m', 'Ω·m', 1),
    Unit('ohm.cm', 'Ω·cm', 0.01),
  ],
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
  Quantity.tempDiff: ('K', 'dF'),
  Quantity.mass: ('kg', 'lb'),
  Quantity.volume: ('m3', 'ft3'),
  Quantity.area: ('m2', 'ft2'),
  Quantity.velocity: ('m/s', 'ft/s'),
  Quantity.time: ('h', 'h'),
  Quantity.power: ('kW', 'hp'),
  Quantity.energy: ('kJ', 'BTU'),
  Quantity.force: ('kN', 'lbf'),
  Quantity.torque: ('N.m', 'lbf.ft'),
  Quantity.stress: ('MPa', 'psi'),
  Quantity.specEnergy: ('kJ/kg', 'BTU/lb'),
  Quantity.specEntropy: ('kJ/kgK', 'BTU/lbF'),
  Quantity.specVolume: ('m3/kg', 'ft3/lb'),
  Quantity.heatTransfer: ('W/m2K', 'BTU/hft2F'),
  Quantity.voltageV: ('V', 'V'),
  Quantity.currentA: ('A', 'A'),
  Quantity.apparentPower: ('kVA', 'kVA'),
  Quantity.reactivePower: ('kvar', 'kvar'),
  Quantity.frequency: ('Hz', 'Hz'),
  Quantity.rotSpeed: ('rpm', 'rpm'),
  Quantity.capacitance: ('uF', 'uF'),
  Quantity.conductivity: ('uS/cm', 'uS/cm'),
  Quantity.massConc: ('mg/L', 'mg/L'),
  Quantity.molarConc: ('mol/L', 'mol/L'),
  Quantity.soundLevel: ('dBA', 'dBA'),
  Quantity.linearDensity: ('kg/m', 'lb/ft'),
  Quantity.lineLoad: ('kN/m', 'lbf/ft'),
  Quantity.secondMoment: ('cm4', 'in4'),
  Quantity.resistivity: ('ohm.m', 'ohm.m'),
};

abstract final class Units {
  static List<Unit> of(Quantity q) => _units[q]!;

  static Unit byId(Quantity q, String id) =>
      of(q).firstWhere((u) => u.id == id, orElse: () => of(q).first);

  static Unit defaultFor(Quantity q, UnitSystem s) {
    final d = _defaults[q]!;
    return byId(q, s == UnitSystem.metric ? d.$1 : d.$2);
  }

  /// Default unit for [q], honouring a tool's (metric, imperial) override.
  static Unit preferred(Quantity q, UnitSystem s, (String, String)? override) {
    if (override == null) return defaultFor(q, s);
    return byId(q, s == UnitSystem.metric ? override.$1 : override.$2);
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
