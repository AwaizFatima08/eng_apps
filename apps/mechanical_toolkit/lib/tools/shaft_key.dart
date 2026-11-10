import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// DIN 6885-1 (1968) / ISO 773 parallel key: shaft Ø range (over, up to),
/// key b × h, shaft keyway depth t1 and hub keyway depth t2. mm.
class ParallelKey {
  const ParallelKey(this.over, this.upTo, this.b, this.h, this.t1, this.t2);
  final double over, upTo, b, h, t1, t2;
  String get name => '${_f(b)} × ${_f(h)}';
  static String _f(double x) => formatNumber(x, sig: 3);
}

const List<ParallelKey> din6885Keys = [
  ParallelKey(6, 8, 2, 2, 1.2, 1.0),
  ParallelKey(8, 10, 3, 3, 1.8, 1.4),
  ParallelKey(10, 12, 4, 4, 2.5, 1.8),
  ParallelKey(12, 17, 5, 5, 3.0, 2.3),
  ParallelKey(17, 22, 6, 6, 3.5, 2.8),
  ParallelKey(22, 30, 8, 7, 4.0, 3.3),
  ParallelKey(30, 38, 10, 8, 5.0, 3.3),
  ParallelKey(38, 44, 12, 8, 5.0, 3.3),
  ParallelKey(44, 50, 14, 9, 5.5, 3.8),
  ParallelKey(50, 58, 16, 10, 6.0, 4.3),
  ParallelKey(58, 65, 18, 11, 7.0, 4.4),
  ParallelKey(65, 75, 20, 12, 7.5, 4.9),
  ParallelKey(75, 85, 22, 14, 9.0, 5.4),
  ParallelKey(85, 95, 25, 14, 9.0, 5.4),
  ParallelKey(95, 110, 28, 16, 10.0, 6.4),
  ParallelKey(110, 130, 32, 18, 11.0, 7.4),
  ParallelKey(130, 150, 36, 20, 12.0, 8.4),
  ParallelKey(150, 170, 40, 22, 13.0, 9.4),
  ParallelKey(170, 200, 45, 25, 15.0, 10.4),
  ParallelKey(200, 230, 50, 28, 17.0, 11.4),
  ParallelKey(230, 260, 56, 32, 20.0, 12.4),
  ParallelKey(260, 290, 63, 32, 20.0, 12.4),
  ParallelKey(290, 330, 70, 36, 22.0, 14.4),
  ParallelKey(330, 380, 80, 40, 25.0, 15.4),
  ParallelKey(380, 440, 90, 45, 28.0, 17.4),
  ParallelKey(440, 500, 100, 50, 31.0, 19.5),
];

/// Key for a shaft Ø in mm ("over … up to and including"), or null.
ParallelKey? keyForShaft(double dMm) {
  for (final k in din6885Keys) {
    if (dMm > k.over && dMm <= k.upTo + 1e-9) return k;
  }
  return null;
}

String _keyText(double dM) {
  final k = keyForShaft(dM * 1000);
  return k == null
      ? 'Outside DIN 6885-1 (Ø 6–500 mm)'
      : '${k.name} mm, t1 ${formatNumber(k.t1)} / t2 ${formatNumber(k.t2)} mm';
}

