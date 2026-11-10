import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// API 526 standard effective orifice areas (letter, in²).
const List<(String, double)> api526Orifices = [
  ('D', 0.110),
  ('E', 0.196),
  ('F', 0.307),
  ('G', 0.503),
  ('H', 0.785),
  ('J', 1.287),
  ('K', 1.838),
  ('L', 2.853),
  ('M', 3.60),
  ('N', 4.34),
  ('P', 6.38),
  ('Q', 11.05),
  ('R', 16.0),
  ('T', 26.0),
];
const double _in2mm2 = 645.16;

/// Smallest API 526 orifice with area ≥ [aMm2]; null if larger than T.
(String, double)? api526Select(double aMm2) {
  for (final (l, a) in api526Orifices) {
    if (a * _in2mm2 >= aMm2) return (l, a * _in2mm2);
  }
  return null;
}

/// API 520 Part I critical-flow coefficient C (SI form, Eq. for C).
double api520C(double k) {
  if ((k - 1).abs() < 1e-9) return 0.03948 * math.sqrt(1 / math.e);
  return 0.03948 * math.sqrt(k * math.pow(2 / (k + 1), (k + 1) / (k - 1)));
}

/// API 520 Part I subcritical coefficient F₂.
double api520F2(double k, double r) => math.sqrt(
  k / (k - 1) * math.pow(r, 2 / k) * (1 - math.pow(r, (k - 1) / k)) / (1 - r),
);

/// API 520 Part I (10th ed.) viscosity correction, valid for Re > 80.
double api520Kv(double re) => 1 / math.sqrt(1 + 170 / re);

