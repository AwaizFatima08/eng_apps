import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

// 8-point Gauss–Legendre nodes and weights on [−1, 1].
const _glX = [
  -0.9602898564975363,
  -0.7966664774136267,
  -0.5255324099163290,
  -0.1834346424956498,
  0.1834346424956498,
  0.5255324099163290,
  0.7966664774136267,
  0.9602898564975363,
];
const _glW = [
  0.1012285362903763,
  0.2223810344533745,
  0.3137066458778873,
  0.3626837833783620,
  0.3626837833783620,
  0.3137066458778873,
  0.2223810344533745,
  0.1012285362903763,
];

/// Composite Gauss–Legendre integral of [f] over [a, b] with [n] panels.
double _integrate(double Function(double) f, double a, double b, [int n = 32]) {
  if (b <= a) return 0;
  final hw = (b - a) / n / 2;
  var sum = 0.0;
  for (var p = 0; p < n; p++) {
    final mid = a + (2 * p + 1) * hw;
    for (var i = 0; i < 8; i++) {
      sum += _glW[i] * f(mid + hw * _glX[i]);
    }
  }
  return sum * hw;
}

/// Area of a circle of radius [rho] below a chord at depth [d] from its
/// lowest point (0 ≤ d ≤ 2ρ, clamped).
double segmentArea(double rho, double d) {
  if (d <= 0 || rho <= 0) return 0;
  if (d >= 2 * rho) return math.pi * rho * rho;
  final c = rho - d;
  return rho * rho * math.acos(c / rho) - c * math.sqrt(2 * rho * d - d * d);
}

/// One dished head of a cylinder of radius [r]: depth, profile radius
/// and partial volume from the apex.
class TankHead {
  TankHead(this.type, double dia, {this.f = 1, this.k = 0.06}) : r = dia / 2 {
    switch (type) {
      case 'ellip':
        a = dia / 4;
      case 'hemi':
        a = dia / 2;
      case 'tori':
        rc = f * dia;
        rk = k * dia;
        final sinA = (r - rk) / (rc - rk);
        cosA = math.sqrt(1 - sinA * sinA);
        a = rc - (rc - rk) * cosA;
        y1 = rc * (1 - cosA);
      default:
        a = 0;
    }
  }

  final String type;
  final double r, f, k;
  late final double a;
  double rc = 0, rk = 0, cosA = 1, y1 = 0;

  /// Volume of one full head.
  double get full => fromApex(a);

  /// Volume between the apex and a plane at height [y] above it (0…a).
  double fromApex(double y) {
    y = y.clamp(0, a).toDouble();
    switch (type) {
      case 'ellip' || 'hemi':
        return math.pi * r * r / (a * a) * (a * y * y - y * y * y / 3);
      case 'tori':
        double cap(double t) => math.pi * t * t * (rc - t / 3);
        if (y <= y1) return cap(y);
        final c = r - rk;
        double big(double u) =>
            (c * c + rk * rk) * u -
            u * u * u / 3 +
            c *
                (u * math.sqrt(math.max(0, rk * rk - u * u)) +
                    rk * rk * math.asin((u / rk).clamp(-1, 1)));
        return cap(y1) + math.pi * (big(a - y1) - big(a - y));
      default:
        return 0;
    }
  }

  /// Radius of the head surface at axial distance [x] from the tangent line.
  double rhoAt(double x) {
    switch (type) {
      case 'ellip' || 'hemi':
        final t = x / a;
        return r * math.sqrt(math.max(0, 1 - t * t));
      case 'tori':
        final xj = rk * cosA;
        if (x <= xj) return r - rk + math.sqrt(math.max(0, rk * rk - x * x));
        final dy = rc - a + x;
        return math.sqrt(math.max(0, rc * rc - dy * dy));
      default:
        return 0;
    }
  }

