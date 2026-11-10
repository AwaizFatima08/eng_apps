import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// ACI 318-19 §19.2.2.1(b): Ec = 4700·√fc' (MPa) for normalweight concrete.
double aciEc(double fcPa) => 4700 * math.sqrt(fcPa / 1e6) * 1e6;

/// Prismatic beam solved by double integration with Macaulay brackets.
/// x runs from the left end; loads act downward; sagging moment positive.
/// Cantilever and propped cantilever are fixed at the LEFT end.
class BeamSolution {
  BeamSolution({
    required this.support,
    required this.span,
    required this.p,
    required this.a,
    required this.w,
    required this.ei,
  }) {
    final L = span, b = L - a;
    switch (support) {
      case 'simple':
        ma = 0;
        ra = p * b / L + w * L / 2;
        c2 = 0;
        // y(L) = 0
        c1 =
            -(ra * L * L * L / 6 -
                w * math.pow(L, 4) / 24 -
                p * b * b * b / 6) /
            (ei * L);
      case 'cant':
        ra = p + w * L;
        ma = -(p * a + w * L * L / 2);
        c1 = 0;
        c2 = 0;
      case 'fixed':
        // y(L) = 0 and θ(L) = 0 with y(0) = θ(0) = 0.
        final (m, r) = _solve2(
          L * L / 2,
          L * L * L / 6,
          w * math.pow(L, 4) / 24 + p * b * b * b / 6,
          L,
          L * L / 2,
          w * L * L * L / 6 + p * b * b / 2,
        );
        ma = m;
        ra = r;
        c1 = 0;
        c2 = 0;
      default: // propped: fixed left, roller right: y(L) = 0 and M(L) = 0.
        final (m, r) = _solve2(
          L * L / 2,
          L * L * L / 6,
          w * math.pow(L, 4) / 24 + p * b * b * b / 6,
          1,
          L,
          w * L * L / 2 + p * b,
        );
        ma = m;
        ra = r;
        c1 = 0;
        c2 = 0;
    }
    rb = p + w * L - ra;
  }

  final String support;
  final double span, p, a, w, ei;
  late final double ra, rb, ma;
  late final double c1, c2;

  /// Fixed-end moment at the right support (sagging positive).
  double get mb => support == 'fixed' ? moment(span) : 0;

  static (double, double) _solve2(
    double a11,
    double a12,
    double b1,
    double a21,
    double a22,
    double b2,
  ) {
    final det = a11 * a22 - a12 * a21;
    return ((b1 * a22 - a12 * b2) / det, (a11 * b2 - a21 * b1) / det);
  }

  double moment(double x) =>
      ma + ra * x - w * x * x / 2 - (x > a ? p * (x - a) : 0);

  /// Shear just to the right of x ([left] = just to the left).
  double shear(double x, {bool left = false}) {
    final pastLoad = left ? x > a : x >= a;
    return ra - w * x - (pastLoad ? p : 0);
  }

  /// Downward deflection (positive down).
  double deflection(double x) {
    final d = x > a ? x - a : 0.0;
    final y =
        (ma * x * x / 2 +
                ra * x * x * x / 6 -
                w * math.pow(x, 4) / 24 -
                p * d * d * d / 6) /
            ei +
        c1 * x +
        c2;
    return -y;
  }
}

/// Location and value of the largest downward deflection.
(double, double) maxDeflection(BeamSolution s) {
  final L = s.span;
  const n = 400;
  var bestX = 0.0, best = s.deflection(0);
  final xs = [for (var i = 0; i <= n; i++) L * i / n, s.a];
  for (final x in xs) {
    final d = s.deflection(x);
    if (d > best) {
      best = d;
      bestX = x;
    }
  }
  // Golden-section refinement in the neighbouring sample interval.
  var lo = math.max(0.0, bestX - L / n), hi = math.min(L, bestX + L / n);
  const g = 0.6180339887498949;
  var x1 = hi - g * (hi - lo), x2 = lo + g * (hi - lo);
  var f1 = s.deflection(x1), f2 = s.deflection(x2);
  for (var i = 0; i < 80; i++) {
    if (f1 < f2) {
      lo = x1;
      x1 = x2;
      f1 = f2;
      x2 = lo + g * (hi - lo);
      f2 = s.deflection(x2);
    } else {
      hi = x2;
      x2 = x1;
      f2 = f1;
      x1 = hi - g * (hi - lo);
      f1 = s.deflection(x1);
    }
  }
  final xr = (lo + hi) / 2, dr = s.deflection(xr);
  return dr > best ? (xr, dr) : (bestX, best);
}

