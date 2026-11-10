import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// BS 7430 λ for n rods in a straight line (1998 Table 2 = 2011 Table 4).
const Map<int, double> lambdaLine = {
  2: 1.00, 3: 1.66, 4: 2.15, 5: 2.54, 6: 2.87, 7: 3.15, 8: 3.39, 9: 3.61, //
  10: 3.81,
};

/// BS 7430 λ for a hollow square, n rods per side (total 4(n − 1)).
/// BS 7430:1998 Table 3 values. The 2011 edition prints 5.46 (4), 7.30 (8),
/// 8.22 (12), 8.95 (16): they break the smooth trend and are lower (less
/// conservative), so the 1998 values are kept — FFL validator to confirm.
const List<(double, double)> lambdaSquare = [
  (2, 2.71), (3, 4.51), (4, 5.48), (5, 6.14), (6, 6.63), (7, 7.03), //
  (8, 7.36), (9, 7.65), (10, 7.90), (12, 8.32), (14, 8.67), (16, 8.96),
  (18, 9.22), (20, 9.40),
];

/// IEEE 142 multiplying factor F for n rods, spacing = rod length, in a line,
/// hollow triangle, circle or square: R = R₁ · F / n.
const List<(double, double)> ieeeF = [
  (2, 1.16), (3, 1.29), (4, 1.36), (6, 1.52), (8, 1.68), (12, 1.80), //
  (16, 1.92), (20, 2.00), (24, 2.16),
];

double _interp(List<(double, double)> t, double x) {
  for (var i = 0; i < t.length - 1; i++) {
    final (x0, y0) = t[i];
    final (x1, y1) = t[i + 1];
    if (x <= x1) return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
  }
  return t.last.$2;
}

/// Single vertical rod (BS 7430 §9.5.3; = Dwight / IEEE 142 with a = d/2).
double rodResistance(double rho, double l, double d) =>
    rho / (2 * math.pi * l) * (math.log(8 * l / d) - 1);

/// Resistance of [n] rods in [arr]; returns (R, total rods, α or NaN).
(double, int, double) rodGroup(
  String arr,
  int n,
  double rho,
  double l,
  double d,
  double s,
) {
  final r1 = rodResistance(rho, l, d);
  final alpha = rho / (2 * math.pi * r1 * s);
  switch (arr) {
    case 'line':
      return (r1 * (1 + lambdaLine[n]! * alpha) / n, n, alpha);
    case 'square':
      final total = 4 * (n - 1);
      final lam = _interp(lambdaSquare, n.toDouble());
      return (r1 * (1 + lam * alpha) / total, total, alpha);
    case 'heppe':
      final r =
          rho /
          (2 * math.pi * l) /
          n *
          (math.log(8 * l / d) - 1 + l / s * math.log(1.78 * n / 2.718));
      return (r, n, double.nan);
    case 'ring':
      return (r1 * _interp(ieeeF, n.toDouble()) / n, n, double.nan);
    default:
      return (r1, 1, double.nan);
  }
}

/// Allowed range of the count input per arrangement.
(int, int) rodRange(String arr) => switch (arr) {
  'line' => (2, 10),
  'square' => (2, 20),
  'heppe' => (2, 50),
  'ring' => (2, 24),
  _ => (1, 1),
};

