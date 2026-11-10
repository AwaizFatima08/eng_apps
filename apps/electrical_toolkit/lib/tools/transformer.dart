import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// IEC 60076-1 / R10 preferred ratings, kVA.
const List<double> transformerRatings = [
  25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, //
  800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000,
];

final transformerTool = ToolDef(
  id: 'transformer',
  title: 'Transformer current & fault level',
  summary:
      'Full-load current on both sides, the kVA needed for a load, and the '
      'secondary short-circuit current from %Z — infinite source or with the '
      'upstream fault level.',
  icon: Icons.electrical_services,
  keywords: [
    'transformer',
    'kva',
    'full load current',
    'impedance',
    'uk',
    'usc',
    'short circuit',
    'fault level',
    'isc',
    'mva',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Transformer rating',
      options: [
        ChoiceOption('given', 'Known kVA'),
        ChoiceOption('load', 'Size from load'),
      ],
    ),
    NumberInput(
      's',
      'Rated power',
      quantity: Quantity.apparentPower,
      initial: 1000e3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'given',
    ),
    NumberInput(
      'pload',
      'Maximum demand (real)',
      quantity: Quantity.power,
      initial: 700e3,
      min: 0,
      minInclusive: false,
      units: ('kW', 'kW'),
      visibleWhen: (v) => v.c('mode') == 'load',
    ),
    NumberInput(
      'pf',
      'Load power factor',
      quantity: Quantity.dimensionless,
      initial: 0.85,
      min: 0.1,
      max: 1,
      visibleWhen: (v) => v.c('mode') == 'load',
    ),
    NumberInput(
      'loading',
      'Max loading at demand',
      quantity: Quantity.percent,
      initial: 0.8,
      min: 0.1,
      max: 1.2,
      help:
          'Planned loading of the transformer at maximum demand '
          '(80 % leaves room for growth).',
      visibleWhen: (v) => v.c('mode') == 'load',
    ),
    const NumberInput(
      'v1',
      'Primary line voltage',
      quantity: Quantity.voltageV,
      initial: 11000,
      min: 0,
      minInclusive: false,
      units: ('kV', 'kV'),
    ),
    const NumberInput(
      'v2',
      'Secondary line voltage',
      quantity: Quantity.voltageV,
      initial: 400,
      min: 0,
      minInclusive: false,
      help:
          'For fault level use the no-load voltage (e.g. 415 or 433 V); '
          'the Schneider guide uses U₂₀ = 410–420 V.',
    ),
    const NumberInput(
      'z',
      'Impedance voltage uk (%Z)',
      quantity: Quantity.percent,
      initial: 0.06,
      min: 0,
      minInclusive: false,
      max: 0.25,
      help:
          'Nameplate. IEC 60076-5 minimum: 4 % to 630 kVA, 5 % to 1250 kVA, '
          '6 % to 2500 kVA (verify against your edition).',
    ),
    const ChoiceInput(
      'source',
      'Upstream network',
      options: [
        ChoiceOption('inf', 'Infinite source'),
        ChoiceOption('fin', 'Known fault level'),
      ],
    ),
    NumberInput(
      'ssc',
      'Source fault level at primary',
      quantity: Quantity.apparentPower,
      initial: 250e6,
      min: 0,
      minInclusive: false,
      units: ('MVA', 'MVA'),
      help: 'From the utility (e.g. 11 kV: 150–500 MVA).',
      visibleWhen: (v) => v.c('source') == 'fin',
    ),
  ],
  compute: (v) {
    final v1 = v.n('v1'), v2 = v.n('v2'), z = v.n('z');
    final byLoad = v.c('mode') == 'load';
    double? sReq;
    double s;
    if (byLoad) {
      sReq = v.n('pload') / v.n('pf') / v.n('loading');
      final kva = transformerRatings.firstWhere(
        (r) => r * 1000 >= sReq! - 1e-6,
        orElse: () => throw ToolInputError(
          'More than 10 MVA needed: split the load over several transformers.',
        ),
      );
      s = kva * 1000;
    } else {
      s = v.n('s');
    }
    final i1 = s / (math.sqrt(3) * v1);
    final i2 = s / (math.sqrt(3) * v2);
    final finite = v.c('source') == 'fin';
    // Per-unit on the transformer base: zq = S / Ssc (source treated as a
    // pure reactance in series with the transformer — arithmetic sum).
    final zq = finite ? s / v.n('ssc') : 0.0;
    final isc = i2 / (z + zq);
    final iscInf = i2 / z;

    final w = <String>[];
    if (v2 >= v1) w.add('Secondary voltage ≥ primary: check the inputs.');
    if (z < 0.03) {
      w.add('uk below 3 % is unusual for a distribution transformer.');
    }
    if (finite && zq > z) {
      w.add('Source impedance exceeds the transformer\'s: weak source.');
    }
    return ToolResult(
      [
        if (byLoad) ...[
          ToolOutput(
            'sreq',
            'kVA needed',
            sReq!,
            quantity: Quantity.apparentPower,
            sig: 4,
          ),
          ToolOutput(
            'srated',
            'Next standard rating',
            s,
            quantity: Quantity.apparentPower,
            level: OutputLevel.primary,
            sig: 4,
          ),
        ],
        ToolOutput(
          'i1',
          'Primary full-load current',
          i1,
          quantity: Quantity.currentA,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'i2',
          'Secondary full-load current',
          i2,
          quantity: Quantity.currentA,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'isc',
          'Secondary 3-ph fault current',
          isc,
          quantity: Quantity.currentA,
          units: ('kA', 'kA'),
          level: OutputLevel.warn,
          sig: 4,
        ),
        if (finite)
          ToolOutput(
            'iscinf',
            'Fault current, infinite source',
            iscInf,
            quantity: Quantity.currentA,
            units: ('kA', 'kA'),
            sig: 4,
          ),
        ToolOutput(
          'ssc2',
          'Fault level at secondary',
          s / (z + zq),
          quantity: Quantity.apparentPower,
          units: ('MVA', 'MVA'),
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'Symmetrical RMS current at the secondary terminals; motor '
            'contribution, cable impedance and the peak (ip ≈ 2.0–2.2 × Isc) '
            'are not included.',
        'Use the rated no-load secondary voltage for fault current; IEC 60909 '
            'would add the voltage factor c = 1.05 (LV, +6 % tolerance) and '
            'the KT correction.',
      ],
    );
  },
  formula: '''Full-load current:
  I₁ = S / (√3 · U₁),   I₂ = S / (√3 · U₂)

Size from load:
  S ≥ P / (cos φ · loading),  rounded up to R10 rating

Short circuit at secondary terminals:
  Infinite source:   Isc = I₂ / uk          (uk as a fraction)
  With source Ssc:   zq = S / Ssc   (per unit on the transformer base)
                     Isc = I₂ / (uk + zq)
  Fault level        Ssc₂ = S / (uk + zq)''',
  references: [
    'Schneider Electric, Electrical Installation Guide, ch. G §4 (Isc at the terminals of an MV/LV transformer, Isc = In × 100/Usc)',
    'IEC 60076-5:2006, Table 1 (minimum short-circuit impedance by rating)',
    'IEC 60909-0:2016 (method basis: per-unit impedances, voltage factor c)',
    'IEC 60076-1 (rated power; R10 preferred values)',
  ],
  assumptions: [
    'Balanced 3-phase bolted fault; source and transformer impedances added arithmetically (both treated as reactance) — slightly low if their X/R differ greatly.',
    'Off-load tap at principal tapping.',
  ],
  cases: [
    const ToolCase(
      'Schneider EIG: 400 kVA, 420 V no-load, Usc 4 %',
      source:
          'Electrical Installation Guide ch. G §4: In = 550 A, Isc = 550 × '
          '100/4 = 13.7 kA',
      numbers: {
        's': (400, 'kVA'),
        'v1': (20, 'kV'),
        'v2': (420, 'V'),
        'z': (4, '%'),
      },
      expect: {'i2': (550, 'A'), 'isc': (13.75, 'kA')},
      relTol: 3e-3,
    ),
    const ToolCase(
      '1000 kVA 11/0.4 kV, 6 %, infinite and 500 MVA source',
      source:
          'Hand calc: I₁ = 52.486 A, I₂ = 1443.38 A; Isc∞ = 24.056 kA; with '
          'zq = 1/500 = 0.002 pu → Isc = 23.280 kA, 16.129 MVA',
      choices: {'source': 'fin'},
      numbers: {
        's': (1000, 'kVA'),
        'v1': (11, 'kV'),
        'v2': (400, 'V'),
        'z': (6, '%'),
        'ssc': (500, 'MVA'),
      },
      expect: {
        'i1': (52.4864, 'A'),
        'i2': (1443.376, 'A'),
        'iscinf': (24.0563, 'kA'),
        'isc': (23.2803, 'kA'),
        'ssc2': (16.129, 'MVA'),
      },
    ),
    const ToolCase(
      'Size for 700 kW at cos φ 0.85, 80 % loading, 11/0.415 kV',
      source:
          'Hand calc: 700/0.85/0.8 = 1029.4 kVA → 1250 kVA; I₁ = 65.608 A, '
          'I₂ = 1739.0 A, Isc (6 %) = 28.983 kA',
      choices: {'mode': 'load'},
      numbers: {
        'pload': (700, 'kW'),
        'pf': (0.85, '-'),
        'loading': (80, '%'),
        'v1': (11, 'kV'),
        'v2': (415, 'V'),
        'z': (6, '%'),
      },
      expect: {
        'sreq': (1029.41, 'kVA'),
        'srated': (1250, 'kVA'),
        'i1': (65.608, 'A'),
        'i2': (1739.007, 'A'),
        'isc': (28.9834, 'kA'),
      },
    ),
    const ToolCase(
      '630 kVA 6.6/0.4 kV, 4.5 %, 150 MVA source',
      source:
          'Hand calc: I₁ = 55.111 A, I₂ = 909.33 A; zq = 0.63/150 = 0.0042 pu '
          '→ Isc = 909.33/0.0492 = 18.482 kA',
      choices: {'source': 'fin'},
      numbers: {
        's': (630, 'kVA'),
        'v1': (6.6, 'kV'),
        'v2': (400, 'V'),
        'z': (4.5, '%'),
        'ssc': (150, 'MVA'),
      },
      expect: {'i1': (55.1107, 'A'), 'isc': (18.4822, 'kA')},
    ),
  ],
);