final beamTool = ToolDef(
  id: 'beam',
  title: 'Beam shear, moment & deflection',
  summary:
      'Simply supported, cantilever, fixed-fixed or propped beam with a point '
      'load and/or UDL: reactions, max shear and moment, deflection vs L/n.',
  icon: Icons.horizontal_rule,
  keywords: [
    'beam',
    'bending moment',
    'shear force',
    'deflection',
    'cantilever',
    'fixed',
    'propped',
    'udl',
    'point load',
    'reaction',
    'aisc',
    'roark',
    'l/360',
  ],
  inputs: [
    const ChoiceInput(
      'support',
      'Supports',
      options: [
        ChoiceOption('simple', 'Simply supported'),
        ChoiceOption('cant', 'Cantilever'),
        ChoiceOption('fixed', 'Fixed both ends'),
        ChoiceOption('propped', 'Propped cantilever'),
      ],
      help:
          'Cantilever and propped cantilever are fixed at the LEFT end; the propped end is a roller on the right.',
    ),
    const NumberInput(
      'L',
      'Span L',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 6,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'P',
      'Point load P',
      quantity: Quantity.force,
      units: ('kN', 'kip'),
      initial: 50e3,
      min: 0,
      help: 'Enter 0 for UDL only.',
    ),
    const NumberInput(
      'a',
      'P at distance a from left end',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 2,
      min: 0,
      help: 'Cantilever tip load: a = L.',
    ),
    const NumberInput(
      'w',
      'UDL w over full span',
      quantity: Quantity.lineLoad,
      units: ('kN/m', 'kip/ft'),
      initial: 5e3,
      min: 0,
      help: 'Include the beam self-weight. Enter 0 for point load only.',
    ),
    const ChoiceInput(
      'mat',
      'Modulus E',
      options: [
        ChoiceOption('steel', 'Steel (200 GPa)'),
        ChoiceOption('conc', "Concrete (from fc')"),
        ChoiceOption('custom', 'Enter E'),
      ],
    ),
    NumberInput(
      'fc',
      "Concrete strength fc'",
      quantity: Quantity.stress,
      units: ('MPa', 'psi'),
      initial: 28e6,
      min: 0,
      minInclusive: false,
      help: "Specified cylinder strength. Ec = 4700√fc' (ACI 318-19 19.2.2.1).",
      visibleWhen: (v) => v.c('mat') == 'conc',
    ),
    NumberInput(
      'E',
      'Elastic modulus E',
      quantity: Quantity.stress,
      units: ('GPa', 'ksi'),
      initial: 200e9,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mat') == 'custom',
    ),
    const ChoiceInput(
      'isrc',
      'Second moment I',
      options: [
        ChoiceOption('enter', 'Enter I'),
        ChoiceOption('rect', 'Rectangle b × h'),
      ],
    ),
    NumberInput(
      'I',
      'Second moment of area I',
      quantity: Quantity.secondMoment,
      units: ('cm4', 'in4'),
      initial: 8356e-8,
      min: 0,
      minInclusive: false,
      help: 'About the bending axis, from the section table (e.g. I_x).',
      visibleWhen: (v) => v.c('isrc') == 'enter',
    ),
    NumberInput(
      'b',
      'Width b',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('isrc') == 'rect',
    ),
    NumberInput(
      'h',
      'Depth h',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.5,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('isrc') == 'rect',
    ),
    const NumberInput(
      'n',
      'Deflection limit L/n, n =',
      quantity: Quantity.dimensionless,
      initial: 360,
      min: 1,
      help:
          'ACI 318-19 Table 24.2.2: floors L/360 (live load), roofs L/180, '
          'sensitive finishes L/480, others L/240. Cantilevers use 2L.',
    ),
  ],
  compute: (v) {
    final support = v.c('support');
    final L = v.n('L'), P = v.n('P'), a = v.n('a'), w = v.n('w');
    if (a > L) {
      throw ToolInputError('Load position a must be within the span (≤ L).');
    }
    if (P <= 0 && w <= 0) {
      throw ToolInputError('Enter a point load, a UDL, or both.');
    }
    final mat = v.c('mat');
    final E = switch (mat) {
      'conc' => aciEc(v.n('fc')),
      'custom' => v.n('E'),
      _ => 200e9,
    };
    final I = v.c('isrc') == 'rect'
        ? v.n('b') * math.pow(v.n('h'), 3) / 12
        : v.n('I');
    final s = BeamSolution(
      support: support,
      span: L,
      p: P,
      a: a,
      w: w,
      ei: E * I,
    );

    // Moment extremes: supports, the point load and zero-shear points.
    final cand = <double>[0, L, a];
    if (w > 0) {
      final x1 = s.ra / w; // V = 0 left of the load
      if (x1 > 0 && x1 < a) cand.add(x1);
      final x2 = (s.ra - P) / w; // V = 0 right of the load
      if (x2 > a && x2 < L) cand.add(x2);
    }
    var mPos = 0.0, mNeg = 0.0, mAbs = -1.0, xM = 0.0;
    for (final x in cand..sort()) {
      final m = s.moment(x);
      if (m > mPos) mPos = m;
      if (-m > mNeg) mNeg = -m;
      if (m.abs() > mAbs + 1e-9 * (mAbs.abs() + 1)) {
        mAbs = m.abs();
        xM = x;
      }
    }
    final vMax = [
      s.shear(0),
      s.shear(a, left: true),
      s.shear(a),
      s.shear(L, left: true),
    ].map((e) => e.abs()).reduce(math.max);
    final (xD, dMax) = maxDeflection(s);
    final cant = support == 'cant';
    final lRef = cant ? 2 * L : L;
    final n = v.n('n');
    final allow = lRef / n;
    final ok = dMax <= allow;

    final w0 = <String>[];
    final notes = <String>[
      'Elastic, small-deflection beam theory (Euler-Bernoulli); shear deformation ignored.',
    ];
    if (mat == 'conc') {
      final fcMpa = v.n('fc') / 1e6;
      if (fcMpa < 17) {
        w0.add(
          "fc' < 17 MPa: below the ACI 318 minimum for structural concrete.",
        );
      }
      w0.add(
        'Concrete: gross I gives the uncracked deflection only. Cracked members '
        'deflect more: use I_e (ACI 318-19 24.2.3.5) and the long-term factor λΔ (24.2.4).',
      );
    }
    if (cant) notes.add('Cantilever: limit uses 2L (IBC Table 1604.3 note).');
    if (dMax > L / 100) {
      w0.add(
        'Deflection over L/100: small-deflection theory is becoming inaccurate.',
      );
    }

    final fixedRight = support == 'fixed';
    final fixedLeft = support != 'simple';
    return ToolResult(
      [
        ToolOutput(
          'ra',
          'Left reaction R_A',
          s.ra,
          quantity: Quantity.force,
          units: ('kN', 'kip'),
        ),
        ToolOutput(
          'rb',
          'Right reaction R_B',
          s.rb,
          quantity: Quantity.force,
          units: ('kN', 'kip'),
        ),
        if (fixedLeft)
          ToolOutput(
            'ma',
            'Left end moment M_A',
            s.ma,
            quantity: Quantity.torque,
            units: ('kN.m', 'kip.ft'),
          ),
        if (fixedRight)
          ToolOutput(
            'mb',
            'Right end moment M_B',
            s.mb,
            quantity: Quantity.torque,
            units: ('kN.m', 'kip.ft'),
          ),
        ToolOutput(
          'vmax',
          'Max shear |V|',
          vMax,
          quantity: Quantity.force,
          units: ('kN', 'kip'),
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'mmax',
          'Max moment |M|',
          mAbs,
          quantity: Quantity.torque,
          units: ('kN.m', 'kip.ft'),
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'xm',
          '|M| max at x',
          xM,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 4,
        ),
        ToolOutput(
          'mpos',
          'Max sagging M+',
          mPos,
          quantity: Quantity.torque,
          units: ('kN.m', 'kip.ft'),
        ),
        ToolOutput(
          'mneg',
          'Max hogging M−',
          mNeg,
          quantity: Quantity.torque,
          units: ('kN.m', 'kip.ft'),
        ),
        ToolOutput(
          'dmax',
          'Max deflection δ',
          dMax,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'xd',
          'δ max at x',
          xD,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 4,
        ),
        ToolOutput(
          'allow',
          cant ? 'Limit 2L/n' : 'Limit L/n',
          allow,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 4,
        ),
        ToolOutput('ratio', cant ? '2L/δ' : 'L/δ', lRef / dMax, sig: 4),
        ToolOutput.text(
          'check',
          'Deflection check',
          ok ? 'OK (δ ≤ limit)' : 'Exceeds limit',
          level: ok ? OutputLevel.ok : OutputLevel.fail,
        ),
        ToolOutput(
          'ec',
          'E used',
          E,
          quantity: Quantity.stress,
          units: ('GPa', 'ksi'),
          sig: 4,
        ),
        ToolOutput(
          'ei',
          'I used',
          I,
          quantity: Quantity.secondMoment,
          units: ('cm4', 'in4'),
          sig: 5,
        ),
      ],
      warnings: w0,
      notes: notes,
    );
  },
  formula: '''x from the left end; loads down; sagging M positive.
⟨x−a⟩ = 0 for x < a (Macaulay bracket).

  V(x) = R_A − w·x − P·⟨x−a⟩⁰
  M(x) = M_A + R_A·x − w·x²/2 − P·⟨x−a⟩
  EI·y = M_A·x²/2 + R_A·x³/6 − w·x⁴/24
         − P·⟨x−a⟩³/6 + C₁·x + C₂

Boundary conditions give R_A, M_A, C₁, C₂:
  Simple:     M_A = 0, y(0) = y(L) = 0
  Cantilever: fixed at x = 0 (y = y′ = 0)
  Fixed both: y = y′ = 0 at x = 0 and x = L
  Propped:    fixed at 0, y(L) = 0, M(L) = 0

Max M is at a support, under P, or where V = 0.
Max δ is found by search (golden section).

Checks (AISC Table 3-23):
  Simple UDL:   M = wL²/8,  δ = 5wL⁴/(384EI)
  Simple P mid: M = PL/4,   δ = PL³/(48EI)
  Cantilever:   M = PL + wL²/2 at support
  Fixed UDL:    M = wL²/12 at ends, δ = wL⁴/(384EI)
  Propped UDL:  M = wL²/8 at fixed end, δ ≈ wL⁴/(185EI)

Concrete: Ec = 4700·√fc′ MPa (ACI 318-19 19.2.2.1b)
Rectangle: I = b·h³/12
Deflection limit: δ ≤ L/n (cantilever: 2L/n)''',
  references: [
    'AISC Steel Construction Manual, 15th/16th ed., Table 3-23 "Shears, Moments and Deflections" (cases 1, 7, 8, 12, 14, 15, 18, 19, 21)',
    "Roark's Formulas for Stress and Strain, 8th ed., Table 8.1 (straight beams)",
    'ACI 318-19 §19.2.2.1 (Ec), §24.2.2 Table 24.2.2 (deflection limits), §24.2.3.5 (I_e)',
    'IBC 2021 Table 1604.3 note: cantilever span taken as twice its length for deflection limits',
  ],
  assumptions: [
    'Prismatic, linear-elastic beam; small deflections; shear deformation ignored.',
    'Loads are service (unfactored) loads for the deflection check; use factored loads for strength moments.',
    'One point load plus one full-span UDL; superpose other cases by hand or run twice.',
    'Concrete deflection uses the gross section (uncracked), short-term only.',
  ],
  cases: [
    const ToolCase(
      'Simply supported, UDL 10 kN/m, L = 6 m, steel I = 8356 cm⁴',
      source:
          'AISC Table 3-23 case 1: R = wL/2 = 30 kN, M = wL²/8 = 45 kN·m, δ = 5wL⁴/384EI = 10.0975 mm (Python hand calc)',
      numbers: {
        'L': (6, 'm'),
        'P': (0, 'kN'),
        'a': (0, 'm'),
        'w': (10, 'kN/m'),
        'I': (8356, 'cm4'),
      },
      expect: {
        'ra': (30, 'kN'),
        'vmax': (30, 'kN'),
        'mmax': (45, 'kN.m'),
        'xm': (3, 'm'),
        'dmax': (10.097535, 'mm'),
        'xd': (3, 'm'),
        'allow': (16.6667, 'mm'),
      },
      expectText: {'check': 'OK'},
      relTol: 1e-5,
    ),
    const ToolCase(
      'Simply supported, P 50 kN at 2 m + UDL 5 kN/m, L = 6 m',
      source:
          'AISC cases 8 + 1 superposed, scanned in Python: R_A 48.333, M 86.667 kN·m at 2 m, δ 16.5961 mm at 2.812 m',
      numbers: {
        'L': (6, 'm'),
        'P': (50, 'kN'),
        'a': (2, 'm'),
        'w': (5, 'kN/m'),
        'I': (8356, 'cm4'),
        'n': (360, '-'),
      },
      expect: {
        'ra': (48.333333, 'kN'),
        'rb': (31.666667, 'kN'),
        'mmax': (86.666667, 'kN.m'),
        'xm': (2, 'm'),
        'dmax': (16.596061, 'mm'),
        'xd': (2.81241, 'm'),
      },
      expectText: {'check': 'OK'},
      relTol: 2e-5,
    ),
    const ToolCase(
      'Cantilever 3 m, tip load 20 kN + UDL 4 kN/m, I = 2770 cm⁴',
      source:
          'AISC cases 19 + 21: M = PL + wL²/2 = 78 kN·m, δ = PL³/3EI + wL⁴/8EI = 39.8014 mm; limit 2L/360 = 16.67 mm',
      choices: {'support': 'cant'},
      numbers: {
        'L': (3, 'm'),
        'P': (20, 'kN'),
        'a': (3, 'm'),
        'w': (4, 'kN/m'),
        'I': (2770, 'cm4'),
      },
      expect: {
        'ra': (32, 'kN'),
        'ma': (-78, 'kN.m'),
        'mmax': (78, 'kN.m'),
        'vmax': (32, 'kN'),
        'dmax': (39.801444, 'mm'),
        'xd': (3, 'm'),
        'allow': (16.666667, 'mm'),
      },
      expectText: {'check': 'Exceeds'},
      relTol: 1e-5,
    ),
    const ToolCase(
      'Fixed both ends, 100 kN at 3 m, L = 8 m, I = 20 000 cm⁴',
      source:
          'AISC case 18: M₁ = Pab²/L² = 117.19, M₂ = Pa²b/L² = 70.31, M_load = 87.89 kN·m, δ = 2Pa³b²/3EI(3a+b)² = 5.787 mm',
      choices: {'support': 'fixed'},
      numbers: {
        'L': (8, 'm'),
        'P': (100, 'kN'),
        'a': (3, 'm'),
        'w': (0, 'kN/m'),
        'I': (20000, 'cm4'),
      },
      expect: {
        'ra': (68.359375, 'kN'),
        'rb': (31.640625, 'kN'),
        'ma': (-117.1875, 'kN.m'),
        'mb': (-70.3125, 'kN.m'),
        'mpos': (87.890625, 'kN.m'),
        'mneg': (117.1875, 'kN.m'),
        'dmax': (5.787037, 'mm'),
        'xd': (3.555556, 'm'),
      },
      relTol: 1e-5,
    ),
    const ToolCase(
      "Propped cantilever, UDL 12 kN/m, L = 5 m, concrete fc' 28 MPa, 300 × 500",
      source:
          'AISC case 12: R = 5wL/8 (fixed) / 3wL/8, M = wL²/8 = 37.5, M+ = 9wL²/128 = 21.094 kN·m; Ec = 24 870 MPa; δ 0.52266 mm (Python scan)',
      choices: {'support': 'propped', 'mat': 'conc', 'isrc': 'rect'},
      numbers: {
        'L': (5, 'm'),
        'P': (0, 'kN'),
        'a': (0, 'm'),
        'w': (12, 'kN/m'),
        'fc': (28, 'MPa'),
        'b': (300, 'mm'),
        'h': (500, 'mm'),
      },
      expect: {
        'ra': (37.5, 'kN'),
        'rb': (22.5, 'kN'),
        'ma': (-37.5, 'kN.m'),
        'mpos': (21.09375, 'kN.m'),
        'dmax': (0.522664, 'mm'),
        'xd': (2.89233, 'm'),
        'ec': (24870.06, 'MPa'),
      },
      relTol: 2e-5,
      expectWarning: 'gross I',
    ),
    const ToolCase(
      'Propped cantilever, 40 kN at 2 m from fixed end, L = 6 m',
      source:
          'AISC case 14 (a = 4 m from simple end): R = 5.926 kN, M_fixed = Pab(a+L)/2L² = 44.444 kN·m, δ = Pab²/6EI·√(a/(2L+a)) = 5.3333 mm',
      choices: {'support': 'propped'},
      numbers: {
        'L': (6, 'm'),
        'P': (40, 'kN'),
        'a': (2, 'm'),
        'w': (0, 'kN/m'),
        'I': (5000, 'cm4'),
      },
      expect: {
        'rb': (5.925926, 'kN'),
        'ma': (-44.444444, 'kN.m'),
        'mpos': (23.703704, 'kN.m'),
        'dmax': (5.333333, 'mm'),
        'xd': (3, 'm'),
      },
      relTol: 1e-5,
    ),
  ],
);