  /// Liquid volume in one head of a horizontal tank filled to [h] above the
  /// bottom of the shell.
  double horizontal(double h) {
    if (type == 'flat' || h <= 0) return 0;
    if (h >= 2 * r) return full;
    if (type == 'ellip' || type == 'hemi') {
      // Exact: ellipsoid = hemisphere scaled by a/R along the axis.
      return math.pi * a * h * h * (3 * r - h) / (6 * r);
    }
    // Torispherical: integrate the wetted segment of each circular slice.
    double g(double x) {
      final rho = rhoAt(x);
      return segmentArea(rho, h - (r - rho));
    }

    final target = (r - h).abs();
    var lo = 0.0, hi = a;
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      if (rhoAt(mid) > target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final xs = (lo + hi) / 2; // slice where the level is tangent to it
    final xj = rk * cosA; // knuckle → crown junction
    final cuts = <double>{0, xj, xs, a}.toList()..sort();
    var sum = 0.0;
    for (var i = 0; i + 1 < cuts.length; i++) {
      final x0 = cuts[i], x1 = cuts[i + 1];
      if (x1 - x0 <= 0) continue;
      // Quadratic clustering towards both ends removes the (Δx)^1.5
      // behaviour of the segment area next to the tangent slice.
      sum += _integrate(
        (t) {
          final s = t * t * (3 - 2 * t);
          return g(x0 + (x1 - x0) * s) * (x1 - x0) * 6 * t * (1 - t);
        },
        0,
        1,
      );
    }
    return sum;
  }
}

class TankGeometry {
  TankGeometry({
    required this.horizontal,
    required this.d,
    required this.l,
    required this.head,
  });
  final bool horizontal;
  final double d, l;
  final TankHead head;

  double get r => d / 2;
  double get maxLevel => horizontal ? d : 2 * head.a + l;
  double get total => volumeAt(maxLevel);

  double volumeAt(double h) {
    h = h.clamp(0, maxLevel).toDouble();
    if (horizontal) {
      return segmentArea(r, h) * l + 2 * head.horizontal(h);
    }
    final a = head.a;
    var v = head.fromApex(h);
    v += math.pi * r * r * (h - a).clamp(0, l);
    if (h > a + l) v += head.full - head.fromApex(a - (h - a - l));
    return v;
  }