final shaftKeyTool = ToolDef(
  id: 'shaft_key',
  title: 'Shaft Ø & parallel key',
  summary:
      'Solid shaft diameter for combined bending and torsion (ASME code with '
      'Km/Kt, or ASME B106.1M fatigue form), DIN 6885-1 key size and key '
      'shear / crushing check.',
  icon: Icons.linear_scale,
  keywords: [
    'shaft',
    'diameter',
    'key',
    'keyway',
    'din 6885',
    'iso 773',
    'asme',
    'b106',
    'tresca',
    'torsion',
    'bending',
    'shear',
    'crushing',
    'hub',
  ],
  inputs: [
    const ChoiceInput(
      'task',
      'Calculation',
      options: [
        ChoiceOption('asme', 'Shaft Ø, ASME code'),
        ChoiceOption('b106', 'Shaft Ø, B106.1M'),
        ChoiceOption('key', 'Key size & stress'),
      ],
    ),
    NumberInput(
      'm',
      'Bending moment M',
      quantity: Quantity.torque,
      initial: 500,
      min: 0,
      help: 'Largest resultant moment at the section, √(M_h² + M_v²).',
      visibleWhen: (v) => v.c('task') != 'key',
    ),
    const NumberInput(
      't',
      'Torque T',
      quantity: Quantity.torque,
      initial: 800,
      min: 0,
      help: 'Shaft torque = 9549·P[kW]/n[rpm] N·m.',
    ),
    NumberInput(
      'km',
      'Shock factor bending K_m',
      quantity: Quantity.dimensionless,
      initial: 1.5,
      min: 1,
      max: 3,
      help:
          'Rotating shaft: steady/gradual 1.5; minor shock 1.5–2.0; heavy shock 2.0–3.0. Stationary: 1.0 (gradual), 1.5–2.0 (sudden).',
      visibleWhen: (v) => v.c('task') == 'asme',
    ),
    NumberInput(
      'kt',
      'Shock factor torsion K_t',
      quantity: Quantity.dimensionless,
      initial: 1.0,
      min: 1,
      max: 3,
      help:
          'Rotating shaft: steady/gradual 1.0; minor shock 1.0–1.5; heavy shock 1.5–3.0. Stationary: 1.0 (gradual), 1.5–2.0 (sudden).',
      visibleWhen: (v) => v.c('task') == 'asme',
    ),
    NumberInput(
      'sy',
      'Shaft yield strength S_y',
      quantity: Quantity.stress,
      initial: 350e6,
      min: 0,
      minInclusive: false,
      help:
          'Use the guaranteed minimum (e.g. C45/EN8 normalised ≈ 300–350 MPa, 42CrMo4 QT ≈ 650 MPa).',
      visibleWhen: (v) => v.c('task') != 'key',
    ),
    NumberInput(
      'su',
      'Shaft tensile strength S_u',
      quantity: Quantity.stress,
      initial: 600e6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('task') == 'asme',
    ),
    ChoiceInput(
      'keyway',
      'Keyway at the section',
      options: const [
        ChoiceOption('yes', 'Yes (−25 %)'),
        ChoiceOption('no', 'No'),
      ],
      visibleWhen: (v) => v.c('task') == 'asme',
    ),
    NumberInput(
      'se',
      'Corrected endurance limit S_e',
      quantity: Quantity.stress,
      initial: 200e6,
      min: 0,
      minInclusive: false,
      help:
          'Marin-corrected (surface, size, reliability, temperature…), without K_f.',
      visibleWhen: (v) => v.c('task') == 'b106',
    ),
    NumberInput(
      'kf',
      'Fatigue notch factor K_f',
      quantity: Quantity.dimensionless,
      initial: 2.0,
      min: 1,
      max: 5,
      help:
          'Shigley Table 7-1 first estimates: end-milled keyseat 2.14, sharp shoulder 2.7, well-rounded shoulder 1.7.',
      visibleWhen: (v) => v.c('task') == 'b106',
    ),
    NumberInput(
      'fs',
      'Design factor n',
      quantity: Quantity.dimensionless,
      initial: 2.0,
      min: 1,
      max: 6,
      visibleWhen: (v) => v.c('task') == 'b106',
    ),
    NumberInput(
      'd',
      'Shaft Ø at the key',
      quantity: Quantity.length,
      initial: 0.050,
      min: 0.006,
      minInclusive: false,
      max: 0.5,
      visibleWhen: (v) => v.c('task') == 'key',
    ),
    NumberInput(
      'l',
      'Key length l',
      quantity: Quantity.length,
      initial: 0.070,
      min: 0,
      minInclusive: false,
      help: 'Not longer than the hub; usual practice l ≤ 1.5·d.',
      visibleWhen: (v) => v.c('task') == 'key',
    ),
    ChoiceInput(
      'form',
      'Key form',
      options: const [
        ChoiceOption('A', 'A, round ends'),
        ChoiceOption('B', 'B, square ends'),
      ],
      visibleWhen: (v) => v.c('task') == 'key',
    ),
    NumberInput(
      'tauall',
      'Allowable key shear',
      quantity: Quantity.stress,
      initial: 60e6,
      min: 0,
      minInclusive: false,
      help: 'Plant/maker value. E.g. Shigley: 0.577·S_y(key)/n.',
      visibleWhen: (v) => v.c('task') == 'key',
    ),
    NumberInput(
      'pall',
      'Allowable crushing pressure',
      quantity: Quantity.stress,
      initial: 100e6,
      min: 0,
      minInclusive: false,
      help:
          'Of the weakest of key, shaft and hub. DIN 6892 uses about 0.9·R_e of that part, reduced for shock; cast-iron hubs are lower.',
      visibleWhen: (v) => v.c('task') == 'key',
    ),
  ],
  compute: (v) {
    final task = v.c('task');
    final t = v.n('t');
    final w = <String>[];
    final notes = <String>[];

    if (task == 'key') {
      final d = v.n('d'), l = v.n('l');
      final key = keyForShaft(d * 1000);
      if (key == null) {
        throw ToolInputError('Shaft Ø must be over 6 and up to 500 mm.');
      }
      final b = key.b * 1e-3, h = key.h * 1e-3, t1 = key.t1 * 1e-3;
      final lEff = v.c('form') == 'A' ? l - b : l;
      if (lEff <= 0) {
        throw ToolInputError('Form A key must be longer than its width.');
      }
      final f = 2 * t / d; // tangential force at the shaft surface
      final tau = f / (b * lEff);
      final pHub = f / ((h - t1) * lEff);
      final pShaft = f / (t1 * lEff);
      final p = math.max(pHub, pShaft);
      final tauAll = v.n('tauall'), pAll = v.n('pall');
      final lNeed =
          math.max(f / (b * tauAll), f / ((h - t1) * pAll)) +
          (v.c('form') == 'A' ? b : 0);
      if (l > 1.5 * d) {
        notes.add(
          'l > 1.5·d: the load is not shared evenly along a long key; consider two keys or a spline.',
        );
      }
      return ToolResult(
        [
          ToolOutput.text(
            'key',
            'DIN 6885-1 key b × h',
            _keyText(d),
            level: OutputLevel.primary,
          ),
          ToolOutput(
            'f',
            'Key force 2T/d',
            f,
            quantity: Quantity.force,
            sig: 4,
          ),
          ToolOutput(
            'leff',
            'Bearing length l_eff',
            lEff,
            quantity: Quantity.length,
            sig: 4,
          ),
          ToolOutput(
            'tau',
            'Key shear stress',
            tau,
            quantity: Quantity.stress,
            level: tau <= tauAll ? OutputLevel.ok : OutputLevel.fail,
            sig: 4,
          ),
          ToolOutput(
            'phub',
            'Crushing on hub side',
            pHub,
            quantity: Quantity.stress,
            level: pHub <= pAll ? OutputLevel.ok : OutputLevel.fail,
            sig: 4,
          ),
          ToolOutput(
            'pshaft',
            'Crushing on shaft side',
            pShaft,
            quantity: Quantity.stress,
            level: pShaft <= pAll ? OutputLevel.ok : OutputLevel.fail,
            sig: 4,
          ),
          ToolOutput(
            'lneed',
            'Minimum key length',
            lNeed,
            quantity: Quantity.length,
            level: lNeed <= l ? OutputLevel.ok : OutputLevel.warn,
            sig: 3,
          ),
        ],
        warnings: [
          if (tau > tauAll) 'Key shear stress is above the allowable.',
          if (p > pAll)
            'Crushing pressure is above the allowable: lengthen the key/hub or use two keys.',
        ],
        notes: [
          ...notes,
          'Contact heights: hub side h − t1, shaft side t1 (chamfers ignored — DIN 6892 deducts them, giving slightly higher pressures).',
        ],
      );
    }

    final m = v.n('m'), sy = v.n('sy');
    if (m == 0 && t == 0) {
      throw ToolInputError('Enter a bending moment and/or torque.');
    }
    double d;
    final out = <ToolOutput>[];
    if (task == 'asme') {
      final su = v.n('su'), km = v.n('km'), kt = v.n('kt');
      if (sy > su) {
        throw ToolInputError('Yield strength cannot exceed tensile strength.');
      }
      var tauAll = math.min(0.30 * sy, 0.18 * su);
      if (v.c('keyway') == 'yes') tauAll *= 0.75;
      final te = math.sqrt(math.pow(km * m, 2) + math.pow(kt * t, 2));
      d = math.pow(16 * te / (math.pi * tauAll), 1 / 3).toDouble();
      out.addAll([
        ToolOutput(
          'd',
          'Minimum shaft Ø',
          d,
          quantity: Quantity.length,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'tauall',
          'Allowable shear τ',
          tauAll,
          quantity: Quantity.stress,
          sig: 4,
        ),
        ToolOutput(
          'te',
          'Equivalent torque T_e',
          te,
          quantity: Quantity.torque,
          sig: 4,
        ),
      ]);
    } else {
      final se = v.n('se'), kf = v.n('kf'), n = v.n('fs');
      d = math
          .pow(
            32 *
                n /
                math.pi *
                math.sqrt(
                  math.pow(kf * m / se, 2) + 0.75 * math.pow(t / sy, 2),
                ),
            1 / 3,
          )
          .toDouble();
      out.add(
        ToolOutput(
          'd',
          'Minimum shaft Ø',
          d,
          quantity: Quantity.length,
          level: OutputLevel.primary,
          sig: 4,
        ),
      );
      notes.add(
        'ASME B106.1M-1985 was withdrawn; its equation survives as a textbook method (Shigley DE-elliptic with M_m = T_a = 0).',
      );
      if (se > sy) {
        w.add(
          'S_e is above S_y: check the endurance limit (normally ≤ 0.5·S_u before Marin factors).',
        );
      }
    }
    out.add(ToolOutput.text('key', 'DIN 6885-1 key at this Ø', _keyText(d)));
    notes.add(
      'Round up to a standard shaft size, then check deflection, critical speed and bearing seats separately.',
    );
    return ToolResult(out, warnings: w, notes: notes);
  },
  formula: '''ASME code (max-shear-stress / Tresca with shock factors):
  τ_all = min(0.30·S_y, 0.18·S_u) × 0.75 if keyway
  T_e = √((K_m·M)² + (K_t·T)²)
  d = (16·T_e / (π·τ_all))^(1/3)

ASME B106.1M (fatigue, rotating bending + steady torque):
  d = [32·n/π · √((K_f·M/S_e)² + ¾·(T/S_y)²)]^(1/3)

Parallel key (DIN 6885-1 b × h, t1 by shaft Ø):
  F = 2T/d,  l_eff = l − b (form A) or l (form B)
  τ = F/(b·l_eff)
  p_hub = F/((h − t1)·l_eff),  p_shaft = F/(t1·l_eff)''',
  references: [
    'ASME "Code for Design of Transmission Shafting" (ASA B17c-1927), as given in Bhandari, Design of Machine Elements, §9.13 (K_m, K_t table)',
    'ANSI/ASME B106.1M-1985 Design of Transmission Shafting (withdrawn); Shigley 10th ed. §7-4 Eq. (7-12)',
    'DIN 6885-1:1968 (parallel keys, keyway dimensions); ISO/R 773 (same b × h series)',
    'DIN 6892:2012 Method C (key bearing-pressure check) — simplified',
  ],
  assumptions: [
    'Solid circular shaft; static strength by τ_max (ASME code) or fatigue by B106.1M.',
    'Key carries the whole torque with uniform pressure along l_eff (DIN 6892 load-sharing factors = 1).',
    'Key size from the DIN table is the normal size for the shaft Ø; other sizes may be used by agreement.',
  ],
  cases: const [
    ToolCase(
      'ASME code, M 500, T 800 N·m, K_m 1.5, K_t 1.0, S_y 350, S_u 600 MPa, keyway',
      source:
          'Hand calc (ref_cases.py): τ_all = 0.75·min(105, 108) = 78.75 MPa, T_e 1096.59 N·m, d 41.392 mm',
      numbers: {
        'm': (500, 'N.m'),
        't': (800, 'N.m'),
        'km': (1.5, '-'),
        'kt': (1.0, '-'),
        'sy': (350, 'MPa'),
        'su': (600, 'MPa'),
      },
      expect: {
        'd': (41.3924, 'mm'),
        'tauall': (78.75, 'MPa'),
        'te': (1096.586, 'N.m'),
      },
      expectText: {'key': '12 × 8'},
      relTol: 2e-5,
    ),
    ToolCase(
      'ASME code, heavy shock K_m 2, K_t 1.5, no keyway, S_y 280, S_u 520 MPa',
      source: 'Hand calc: τ_all = min(84, 93.6) = 84 MPa, d = 64.628 mm',
      choices: {'keyway': 'no'},
      numbers: {
        'm': (1200, 'N.m'),
        't': (2500, 'N.m'),
        'km': (2, '-'),
        'kt': (1.5, '-'),
        'sy': (280, 'MPa'),
        'su': (520, 'MPa'),
      },
      expect: {'d': (64.6284, 'mm'), 'tauall': (84, 'MPa')},
      expectText: {'key': '18 × 11'},
      relTol: 2e-5,
    ),
    ToolCase(
      'ASME B106.1M, M 300, T 400 N·m, n 2, K_f 1.8, S_e 180, S_y 420 MPa',
      source: 'Hand calc (ref_cases.py): d = 39.871 mm',
      choices: {'task': 'b106'},
      numbers: {
        'm': (300, 'N.m'),
        't': (400, 'N.m'),
        'fs': (2, '-'),
        'kf': (1.8, '-'),
        'se': (180, 'MPa'),
        'sy': (420, 'MPa'),
      },
      expect: {'d': (39.8711, 'mm')},
      relTol: 2e-5,
    ),
    ToolCase(
      'Key on Ø 50 shaft, T 800 N·m, form A, l = 70 mm',
      source:
          'DIN 6885-1 table (fasten.it): 44 < d ≤ 50 → 14 × 9, t1 5.5; hand calc τ 40.82, p_hub 163.27, p_shaft 103.90 MPa',
      choices: {'task': 'key', 'form': 'A'},
      numbers: {
        't': (800, 'N.m'),
        'd': (50, 'mm'),
        'l': (70, 'mm'),
        'tauall': (60, 'MPa'),
        'pall': (100, 'MPa'),
      },
      expect: {
        'f': (32000, 'N'),
        'tau': (40.8163, 'MPa'),
        'phub': (163.2653, 'MPa'),
        'pshaft': (103.8961, 'MPa'),
      },
      expectText: {'key': '14 × 9'},
      expectWarning: 'Crushing',
      relTol: 2e-5,
    ),
    ToolCase(
      'Key on Ø 30 shaft (range boundary), T 250 N·m, form B, l = 40 mm',
      source:
          'DIN 6885-1: 22 < d ≤ 30 → 8 × 7, t1 4.0; hand calc τ 52.08, p_hub 138.89 MPa',
      choices: {'task': 'key', 'form': 'B'},
      numbers: {
        't': (250, 'N.m'),
        'd': (30, 'mm'),
        'l': (40, 'mm'),
        'tauall': (60, 'MPa'),
        'pall': (150, 'MPa'),
      },
      expect: {'tau': (52.0833, 'MPa'), 'phub': (138.8889, 'MPa')},
      expectText: {'key': '8 × 7'},
      relTol: 2e-5,
    ),
  ],
);
