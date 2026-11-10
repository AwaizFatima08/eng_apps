import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const double _cft = 0.3048 * 0.3048 * 0.3048;

final concreteMixTool = ToolDef(
  id: 'concrete_mix',
  title: 'Concrete mix & quantity',
  summary:
      'Cement bags, sand and aggregate (m³ and cft) and water for a nominal '
      'mix, from a slab, beam, column or pad volume, with wastage.',
  icon: Icons.foundation,
  keywords: [
    'concrete',
    'cement',
    'bags',
    'sand',
    'aggregate',
    'crush',
    'bajri',
    'nominal mix',
    '1:2:4',
    '1:1.5:3',
    '1:3:6',
    'dry volume',
    '1.54',
    'cft',
    'slab',
    'column',
    'footing',
    'water cement ratio',
  ],
  inputs: [
    const ChoiceInput(
      'shape',
      'Volume from',
      options: [
        ChoiceOption('vol', 'Enter volume'),
        ChoiceOption('rect', 'Rectangular L×B×D'),
        ChoiceOption('circ', 'Circular column'),
      ],
      help: 'Rectangular covers slabs, beams, square columns and pads.',
    ),
    NumberInput(
      'V',
      'Wet (finished) volume',
      quantity: Quantity.volume,
      units: ('m3', 'ft3'),
      initial: 1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'vol',
    ),
    NumberInput(
      'L',
      'Length L',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'rect',
    ),
    NumberInput(
      'B',
      'Width B',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 4,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'rect',
    ),
    NumberInput(
      'D',
      'Depth / thickness D',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.15,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'rect',
    ),
    NumberInput(
      'dia',
      'Column diameter',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.45,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'circ',
    ),
    NumberInput(
      'H',
      'Column height',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 3.5,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('shape') == 'circ',
    ),
    NumberInput(
      'count',
      'Number of members',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 1,
      visibleWhen: (v) => v.c('shape') != 'vol',
    ),
    const ChoiceInput(
      'mix',
      'Nominal mix C:S:A',
      initial: 'm20',
      options: [
        ChoiceOption('m20', '1:1.5:3'),
        ChoiceOption('m15', '1:2:4'),
        ChoiceOption('m10', '1:3:6'),
        ChoiceOption('custom', 'Custom ratio'),
      ],
      help:
          'By volume. Typical use: 1:1.5:3 RCC beams/slabs/columns; 1:2:4 '
          'lightly loaded RCC; 1:3:6 blinding (lean) concrete.',
    ),
    NumberInput(
      'rc',
      'Cement parts',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mix') == 'custom',
    ),
    NumberInput(
      'rs',
      'Sand parts',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      visibleWhen: (v) => v.c('mix') == 'custom',
    ),
    NumberInput(
      'ra',
      'Aggregate parts',
      quantity: Quantity.dimensionless,
      initial: 2,
      min: 0,
      visibleWhen: (v) => v.c('mix') == 'custom',
    ),
    const NumberInput(
      'f',
      'Dry-volume factor',
      quantity: Quantity.dimensionless,
      initial: 1.54,
      min: 1,
      max: 2,
      help:
          'Practice value: dry loose materials ÷ finished concrete. 1.54 is the '
          'usual site figure; published values range 1.50–1.57.',
    ),
    const NumberInput(
      'waste',
      'Wastage allowance',
      quantity: Quantity.percent,
      initial: 0.05,
      min: 0,
      max: 0.5,
      help: 'Typical 2–5 % (spillage, over-break, uneven formwork).',
    ),
    const NumberInput(
      'wc',
      'Water / cement ratio',
      quantity: Quantity.dimensionless,
      initial: 0.5,
      min: 0.25,
      max: 1,
      help:
          'By mass. Lower w/c gives higher strength; ACI 318 Table 19.3.2.1 caps w/c by exposure.',
    ),
    const NumberInput(
      'rho',
      'Cement bulk density',
      quantity: Quantity.density,
      initial: 1440,
      min: 1000,
      max: 1700,
      help: '1440 kg/m³ (90 lb/ft³) loose: 50 kg bag = 0.0347 m³ = 1.226 cft.',
    ),
    const NumberInput(
      'bag',
      'Bag mass',
      quantity: Quantity.mass,
      initial: 50,
      min: 0,
      minInclusive: false,
    ),
  ],
  compute: (v) {
    final shape = v.c('shape');
    final count = shape == 'vol' ? 1.0 : v.n('count');
    if (count != count.roundToDouble()) {
      throw ToolInputError('Number of members must be a whole number.');
    }
    final one = switch (shape) {
      'rect' => v.n('L') * v.n('B') * v.n('D'),
      'circ' => math.pi / 4 * v.n('dia') * v.n('dia') * v.n('H'),
      _ => v.n('V'),
    };
    final wet = one * count;
    final (c, s, a) = switch (v.c('mix')) {
      'm15' => (1.0, 2.0, 4.0),
      'm10' => (1.0, 3.0, 6.0),
      'custom' => (v.n('rc'), v.n('rs'), v.n('ra')),
      _ => (1.0, 1.5, 3.0),
    };
    final parts = c + s + a;
    final f = v.n('f'), waste = v.n('waste');
    final dry = wet * f * (1 + waste);
    final cementVol = dry * c / parts;
    final cementKg = cementVol * v.n('rho');
    final bagKg = v.n('bag');
    final bags = cementKg / bagKg;
    final sand = dry * s / parts, agg = dry * a / parts;
    final water = v.n('wc') * cementKg; // kg ≈ litres

    final w = <String>[];
    if (f < 1.50 || f > 1.57) {
      w.add(
        'Dry-volume factor outside the 1.50–1.57 range found in practice references.',
      );
    }
    if (c / parts > 0.4 || (s + a) / c > 12) {
      w.add('Unusual mix ratio: check the C:S:A parts.');
    }
    return ToolResult(
      [
        ToolOutput(
          'wet',
          'Wet volume',
          wet,
          quantity: Quantity.volume,
          units: ('m3', 'ft3'),
        ),
        ToolOutput(
          'dry',
          'Dry volume (with wastage)',
          dry,
          quantity: Quantity.volume,
          units: ('m3', 'ft3'),
        ),
        ToolOutput(
          'bags',
          'Cement bags',
          bags,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'order',
          'Bags to order (rounded up)',
          (bags - 1e-9).ceilToDouble(),
          sig: 6,
        ),
        ToolOutput(
          'cement',
          'Cement mass',
          cementKg,
          quantity: Quantity.mass,
          units: ('kg', 'lb'),
          sig: 5,
        ),
        ToolOutput(
          'sand',
          'Sand',
          sand,
          quantity: Quantity.volume,
          fixedUnit: 'm3',
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'sandcft',
          'Sand (cft)',
          sand,
          quantity: Quantity.volume,
          fixedUnit: 'ft3',
          sig: 4,
        ),
        ToolOutput(
          'agg',
          'Aggregate',
          agg,
          quantity: Quantity.volume,
          fixedUnit: 'm3',
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'aggcft',
          'Aggregate (cft)',
          agg,
          quantity: Quantity.volume,
          fixedUnit: 'ft3',
          sig: 4,
        ),
        ToolOutput(
          'water',
          'Water',
          water / 1000,
          quantity: Quantity.volume,
          units: ('L', 'gal'),
          sig: 4,
        ),
        ToolOutput(
          'cft_bag',
          'Bag volume (cft)',
          bagKg / v.n('rho') / _cft,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'Nominal (volume-batched) mixes are site practice for minor work. ACI 318 / '
            'Building Code of Pakistan structural concrete should be a designed mix '
            '(ACI 211.1 proportions, ACI 301 / ACI 318 Ch. 26 acceptance).',
        'Water is for the cement only; adjust for sand and aggregate moisture on site.',
      ],
    );
  },
  formula: '''Wet volume V (finished, compacted concrete):
  Rectangle:   V = L·B·D × count
  Circular:    V = π/4·d²·H × count

Dry volume (loose materials, voids and bulking):
  V_dry = V × f × (1 + wastage),   f ≈ 1.54 (practice)

Mix C:S:A by volume, Σ = C + S + A:
  Cement volume = V_dry · C/Σ
  Cement mass   = cement volume × 1440 kg/m³
  Bags          = cement mass / 50 kg
  Sand          = V_dry · S/Σ
  Aggregate     = V_dry · A/Σ
Water = (w/c) × cement mass   (1 kg ≈ 1 L)

1 m³ = 35.3147 cft;  50 kg bag = 0.0347 m³ = 1.226 cft

Example 1 m³ of 1:1.5:3:
  1.54/5.5 × 1440 = 403.2 kg = 8.06 bags
  sand 0.42 m³ (14.8 cft), aggregate 0.84 m³ (29.7 cft)''',
  references: [
    'IS 456:2000 §9.3 and Table 9 (nominal mixes M5–M20 by aggregate mass per 50 kg cement; traditionally quoted as M10 ≈ 1:3:6, M15 ≈ 1:2:4, M20 ≈ 1:1.5:3)',
    'Dry-volume factor 1.54: South-Asian site-estimating practice; secondary sources give 1.50, 1.52, 1.54 or 1.57 — a practice value, not a code requirement',
    'ACI 211.1-91 (reapproved 2009) Standard Practice for Selecting Proportions for Normal, Heavyweight and Mass Concrete',
    'ACI 318-19 Table 19.3.2.1 (maximum w/cm by exposure class)',
  ],
  assumptions: [
    'Volume batching of loose, dry materials; cement bulk density 1440 kg/m³.',
    'The dry-volume factor already includes voids and sand bulking; wastage is added on top.',
    'Steel volume in the member is not deducted (≈1–2 % for RCC).',
  ],
  cases: [
    const ToolCase(
      '1 m³ of 1:1.5:3, no wastage',
      source:
          'Published site example: 1.54/5.5 × 1440 = 403.2 kg = 8.064 bags; sand 0.42 m³, aggregate 0.84 m³ ; bag = 50/1440 m³ = 1.2262 cft (Python hand calc)',
      numbers: {'V': (1, 'm3'), 'waste': (0, '%'), 'wc': (0.5, '-')},
      expect: {
        'cement': (403.2, 'kg'),
        'bags': (8.064, '-'),
        'order': (9, '-'),
        'sand': (0.42, 'm3'),
        'sandcft': (14.8322, 'ft3'),
        'agg': (0.84, 'm3'),
        'aggcft': (29.6643, 'ft3'),
        'water': (201.6, 'L'),
        'cft_bag': (1.226204, '-'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      'Slab 6 × 4 × 0.15 m, 1:2:4, 5 % wastage, w/c 0.55',
      source:
          'Python hand calc: V 3.6 m³, dry 5.8212 m³, cement 1197.50 kg = 23.950 bags, sand 1.6632 m³ (58.735 cft), aggregate 3.3264 m³',
      choices: {'shape': 'rect', 'mix': 'm15'},
      numbers: {
        'L': (6, 'm'),
        'B': (4, 'm'),
        'D': (150, 'mm'),
        'waste': (5, '%'),
        'wc': (0.55, '-'),
      },
      expect: {
        'wet': (3.6, 'm3'),
        'dry': (5.8212, 'm3'),
        'bags': (23.95008, '-'),
        'sand': (1.6632, 'm3'),
        'sandcft': (58.7354, 'ft3'),
        'agg': (3.3264, 'm3'),
        'water': (658.627, 'L'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      '8 circular columns Ø450 × 3.5 m, 1:1.5:3, 2 % wastage',
      source:
          'Python hand calc: V = 8·π/4·0.45²·3.5 = 4.45321 m³, 36.629 bags, sand 67.372 cft, aggregate 134.743 cft',
      choices: {'shape': 'circ'},
      numbers: {
        'dia': (450, 'mm'),
        'H': (3.5, 'm'),
        'count': (8, '-'),
        'waste': (2, '%'),
        'wc': (0.45, '-'),
      },
      expect: {
        'wet': (4.453208, 'm3'),
        'bags': (36.62888, '-'),
        'sandcft': (67.3717, 'ft3'),
        'aggcft': (134.7434, 'ft3'),
        'water': (824.150, 'L'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      '100 cft of 1:1:2 (custom), factor 1.57',
      source:
          'Python hand calc: dry 157 cft → sand 39.25 cft, aggregate 78.5 cft, cement 1600.47 kg = 32.009 bags',
      choices: {'mix': 'custom'},
      numbers: {
        'V': (100, 'ft3'),
        'rc': (1, '-'),
        'rs': (1, '-'),
        'ra': (2, '-'),
        'f': (1.57, '-'),
        'waste': (0, '%'),
      },
      expect: {
        'sandcft': (39.25, 'ft3'),
        'aggcft': (78.5, 'ft3'),
        'bags': (32.00936, '-'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      '1 m³ of 1:3:6 lean concrete',
      source:
          'Python hand calc: 1.54/10 × 1440 = 221.76 kg = 4.435 bags; sand 0.462 m³, aggregate 0.924 m³',
      choices: {'mix': 'm10'},
      numbers: {'V': (1, 'm3'), 'waste': (0, '%')},
      expect: {
        'bags': (4.4352, '-'),
        'sand': (0.462, 'm3'),
        'agg': (0.924, 'm3'),
      },
      relTol: 2e-5,
    ),
  ],
);
