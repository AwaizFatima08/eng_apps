import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Rebar nominal diameters in metres. ASTM A615/A706 inch-pound bar
/// numbers are #n = n/8 in. up to #8; #9–#11 per ASTM Table 1.
const Map<String, double> rebarDia = {
  '#3': 0.375 * 0.0254,
  '#4': 0.500 * 0.0254,
  '#5': 0.625 * 0.0254,
  '#6': 0.750 * 0.0254,
  '#7': 0.875 * 0.0254,
  '#8': 1.000 * 0.0254,
  '#9': 1.128 * 0.0254,
  '#10': 1.270 * 0.0254,
  '#11': 1.410 * 0.0254,
  '10': 0.010,
  '12': 0.012,
  '16': 0.016,
  '20': 0.020,
  '25': 0.025,
  '32': 0.032,
};

final steelWeightTool = ToolDef(
  id: 'steel_weight',
  title: 'Steel section weight',
  summary:
      'Mass per metre and total weight of rebar, round or square bar, plate, '
      'pipe (OD × wall) and angles, for a given length and count.',
  icon: Icons.view_column,
  keywords: [
    'steel',
    'weight',
    'mass',
    'rebar',
    'sarya',
    'bar',
    'd²/162',
    'plate',
    'pipe',
    'b36.10',
    'angle',
    'kg/m',
    'tonnage',
  ],
  inputs: [
    const ChoiceInput(
      'shape',
      'Section',
      options: [
        ChoiceOption('rebar', 'Rebar'),
        ChoiceOption('round', 'Round bar'),
        ChoiceOption('square', 'Square bar'),
        ChoiceOption('plate', 'Plate / flat'),
        ChoiceOption('pipe', 'Pipe (OD × wall)'),
        ChoiceOption('angle', 'Angle'),
      ],
    ),
    ChoiceInput(
      'bar',
      'Bar size',
      initial: '12',
      options: const [
        ChoiceOption('#3', '#3 (3/8″, 9.5 mm)'),
        ChoiceOption('#4', '#4 (1/2″, 12.7 mm)'),
        ChoiceOption('#5', '#5 (5/8″, 15.9 mm)'),
        ChoiceOption('#6', '#6 (3/4″, 19.1 mm)'),
        ChoiceOption('#7', '#7 (7/8″, 22.2 mm)'),
        ChoiceOption('#8', '#8 (1″, 25.4 mm)'),
        ChoiceOption('#9', '#9 (28.7 mm)'),
        ChoiceOption('#10', '#10 (32.3 mm)'),
        ChoiceOption('#11', '#11 (35.8 mm)'),
        ChoiceOption('10', '10 mm'),
        ChoiceOption('12', '12 mm'),
        ChoiceOption('16', '16 mm'),
        ChoiceOption('20', '20 mm'),
        ChoiceOption('25', '25 mm'),
        ChoiceOption('32', '32 mm'),
        ChoiceOption('other', 'Other diameter'),
      ],
      help:
          '#n = ASTM A615/A706 bar numbers; mm sizes per BS 4449 / ASTM A615M.',
      visibleWhen: (v) => v.c('shape') == 'rebar',
    ),
    NumberInput(
      'd',
      'Diameter d',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.025,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) =>
          v.c('shape') == 'round' ||
          (v.c('shape') == 'rebar' && v.c('bar') == 'other'),
    ),
    NumberInput(
      'a',
      'Side / width / leg A',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.05,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) =>
          const ['square', 'plate', 'angle'].contains(v.c('shape')),
    ),
    NumberInput(
      'b',
      'Leg B',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.05,
      min: 0,
      minInclusive: false,
      help: 'Equal angle: B = A.',
      visibleWhen: (v) => v.c('shape') == 'angle',
    ),
    NumberInput(
      'od',
      'Outside diameter OD',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.1143,
      min: 0,
      minInclusive: false,
      help:
          'NPS 2 = 60.3, 3 = 88.9, 4 = 114.3, 6 = 168.3, 8 = 219.1, 10 = 273.0, 12 = 323.8 mm.',
      visibleWhen: (v) => v.c('shape') == 'pipe',
    ),
    NumberInput(
      't',
      'Thickness t',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.005,
      min: 0,
      minInclusive: false,
      help: 'Plate/angle thickness, or pipe wall (e.g. 4″ Sch 40 = 6.02 mm).',
      visibleWhen: (v) =>
          const ['plate', 'pipe', 'angle'].contains(v.c('shape')),
    ),
    NumberInput(
      'r1',
      'Angle root radius r₁',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.007,
      min: 0,
      help:
          'From the section table (EN 10056-1). 0 = sharp corners (≈1 % light).',
      visibleWhen: (v) => v.c('shape') == 'angle',
    ),
    NumberInput(
      'r2',
      'Angle toe radius r₂',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.0035,
      min: 0,
      help: 'Usually r₁/2 in EN 10056-1.',
      visibleWhen: (v) => v.c('shape') == 'angle',
    ),
    const NumberInput(
      'len',
      'Length of each piece',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 12,
      min: 0,
    ),
    const NumberInput(
      'count',
      'Number of pieces',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
    ),
    const NumberInput(
      'rho',
      'Steel density',
      quantity: Quantity.density,
      initial: 7850,
      min: 1000,
      max: 20000,
      help:
          'Carbon steel 7850 kg/m³ (ASTM 490 lb/ft³ ≈ 7849); stainless 7900–8000.',
    ),
  ],
  compute: (v) {
    final shape = v.c('shape');
    final w = <String>[];
    final notes = <String>[];
    double area;
    switch (shape) {
      case 'rebar':
      case 'round':
        final d = shape == 'rebar' && v.c('bar') != 'other'
            ? rebarDia[v.c('bar')]!
            : v.n('d');
        area = math.pi / 4 * d * d;
        if (shape == 'rebar') {
          final dmm = d * 1000;
          notes.add(
            'Site rule d²/162 = ${formatNumber(dmm * dmm / 162, sig: 4)} kg/m '
            '(d in mm; = π/4·d²·7850 with 7850·π/4 ≈ 1/162.2).',
          );
        }
      case 'square':
        area = v.n('a') * v.n('a');
      case 'plate':
        area = v.n('a') * v.n('t');
      case 'pipe':
        final od = v.n('od'), t = v.n('t');
        if (2 * t >= od) {
          throw ToolInputError('Wall thickness must be less than OD/2.');
        }
        area = math.pi * (od - t) * t;
        notes.add(
          'Plain-end weight, as ASME B36.10M: W = 0.0246615·(D − t)·t kg/m (mm) '
          '= 10.69·(D − t)·t lb/ft (in).',
        );
      default: // angle
        final a = v.n('a'), b = v.n('b'), t = v.n('t');
        final r1 = v.n('r1'), r2 = v.n('r2');
        if (t >= math.min(a, b)) {
          throw ToolInputError('Thickness must be less than both legs.');
        }
        area = t * (a + b - t) + (1 - math.pi / 4) * (r1 * r1 - 2 * r2 * r2);
        if (r2 > t) w.add('Toe radius larger than t: check the radii.');
        if (r1 == 0) {
          notes.add(
            'Sharp corners (r₁ = 0): table mass is usually ≈1 % higher.',
          );
        }
    }
    final rho = v.n('rho');
    final kgm = area * rho;
    final len = v.n('len'), count = v.n('count');
    final totLen = len * count;
    final mass = kgm * totLen;
    return ToolResult(
      [
        ToolOutput(
          'area',
          'Cross-section area',
          area,
          quantity: Quantity.area,
          units: ('mm2', 'in2'),
        ),
        ToolOutput(
          'kgm',
          'Mass per metre',
          kgm,
          quantity: Quantity.linearDensity,
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'totlen',
          'Total length',
          totLen,
          quantity: Quantity.length,
          units: ('m', 'ft'),
        ),
        ToolOutput(
          'mass',
          'Total mass',
          mass,
          quantity: Quantity.mass,
          units: ('kg', 'lb'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'tonnes',
          'Total mass (t)',
          mass,
          quantity: Quantity.mass,
          fixedUnit: 't',
          sig: 4,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''Mass per metre = A × ρ   (ρ = 7850 kg/m³)

Rebar / round bar:  A = π·d²/4
  kg/m = π/4 · d² · 7850 ≈ d²/162   (d in mm)
Square bar:         A = a²
Plate / flat:       A = width × t
Pipe:               A = π·(OD − t)·t
  ASME B36.10M:     W = 0.0246615·(D − t)·t  kg/m (mm)
                    W = 10.69·(D − t)·t     lb/ft (in)
Angle (EN 10056-1 Table 1/2 note):
  A = t·(A + B − t) + (1 − π/4)·(r₁² − 2·r₂²)

Total mass = kg/m × length × count

ASTM bar #n: d = n/8 in (#3–#8); #9 1.128, #10 1.270, #11 1.410 in''',
  references: [
    'ASTM A615/A615M-22 Table 1 (nominal mass and dimensions of deformed bars, #3–#18 / 10–57)',
    'BS 4449:2005+A3:2016 Table 4 (nominal mass per metre: 0.617, 0.888, 1.579, 2.466, 3.854, 6.313 kg/m)',
    'ASME B36.10M-2018 Welded and Seamless Wrought Steel Pipe, Table 1 and weight formula (§4.4)',
    'BS EN 10056-1:2017 Structural steel equal and unequal leg angles — dimensions; British Steel EA data sheet',
  ],
  assumptions: [
    'Nominal dimensions; mill rolling tolerance (ASTM A615 −6 % per bar) not applied.',
    'Pipe weight is plain-end (no threads, couplings or coatings).',
    'Rebar deformations are included in the nominal diameter (mass-equivalent).',
  ],
  cases: [
    const ToolCase(
      'Rebar #8, one metre',
      source: 'ASTM A615 Table 1: #8 = 2.670 lb/ft (3.973 kg/m)',
      choices: {'bar': '#8'},
      numbers: {'len': (1, 'm'), 'count': (1, '-')},
      expect: {'kgm': (2.670, 'lb/ft'), 'mass': (3.973, 'kg')},
      relTol: 2e-3,
    ),
    const ToolCase(
      'Rebar #11 per foot',
      source: 'ASTM A615 Table 1: #11 = 5.313 lb/ft, area 1.56 in²',
      choices: {'bar': '#11'},
      numbers: {'len': (1, 'ft'), 'count': (1, '-')},
      expect: {
        'kgm': (5.313, 'lb/ft'),
        'mass': (5.313, 'lb'),
        'area': (1.56, 'in2'),
      },
      relTol: 2e-3,
    ),
    const ToolCase(
      '100 bars of 12 mm × 12 m',
      source:
          'BS 4449 Table 4: 12 mm = 0.888 kg/m → 1065.6 kg (Python: 0.88781 kg/m, 1065.38 kg)',
      choices: {'bar': '12'},
      numbers: {'len': (12, 'm'), 'count': (100, '-')},
      expect: {
        'kgm': (0.888, 'kg/m'),
        'mass': (1065.6, 'kg'),
        'tonnes': (1.0656, 't'),
      },
      relTol: 1e-3,
    ),
    const ToolCase(
      'Rebar 25 mm',
      source: 'BS 4449 Table 4: 25 mm = 3.854 kg/m',
      choices: {'bar': '25'},
      numbers: {'len': (1, 'm'), 'count': (1, '-')},
      expect: {'kgm': (3.854, 'kg/m')},
      relTol: 5e-4,
    ),
    const ToolCase(
      'Pipe NPS 4 Sch 40 (114.3 × 6.02)',
      source: 'ASME B36.10M Table 1: 16.07 kg/m (10.79 lb/ft)',
      choices: {'shape': 'pipe'},
      numbers: {
        'od': (114.3, 'mm'),
        't': (6.02, 'mm'),
        'len': (6, 'm'),
        'count': (1, '-'),
      },
      expect: {'kgm': (16.07, 'kg/m'), 'mass': (96.42, 'kg')},
      relTol: 1e-3,
    ),
    const ToolCase(
      'Pipe NPS 12 STD (323.8 × 9.53), in lb/ft',
      source: 'ASME B36.10M Table 1: 73.88 kg/m, 49.56 lb/ft',
      choices: {'shape': 'pipe'},
      numbers: {
        'od': (323.8, 'mm'),
        't': (9.53, 'mm'),
        'len': (1, 'm'),
        'count': (1, '-'),
      },
      expect: {'kgm': (49.56, 'lb/ft')},
      relTol: 2e-3,
    ),
    const ToolCase(
      'Equal angle 150 × 150 × 15 (r₁ 16, r₂ 8)',
      source:
          'British Steel EA data sheet (BS EN 10056-1): 33.8 kg/m, area 43.0 cm²',
      choices: {'shape': 'angle'},
      numbers: {
        'a': (150, 'mm'),
        'b': (150, 'mm'),
        't': (15, 'mm'),
        'r1': (16, 'mm'),
        'r2': (8, 'mm'),
        'len': (1, 'm'),
        'count': (1, '-'),
      },
      expect: {'kgm': (33.8, 'kg/m'), 'area': (43.0, 'cm2')},
      relTol: 2e-3,
    ),
    const ToolCase(
      'Equal angle 120 × 120 × 10 (r₁ 13, r₂ 6.5)',
      source:
          'British Steel EA data sheet (BS EN 10056-1): 18.2 kg/m, area 23.2 cm²',
      choices: {'shape': 'angle'},
      numbers: {
        'a': (120, 'mm'),
        'b': (120, 'mm'),
        't': (10, 'mm'),
        'r1': (13, 'mm'),
        'r2': (6.5, 'mm'),
        'len': (1, 'm'),
        'count': (1, '-'),
      },
      expect: {'kgm': (18.2, 'kg/m'), 'area': (23.2, 'cm2')},
      relTol: 2e-3,
    ),
    const ToolCase(
      'Plate 1500 × 10 mm, 4 pieces × 6 m',
      source: 'Hand calc: 1.5 × 0.010 × 7850 = 117.75 kg/m; × 24 m = 2826 kg',
      choices: {'shape': 'plate'},
      numbers: {
        'a': (1500, 'mm'),
        't': (10, 'mm'),
        'len': (6, 'm'),
        'count': (4, '-'),
      },
      expect: {'kgm': (117.75, 'kg/m'), 'mass': (2826, 'kg')},
      relTol: 1e-6,
    ),
  ],
);
