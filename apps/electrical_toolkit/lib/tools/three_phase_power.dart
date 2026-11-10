import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final threePhasePowerTool = ToolDef(
  id: 'three_phase_power',
  title: 'Three-phase power',
  summary:
      'Line voltage plus any two of P, Q, S, power factor and line current '
      'give the rest of the power triangle, with phase voltage, current and '
      'impedance for star and delta connections.',
  icon: Icons.bolt,
  keywords: [
    'power',
    'kw',
    'kva',
    'kvar',
    'power factor',
    'current',
    'star',
    'delta',
    'wye',
    'phase',
    'line',
    'power triangle',
  ],
  inputs: [
    const ChoiceInput(
      'known',
      'Known besides voltage',
      options: [
        ChoiceOption('p_pf', 'P and power factor'),
        ChoiceOption('s_pf', 'S and power factor'),
        ChoiceOption('i_pf', 'I and power factor'),
        ChoiceOption('p_q', 'P and Q'),
        ChoiceOption('p_s', 'P and S'),
        ChoiceOption('p_i', 'P and I'),
        ChoiceOption('s_q', 'S and Q'),
      ],
    ),
    const NumberInput(
      'v',
      'Line-to-line voltage',
      quantity: Quantity.voltageV,
      initial: 400,
      min: 0,
      minInclusive: false,
    ),
    NumberInput(
      'p',
      'Real power P',
      quantity: Quantity.power,
      initial: 100e3,
      min: 0,
      minInclusive: false,
      units: ('kW', 'kW'),
      visibleWhen: (v) => v.c('known').startsWith('p_'),
    ),
    NumberInput(
      'q',
      'Reactive power Q',
      quantity: Quantity.reactivePower,
      initial: 75e3,
      help: 'Positive = lagging (inductive), negative = leading.',
      visibleWhen: (v) => v.c('known').endsWith('_q'),
    ),
    NumberInput(
      's',
      'Apparent power S',
      quantity: Quantity.apparentPower,
      initial: 125e3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) =>
          v.c('known').startsWith('s_') || v.c('known') == 'p_s',
    ),
    NumberInput(
      'pf',
      'Power factor cos φ',
      quantity: Quantity.dimensionless,
      initial: 0.8,
      min: 0,
      max: 1,
      minInclusive: false,
      visibleWhen: (v) => v.c('known').endsWith('_pf'),
    ),
    ChoiceInput(
      'sense',
      'Power factor sense',
      options: const [
        ChoiceOption('lag', 'Lagging (inductive)'),
        ChoiceOption('lead', 'Leading (capacitive)'),
      ],
      visibleWhen: (v) => v.c('known').endsWith('_pf'),
    ),
    NumberInput(
      'i',
      'Line current I',
      quantity: Quantity.currentA,
      initial: 180,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('known').contains('i'),
    ),
  ],
  compute: (v) {
    final u = v.n('v');
    final r3 = math.sqrt(3);
    final known = v.c('known');
    double p, q, s;
    double signOf() => v.c('sense') == 'lead' ? -1.0 : 1.0;
    double qFrom(double s, double p) {
      if (p > s * (1 + 1e-9)) {
        throw ToolInputError('P cannot exceed S (power factor > 1).');
      }
      return math.sqrt(math.max(0, s * s - p * p));
    }

    switch (known) {
      case 'p_pf':
        p = v.n('p');
        s = p / v.n('pf');
        q = signOf() * qFrom(s, p);
      case 's_pf':
        s = v.n('s');
        p = s * v.n('pf');
        q = signOf() * qFrom(s, p);
      case 'i_pf':
        s = r3 * u * v.n('i');
        p = s * v.n('pf');
        q = signOf() * qFrom(s, p);
      case 'p_q':
        p = v.n('p');
        q = v.n('q');
        s = math.sqrt(p * p + q * q);
      case 'p_s':
        p = v.n('p');
        s = v.n('s');
        q = qFrom(s, p);
      case 'p_i':
        p = v.n('p');
        s = r3 * u * v.n('i');
        q = qFrom(s, p);
      default: // s_q
        s = v.n('s');
        q = v.n('q');
        if (q.abs() > s) throw ToolInputError('|Q| cannot exceed S.');
        p = math.sqrt(s * s - q * q);
    }
    final i = s / (r3 * u);
    final pf = p / s;
    final phi = math.atan2(q, p) * 180 / math.pi;
    final notes = <String>[
      'Balanced load, sinusoidal voltages and currents (no harmonics).',
    ];
    if (known == 'p_s' || known == 'p_i') {
      notes.add(
        'Q assumed lagging (inductive); its sign is not known from P and S.',
      );
    }
    return ToolResult([
      ToolOutput(
        'p',
        'Real power P',
        p,
        quantity: Quantity.power,
        units: ('kW', 'kW'),
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput(
        'q',
        'Reactive power Q',
        q,
        quantity: Quantity.reactivePower,
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput(
        's',
        'Apparent power S',
        s,
        quantity: Quantity.apparentPower,
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput('pf', 'Power factor cos φ', pf, sig: 4),
      ToolOutput.text(
        'pftype',
        'Power factor type',
        q.abs() < 1e-9 * s
            ? 'Unity'
            : q > 0
            ? 'Lagging (inductive)'
            : 'Leading (capacitive)',
      ),
      ToolOutput('phi', 'Angle φ, degrees', phi, sig: 4),
      ToolOutput(
        'i',
        'Line current I',
        i,
        quantity: Quantity.currentA,
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput(
        'vphy',
        'Star: phase voltage',
        u / r3,
        quantity: Quantity.voltageV,
        sig: 5,
      ),
      ToolOutput(
        'zy',
        'Star: phase impedance',
        u / r3 / i,
        quantity: Quantity.resistance,
        sig: 5,
      ),
      ToolOutput(
        'iphd',
        'Delta: phase current',
        i / r3,
        quantity: Quantity.currentA,
        sig: 5,
      ),
      ToolOutput(
        'zd',
        'Delta: phase impedance',
        u / (i / r3),
        quantity: Quantity.resistance,
        sig: 5,
      ),
    ], notes: notes);
  },
  formula: '''S = √3 · U · I          (U line-to-line, I line)
P = S · cos φ,   Q = S · sin φ,   S² = P² + Q²
cos φ = P / S,   φ = atan(Q / P)

Star (Y):   U_ph = U/√3,  I_ph = I,     Z_ph = U_ph / I
Delta (Δ):  U_ph = U,     I_ph = I/√3,  Z_ph = U / I_ph
(The same S in either connection: S = 3 · U_ph · I_ph)''',
  references: [
    'IEC 60050-131 / IEC 60050-141 (definitions of active, reactive, apparent power and power factor in polyphase circuits)',
    'Hughes Electrical and Electronic Technology, 10th ed., ch. 16 (three-phase circuits)',
  ],
  assumptions: ['Balanced three-phase system, fundamental frequency only.'],
  cases: [
    const ToolCase(
      '100 kW at 0.8 lagging, 400 V',
      source:
          'Hand calc: S = 125 kVA, Q = 75 kvar, I = 125000/(√3·400) = '
          '180.42 A; star Z = 1.28 Ω, delta Z = 3.84 Ω',
      numbers: {'v': (400, 'V'), 'p': (100, 'kW'), 'pf': (0.8, '-')},
      expect: {
        's': (125, 'kVA'),
        'q': (75, 'kvar'),
        'i': (180.422, 'A'),
        'zy': (1.28, 'ohm'),
        'zd': (3.84, 'ohm'),
        'phi': (36.8699, '-'),
      },
      expectText: {'pftype': 'Lagging'},
    ),
    const ToolCase(
      '11 kV, 100 A, cos φ 0.9',
      source:
          'Hand calc: S = √3·11000·100 = 1905.26 kVA, P = 1714.73 kW, '
          'Q = 830.48 kvar; star U_ph = 6350.85 V; delta I_ph = 57.735 A',
      choices: {'known': 'i_pf'},
      numbers: {'v': (11, 'kV'), 'i': (100, 'A'), 'pf': (0.9, '-')},
      expect: {
        's': (1905.256, 'kVA'),
        'p': (1714.730, 'kW'),
        'q': (830.482, 'kvar'),
        'vphy': (6350.853, 'V'),
        'iphd': (57.735, 'A'),
      },
    ),
    const ToolCase(
      'P 80 kW and Q −60 kvar (leading), 400 V',
      source: 'Hand calc (3-4-5 triangle): S = 100 kVA, pf 0.8, I = 144.34 A',
      choices: {'known': 'p_q'},
      numbers: {'v': (400, 'V'), 'p': (80, 'kW'), 'q': (-60, 'kvar')},
      expect: {'s': (100, 'kVA'), 'pf': (0.8, '-'), 'i': (144.3376, 'A')},
      expectText: {'pftype': 'Leading'},
    ),
    const ToolCase(
      'Measured 50 kW and 90 A at 415 V',
      source:
          'Hand calc: S = √3·415·90 = 64.692 kVA, pf = 0.77289, '
          'Q = 41.050 kvar',
      choices: {'known': 'p_i'},
      numbers: {'v': (415, 'V'), 'p': (50, 'kW'), 'i': (90, 'A')},
      expect: {
        's': (64.6921, 'kVA'),
        'pf': (0.772892, '-'),
        'q': (41.0496, 'kvar'),
      },
    ),
  ],
);
