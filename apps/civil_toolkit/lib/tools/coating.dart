import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// m²/L → ft²/US gal.
const double _m2PerLToFt2PerGal = 3.785411784 / (0.3048 * 0.3048);

final coatingTool = ToolDef(
  id: 'coating',
  title: 'Paint & coating quantity',
  summary:
      'Surface area of steel, pipe or a tank, then theoretical and practical '
      'spreading rate, litres per coat and packs from volume solids and DFT.',
  icon: Icons.format_paint,
  keywords: [
    'paint',
    'coating',
    'dft',
    'wft',
    'volume solids',
    'spreading rate',
    'coverage',
    'loss factor',
    'iso 12944',
    'sspc',
    'tank',
    'pipe',
    'epoxy',
    'primer',
  ],
  inputs: [
    const ChoiceInput(
      'surf',
      'Surface',
      options: [
        ChoiceOption('area', 'Enter area'),
        ChoiceOption('pipe', 'Pipe OD × length'),
        ChoiceOption('tank', 'Tank shell + roof'),
      ],
    ),
    NumberInput(
      'A',
      'Area to coat',
      quantity: Quantity.area,
      units: ('m2', 'ft2'),
      initial: 1000,
      min: 0,
      minInclusive: false,
      help:
          'Steelwork: use the section tables (surface area per metre) or m²/t.',
      visibleWhen: (v) => v.c('surf') == 'area',
    ),
    NumberInput(
      'od',
      'Pipe outside diameter',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.2191,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('surf') == 'pipe',
    ),
    NumberInput(
      'len',
      'Pipe length',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 120,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('surf') == 'pipe',
    ),
    NumberInput(
      'D',
      'Tank diameter',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 20,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('surf') == 'tank',
    ),
    NumberInput(
      'H',
      'Shell height',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 12,
      min: 0,
      visibleWhen: (v) => v.c('surf') == 'tank',
    ),
    ChoiceInput(
      'roof',
      'Roof',
      initial: 'cone',
      options: const [
        ChoiceOption('none', 'Shell only'),
        ChoiceOption('flat', 'Flat roof'),
        ChoiceOption('cone', 'Cone roof'),
      ],
      visibleWhen: (v) => v.c('surf') == 'tank',
    ),
    NumberInput(
      'slope',
      'Cone roof slope (rise/run)',
      quantity: Quantity.dimensionless,
      initial: 0.0625,
      min: 0,
      max: 2,
      help:
          '1:16 = 0.0625 (API 650 minimum for supported cone roofs); 1:5 = 0.2.',
      visibleWhen: (v) => v.c('surf') == 'tank' && v.c('roof') == 'cone',
    ),
    const NumberInput(
      'vs',
      'Volume solids',
      quantity: Quantity.percent,
      initial: 0.60,
      min: 0.05,
      max: 1,
      help: 'From the product data sheet (ISO 3233-1 / ASTM D2697).',
    ),
    const NumberInput(
      'dft',
      'DFT per coat',
      quantity: Quantity.length,
      units: ('um', 'mil'),
      initial: 100e-6,
      min: 0,
      minInclusive: false,
      help: 'Nominal dry film thickness per the ISO 12944-5 system / spec.',
    ),
    const NumberInput(
      'coats',
      'Number of coats',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 1,
      max: 10,
      help: 'Same product and DFT each coat; run once per product in a system.',
    ),
    const NumberInput(
      'loss',
      'Loss (overspray, profile)',
      quantity: Quantity.percent,
      initial: 0.30,
      min: 0,
      max: 0.9,
      help:
          'Fraction of paint not ending up as film. Typical: brush/roller 5–15 %, '
          'airless spray on plate 20–30 %, on structural steel 30–50 %, outdoors windy 40–60 %.',
    ),
    const NumberInput(
      'pack',
      'Pack (kit) size',
      quantity: Quantity.volume,
      units: ('L', 'gal'),
      initial: 20e-3,
      min: 0,
      minInclusive: false,
    ),
  ],
  compute: (v) {
    final surf = v.c('surf');
    double area;
    switch (surf) {
      case 'pipe':
        area = math.pi * v.n('od') * v.n('len');
      case 'tank':
        final d = v.n('D'), r = d / 2;
        final roof = switch (v.c('roof')) {
          'flat' => math.pi * r * r,
          'cone' =>
            math.pi * r * math.sqrt(r * r + math.pow(r * v.n('slope'), 2)),
          _ => 0.0,
        };
        area = math.pi * d * v.n('H') + roof;
        if (area <= 0) throw ToolInputError('Enter a shell height or a roof.');
      default:
        area = v.n('A');
    }
    final coats = v.n('coats');
    if (coats != coats.roundToDouble()) {
      throw ToolInputError('Number of coats must be a whole number.');
    }
    final vs = v.n('vs'), dftUm = v.n('dft') * 1e6, loss = v.n('loss');
    final tsr = vs * 100 * 10 / dftUm; // m²/L
    final psr = tsr * (1 - loss);
    final perCoat = area / psr; // L
    final total = perCoat * coats;
    final packL = v.n('pack') * 1000;
    final packs = (total / packL - 1e-9).ceilToDouble();
    final w = <String>[];
    if (dftUm > 500) {
      w.add(
        'DFT over 500 µm per coat: check the data sheet maximum (sagging, solvent entrapment).',
      );
    }
    if (loss < 0.05) {
      w.add('Loss below 5 % is unrealistic for field application.');
    }
    return ToolResult(
      [
        ToolOutput(
          'area',
          'Area per coat',
          area,
          quantity: Quantity.area,
          units: ('m2', 'ft2'),
        ),
        ToolOutput('tsr', 'Theoretical (m²/L)', tsr, sig: 4),
        ToolOutput(
          'tsrft',
          'Theoretical (ft²/gal)',
          tsr * _m2PerLToFt2PerGal,
          sig: 4,
        ),
        ToolOutput('psr', 'Practical (m²/L)', psr, sig: 4),
        ToolOutput(
          'wft',
          'Wet film WFT',
          dftUm / (vs * 100) * 100 * 1e-6,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          sig: 4,
        ),
        ToolOutput(
          'percoat',
          'Paint per coat',
          perCoat / 1000,
          quantity: Quantity.volume,
          units: ('L', 'gal'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'total',
          'Total paint',
          total / 1000,
          quantity: Quantity.volume,
          units: ('L', 'gal'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'theo',
          'Total, no losses',
          area * coats / tsr / 1000,
          quantity: Quantity.volume,
          units: ('L', 'gal'),
          sig: 5,
        ),
        ToolOutput('packs', 'Packs to order', packs, sig: 6),
      ],
      warnings: w,
      notes: [
        'Thinner is extra: volume solids refers to the unthinned product, so thinning '
            'raises the WFT needed but not the litres of paint.',
        'Order to the data-sheet practical rate when the maker gives one; '
            'add touch-up and stripe coats separately.',
      ],
    );
  },
  formula: '''Area:
  Pipe:  A = π · OD · length
  Tank:  shell π·D·H
         flat roof π·r²
         cone roof π·r·√(r² + (r·slope)²)

Theoretical spreading rate (data-sheet basis):
  TSR [m²/L] = VS[%] × 10 / DFT[µm]
  TSR [ft²/US gal] = 1604 × VS[fraction] / DFT[mil]
Wet film:  WFT = DFT × 100 / VS[%]

Practical rate (loss = fraction of paint lost):
  PSR = TSR × (1 − loss)
Paint per coat = A / PSR
Total = per coat × coats;  packs = ⌈total / pack⌉''',
  references: [
    'ISO 12944-5:2019 Paints and varnishes — Corrosion protection of steel structures by protective paint systems — Part 5: Protective paint systems (nominal DFT per system)',
    'ISO 3233-1:2019 Determination of the percentage volume of non-volatile matter (volume solids)',
    'SSPC-PA 2 (2022) Procedure for determining conformance to dry coating thickness requirements',
    'Hempel / Jotun / International Paint product data sheets: theoretical spreading rate = VS × 10 / DFT; practical = theoretical × (1 − loss)',
    'API 650 §5.10.4 (supported cone roofs: slope ≥ 1:16)',
  ],
  assumptions: [
    'One product per run, the same DFT for each coat.',
    'Loss covers overspray, surface profile ("dead volume"), geometry and residue in containers.',
    'Tank: external shell and roof only; bottom and internal lining calculated separately.',
  ],
  cases: [
    const ToolCase(
      'Data-sheet example: VS 50 %, DFT 100 µm, 1000 m², 30 % loss',
      source:
          'Data-sheet rule: TSR = 50×10/100 = 5.0 m²/L, PSR = 3.5 m²/L → 285.71 L; WFT = 200 µm (Python hand calc)',
      numbers: {
        'A': (1000, 'm2'),
        'vs': (50, '%'),
        'dft': (100, 'um'),
        'coats': (1, '-'),
        'loss': (30, '%'),
      },
      expect: {
        'tsr': (5.0, '-'),
        'psr': (3.5, '-'),
        'wft': (200, 'um'),
        'total': (285.7143, 'L'),
        'theo': (200, 'L'),
        'packs': (15, '-'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      '8″ pipe (219.1 mm) × 120 m, VS 65 %, 2 × 125 µm, 40 % loss',
      source:
          'Python hand calc: A = π·0.2191·120 = 82.599 m²; TSR 5.2, PSR 3.12 m²/L; 26.474 L/coat, 52.948 L total',
      choices: {'surf': 'pipe'},
      numbers: {
        'od': (219.1, 'mm'),
        'len': (120, 'm'),
        'vs': (65, '%'),
        'dft': (125, 'um'),
        'coats': (2, '-'),
        'loss': (40, '%'),
      },
      expect: {
        'area': (82.5988, 'm2'),
        'psr': (3.12, '-'),
        'percoat': (26.4740, 'L'),
        'total': (52.9479, 'L'),
        'packs': (3, '-'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      'Tank Ø20 × 12 m with 1:16 cone roof, VS 80 %, 250 µm, 25 % loss',
      source:
          'Python hand calc: shell 753.982 + roof 314.772 = 1068.754 m²; TSR 3.2, PSR 2.4 m²/L → 445.31 L, 23 × 20 L',
      choices: {'surf': 'tank', 'roof': 'cone'},
      numbers: {
        'D': (20, 'm'),
        'H': (12, 'm'),
        'slope': (0.0625, '-'),
        'vs': (80, '%'),
        'dft': (250, 'um'),
        'coats': (1, '-'),
        'loss': (25, '%'),
      },
      expect: {
        'area': (1068.7545, 'm2'),
        'tsr': (3.2, '-'),
        'total': (445.3144, 'L'),
        'wft': (312.5, 'um'),
        'packs': (23, '-'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      'Imperial check: 100 % solids at 1 mil',
      source:
          'Industry constant: 1 US gal at 1 mil covers 1604 ft² (231 in³ / 0.001 in ÷ 144)',
      numbers: {
        'A': (1000, 'ft2'),
        'vs': (100, '%'),
        'dft': (1, 'mil'),
        'coats': (1, '-'),
        'loss': (0, '%'),
      },
      expect: {'tsrft': (1604.17, '-'), 'total': (0.623377, 'gal')},
      relTol: 2e-5,
      expectWarning: 'unrealistic',
    ),
  ],
);
