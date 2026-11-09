import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const _shown = [
  ('bar', 'bar'),
  ('mbar', 'mbar'),
  ('kPa', 'kPa'),
  ('MPa', 'MPa'),
  ('psi', 'psi'),
  ('kgf/cm2', 'kgf/cm²'),
  ('mmH2O', 'mmH₂O'),
  ('mH2O', 'mH₂O'),
  ('inH2O', 'inH₂O 4 °C'),
  ('inH2O68', 'inH₂O 68 °F'),
  ('mmHg', 'mmHg'),
  ('inHg', 'inHg'),
  ('atm', 'atm'),
  ('Pa', 'Pa'),
];

final pressureConverterTool = ToolDef(
  id: 'pressure_converter',
  title: 'Pressure & head converter',
  summary:
      'Every common plant pressure unit at once, gauge ⇄ absolute, and the '
      'equivalent liquid column for any specific gravity.',
  icon: Icons.speed,
  keywords: [
    'pressure',
    'unit',
    'convert',
    'bar',
    'psi',
    'kg/cm2',
    'mmwc',
    'inh2o',
    'head',
    'gauge',
    'absolute',
    'level',
  ],
  inputs: [
    const NumberInput(
      'p',
      'Pressure',
      quantity: Quantity.pressure,
      initial: 1e5,
    ),
    const ChoiceInput(
      'basis',
      'Entered value is',
      options: [
        ChoiceOption('g', 'Gauge'),
        ChoiceOption('a', 'Absolute'),
        ChoiceOption('d', 'Differential'),
      ],
    ),
    NumberInput(
      'patm',
      'Local atmospheric pressure',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 101325,
      min: 0,
      minInclusive: false,
      help: 'Sea level 1.01325 bar. Roughly −0.12 bar per 1000 m altitude.',
      visibleWhen: (v) => v.c('basis') != 'd',
    ),
    const NumberInput(
      'sg',
      'Liquid specific gravity (for head)',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help: 'Relative to water at 4 °C (1000 kg/m³).',
    ),
  ],
  compute: (v) {
    final p = v.n('p'), sg = v.n('sg');
    final basis = v.c('basis');
    final w = <String>[];
    final out = <ToolOutput>[
      for (final (id, label) in _shown)
        ToolOutput(
          'u_$id',
          label,
          p,
          quantity: Quantity.pressure,
          fixedUnit: id,
          sig: 6,
        ),
    ];
    if (basis != 'd') {
      final patm = v.n('patm');
      final abs = basis == 'g' ? p + patm : p;
      if (abs < 0) w.add('Absolute pressure below zero — check the entry.');
      out.insert(
        0,
        ToolOutput(
          basis == 'g' ? 'abs' : 'gauge',
          basis == 'g' ? 'Absolute pressure' : 'Gauge pressure',
          basis == 'g' ? abs : p - patm,
          quantity: Quantity.pressure,
          level: OutputLevel.primary,
          sig: 6,
        ),
      );
    }
    out.insert(
      0,
      ToolOutput(
        'head',
        'Liquid column (SG ${formatNumber(sg, sig: 4)})',
        p / (sg * rhoWaterConv * gStd),
        quantity: Quantity.length,
        level: OutputLevel.primary,
        sig: 6,
      ),
    );
    return ToolResult(out, warnings: w);
  },
  formula: '''Exact unit definitions (base: Pa):
  1 bar = 100 000          1 psi = 6 894.757
  1 kgf/cm² = 98 066.5     1 atm = 101 325
  1 mmH₂O = 9.80665 (conventional, 4 °C)
  1 inH₂O (4 °C) = 249.0889   1 inH₂O (68 °F) = 248.64
  1 mmHg = 133.3224        1 inHg (32 °F) = 3 386.389

Absolute = Gauge + Atmospheric
Liquid head  h = P / (SG · 1000 kg/m³ · 9.80665 m/s²)''',
  references: [
    'BIPM SI Brochure, 9th ed. (2019) and NIST SP 811 (2008) conversion factors',
    'ISA / transmitter-maker convention for inH₂O at 68 °F (248.64 Pa)',
  ],
  assumptions: [
    'Standard gravity 9.80665 m/s²; local gravity differs by up to ±0.3 %.',
  ],
  cases: [
    const ToolCase(
      '1 bar g at sea level',
      source: '1 bar = 14.5038 psi = 1.01972 kgf/cm²; abs 2.01325 bar',
      numbers: {'p': (1, 'bar')},
      expect: {
        'u_psi': (14.50377, 'psi'),
        'u_kgf/cm2': (1.019716, 'kgf/cm2'),
        'abs': (2.01325, 'bar'),
        'head': (10.19716, 'm'),
      },
    ),
    const ToolCase(
      '100 psi g → bar',
      source: 'NIST SP 811: 1 psi = 6.894757 kPa',
      numbers: {'p': (100, 'psi')},
      expect: {'u_bar': (6.894757, 'bar'), 'u_inH2O': (2768.068, 'inH2O')},
    ),
    const ToolCase(
      '500 mmH₂O DP, SG 0.8',
      source: 'Head = 0.5 / 0.8 = 0.625 m',
      choices: {'basis': 'd'},
      numbers: {'p': (500, 'mmH2O'), 'sg': (0.8, '-')},
      expect: {'head': (0.625, 'm'), 'u_mbar': (49.03325, 'mbar')},
    ),
    const ToolCase(
      'Vacuum 0.2 bar a → gauge',
      source: '0.2 − 1.01325 = −0.81325 bar g',
      choices: {'basis': 'a'},
      numbers: {'p': (0.2, 'bar')},
      expect: {'gauge': (-0.81325, 'bar')},
    ),
  ],
);