final reliefValveTool = ToolDef(
  id: 'relief_valve',
  title: 'Relief valve sizing (API 520)',
  summary:
      'Required effective orifice area for a pressure-relief valve in gas/vapour '
      'or liquid service, and the next API 526 orifice letter.',
  icon: Icons.warning_amber,
  keywords: [
    'relief',
    'safety valve',
    'psv',
    'prv',
    'api 520',
    'api 526',
    'orifice letter',
    'overpressure',
    'set pressure',
    'backpressure',
    'kd',
    'kb',
    'kw',
    'kv',
  ],
  inputs: [
    const ChoiceInput(
      'fluid',
      'Service',
      options: [
        ChoiceOption('gas', 'Gas / vapour'),
        ChoiceOption('liquid', 'Liquid'),
      ],
    ),
    const ChoiceInput(
      'valve',
      'Valve type',
      options: [
        ChoiceOption('conv', 'Conventional'),
        ChoiceOption('bellows', 'Balanced bellows'),
      ],
    ),
    const NumberInput(
      'pset',
      'Set pressure',
      quantity: Quantity.pressure,
      unitSuffix: 'g',
      initial: 10e5,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'op',
      'Allowable overpressure',
      quantity: Quantity.percent,
      initial: 0.10,
      min: 0,
      max: 0.5,
      help:
          'ASME VIII: 10 % single valve, 16 % multiple valves, 21 % fire case.',
    ),
    const NumberInput(
      'pb',
      'Total back pressure',
      quantity: Quantity.pressure,
      unitSuffix: 'g',
      initial: 0,
      min: 0,
      help: 'Superimposed + built-up back pressure at the valve outlet.',
    ),
    NumberInput(
      'patm',
      'Atmospheric pressure',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 101325,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'w',
      'Required relieving mass flow',
      quantity: Quantity.massFlow,
      initial: 10000 / 3600,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      't',
      'Relieving temperature',
      quantity: Quantity.temperature,
      initial: 100,
      min: -273.15,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'mw',
      'Molecular mass M',
      quantity: Quantity.dimensionless,
      unitSuffix: 'kg/kmol',
      initial: 28.96,
      min: 0,
      minInclusive: false,
      help: 'Air 28.96, N₂ 28.01, NH₃ 17.03, CO₂ 44.01, H₂ 2.016, CH₄ 16.04.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'z',
      'Compressibility Z',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help:
          'At relieving conditions. Z = 1 is conservative when Z < 1 is uncertain.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'k',
      'Ideal-gas Cp/Cv ratio k',
      quantity: Quantity.dimensionless,
      initial: 1.4,
      min: 1,
      max: 2,
      minInclusive: false,
      help: 'Air/N₂ 1.40, NH₃ 1.31, CO₂ 1.29, CH₄ 1.31, H₂ 1.41.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'kdg',
      'Discharge coefficient Kd',
      quantity: Quantity.dimensionless,
      initial: 0.975,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'API 520 preliminary sizing 0.975; with a rupture disk only 0.62.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'kb',
      'Back pressure factor Kb',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'From the valve maker or API 520 Part I Fig. 31.',
      visibleWhen: (v) => v.c('fluid') == 'gas' && v.c('valve') == 'bellows',
    ),
    NumberInput(
      'q',
      'Required relieving flow',
      quantity: Quantity.volumeFlow,
      units: ('L/min', 'gpm'),
      initial: 1000 / 60000,
      min: 0,
      minInclusive: false,
      help: 'At flowing temperature.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'g',
      'Specific gravity G',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help: 'At flowing temperature, referred to water at standard conditions.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'mu',
      'Viscosity μ',
      quantity: Quantity.viscosity,
      initial: 1e-3,
      min: 0,
      minInclusive: false,
      help: 'At flowing temperature; used for the viscosity factor Kv.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'kdl',
      'Discharge coefficient Kd',
      quantity: Quantity.dimensionless,
      initial: 0.65,
      min: 0,
      max: 1,
      minInclusive: false,
      help:
          'API 520 preliminary sizing for certified liquid valves 0.65; with a rupture disk 0.62.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'kw',
      'Back pressure factor Kw',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'From the valve maker or API 520 Part I Fig. 32.',
      visibleWhen: (v) => v.c('fluid') == 'liquid' && v.c('valve') == 'bellows',
    ),
    const NumberInput(
      'kc',
      'Rupture disk factor Kc',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      max: 1,
      minInclusive: false,
      help:
          '1.0 without rupture disk; 0.9 for an uncertified disk + valve combination.',
    ),
  ],
  compute: (v) {
    final pset = v.n('pset'), op = v.n('op'), pb = v.n('pb'), kc = v.n('kc');
    final bellows = v.c('valve') == 'bellows';
    final w = <String>[];
    final notes = <String>[
      'Preliminary sizing with API 526 effective areas and effective Kd. Final '
          'selection uses the maker\'s rated area and certified Kd.',
    ];
    if (!bellows && pb > op * pset * (1 + 1e-9)) {
      w.add(
        'Back pressure above the allowable overpressure '
        '(${formatNumber(op * 100, sig: 3)} % of set): a conventional valve is '
        'normally not suitable (API 520 Part I). Consider a balanced bellows '
        'or pilot valve.',
      );
    }
    if (pset < 207e3 && op <= 0.10) {
      w.add(
        'Set pressure below 207 kPa g (30 psig): ASME allows the greater of '
        '10 % or 21 kPa (3 psi) overpressure.',
      );
    }
    final out = <ToolOutput>[];
    double aReq;
    if (v.c('fluid') == 'gas') {
      final patm = v.n('patm');
      final p1 = (pset * (1 + op) + patm) / 1000; // kPa abs
      final p2 = (pb + patm) / 1000;
      final k = v.n('k'), z = v.n('z'), mw = v.n('mw');
      final tK = v.n('t') + 273.15;
      final wKgH = v.n('w') * 3600;
      final kd = v.n('kdg');
      final rCrit = math.pow(2 / (k + 1), k / (k - 1)).toDouble();
      final r = p2 / p1;
      if (r >= 1) {
        throw ToolInputError(
          'Back pressure must be below the relieving pressure.',
        );
      }
      final critical = r <= rCrit;
      final String regime;
      if (critical || bellows) {
        final c = api520C(k);
        final kb = bellows ? v.n('kb') : 1.0;
        aReq = wKgH / (c * kd * p1 * kb * kc) * math.sqrt(tK * z / mw);
        regime = critical
            ? 'Critical (choked) flow'
            : 'Subcritical (bellows: critical eq. with Kb)';
        out.add(ToolOutput('c', 'Coefficient C', c, sig: 5));
        if (!critical) {
          notes.add(
            'API 520 Part I §5.6.3: balanced valves in subcritical flow use the critical equation with the maker\'s Kb.',
          );
        }
      } else {
        final f2 = api520F2(k, r);
        aReq =
            17.9 *
            wKgH /
            (f2 * kd * kc) *
            math.sqrt(tK * z / (mw * p1 * (p1 - p2)));
        regime = 'Subcritical flow (F₂ equation)';
        out.add(ToolOutput('f2', 'Coefficient F₂', f2, sig: 5));
      }
      out.insertAll(0, [
        ToolOutput.text('regime', 'Flow regime', regime),
        ToolOutput(
          'p1',
          'Relieving pressure P₁',
          p1 * 1000,
          quantity: Quantity.pressure,
          sig: 6,
        ),
        ToolOutput('rc', 'Critical pressure ratio', rCrit, sig: 4),
        ToolOutput('ratio', 'P₂/P₁', r, sig: 4),
      ]);
    } else {
      final p1g = pset * (1 + op) / 1000; // kPa g
      final dp = p1g - pb / 1000;
      if (dp <= 0) {
        throw ToolInputError(
          'Back pressure must be below the relieving pressure.',
        );
      }
      final qLmin = v.n('q') * 60000;
      final g = v.n('g'), muCp = v.n('mu') * 1000;
      final kd = v.n('kdl'), kw = bellows ? v.n('kw') : 1.0;
      final a0 = 11.78 * qLmin / (kd * kw * kc) * math.sqrt(g / dp);
      // API 520 Part I §5.9: Re on the next larger standard orifice, then
      // Kv; step up the orifice while the corrected area does not fit.
      var a = a0, kv = 1.0, re = double.infinity;
      var pick = api526Select(a0);
      for (var i = 0; i < api526Orifices.length; i++) {
        final aOrif = pick?.$2 ?? a;
        re = qLmin * 18800 * g / (muCp * math.sqrt(aOrif));
        kv = api520Kv(re);
        a = a0 / kv;
        if (pick == null || a <= pick.$2) break;
        pick = api526Select(a);
      }
      aReq = a;
      if (re < 80) {
        w.add(
          'Re = ${formatNumber(re, sig: 3)} < 80: below the range of the API 520 Kv equation.',
        );
      }
      out.addAll([
        ToolOutput(
          'p1',
          'Relieving pressure P₁',
          p1g * 1000,
          quantity: Quantity.pressure,
          sig: 6,
        ),
        ToolOutput(
          'a0',
          'Area before Kv',
          a0 * 1e-6,
          quantity: Quantity.area,
          units: ('mm2', 'in2'),
          sig: 5,
        ),
        ToolOutput('re', 'Reynolds number Re', re, sig: 4),
        ToolOutput('kv', 'Viscosity factor Kv', kv, sig: 4),
      ]);
    }
    final sel = api526Select(aReq);
    out.insertAll(0, [
      ToolOutput(
        'a',
        'Required effective area',
        aReq * 1e-6,
        quantity: Quantity.area,
        units: ('mm2', 'in2'),
        sig: 5,
        level: OutputLevel.primary,
      ),
      ToolOutput.text(
        'letter',
        'API 526 orifice',
        sel == null
            ? 'Larger than T (16 774 mm²): use multiple valves'
            : '${sel.$1} (${formatNumber(sel.$2, sig: 4)} mm² / ${formatNumber(sel.$2 / _in2mm2, sig: 4)} in²)',
        level: sel == null ? OutputLevel.fail : OutputLevel.primary,
      ),
      if (sel != null)
        ToolOutput(
          'use',
          'Orifice area used',
          aReq / sel.$2,
          quantity: Quantity.percent,
          sig: 3,
        ),
    ]);
    if (sel == null) {
      w.add('Required area exceeds the largest API 526 orifice (T).');
    }
    return ToolResult(out, warnings: w, notes: notes);
  },
  formula: '''API 520 Part I SI units: A mm², W kg/h, Q L/min,
P kPa, T K.  P₁ = Pset·(1 + overpressure) + Patm

Gas/vapour, critical flow (P₂/P₁ ≤ (2/(k+1))^(k/(k−1))):
  A = W / (C·Kd·P₁·Kb·Kc) · √(T·Z/M)
  C = 0.03948·√( k·(2/(k+1))^((k+1)/(k−1)) )

Gas/vapour, subcritical, conventional valve:
  A = 17.9·W / (F₂·Kd·Kc) · √( T·Z / (M·P₁·(P₁ − P₂)) )
  F₂ = √( k/(k−1) · r^(2/k) · (1 − r^((k−1)/k)) / (1 − r) )
  r = P₂/P₁   (balanced bellows: critical eq. with Kb)

Liquid, certified valve (P in kPa g):
  A = 11.78·Q / (Kd·Kw·Kc·Kv) · √( G / (P₁ − P₂) )
  Re = Q·18 800·G / (μ[cP]·√A_orifice)
  Kv = (1 + 170/Re)^−0.5     (10th ed., Re > 80)
  A_orifice = next API 526 area above the Kv = 1 area

Orifice letter: smallest API 526 area ≥ A.''',
  references: [
    'API Standard 520 Part I, 10th ed. (2020): §5.6.2 critical flow Eq. (3)–(5), §5.6.3 subcritical flow Eq. (13)–(14), §5.9 liquid Eq. (31)–(32), Kv equation',
    'API Standard 526, 7th ed.: standard effective orifice areas D … T',
    'ASME BPVC Section VIII Div. 1 UG-125/UG-134 (allowable overpressure 10 % / 16 % / 21 %)',
    'Cross-checked against the open-source "fluids" 1.3.1 library (C. Bell): API520_A_g, API520_A_l, API520_Kv, API520_C, API520_F2; and API 520 Part I Examples 1, 2 and 5',
  ],
  assumptions: [
    'Single-phase gas/vapour (ideal-gas k) or non-flashing liquid. Steam (Napier), two-phase and choked liquid are not covered.',
    'Relieving pressure = set pressure + overpressure (+ atmospheric for gas); inlet line losses not deducted.',
    'Kd, Kb, Kw are effective values for preliminary sizing; use the maker\'s certified values for final design.',
  ],
  cases: [
    const ToolCase(
      'API 520 Example 1: gas, critical flow',
      source:
          'API 520 Part I Example 1 (W 24 270 kg/h, P₁ 670 kPa a, 348 K, Z 0.90, '
          'M 51, k 1.11): A = 3699 mm²; fluids 1.3.1 API520_A_g = 3699.046 mm²',
      numbers: {
        'pset': (516.9772727272727, 'kPa'),
        'op': (10, '%'),
        'patm': (101.325, 'kPa'),
        'w': (24270, 'kg/h'),
        't': (348, 'K'),
        'mw': (51, '-'),
        'z': (0.9, '-'),
        'k': (1.11, '-'),
      },
      expect: {
        'a': (3699.0460646834413, 'mm2'),
        'c': (0.024890086557206686, '-'),
        'p1': (670, 'kPa'),
      },
      expectText: {'letter': 'P', 'regime': 'Critical'},
      relTol: 1e-8,
    ),
    const ToolCase(
      'API 520 Example 2: gas, subcritical (P₂ 532 kPa a)',
      source:
          'API 520 Part I Example 2: A = 4248 mm²; fluids 1.3.1 API520_A_g = '
          '4248.359 mm², F₂ 0.854763',
      numbers: {
        'pset': (516.9772727272727, 'kPa'),
        'op': (10, '%'),
        'pb': (430.675, 'kPa'),
        'patm': (101.325, 'kPa'),
        'w': (24270, 'kg/h'),
        't': (348, 'K'),
        'mw': (51, '-'),
        'z': (0.9, '-'),
        'k': (1.11, '-'),
      },
      expect: {
        'a': (4248.358775943481, 'mm2'),
        'f2': (0.8547632657974537, '-'),
      },
      expectText: {'letter': 'Q', 'regime': 'Subcritical'},
      relTol: 1e-8,
    ),
    const ToolCase(
      'Ammonia vapour, bellows, Kb 0.9, Kc 0.9 (rupture disk)',
      source:
          'fluids 1.3.1 API520_A_g (critical, Kb 0.9, Kc 0.9): 538.201 mm² → J',
      choices: {'valve': 'bellows'},
      numbers: {
        'pset': (16, 'bar'),
        'w': (5000, 'kg/h'),
        't': (40, 'C'),
        'mw': (17.03, '-'),
        'z': (0.95, '-'),
        'k': (1.31, '-'),
        'kb': (0.9, '-'),
        'kc': (0.9, '-'),
      },
      expect: {'a': (538.2008938210672, 'mm2')},
      expectText: {'letter': 'J'},
      relTol: 1e-8,
    ),
    const ToolCase(
      'Bellows in subcritical flow → critical eq. with Kb (API §5.6.3)',
      source:
          'fluids 1.3.1 API520_A_g evaluated with the critical equation and '
          'Kb 0.75: 581.257 mm² (fluids itself would use F₂ and drop Kb: 446.4 mm²)',
      choices: {'valve': 'bellows'},
      numbers: {
        'pset': (16, 'bar'),
        'pb': (11, 'bar'),
        'w': (5000, 'kg/h'),
        't': (40, 'C'),
        'mw': (17.03, '-'),
        'z': (0.95, '-'),
        'k': (1.31, '-'),
        'kb': (0.75, '-'),
      },
      expect: {'a': (581.2569653267526, 'mm2')},
      expectText: {'regime': 'bellows'},
      relTol: 1e-8,
    ),
    const ToolCase(
      'API 520 Example 5: viscous liquid, bellows, Kw 0.97',
      source:
          'API 520 Part I 10th ed. Example 5 (6 814 L/min, G 0.90, 2000 SSU ≈ 388 cP, '
          'set 1 724 kPa g, 10 %, back pressure 344.8 kPa g): A₀ 3 066 mm², '
          'Re on orifice P, final A = 3 122 mm²; fluids API520_A_l/API520_Kv(10E) '
          'with Re on orifice P: 3 121.92 mm²',
      choices: {'fluid': 'liquid', 'valve': 'bellows'},
      numbers: {
        'pset': (1724, 'kPa'),
        'op': (10, '%'),
        'pb': (344.8, 'kPa'),
        'q': (6814, 'L/min'),
        'g': (0.9, '-'),
        'mu': (388, 'cP'),
        'kw': (0.97, '-'),
      },
      expect: {
        'a0': (3066.1521232961195, 'mm2'),
        'kv': (0.982137869017385, '-'),
        'a': (3121.916199365942, 'mm2'),
      },
      expectText: {'letter': 'P'},
      relTol: 1e-5,
    ),
    const ToolCase(
      'Water 1000 L/min, set 10 bar g, conventional',
      source:
          'fluids 1.3.1 API520_A_l (Kd 0.65, Kw = Kv = 1) 546.431 mm², then '
          'API520_Kv(10E) with Re 652 431 on orifice J: Kv 0.99987 → 546.503 mm² → J',
      choices: {'fluid': 'liquid'},
      numbers: {
        'pset': (10, 'bar'),
        'q': (1000, 'L/min'),
        'g': (1, '-'),
        'mu': (1, 'cP'),
      },
      expect: {
        'a0': (546.4313290963162, 'mm2'),
        'a': (546.5025145685063, 'mm2'),
      },
      expectText: {'letter': 'J'},
      relTol: 1e-5,
    ),
  ],
);
