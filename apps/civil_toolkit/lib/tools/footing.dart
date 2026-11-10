import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Soil pressure under a rigid rectangular pad: B is the side in the
/// moment direction, L the other side. Returns (e, qmax, qmin, contact).
(double, double, double, double) padPressure(
  double n,
  double m,
  double b,
  double l,
) {
  final e = m / n;
  if (e >= b / 2) return (e, double.infinity, 0, 0);
  if (e <= b / 6) {
    final q = n / (b * l);
    return (e, q * (1 + 6 * e / b), q * (1 - 6 * e / b), b);
  }
  // No tension: triangular pressure over contact length 3(B/2 − e).
  return (e, 2 * n / (3 * l * (b / 2 - e)), 0, 3 * (b / 2 - e));
}

final footingTool = ToolDef(
  id: 'footing',
  title: 'Footing / pad sizing',
  summary:
      'Plan size of a square or rectangular pad from the allowable bearing '
      'pressure, including its own and soil weight, with moment and no-tension check.',
  icon: Icons.crop_square,
  keywords: [
    'footing',
    'pad',
    'foundation',
    'bearing',
    'allowable bearing pressure',
    'eccentricity',
    'kern',
    'b/6',
    'uplift',
    'no tension',
    'isolated',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('square', 'Size square pad'),
        ChoiceOption('fixL', 'Size B for given L'),
        ChoiceOption('check', 'Check B × L'),
      ],
    ),
    const NumberInput(
      'P',
      'Column load P (service)',
      quantity: Quantity.force,
      units: ('kN', 'kip'),
      initial: 1000e3,
      min: 0,
      minInclusive: false,
      help:
          'Unfactored dead + live (ACI 318-19 13.3.1.1: area from service loads).',
    ),
    const NumberInput(
      'M',
      'Moment M (service)',
      quantity: Quantity.torque,
      units: ('kN.m', 'kip.ft'),
      initial: 0,
      min: 0,
      help:
          'About one axis, acting along side B. Enter 0 for a concentric load.',
    ),
    const NumberInput(
      'qa',
      'Allowable bearing q_a (gross)',
      quantity: Quantity.stress,
      units: ('kPa', 'psf'),
      initial: 200e3,
      min: 0,
      minInclusive: false,
      help: 'Gross allowable pressure at founding level, from the soil report.',
    ),
    const NumberInput(
      'Df',
      'Depth to underside Df',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.5,
      min: 0,
    ),
    const NumberInput(
      'h',
      'Footing thickness h',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.6,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'gc',
      'Concrete unit weight γc',
      quantity: Quantity.dimensionless,
      unitSuffix: 'kN/m³',
      initial: 24,
      min: 0,
      help: 'RCC 24–25 kN/m³ (150 pcf = 23.6 kN/m³).',
    ),
    const NumberInput(
      'gs',
      'Backfill unit weight γs',
      quantity: Quantity.dimensionless,
      unitSuffix: 'kN/m³',
      initial: 18,
      min: 0,
      help: 'Compacted fill typically 16–20 kN/m³ (100–125 pcf).',
    ),
    const NumberInput(
      'qs',
      'Surcharge on top (floor etc.)',
      quantity: Quantity.stress,
      units: ('kPa', 'psf'),
      initial: 0,
      min: 0,
    ),
    NumberInput(
      'L',
      'Side L (across moment)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 2,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') != 'square',
    ),
    NumberInput(
      'B',
      'Side B (moment direction)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 2.5,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'check',
    ),
    NumberInput(
      'step',
      'Round size up to',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.05,
      min: 0,
      help: '0 = no rounding.',
      visibleWhen: (v) => v.c('mode') != 'check',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final P = v.n('P') / 1000, M = v.n('M') / 1000; // kN, kN·m
    final qa = v.n('qa') / 1000, qs = v.n('qs') / 1000; // kPa
    final depth = v.n('Df'), h = v.n('h');
    if (h > depth) {
      throw ToolInputError('Footing thickness cannot exceed the depth Df.');
    }
    final w0 = v.n('gc') * h + v.n('gs') * (depth - h) + qs; // kPa over the pad
    final qe = qa - w0;
    if (qe <= 0) {
      throw ToolInputError(
        'Footing + soil weight (${formatNumber(w0, sig: 4)} kPa) uses up all of q_a.',
      );
    }
    double qmaxFor(double b, double l) =>
        padPressure(P + w0 * b * l, M, b, l).$2;

    double B, L;
    if (mode == 'check') {
      B = v.n('B');
      L = v.n('L');
    } else {
      final fixedL = mode == 'fixL' ? v.n('L') : null;
      double q(double b) => qmaxFor(b, fixedL ?? b);
      var lo = 1e-4, hi = math.max(1.0, fixedL ?? 1.0);
      while (q(hi) > qa) {
        hi *= 2;
        if (hi > 1e4) throw ToolInputError('No practical size found.');
      }
      for (var i = 0; i < 200; i++) {
        final mid = (lo + hi) / 2;
        if (q(mid) > qa) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      B = hi;
      final step = v.n('step');
      if (step > 0) B = (B / step - 1e-9).ceilToDouble() * step;
      L = fixedL ?? B;
    }
    final A = B * L;
    final N = P + w0 * A;
    final (e, qmax, qmin, contact) = padPressure(N, M, B, L);
    if (qmax.isInfinite) {
      throw ToolInputError(
        'e = M/N ≥ B/2: the pad would overturn. Increase B or the vertical load.',
      );
    }
    final util = qmax / qa;
    final w = <String>[];
    final partial = e > B / 6 * (1 + 1e-12);
    if (partial) {
      w.add(
        'e > B/6: part of the base lifts off (no tension). Contact length '
        '${formatNumber(contact, sig: 3)} m of ${formatNumber(B, sig: 3)} m. '
        'Usually acceptable only for wind/seismic cases; check overturning and sliding.',
      );
    }
    final over = util > 1 + 1e-9;
    if (over) w.add('q_max exceeds the allowable bearing pressure.');
    if (mode == 'fixL' && B < L) {
      w.add(
        'B came out smaller than L: consider a square pad or swap the sides.',
      );
    }
    final status = over
        ? 'Overstressed (q_max > q_a)'
        : partial
        ? 'OK, partial contact'
        : 'OK, full contact';
    return ToolResult(
      [
        ToolOutput(
          'B',
          'Side B (moment dir.)',
          B,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'L',
          'Side L',
          L,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'A',
          'Plan area',
          A,
          quantity: Quantity.area,
          units: ('m2', 'ft2'),
        ),
        ToolOutput(
          'w0',
          'Pad + soil + surcharge',
          w0 * 1000,
          quantity: Quantity.stress,
          units: ('kPa', 'psf'),
        ),
        ToolOutput(
          'qe',
          'Available for P: q_a − w',
          qe * 1000,
          quantity: Quantity.stress,
          units: ('kPa', 'psf'),
        ),
        ToolOutput(
          'N',
          'Total vertical N',
          N * 1000,
          quantity: Quantity.force,
          units: ('kN', 'kip'),
        ),
        ToolOutput(
          'e',
          'Eccentricity e = M/N',
          e,
          quantity: Quantity.length,
          units: ('mm', 'in'),
        ),
        ToolOutput(
          'kern',
          'Kern limit B/6',
          B / 6,
          quantity: Quantity.length,
          units: ('mm', 'in'),
        ),
        ToolOutput(
          'qmax',
          'q_max',
          qmax * 1000,
          quantity: Quantity.stress,
          units: ('kPa', 'psf'),
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'qmin',
          'q_min',
          qmin * 1000,
          quantity: Quantity.stress,
          units: ('kPa', 'psf'),
        ),
        ToolOutput(
          'contact',
          'Contact length',
          contact,
          quantity: Quantity.length,
          units: ('m', 'ft'),
        ),
        ToolOutput(
          'util',
          'q_max / q_a',
          util,
          quantity: Quantity.percent,
          sig: 4,
        ),
        ToolOutput.text(
          'status',
          'Bearing check',
          status,
          level: over
              ? OutputLevel.fail
              : partial
              ? OutputLevel.warn
              : OutputLevel.ok,
        ),
      ],
      warnings: w,
      notes: [
        'Sizing only. Design thickness (one-way and punching shear) and steel with '
            'factored loads per ACI 318-19 Ch. 13 and 22.',
        'Column area is not deducted from the soil weight (slightly conservative).',
      ],
    );
  },
  formula: '''B = side in the moment direction, L = other side
w = γc·h + γs·(Df − h) + surcharge     (pad + soil above)

Concentric (M = 0):
  A_req = P / (q_a − w)     (= (P + W)/q_a with W = w·A)

With moment, N = P + w·A,  e = M / N:
  e ≤ B/6 (full contact):
    q_max,min = N/A · (1 ± 6e/B)
  B/6 < e < B/2 (no tension, triangular):
    q_max = 2N / (3·L·(B/2 − e))
    contact length = 3·(B/2 − e)
  e ≥ B/2: overturns

Sizing: smallest B (square: B = L) with q_max ≤ q_a,
then rounded up to the step.''',
  references: [
    'ACI 318-19 §13.3.1.1 (base area from unfactored forces and permissible soil pressure)',
    'B. M. Das, Principles of Foundation Engineering, 9th ed., §6.3–6.4 (eccentrically loaded foundations, one-way eccentricity)',
    'J. Wight & J. MacGregor, Reinforced Concrete: Mechanics and Design, 7th ed., §15.2 (soil pressure, gross vs net allowable)',
    'Building Code of Pakistan, Seismic Provisions (BCP SP-2007): concrete design by reference to ACI 318',
  ],
  assumptions: [
    'Rigid footing with linear soil pressure; soil takes no tension.',
    'Moment about one axis only (no biaxial eccentricity).',
    'q_a is the GROSS allowable pressure; for a NET value from the soil report, add γ·Df first or consult the geotechnical engineer.',
  ],
  cases: [
    const ToolCase(
      'Square pad, P 1000 kN, q_a 200 kPa, Df 1.5 m, h 0.6 m',
      source:
          'Python hand calc: w = 24·0.6 + 18·0.9 = 30.6 kPa; A = 1000/169.4 = 5.90319 m²; B = 2.42965 m',
      numbers: {
        'P': (1000, 'kN'),
        'qa': (200, 'kPa'),
        'Df': (1.5, 'm'),
        'h': (0.6, 'm'),
        'step': (0, 'mm'),
      },
      expect: {
        'w0': (30.6, 'kPa'),
        'A': (5.903188, 'm2'),
        'B': (2.429648, 'm'),
        'qmax': (200, 'kPa'),
      },
      expectText: {'status': 'full contact'},
      relTol: 1e-5,
    ),
    const ToolCase(
      'Same, rounded up to 50 mm',
      source:
          'Python hand calc: B = L = 2.45 m; q = 1000/6.0025 + 30.6 = 197.197 kPa',
      numbers: {
        'P': (1000, 'kN'),
        'qa': (200, 'kPa'),
        'Df': (1.5, 'm'),
        'h': (0.6, 'm'),
        'step': (50, 'mm'),
      },
      expect: {'B': (2.45, 'm'), 'qmax': (197.19725, 'kPa')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Check 2.5 × 2.0 m, P 600 kN, M 150 kN·m (inside kern)',
      source:
          'Python hand calc: w 24.6 kPa, N 723 kN, e 0.20747 m < B/6 0.41667; q = 144.6·(1 ± 0.49793) = 216.60 / 72.60 kPa',
      choices: {'mode': 'check'},
      numbers: {
        'P': (600, 'kN'),
        'M': (150, 'kN.m'),
        'qa': (250, 'kPa'),
        'Df': (1.2, 'm'),
        'h': (0.5, 'm'),
        'B': (2.5, 'm'),
        'L': (2.0, 'm'),
      },
      expect: {
        'N': (723, 'kN'),
        'e': (207.469, 'mm'),
        'qmax': (216.6, 'kPa'),
        'qmin': (72.6, 'kPa'),
      },
      expectText: {'status': 'full contact'},
      relTol: 1e-5,
    ),
    const ToolCase(
      'Check 2 × 2 m, P 300 kN, M 150 kN·m (e > B/6)',
      source:
          'Python hand calc: N 384 kN, e 0.390625 > 0.3333; q_max = 2N/(3L(B/2 − e)) = 210.051 kPa; contact 1.82813 m',
      choices: {'mode': 'check'},
      numbers: {
        'P': (300, 'kN'),
        'M': (150, 'kN.m'),
        'qa': (250, 'kPa'),
        'Df': (1.0, 'm'),
        'h': (0.5, 'm'),
        'B': (2, 'm'),
        'L': (2, 'm'),
      },
      expect: {
        'e': (390.625, 'mm'),
        'qmax': (210.05128, 'kPa'),
        'qmin': (0, 'kPa'),
        'contact': (1.828125, 'm'),
      },
      expectText: {'status': 'partial contact'},
      expectWarning: 'e > B/6',
      relTol: 1e-5,
    ),
    const ToolCase(
      'Size B for L = 2 m, P 800 kN, M 200 kN·m',
      source:
          'Python closed form q_e·L·B² − P·B − 6M = 0 → B = 3.40231 m, e 0.19837 m < B/6, q_min 96.335 kPa',
      choices: {'mode': 'fixL'},
      numbers: {
        'P': (800, 'kN'),
        'M': (200, 'kN.m'),
        'qa': (200, 'kPa'),
        'Df': (1.5, 'm'),
        'h': (0.6, 'm'),
        'L': (2, 'm'),
        'step': (0, 'mm'),
      },
      expect: {
        'B': (3.402308, 'm'),
        'e': (198.369, 'mm'),
        'qmax': (200, 'kPa'),
        'qmin': (96.33453, 'kPa'),
      },
      relTol: 1e-5,
    ),
    const ToolCase(
      'Square pad with 5 kPa floor surcharge',
      source: 'Python hand calc: w = 35.6 kPa; A = 1000/164.4; B = 2.46632 m',
      numbers: {
        'P': (1000, 'kN'),
        'qa': (200, 'kPa'),
        'Df': (1.5, 'm'),
        'h': (0.6, 'm'),
        'qs': (5, 'kPa'),
        'step': (0, 'mm'),
      },
      expect: {'B': (2.466318, 'm'), 'qe': (164.4, 'kPa')},
      relTol: 1e-5,
    ),
  ],
);