  double levelFor(double vol) {
    var lo = 0.0, hi = maxLevel;
    for (var i = 0; i < 100; i++) {
      final mid = (lo + hi) / 2;
      if (volumeAt(mid) < vol) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}

final tankVolumeTool = ToolDef(
  id: 'tank_volume',
  title: 'Tank volume & level',
  summary:
      'Vertical or horizontal cylindrical vessel with flat, 2:1 ellipsoidal, '
      'hemispherical or torispherical heads: level ⇄ volume and % full.',
  icon: Icons.propane_tank,
  keywords: [
    'tank',
    'vessel',
    'drum',
    'volume',
    'level',
    'strapping',
    'ellipsoidal',
    'hemispherical',
    'torispherical',
    'dished',
    'horizontal',
    'vertical',
    'percent full',
  ],
  inputs: [
    const ChoiceInput(
      'orient',
      'Orientation',
      options: [
        ChoiceOption('vert', 'Vertical'),
        ChoiceOption('horiz', 'Horizontal'),
      ],
    ),
    const ChoiceInput(
      'head',
      'Heads (both ends)',
      initial: 'ellip',
      options: [
        ChoiceOption('flat', 'Flat'),
        ChoiceOption('ellip', '2:1 ellipsoidal'),
        ChoiceOption('hemi', 'Hemispherical'),
        ChoiceOption('tori', 'Torispherical'),
      ],
    ),
    NumberInput(
      'f',
      'Crown radius / D (f)',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0.5,
      max: 2,
      help: 'ASME F&D 1.0; DIN 28011 Klöpper 1.0; DIN 28013 Korbbogen 0.8.',
      visibleWhen: (v) => v.c('head') == 'tori',
    ),
    NumberInput(
      'k',
      'Knuckle radius / D (k)',
      quantity: Quantity.dimensionless,
      initial: 0.06,
      min: 0,
      max: 0.5,
      minInclusive: false,
      help: 'ASME F&D 0.06; Klöpper 0.1; Korbbogen 0.154.',
      visibleWhen: (v) => v.c('head') == 'tori',
    ),
    const NumberInput(
      'd',
      'Internal diameter D',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 2,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'l',
      'Straight shell length (T/T)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 5,
      min: 0,
      help: 'Tangent line to tangent line; heads are added to this.',
    ),
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('h2v', 'Volume from level'),
        ChoiceOption('v2h', 'Level from volume'),
      ],
    ),
    NumberInput(
      'h',
      'Liquid level',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1,
      min: 0,
      help:
          'Vertical: from the lowest point of the bottom head. Horizontal: from the bottom of the shell.',
      visibleWhen: (v) => v.c('mode') == 'h2v',
    ),
    NumberInput(
      'vol',
      'Liquid volume',
      quantity: Quantity.volume,
      units: ('m3', 'gal'),
      initial: 5,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'v2h',
    ),
  ],
  compute: (v) {
    final d = v.n('d'), l = v.n('l');
    final type = v.c('head');
    final horizontal = v.c('orient') == 'horiz';
    if (type == 'tori' && v.n('k') >= v.n('f')) {
      throw ToolInputError(
        'Knuckle ratio k must be smaller than crown ratio f.',
      );
    }
    if (type == 'flat' && horizontal && l <= 0) {
      throw ToolInputError('Flat-ended horizontal tank needs a shell length.');
    }
    final head = TankHead(
      type,
      d,
      f: type == 'tori' ? v.n('f') : 1,
      k: type == 'tori' ? v.n('k') : 0.06,
    );
    final g = TankGeometry(horizontal: horizontal, d: d, l: l, head: head);
    final total = g.total;
    final double h, vol;
    if (v.c('mode') == 'v2h') {
      vol = v.n('vol');
      if (vol > total * (1 + 1e-12)) {
        throw ToolInputError(
          'Volume is above the tank capacity (${formatNumber(total, sig: 5)} m³).',
        );
      }
      h = g.levelFor(vol);
    } else {
      h = v.n('h');
      if (h > g.maxLevel * (1 + 1e-12)) {
        throw ToolInputError(
          'Level is above the top of the tank (${formatNumber(g.maxLevel, sig: 5)} m).',
        );
      }
      vol = g.volumeAt(h);
    }
    final v2h = v.c('mode') == 'v2h';
    return ToolResult(
      [
        ToolOutput(
          'vol',
          'Liquid volume',
          vol,
          quantity: Quantity.volume,
          units: ('m3', 'gal'),
          sig: 6,
          level: v2h ? OutputLevel.normal : OutputLevel.primary,
        ),
        ToolOutput(
          'h',
          'Liquid level',
          h,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 6,
          level: v2h ? OutputLevel.primary : OutputLevel.normal,
        ),
        ToolOutput(
          'pct',
          'Volume % full',
          total > 0 ? vol / total : 0,
          quantity: Quantity.percent,
          sig: 4,
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'lpct',
          'Level % of height',
          h / g.maxLevel,
          quantity: Quantity.percent,
          sig: 4,
        ),
        ToolOutput(
          'total',
          'Total volume',
          total,
          quantity: Quantity.volume,
          units: ('m3', 'gal'),
          sig: 6,
        ),
        ToolOutput(
          'ullage',
          'Empty space',
          total - vol,
          quantity: Quantity.volume,
          units: ('m3', 'gal'),
          sig: 5,
        ),
        ToolOutput(
          'vhead',
          'Volume of one head',
          head.full,
          quantity: Quantity.volume,
          units: ('m3', 'gal'),
          sig: 5,
        ),
        ToolOutput(
          'a',
          'Head depth',
          head.a,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 5,
        ),
        ToolOutput(
          'overall',
          horizontal ? 'Overall length' : 'Overall height',
          l + 2 * head.a,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 5,
        ),
      ],
      notes: [
        'Internal dimensions; nozzles, internals and plate thickness of the heads are not deducted.',
      ],
    );
  },
  formula: '''R = D/2, a = head depth, L = straight shell length

Head depths: 2:1 ellipsoidal a = D/4; hemispherical a = D/2;
torispherical (crown Rc = f·D, knuckle r = k·D):
  sin α = (R − r)/(Rc − r)
  a = Rc − (Rc − r)·cos α,  crown height y₁ = Rc(1 − cos α)

Vertical, level y in a dished bottom head (from apex):
  ellipsoidal/hemi: V = π·R²/a² · (a·y² − y³/3)
  torispherical: crown  V = π·y²(Rc − y/3)          y ≤ y₁
                 knuckle V = V(y₁) + π∫ρ(y)² dy     y₁ < y ≤ a
                 ρ(y) = (R − r) + √(r² − (a − y)²)
  shell: V = π·R²·(h − a);  top head by symmetry

Horizontal, level h from the bottom of the shell:
  shell: V = L·[R²·acos((R − h)/R) − (R − h)·√(2Rh − h²)]
  2 ellipsoidal/hemi heads: V = π·a·h²·(3R − h)/(3R)
  torispherical: V = ∫ segment area of each head slice
                 (numerical Gauss–Legendre)

Level from volume: bisection on V(h).''',
  references: [
    'Perry\'s Chemical Engineers\' Handbook, 9th ed., §10 "Storage and process vessels" — partially filled horizontal and vertical tanks',
    'D. Jones, "Calculating Tank Volume" (2017) — exact formulas for ellipsoidal, spherical and torispherical heads',
    'ASME BPVC Section VIII Div. 1 UG-32 (F&D head: crown = D, knuckle ≥ 6 % D); DIN 28011 / 28013 head shapes',
    'Cross-checked against the open-source "fluids" 1.3.1 library (C. Bell): fluids.geometry.TANK',
  ],
  assumptions: [
    'Both heads the same type; dimensions are internal; head depth measured from the tangent line.',
    'Tank exactly vertical or horizontal (no tilt); flat liquid surface.',
    'Torispherical f and k are referred to the internal diameter (ASME quotes them on the outside diameter).',
  ],
  cases: [
    const ToolCase(
      'Vertical, 2:1 heads, D 2 m, T/T 5 m, level 1 m',
      source:
          'fluids 1.3.1 geometry.TANK: V_from_h(1) = 2.617994 m³ (= 2/3·π·R²·a + π·R²·0.5 by hand); V_total 17.80236 m³',
      choices: {'orient': 'vert', 'head': 'ellip'},
      numbers: {'d': (2, 'm'), 'l': (5, 'm'), 'h': (1, 'm')},
      expect: {
        'vol': (2.6179938779914944, 'm3'),
        'total': (17.80235837034216, 'm3'),
        'a': (500, 'mm'),
      },
      relTol: 1e-8,
    ),
    const ToolCase(
      'Vertical, 2:1 heads, level from 10 m³',
      source: 'fluids 1.3.1 geometry.TANK: h_from_V(10) = 3.349766 m',
      choices: {'orient': 'vert', 'head': 'ellip', 'mode': 'v2h'},
      numbers: {'d': (2, 'm'), 'l': (5, 'm'), 'vol': (10, 'm3')},
      expect: {'h': (3.3497655285045735, 'm')},
      relTol: 1e-7,
    ),
    const ToolCase(
      'Vertical, ASME F&D (f 1, k 0.06), level 0.3 m in the knuckle',
      source:
          'fluids 1.3.1 geometry.TANK: head depth 0.338675 m, V_from_h(0.3) = 0.527002 m³',
      choices: {'orient': 'vert', 'head': 'tori'},
      numbers: {'d': (2, 'm'), 'l': (5, 'm'), 'h': (0.3, 'm')},
      expect: {
        'vol': (0.5270022474265285, 'm3'),
        'a': (0.33867522741638517, 'm'),
        'total': (17.003947336607393, 'm3'),
      },
      relTol: 1e-8,
    ),
    const ToolCase(
      'Vertical, ASME F&D, level 5.4 m in the top head',
      source: 'fluids 1.3.1 geometry.TANK: V_from_h(5.4) = 16.54652 m³',
      choices: {'orient': 'vert', 'head': 'tori'},
      numbers: {'d': (2, 'm'), 'l': (5, 'm'), 'h': (5.4, 'm')},
      expect: {'vol': (16.54652334655013, 'm3')},
      relTol: 1e-8,
    ),
    const ToolCase(
      'Vertical, hemispherical heads, D 2 m, T/T 4 m, level 0.5 m',
      source:
          'fluids 1.3.1 geometry.TANK (spherical, a = R): V_from_h(0.5) = 0.654498 m³ = π·h²(R − h/3)',
      choices: {'orient': 'vert', 'head': 'hemi'},
      numbers: {'d': (2, 'm'), 'l': (4, 'm'), 'h': (0.5, 'm')},
      expect: {
        'vol': (0.6544984694978736, 'm3'),
        'total': (16.755160819145562, 'm3'),
      },
      relTol: 1e-8,
    ),
    const ToolCase(
      'Horizontal, 2:1 heads, D 2 m, T/T 5 m, level 0.5 m',
      source: 'fluids 1.3.1 geometry.TANK: V_from_h(0.5) = 3.398173 m³',
      choices: {'orient': 'horiz', 'head': 'ellip'},
      numbers: {'d': (2, 'm'), 'l': (5, 'm'), 'h': (0.5, 'm')},
      expect: {'vol': (3.3981734812708297, 'm3')},
      relTol: 1e-8,
    ),
    const ToolCase(
      'Horizontal, ASME F&D, D 3 m, T/T 8 m, level 0.4 m',
      source:
          'fluids 1.3.1 geometry.TANK (Jones exact formulas): V_from_h(0.4) = 4.683929 m³; V_total 60.92261 m³',
      choices: {'orient': 'horiz', 'head': 'tori'},
      numbers: {'d': (3, 'm'), 'l': (8, 'm'), 'h': (0.4, 'm')},
      expect: {
        'vol': (4.683928712599781, 'm3'),
        'total': (60.92261399633846, 'm3'),
      },
      relTol: 1e-8,
    ),
    const ToolCase(
      'Horizontal, ASME F&D, level from 30 m³',
      source: 'fluids 1.3.1 geometry.TANK: h_from_V(30) = 1.482432 m',
      choices: {'orient': 'horiz', 'head': 'tori', 'mode': 'v2h'},
      numbers: {'d': (3, 'm'), 'l': (8, 'm'), 'vol': (30, 'm3')},
      expect: {'h': (1.4824322218373434, 'm')},
      relTol: 1e-7,
    ),
    const ToolCase(
      'Horizontal, Korbbogen (f 0.8, k 0.154), level 2.2 m',
      source:
          'fluids 1.3.1 geometry.TANK: V_from_h(2.2) = 50.26487 m³, head depth 0.763418 m',
      choices: {'orient': 'horiz', 'head': 'tori'},
      numbers: {
        'd': (3, 'm'),
        'l': (8, 'm'),
        'f': (0.8, '-'),
        'k': (0.154, '-'),
        'h': (2.2, 'm'),
      },
      expect: {
        'vol': (50.26486905314816, 'm3'),
        'a': (0.7634181963616973, 'm'),
      },
      relTol: 1e-8,
    ),
    const ToolCase(
      'Horizontal, flat ends, D 2.5 m, L 6 m, level 0.7 m',
      source:
          'fluids 1.3.1 geometry.TANK: V_from_h(0.7) = 6.750737 m³ (circular segment × L)',
      choices: {'orient': 'horiz', 'head': 'flat'},
      numbers: {'d': (2.5, 'm'), 'l': (6, 'm'), 'h': (0.7, 'm')},
      expect: {'vol': (6.75073718771011, 'm3')},
      relTol: 1e-8,
    ),
  ],
);
