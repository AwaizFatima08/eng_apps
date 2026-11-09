import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'nist_tc_data.dart';

// IEC 60751 Callendar–Van Dusen coefficients (α = 0.00385055 /°C).
const double _a = 3.9083e-3;
const double _b = -5.775e-7;
const double _c = -4.183e-12;

double rtdResistance(double t, double r0) {
  final base = 1 + _a * t + _b * t * t;
  return r0 * (t >= 0 ? base : base + _c * (t - 100) * t * t * t);
}

double rtdTemperature(double r, double r0) {
  if (r >= r0) {
    return (-_a + math.sqrt(_a * _a - 4 * _b * (1 - r / r0))) / (2 * _b);
  }
  // Below 0 °C the C term applies: Newton iteration from the quadratic guess.
  var t = (r / r0 - 1) / _a;
  for (var i = 0; i < 50; i++) {
    final f = rtdResistance(t, r0) - r;
    final df = r0 * (_a + 2 * _b * t + _c * (4 * t * t * t - 300 * t * t));
    final step = f / df;
    t -= step;
    if (step.abs() < 1e-12) break;
  }
  return t;
}

const _rtds = {'pt100': 100.0, 'pt500': 500.0, 'pt1000': 1000.0};

/// IEC 60584-1 tolerance classes: (class, fixed °C, fraction of |t|, tLo, tHi).
const Map<String, List<(String, double, double, double, double)>>
_tcTolerance = {
  'K': [
    ('Class 1', 1.5, 0.004, -40, 1000),
    ('Class 2', 2.5, 0.0075, -40, 1200),
  ],
  'N': [
    ('Class 1', 1.5, 0.004, -40, 1000),
    ('Class 2', 2.5, 0.0075, -40, 1200),
  ],
  'J': [('Class 1', 1.5, 0.004, -40, 750), ('Class 2', 2.5, 0.0075, -40, 750)],
  'E': [('Class 1', 1.5, 0.004, -40, 800), ('Class 2', 2.5, 0.0075, -40, 900)],
  'T': [('Class 1', 0.5, 0.004, -40, 350), ('Class 2', 1.0, 0.0075, -40, 350)],
  'R': [('Class 2', 1.5, 0.0025, 0, 1600)],
  'S': [('Class 2', 1.5, 0.0025, 0, 1600)],
  'B': [('Class 2', 1.5, 0.0025, 600, 1700)],
};

double? _rsClass1(double t) {
  if (t < 0 || t > 1600) return null;
  return t <= 1100 ? 1.0 : 1.0 + 0.003 * (t - 1100);
}