final earthingTool = ToolDef(
  id: 'earthing',
  title: 'Earth rod resistance',
  summary:
      'Resistance of a driven earth rod and of rods in a line, hollow square '
      'or ring (BS 7430 and IEEE 142 factors), compared with a target value.',
  icon: Icons.vertical_align_bottom,
  keywords: [
    'earthing',
    'grounding',
    'earth rod',
    'ground rod',
    'electrode',
    'soil resistivity',
    'bs 7430',
    'ieee 142',
    'ieee 80',
    'earth pit',
  ],
  inputs: [
    const ChoiceInput(
      'arr',
      'Arrangement',
      options: [
        ChoiceOption('single', 'Single rod'),
        ChoiceOption('line', 'Rods in line (BS 7430 λ)'),
        ChoiceOption('heppe', 'Rods in line (Heppe, BS 7430)'),
        ChoiceOption('square', 'Hollow square (BS 7430 λ)'),
        ChoiceOption('ring', 'Line/ring (IEEE 142 F)'),
      ],
    ),
    const NumberInput(
      'rho',
      'Soil resistivity ρ',
      quantity: Quantity.resistivity,
      initial: 100,
      min: 0,
      minInclusive: false,
      help:
          'Measured (Wenner). BS 7430 Table 1 probable values: clay 10, marl '
          '20, chalk 50, sandstone 100, granite 1000 Ω·m.',
    ),
    const NumberInput(
      'l',
      'Rod driven length L',
      quantity: Quantity.length,
      initial: 3,
      min: 0,
      minInclusive: false,
      units: ('m', 'ft'),
    ),
    const NumberInput(
      'd',
      'Rod diameter d',
      quantity: Quantity.length,
      initial: 0.016,
      min: 0,
      minInclusive: false,
      help: '5/8″ copper-bonded = 14.2–16 mm; 3/4″ = 17.2–19 mm.',
    ),
    NumberInput(
      'n',
      'Number of rods',
      quantity: Quantity.dimensionless,
      initial: 4,
      min: 1,
      help:
          'Line (λ): 2–10. Heppe: 2–50. Ring (IEEE): 2–24. Square: rods PER '
          'SIDE, 2–20 (total = 4·(n − 1)).',
      visibleWhen: (v) => v.c('arr') != 'single',
    ),
    NumberInput(
      's',
      'Rod spacing s',
      quantity: Quantity.length,
      initial: 3,
      min: 0,
      minInclusive: false,
      units: ('m', 'ft'),
      help: 'Keep s ≥ L; 2L is better.',
      visibleWhen: (v) => v.c('arr') != 'single',
    ),
    const NumberInput(
      'target',
      'Target resistance',
      quantity: Quantity.resistance,
      initial: 1,
      min: 0,
      minInclusive: false,
      help:
          'Typical: ≤ 1 Ω large/HV substations; 1–5 Ω industrial plant '
          '(IEEE 142 §4.1.3); ≤ 20 Ω generator neutral or LV substation '
          '(BS 7430); 25 Ω single rod (NEC 250.53).',
    ),
  ],
  compute: (v) {
    final arr = v.c('arr');
    final rho = v.n('rho'), l = v.n('l'), d = v.n('d');
    final target = v.n('target');
    if (d >= l) {
      throw ToolInputError('Rod diameter must be far below its length.');
    }
    final multi = arr != 'single';
    final s = multi ? v.n('s') : 1.0;
    final nRaw = multi ? v.n('n') : 1.0;
    if (nRaw != nRaw.roundToDouble()) {
      throw ToolInputError('Number of rods must be a whole number.');
    }
    final n = nRaw.round();
    final (lo, hi) = rodRange(arr);
    if (n < lo || n > hi) {
      throw ToolInputError(
        'This method covers $lo–$hi ${arr == 'square' ? 'rods per side' : 'rods'}.',
      );
    }
    final r1 = rodResistance(rho, l, d);
    final (r, total, alpha) = rodGroup(arr, n, rho, l, d, s);

    // Smallest count in the same arrangement that meets the target.
    int? nNeeded;
    for (var k = lo; k <= hi; k++) {
      if (rodGroup(arr, k, rho, l, d, s).$1 <= target) {
        nNeeded = k;
        break;
      }
    }

    final w = <String>[];
    if (multi && s < l) {
      w.add(
        'Spacing below rod length: rods screen each other and the factors '
        '(valid for s ≥ L) understate R.',
      );
    }
    if (!alpha.isNaN && alpha > 0.2) {
      w.add(
        'α = ρ/(2π·R₁·s) = ${formatNumber(alpha, sig: 3)} > 0.2: outside the '
        'BS 7430 λ method — use wider spacing or the Heppe form.',
      );
    }
    if (l / d < 50) w.add('L/d below 50: the thin-rod formula loses accuracy.');
    final ok = r <= target;
    return ToolResult(
      [
        ToolOutput(
          'r',
          multi ? 'Group resistance' : 'Rod resistance',
          r,
          quantity: Quantity.resistance,
          level: ok ? OutputLevel.ok : OutputLevel.fail,
          sig: 4,
        ),
        ToolOutput.text(
          'verdict',
          'Against target',
          ok
              ? 'Meets the target (${formatNumber(target)} Ω)'
              : 'Above the target (${formatNumber(target)} Ω)',
          level: ok ? OutputLevel.ok : OutputLevel.fail,
        ),
        ToolOutput(
          'r1',
          'One rod alone R₁',
          r1,
          quantity: Quantity.resistance,
          sig: 4,
        ),
        if (multi) ...[
          ToolOutput('total', 'Total rods', total.toDouble(), sig: 3),
          ToolOutput(
            'eff',
            'Group vs ideal parallel',
            r1 / total / r,
            quantity: Quantity.percent,
            sig: 3,
          ),
        ],
        if (!alpha.isNaN) ToolOutput('alpha', 'α = ρ/(2πR₁s)', alpha, sig: 4),
        if (multi)
          ToolOutput.text(
            'needed',
            'Count for target',
            nNeeded == null
                ? 'Not reached within $hi — add rods elsewhere, lengthen '
                      'rods, or add a buried grid/tape'
                : arr == 'square'
                ? '$nNeeded per side (${4 * (nNeeded - 1)} rods)'
                : '$nNeeded rods',
          ),
      ],
      warnings: w,
      notes: [
        'Uniform soil assumed. Measure ρ (Wenner) at the site and in the dry '
            'season; verify the installed earth with a fall-of-potential test.',
        'Rods in line: λ method and Heppe can differ by 10–15 % (BS 7430 gives '
            'both); the larger value is the safer one.',
      ],
    );
  },
  formula: '''Single rod (BS 7430 §9.5.3; IEEE 142 Dwight form):
  R₁ = ρ / (2πL) · [ ln(8L/d) − 1 ]
  (IEEE 142 writes ln(4L/a) − 1 with a = d/2: identical)

Group, BS 7430 λ method (s ≥ L, α < ~0.2):
  α = ρ / (2π · R₁ · s)
  R = R₁ · (1 + λ·α) / N
  λ: rods in line (n = 2–10) or hollow square (n per side,
  N = 4(n − 1)); BS 7430 tables

Rods in line, Heppe (BS 7430 §9.5.4):
  R = ρ/(2πL·n) · [ ln(8L/d) − 1 + (L/s)·ln(1.78n/2.718) ]

IEEE 142 factor (spacing ≈ rod length):
  R = R₁ · F / n,   F = 1.16 (2) … 2.16 (24)''',
  references: [
    'BS 7430:2011+A1:2015, §9.5.3 (rod), §9.5.4 (aligned rods), §9.5.8, Tables 2 and 4 (λ); Annex B worked examples',
    'BS 7430:1998, §8.2.3, Tables 2 and 3 (λ in line, hollow square)',
    'IEEE Std 142-2007 (Green Book), §4.1.3 (target values), §4.2 (Dwight rod formula; multiple-rod factors)',
    'IEEE Std 80-2013, §14 (rod formulas in Schwarz grid method)',
  ],
  assumptions: [
    'Homogeneous soil; rod top at ground level; resistance of connecting conductors ignored.',
    'Seasonal variation not included: apply a margin for dry-season ρ.',
  ],
  cases: [
    const ToolCase(
      'BS 7430 Annex B: single rod ρ 400 Ω·m, 2.4 m, 16 mm',
      source: 'BS 7430:2011 Annex B worked example: R = 161.54 Ω',
      numbers: {'rho': (400, 'ohm.m'), 'l': (2.4, 'm'), 'd': (16, 'mm')},
      expect: {'r': (161.54, 'ohm')},
      expectText: {'verdict': 'Above'},
    ),
    const ToolCase(
      'BS 7430 Annex B: 4 rods in a square, s = 4 m',
      source:
          'BS 7430:2011 Annex B: λ = 2.71, α = 0.0985, R = 51.169 Ω '
          '(hollow square with 2 rods per side)',
      choices: {'arr': 'square'},
      numbers: {
        'rho': (400, 'ohm.m'),
        'l': (2.4, 'm'),
        'd': (16, 'mm'),
        'n': (2, '-'),
        's': (4, 'm'),
      },
      expect: {'r': (51.169, 'ohm'), 'alpha': (0.0985, '-'), 'total': (4, '-')},
    ),
    const ToolCase(
      'BS 7430 Annex B: 6 aligned rods, s = 3.6 m (Heppe)',
      source: 'BS 7430:2011 Annex B, §9.5.4 formula: R = 30.959 Ω',
      choices: {'arr': 'heppe'},
      numbers: {
        'rho': (400, 'ohm.m'),
        'l': (2.4, 'm'),
        'd': (16, 'mm'),
        'n': (6, '-'),
        's': (3.6, 'm'),
        'target': (20, 'ohm'),
      },
      expect: {'r': (30.959, 'ohm')},
    ),
    const ToolCase(
      '10 rods in line, ρ 180, 1.8 m, 19 mm, s = 1.5 m',
      source:
          'Pangonilo earth-rod worked example (BS 7430 λ = 3.81): R₁ = 89.6 Ω, '
          'α = 0.2132, R = 16.23 Ω',
      choices: {'arr': 'line'},
      numbers: {
        'rho': (180, 'ohm.m'),
        'l': (1.8, 'm'),
        'd': (19, 'mm'),
        'n': (10, '-'),
        's': (1.5, 'm'),
      },
      expect: {'r': (16.23, 'ohm'), 'r1': (89.6, 'ohm')},
      relTol: 2e-3,
      expectWarning: 'α',
    ),
    const ToolCase(
      'IEEE 142: 6 rods 3 m × 16 mm in a ring, ρ 100, s = 3 m',
      source:
          'Hand calc: R₁ = 33.493 Ω (= Dwight ln(4L/a) − 1); IEEE 142 F(6) = '
          '1.52 → R = 33.493 × 1.52/6 = 8.485 Ω; target 10 Ω first met at 5 '
          'rods (F 1.44 interpolated → 9.646 Ω)',
      choices: {'arr': 'ring'},
      numbers: {
        'rho': (100, 'ohm.m'),
        'l': (3, 'm'),
        'd': (16, 'mm'),
        'n': (6, '-'),
        's': (3, 'm'),
        'target': (10, 'ohm'),
      },
      expect: {'r1': (33.4927, 'ohm'), 'r': (8.4848, 'ohm')},
      expectText: {'needed': '5 rods', 'verdict': 'Meets'},
    ),
  ],
);
