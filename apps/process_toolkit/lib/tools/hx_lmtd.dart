import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Log-mean of two end temperature differences (both > 0).
double logMean(double dt1, double dt2) {
  if ((dt1 - dt2).abs() < 1e-9 * math.max(dt1, dt2)) return (dt1 + dt2) / 2;
  return (dt1 - dt2) / math.log(dt1 / dt2);
}

/// Bowman–Mueller–Nagle F for one shell pass and 2, 4, … tube passes
/// (TEMA E shell). Returns null where no 1-2 exchanger can do the duty.
double? f12(double r, double p) {
  final s = math.sqrt(r * r + 1);
  final num = 2 - p * (r + 1 - s);
  final den = 2 - p * (r + 1 + s);
  if (num <= 0 || den <= 0 || num / den <= 1) return null;
  final ln2 = math.log(num / den);
  if ((r - 1).abs() < 1e-6) {
    // Limit R → 1.
    if (p >= 1) return null;
    return s * p / (1 - p) / ln2;
  }
  final a = (1 - p) / (1 - p * r);
  if (a <= 0) return null;
  return s / (r - 1) * math.log(a) / ln2;
}

final hxLmtdTool = ToolDef(
  id: 'hx_lmtd',
  title: 'Heat exchanger LMTD & duty',
  summary:
      'Log-mean temperature difference for counter-current, co-current or 1-2 '
      'shell-and-tube (F factor), and Q = U·A·F·LMTD solved for Q, U or A.',
  icon: Icons.thermostat,
  keywords: [
    'heat exchanger',
    'lmtd',
    'mtd',
    'f factor',
    'correction factor',
    'tema',
    'shell and tube',
    'duty',
    'u value',
    'overall heat transfer',
    'area',
    'cooler',
    'condenser',
  ],
  inputs: [
    const ChoiceInput(
      'arr',
      'Flow arrangement',
      options: [
        ChoiceOption('counter', 'Counter-current'),
        ChoiceOption('co', 'Co-current (parallel)'),
        ChoiceOption('s12', '1-2 shell & tube'),
      ],
    ),
    const NumberInput(
      'thi',
      'Hot fluid inlet T',
      quantity: Quantity.temperature,
      initial: 150,
    ),
    const NumberInput(
      'tho',
      'Hot fluid outlet T',
      quantity: Quantity.temperature,
      initial: 90,
    ),
    const NumberInput(
      'tci',
      'Cold fluid inlet T',
      quantity: Quantity.temperature,
      initial: 30,
    ),
    const NumberInput(
      'tco',
      'Cold fluid outlet T',
      quantity: Quantity.temperature,
      initial: 70,
    ),
    const ChoiceInput(
      'solve',
      'Solve for',
      options: [
        ChoiceOption('Q', 'Duty Q'),
        ChoiceOption('U', 'U (overall coeff.)'),
        ChoiceOption('A', 'Area A'),
      ],
    ),
    NumberInput(
      'q',
      'Duty Q',
      quantity: Quantity.power,
      initial: 1e6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('solve') != 'Q',
    ),
    NumberInput(
      'u',
      'Overall coefficient U',
      quantity: Quantity.heatTransfer,
      initial: 500,
      min: 0,
      minInclusive: false,
      help:
          'Typical: water–water 800–1500, light HC–water 350–750, gas–water 20–300 W/(m²·K).',
      visibleWhen: (v) => v.c('solve') != 'U',
    ),
    NumberInput(
      'a',
      'Heat transfer area A',
      quantity: Quantity.area,
      initial: 50,
      min: 0,
      minInclusive: false,
      help: 'Use the area on which U is based (usually the tube outside area).',
      visibleWhen: (v) => v.c('solve') != 'A',
    ),
  ],
  compute: (v) {
    final thi = v.n('thi'), tho = v.n('tho');
    final tci = v.n('tci'), tco = v.n('tco');
    final arr = v.c('arr');
    if (thi < tho) {
      throw ToolInputError(
        'Hot fluid must cool: inlet T at or above outlet T.',
      );
    }
    if (tco < tci) {
      throw ToolInputError(
        'Cold fluid must heat: outlet T at or above inlet T.',
      );
    }
    if (thi == tho && tco == tci) {
      throw ToolInputError(
        'Both fluids isothermal: no temperature change to work with.',
      );
    }
    final co = arr == 'co';
    final dt1 = co ? thi - tci : thi - tco;
    final dt2 = co ? tho - tco : tho - tci;
    if (dt1 <= 0 || dt2 <= 0) {
      throw ToolInputError(
        co
            ? 'Co-current: the hot outlet must stay above the cold outlet.'
            : 'Temperature cross at one end (ΔT ≤ 0): not possible in counter-current flow.',
      );
    }
    final lmtd = logMean(dt1, dt2);
    final w = <String>[];
    final r = (thi - tho) / (tco - tci);
    final p = (tco - tci) / (thi - tci);
    var f = 1.0;
    // One isothermal stream (condensing/boiling): F = 1 for any arrangement.
    final isothermal = thi == tho || tco == tci;
    if (arr == 's12' && !isothermal) {
      final ff = f12(r, p);
      if (ff == null) {
        throw ToolInputError(
          'These temperatures cannot be reached in one 1-2 shell (F undefined). '
          'Use shells in series or a counter-current exchanger.',
        );
      }
      f = ff;
      if (f < 0.75) {
        w.add(
          'F = ${formatNumber(f, sig: 3)} < 0.75: too close to the limit; small '
          'changes give large errors. Use more shells in series (TEMA / Kern).',
        );
      } else if (f < 0.8) {
        w.add('F < 0.8: usual design minimum; consider two shells in series.');
      }
      if (tco > tho) {
        w.add(
          'Temperature cross (cold outlet above hot outlet) in a 1-2 shell.',
        );
      }
    }
    final mtd = f * lmtd;
    final solve = v.c('solve');
    double q, u, a;
    switch (solve) {
      case 'U':
        q = v.n('q');
        a = v.n('a');
        u = q / (a * mtd);
      case 'A':
        q = v.n('q');
        u = v.n('u');
        a = q / (u * mtd);
      default:
        u = v.n('u');
        a = v.n('a');
        q = u * a * mtd;
    }
    OutputLevel lv(String s) =>
        solve == s ? OutputLevel.primary : OutputLevel.normal;
    return ToolResult(
      [
        ToolOutput(
          'q',
          'Duty Q',
          q,
          quantity: Quantity.power,
          sig: 5,
          level: lv('Q'),
        ),
        ToolOutput(
          'u',
          'U',
          u,
          quantity: Quantity.heatTransfer,
          sig: 5,
          level: lv('U'),
        ),
        ToolOutput(
          'a',
          'Area A',
          a,
          quantity: Quantity.area,
          sig: 5,
          level: lv('A'),
        ),
        ToolOutput('lmtd', 'LMTD', lmtd, quantity: Quantity.tempDiff, sig: 6),
        ToolOutput('f', 'Correction factor F', f, sig: 5),
        ToolOutput(
          'mtd',
          'Mean ΔT = F·LMTD',
          mtd,
          quantity: Quantity.tempDiff,
          sig: 6,
        ),
        ToolOutput(
          'dt1',
          'ΔT₁ (end 1)',
          dt1,
          quantity: Quantity.tempDiff,
          sig: 5,
        ),
        ToolOutput(
          'dt2',
          'ΔT₂ (end 2)',
          dt2,
          quantity: Quantity.tempDiff,
          sig: 5,
        ),
        ToolOutput('r', 'R (capacity ratio)', r, sig: 5),
        ToolOutput('p', 'P (thermal effectiveness)', p, sig: 5),
      ],
      warnings: w,
      notes: [
        if (arr == 's12' && !isothermal)
          'F for a 1-2 shell does not depend on which fluid is on the shell side.',
      ],
    );
  },
  formula: '''End differences:
  Counter:  ΔT₁ = Th,in − Tc,out   ΔT₂ = Th,out − Tc,in
  Co-curr.: ΔT₁ = Th,in − Tc,in    ΔT₂ = Th,out − Tc,out
  LMTD = (ΔT₁ − ΔT₂) / ln(ΔT₁/ΔT₂)   (= ΔT₁ if equal)

1-2 shell & tube (TEMA E, 2·n tube passes):
  R = (T₁ − T₂)/(t₂ − t₁)   P = (t₂ − t₁)/(T₁ − t₁)
  S = √(R² + 1)
  F = S/(R − 1) · ln[(1 − P)/(1 − P·R)]
      / ln{[2 − P(R + 1 − S)] / [2 − P(R + 1 + S)]}
  R = 1:  F = S·P/(1 − P) / ln{[2 − P(2 − S)] / [2 − P(2 + S)]}
  (T hot, t cold; LMTD on counter-current basis)

Duty:  Q = U · A · F · LMTD''',
  references: [
    'R. A. Bowman, A. C. Mueller, W. M. Nagle, "Mean temperature difference in design", Trans. ASME 62 (1940) 283–294',
    'TEMA Standards, 10th ed. (2019), Section 7 T-3 (mean temperature difference, F-factor charts)',
    'D. Q. Kern, Process Heat Transfer (1950), ch. 7 eq. 7.42 (1-2 exchanger F_T)',
    'Cross-checked against the open-source "ht" 1.2.0 library (C. Bell): LMTD and F_LMTD_Fakheri',
  ],
  assumptions: [
    'Constant U and constant specific heats. A stream that condenses or boils at constant temperature is entered with equal inlet and outlet T (then F = 1).',
    'No heat loss to ambient; each fluid well mixed across the shell at any cross-section (Bowman assumptions for F).',
  ],
  cases: [
    const ToolCase(
      'Counter-current 150→90 / 30→70 °C, U 500, A 50 m² → Q',
      source:
          'ht 1.2.0 LMTD(counterflow=True) = 69.52119 K; Q = U·A·LMTD = 1 738.03 kW',
      numbers: {
        'thi': (150, 'C'),
        'tho': (90, 'C'),
        'tci': (30, 'C'),
        'tco': (70, 'C'),
        'u': (500, 'W/m2K'),
        'a': (50, 'm2'),
      },
      expect: {
        'lmtd': (69.52118993564414, 'K'),
        'q': (1738029.7483911037, 'W'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Co-current, same temperatures, Q 1 MW, U 500 → A',
      source:
          'ht 1.2.0 LMTD(counterflow=False) = 55.81106 K; A = Q/(U·LMTD) = 35.8352 m²',
      choices: {'arr': 'co', 'solve': 'A'},
      numbers: {
        'thi': (150, 'C'),
        'tho': (90, 'C'),
        'tci': (30, 'C'),
        'tco': (70, 'C'),
        'q': (1, 'MW'),
        'u': (500, 'W/m2K'),
      },
      expect: {'lmtd': (55.81106265512473, 'K'), 'a': (35.8351893845611, 'm2')},
      relTol: 1e-9,
    ),
    const ToolCase(
      '1-2 shell, R 1.5, P 0.333, Q 1 MW, A 20 m² → U',
      source:
          'ht 1.2.0 F_LMTD_Fakheri(shells=1) = 0.910481; U = 789.918 W/(m²·K)',
      choices: {'arr': 's12', 'solve': 'U'},
      numbers: {
        'thi': (150, 'C'),
        'tho': (90, 'C'),
        'tci': (30, 'C'),
        'tco': (70, 'C'),
        'q': (1, 'MW'),
        'a': (20, 'm2'),
      },
      expect: {
        'f': (0.910480603749974, '-'),
        'u': (789.9181796594893, 'W/m2K'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      '1-2 shell, R = 1 (limit formula), equal end ΔT',
      source: 'ht 1.2.0: LMTD = 50 K, F_LMTD_Fakheri = 0.802278',
      choices: {'arr': 's12'},
      numbers: {
        'thi': (150, 'C'),
        'tho': (100, 'C'),
        'tci': (50, 'C'),
        'tco': (100, 'C'),
      },
      expect: {'lmtd': (50, 'K'), 'f': (0.8022781617244772, '-')},
      relTol: 1e-9,
    ),
    const ToolCase(
      '1-2 shell, R 1.2, P 0.417',
      source: 'ht 1.2.0: LMTD 64.87159 K, F_LMTD_Fakheri = 0.866928',
      choices: {'arr': 's12'},
      numbers: {
        'thi': (150, 'C'),
        'tho': (90, 'C'),
        'tci': (30, 'C'),
        'tco': (80, 'C'),
      },
      expect: {'lmtd': (64.8715919463088, 'K'), 'f': (0.8669282341207664, '-')},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Condensing steam 150 °C, water 30→90 °C, 1-2 shell',
      source:
          'ht 1.2.0 LMTD(150, 150, 30, 90) = 86.5617 K; F = 1 (isothermal stream); Q = 800·30·LMTD',
      choices: {'arr': 's12'},
      numbers: {
        'thi': (150, 'C'),
        'tho': (150, 'C'),
        'tci': (30, 'C'),
        'tco': (90, 'C'),
        'u': (800, 'W/m2K'),
        'a': (30, 'm2'),
      },
      expect: {'f': (1, '-'), 'q': (2077480.8588801073, 'W')},
      relTol: 1e-9,
    ),
  ],
);