final temperatureSensorsTool = ToolDef(
  id: 'temp_sensors',
  title: 'Thermocouple & RTD tables',
  summary:
      'Temperature ⇄ mV for types B, E, J, K, N, R, S, T with cold-junction '
      'compensation, and temperature ⇄ ohms for Pt100/Pt500/Pt1000 RTDs.',
  icon: Icons.thermostat,
  keywords: [
    'thermocouple',
    'rtd',
    'pt100',
    'mv',
    'ohm',
    'cjc',
    'its-90',
    'iec 60751',
    'emf',
  ],
  inputs: [
    ChoiceInput(
      'sensor',
      'Sensor',
      initial: 'K',
      options: [
        for (final t in ['K', 'J', 'T', 'E', 'N', 'R', 'S', 'B'])
          ChoiceOption(t, 'Thermocouple type $t'),
        const ChoiceOption('pt100', 'RTD Pt100 (IEC 60751)'),
        const ChoiceOption('pt500', 'RTD Pt500 (IEC 60751)'),
        const ChoiceOption('pt1000', 'RTD Pt1000 (IEC 60751)'),
      ],
    ),
    const ChoiceInput(
      'mode',
      'Convert',
      options: [
        ChoiceOption('t2s', 'Temp → signal'),
        ChoiceOption('s2t', 'Signal → temp'),
      ],
    ),
    NumberInput(
      't',
      'Hot-junction / sensor temperature',
      quantity: Quantity.temperature,
      initial: 100,
      visibleWhen: (v) => v.c('mode') == 't2s',
    ),
    NumberInput(
      'mv',
      'Measured EMF at the terminals',
      quantity: Quantity.voltage,
      initial: 4.096,
      visibleWhen: (v) =>
          v.c('mode') == 's2t' && !_rtds.containsKey(v.c('sensor')),
    ),
    NumberInput(
      'ohm',
      'Measured resistance',
      quantity: Quantity.resistance,
      initial: 138.5055,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) =>
          v.c('mode') == 's2t' && _rtds.containsKey(v.c('sensor')),
    ),
    NumberInput(
      'tcj',
      'Cold (reference) junction temperature',
      quantity: Quantity.temperature,
      initial: 0,
      help:
          'Terminal temperature at the meter/transmitter. Use 0 for an ice-point reference.',
      visibleWhen: (v) => !_rtds.containsKey(v.c('sensor')),
    ),
  ],
  compute: (v) {
    final sensor = v.c('sensor');
    final toSignal = v.c('mode') == 't2s';
    final warnings = <String>[];
    final r0 = _rtds[sensor];
    if (r0 != null) {
      final t = toSignal ? v.n('t') : rtdTemperature(v.n('ohm'), r0);
      final r = toSignal ? rtdResistance(t, r0) : v.n('ohm');
      if (t < -200 || t > 850) {
        warnings.add(
          'Outside the IEC 60751 range −200 … 850 °C; result is an extrapolation.',
        );
      }
      final sens = (rtdResistance(t + 0.5, r0) - rtdResistance(t - 0.5, r0));
      return ToolResult(
        [
          ToolOutput(
            't',
            'Temperature',
            t,
            quantity: Quantity.temperature,
            level: toSignal ? OutputLevel.normal : OutputLevel.primary,
            sig: 6,
          ),
          ToolOutput(
            'ohm',
            'Resistance',
            r,
            quantity: Quantity.resistance,
            level: toSignal ? OutputLevel.primary : OutputLevel.normal,
            sig: 7,
          ),
          ToolOutput('sens', 'Sensitivity (Ω per °C)', sens, sig: 4),
          ToolOutput(
            'tolAA',
            'Class AA tolerance ± (°C)',
            0.1 + 0.0017 * t.abs(),
            sig: 3,
          ),
          ToolOutput(
            'tolA',
            'Class A tolerance ± (°C)',
            0.15 + 0.002 * t.abs(),
            sig: 3,
          ),
          ToolOutput(
            'tolB',
            'Class B tolerance ± (°C)',
            0.3 + 0.005 * t.abs(),
            sig: 3,
          ),
          ToolOutput(
            'tolC',
            'Class C tolerance ± (°C)',
            0.6 + 0.01 * t.abs(),
            sig: 3,
          ),
        ],
        warnings: [
          ...warnings,
          if (t < -50 || t > 250)
            'Class AA applies only −50 … 250 °C (wire-wound), 0 … 150 °C (film).',
          if (t < -100 || t > 450)
            'Class A applies only −100 … 450 °C (wire-wound), −30 … 300 °C (film).',
        ],
        notes: [
          'Lead-wire resistance is not included: use a 3- or 4-wire connection or subtract it.',
        ],
      );
    }

    final tc = nistThermocouples[sensor]!;
    final tcj = v.n('tcj');
    final ecj = tc.emf(tcj);
    late final double t, eAbs, eMeas;
    if (toSignal) {
      t = v.n('t');
      eAbs = tc.emf(t);
      eMeas = eAbs - ecj;
    } else {
      eMeas = v.n('mv');
      eAbs = eMeas + ecj;
      t = tc.temperature(eAbs);
      if (t.isNaN) {
        throw ToolInputError(
          'EMF is outside the type $sensor reference function '
          '(${formatNumber(tc.emf(tc.inverseMin))} … ${formatNumber(tc.emf(tc.tMax))} mV vs 0 °C).',
        );
      }
    }
    if (t < tc.tMin || t > tc.tMax) {
      warnings.add(
        'Outside the NIST type $sensor range ${formatNumber(tc.tMin)} … '
        '${formatNumber(tc.tMax)} °C.',
      );
    }
    if (sensor == 'B' && t < 250) {
      warnings.add(
        'Type B output is tiny and not single-valued below ~50 °C; '
        'not recommended below 250 °C.',
      );
    }
    if (tcj < tc.tMin || tcj > tc.tMax) {
      warnings.add('Cold-junction temperature is outside the type range.');
    }
    final seebeck = (tc.emf(t + 0.5) - tc.emf(t - 0.5)) * 1000; // µV/°C
    final tol = <ToolOutput>[];
    if (sensor == 'R' || sensor == 'S') {
      final c1 = _rsClass1(t);
      if (c1 != null) {
        tol.add(ToolOutput('tol1', 'Class 1 tolerance ± (°C)', c1, sig: 3));
      }
    }
    for (final (name, fixed, frac, lo, hi) in _tcTolerance[sensor]!) {
      if (t < lo || t > hi) continue;
      tol.add(
        ToolOutput(
          'tol${name.substring(6)}',
          '$name tolerance ± (°C)',
          math.max(fixed, frac * t.abs()),
          sig: 3,
        ),
      );
    }
    return ToolResult(
      [
        ToolOutput(
          't',
          'Hot-junction temperature',
          t,
          quantity: Quantity.temperature,
          level: toSignal ? OutputLevel.normal : OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput(
          'mv',
          'EMF at terminals (with CJ)',
          eMeas,
          quantity: Quantity.voltage,
          level: toSignal ? OutputLevel.primary : OutputLevel.normal,
          sig: 6,
        ),
        ToolOutput(
          'mv0',
          'EMF vs 0 °C reference',
          eAbs,
          quantity: Quantity.voltage,
          sig: 6,
        ),
        ToolOutput(
          'mvcj',
          'EMF of cold junction',
          ecj,
          quantity: Quantity.voltage,
          sig: 6,
        ),
        ToolOutput('seebeck', 'Sensitivity (µV per °C)', seebeck, sig: 4),
        ...tol,
      ],
      warnings: warnings,
      notes: [
        'Type $sensor: ${tc.composition}. Compensating/extension cable must match the type and polarity.',
      ],
    );
  },
  formula: '''Thermocouple (NIST ITS-90 reference functions):
  E(t) = Σ cᵢ·tⁱ                        [mV, t in °C]
  Type K, t ≥ 0 °C adds a0·exp(a1·(t − 126.9686)²)
  Terminal EMF  Emeas = E(t_hot) − E(t_cj)
  Signal → temp: solve E(t) = Emeas + E(t_cj)
  (solved on E(t) itself; NIST inverse polynomials are
   only approximations)

RTD (IEC 60751, Callendar–Van Dusen):
  t ≥ 0:  R = R0·(1 + A·t + B·t²)
  t < 0:  R = R0·(1 + A·t + B·t² + C·(t − 100)·t³)
  A = 3.9083e-3,  B = −5.775e-7,  C = −4.183e-12
  R → t (t ≥ 0): t = (−A + √(A² − 4B(1 − R/R0))) / 2B

Tolerances:
  RTD  AA ±(0.1+0.0017|t|)  A ±(0.15+0.002|t|)
       B  ±(0.3+0.005|t|)   C ±(0.6+0.01|t|)
  TC   larger of a fixed value or a fraction of |t|,
       per IEC 60584-1 Table 12 (shown per type/class)''',
  references: [
    'NIST SRD 60 / NIST Monograph 175 (ITS-90 thermocouple reference functions)',
    'IEC 60584-1:2013 Thermocouples — EMF specifications and tolerances',
    'IEC 60751:2022 Industrial platinum resistance thermometers',
  ],
  assumptions: [
    'Homogeneous thermocouple wire matching the NIST reference function; ageing/drift not included.',
    'RTD tolerance validity ranges shown are for wire-wound elements; film elements are narrower.',
    'Thermocouple tolerance values: verify against your copy of IEC 60584-1 Table 12 for acceptance work.',
  ],
  cases: [
    ToolCase(
      'Type K, 100 °C',
      source: 'NIST ITS-90 table: 4.096 mV',
      choices: {'sensor': 'K'},
      numbers: {'t': (100, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (4.096, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type K, 1000 °C',
      source: 'NIST ITS-90 table: 41.276 mV',
      choices: {'sensor': 'K'},
      numbers: {'t': (1000, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (41.276, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type K, −100 °C',
      source: 'NIST ITS-90 table: −3.554 mV',
      choices: {'sensor': 'K'},
      numbers: {'t': (-100, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (-3.554, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type J, 500 °C',
      source: 'NIST ITS-90 table: 27.393 mV',
      choices: {'sensor': 'J'},
      numbers: {'t': (500, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (27.393, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type T, 100 °C',
      source: 'NIST ITS-90 table: 4.279 mV',
      choices: {'sensor': 'T'},
      numbers: {'t': (100, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (4.279, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type E, 100 °C',
      source: 'NIST ITS-90 table: 6.319 mV',
      choices: {'sensor': 'E'},
      numbers: {'t': (100, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (6.319, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type N, 100 °C',
      source: 'NIST ITS-90 table: 2.774 mV',
      choices: {'sensor': 'N'},
      numbers: {'t': (100, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (2.774, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type S, 1000 °C',
      source: 'NIST ITS-90 table: 9.587 mV',
      choices: {'sensor': 'S'},
      numbers: {'t': (1000, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (9.587, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type R, 1000 °C',
      source: 'NIST ITS-90 table: 10.506 mV',
      choices: {'sensor': 'R'},
      numbers: {'t': (1000, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (10.506, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type B, 1000 °C',
      source: 'NIST ITS-90 table: 4.834 mV',
      choices: {'sensor': 'B'},
      numbers: {'t': (1000, 'C'), 'tcj': (0, 'C')},
      expect: {'mv': (4.834, 'mV')},
      absTol: 0.0006,
    ),
    ToolCase(
      'Type K, 20.644 mV → 500 °C',
      source: 'NIST ITS-90 table: 500 °C = 20.644 mV',
      choices: {'sensor': 'K', 'mode': 's2t'},
      numbers: {'mv': (20.644, 'mV'), 'tcj': (0, 'C')},
      expect: {'t': (500, 'C')},
      absTol: 0.02,
    ),
    ToolCase(
      'Type K with CJC: 400 °C, terminals at 25 °C',
      source: 'NIST: E(400)=16.397 mV, E(25)=1.000 mV → 15.397 mV',
      choices: {'sensor': 'K'},
      numbers: {'t': (400, 'C'), 'tcj': (25, 'C')},
      expect: {'mv': (15.397, 'mV')},
      absTol: 0.001,
    ),
    ToolCase(
      'Type K reading 15.397 mV, terminals at 25 °C',
      source: 'Inverse of the case above → 400 °C',
      choices: {'sensor': 'K', 'mode': 's2t'},
      numbers: {'mv': (15.397, 'mV'), 'tcj': (25, 'C')},
      expect: {'t': (400, 'C')},
      absTol: 0.03,
    ),
    ToolCase(
      'Pt100 at 100 °C',
      source: 'IEC 60751 table: 138.51 Ω',
      choices: {'sensor': 'pt100'},
      numbers: {'t': (100, 'C')},
      expect: {'ohm': (138.5055, 'ohm')},
      absTol: 0.0005,
    ),
    ToolCase(
      'Pt100 at −100 °C',
      source: 'IEC 60751 table: 60.26 Ω',
      choices: {'sensor': 'pt100'},
      numbers: {'t': (-100, 'C')},
      expect: {'ohm': (60.2558, 'ohm')},
      absTol: 0.0005,
    ),
    ToolCase(
      'Pt100 at 850 °C',
      source: 'IEC 60751 table: 390.48 Ω',
      choices: {'sensor': 'pt100'},
      numbers: {'t': (850, 'C')},
      expect: {'ohm': (390.4811, 'ohm')},
      absTol: 0.0005,
    ),
    ToolCase(
      'Pt100 175.856 Ω → 200 °C',
      source: 'IEC 60751 table: 200 °C = 175.86 Ω',
      choices: {'sensor': 'pt100', 'mode': 's2t'},
      numbers: {'ohm': (175.856, 'ohm')},
      expect: {'t': (200, 'C')},
      absTol: 0.001,
    ),
    ToolCase(
      'Pt1000 803.06 Ω → −50 °C',
      source: 'IEC 60751 table: Pt100 −50 °C = 80.306 Ω',
      choices: {'sensor': 'pt1000', 'mode': 's2t'},
      numbers: {'ohm': (803.063, 'ohm')},
      expect: {'t': (-50, 'C')},
      absTol: 0.001,
    ),
  ],
);
