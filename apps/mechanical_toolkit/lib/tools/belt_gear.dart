import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Exact open-belt length (Shigley Eq. 17-1) for pitch Ø [small], [big]
/// and centre distance [c] (all m).
double openBeltLength(double small, double big, double c) {
  final beta = math.asin((big - small) / (2 * c));
  return 2 * c * math.cos(beta) +
      math.pi * (big + small) / 2 +
      beta * (big - small);
}

final beltGearTool = ToolDef(
  id: 'belt_gear',
  title: 'Belt, pulley & gear ratio',
  summary:
      'Speed ratio and driven speed for belt drives and gear pairs; open-belt '
      'length ⇄ centre distance, wrap angle, belt speed and shaft torques.',
  icon: Icons.settings,
  keywords: [
    'belt',
    'pulley',
    'v-belt',
    'sheave',
    'gear',
    'ratio',
    'teeth',
    'centre distance',
    'center distance',
    'wrap angle',
    'speed',
    'rpm',
  ],
  inputs: [
    const ChoiceInput(
      'drive',
      'Drive',
      options: [
        ChoiceOption('belt', 'Belt / pulleys'),
        ChoiceOption('gear', 'Gear pair'),
      ],
    ),
    ChoiceInput(
      'solve',
      'Find',
      options: const [
        ChoiceOption('len', 'Belt length'),
        ChoiceOption('ctr', 'Centre distance'),
      ],
      visibleWhen: (v) => v.c('drive') == 'belt',
    ),
    NumberInput(
      'd1',
      'Driver pulley pitch Ø',
      quantity: Quantity.length,
      initial: 0.150,
      min: 0,
      minInclusive: false,
      help:
          'V-belts: use the datum (pitch) diameter, not the outside diameter.',
      visibleWhen: (v) => v.c('drive') == 'belt',
    ),
    NumberInput(
      'd2',
      'Driven pulley pitch Ø',
      quantity: Quantity.length,
      initial: 0.300,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('drive') == 'belt',
    ),
    NumberInput(
      'c',
      'Centre distance C',
      quantity: Quantity.length,
      initial: 0.600,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('drive') == 'belt' && v.c('solve') == 'len',
    ),
    NumberInput(
      'l',
      'Belt pitch length L',
      quantity: Quantity.length,
      initial: 1.900,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('drive') == 'belt' && v.c('solve') == 'ctr',
    ),
    NumberInput(
      'slip',
      'Belt slip',
      quantity: Quantity.percent,
      initial: 0,
      min: 0,
      max: 0.1,
      help: 'V-belts typically 1–2 %; synchronous (toothed) belts 0.',
      visibleWhen: (v) => v.c('drive') == 'belt',
    ),
    NumberInput(
      'z1',
      'Driver teeth z₁',
      quantity: Quantity.dimensionless,
      initial: 20,
      min: 1,
      visibleWhen: (v) => v.c('drive') == 'gear',
    ),
    NumberInput(
      'z2',
      'Driven teeth z₂',
      quantity: Quantity.dimensionless,
      initial: 60,
      min: 1,
      visibleWhen: (v) => v.c('drive') == 'gear',
    ),
    const NumberInput(
      'n1',
      'Driver speed n₁',
      quantity: Quantity.rotSpeed,
      initial: 1480,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'power',
      'Power at driver (optional)',
      quantity: Quantity.power,
      initial: 0,
      min: 0,
      help: 'Enter to get shaft torques (and belt pull). 0 = skip.',
    ),
    const NumberInput(
      'eff',
      'Drive efficiency η',
      quantity: Quantity.percent,
      initial: 1,
      min: 0.3,
      max: 1,
      help: 'V-belt ≈ 0.95–0.97; one spur/helical gear mesh ≈ 0.98–0.99.',
    ),
  ],
  compute: (v) {
    final n1 = v.n('n1');
    final power = v.n('power'), eff = v.n('eff');
    final w = <String>[];
    final notes = <String>[];
    final out = <ToolOutput>[];
    double ratio, n2;

    if (v.c('drive') == 'gear') {
      final z1 = v.n('z1'), z2 = v.n('z2');
      if (z1 != z1.roundToDouble() || z2 != z2.roundToDouble()) {
        throw ToolInputError('Tooth counts must be whole numbers.');
      }
      ratio = z2 / z1;
      n2 = n1 / ratio;
      if (math.min(z1, z2) < 17) {
        w.add(
          'Fewer than 17 teeth: a 20° full-depth spur pinion is undercut unless profile-shifted.',
        );
      }
      if (ratio > 6 || ratio < 1 / 6) {
        notes.add(
          'A single gear stage above about 6:1 is unusual; consider two stages.',
        );
      }
    } else {
      final d1 = v.n('d1'), d2 = v.n('d2'), slip = v.n('slip');
      final small = math.min(d1, d2), big = math.max(d1, d2);
      final diff = big - small;
      double c, l;
      if (v.c('solve') == 'ctr') {
        l = v.n('l');
        final lMin = openBeltLength(small, big, diff / 2 + 1e-12);
        if (l <= lMin) {
          throw ToolInputError(
            'Belt too short for these pulleys (needs more than ${formatNumber(lMin * 1000, sig: 4)} mm).',
          );
        }
        var lo = diff / 2 + 1e-12, hi = l; // L > 2C always
        for (var i = 0; i < 200; i++) {
          final mid = (lo + hi) / 2;
          if (openBeltLength(small, big, mid) < l) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        c = (lo + hi) / 2;
        final x = l - math.pi * (big + small) / 2;
        final cApprox =
            0.25 * (x + math.sqrt(math.max(0, x * x - 2 * diff * diff)));
        out.add(
          ToolOutput(
            'c',
            'Centre distance C',
            c,
            quantity: Quantity.length,
            level: OutputLevel.primary,
            sig: 5,
          ),
        );
        out.add(
          ToolOutput(
            'capprox',
            'C, approximate formula',
            cApprox,
            quantity: Quantity.length,
            sig: 5,
          ),
        );
      } else {
        c = v.n('c');
        if (c <= diff / 2) {
          throw ToolInputError(
            'Centre distance must exceed half the diameter difference.',
          );
        }
        l = openBeltLength(small, big, c);
        out.add(
          ToolOutput(
            'l',
            'Belt pitch length L',
            l,
            quantity: Quantity.length,
            level: OutputLevel.primary,
            sig: 5,
          ),
        );
        out.add(
          ToolOutput(
            'lapprox',
            'L, approximate formula',
            2 * c + math.pi * (big + small) / 2 + diff * diff / (4 * c),
            quantity: Quantity.length,
            sig: 5,
          ),
        );
      }
      final wrap = math.pi - 2 * math.asin(diff / (2 * c));
      ratio = d2 / d1;
      n2 = n1 * d1 / d2 * (1 - slip);
      final speed = math.pi * d1 * n1 / 60;
      out.addAll([
        ToolOutput(
          'wrap',
          'Wrap on small pulley (°)',
          wrap * 180 / math.pi,
          sig: 4,
          level: wrap < 120 * math.pi / 180
              ? OutputLevel.warn
              : OutputLevel.normal,
        ),
        ToolOutput(
          'v',
          'Belt speed',
          speed,
          quantity: Quantity.velocity,
          sig: 4,
        ),
      ]);
      if (power > 0) {
        out.add(
          ToolOutput(
            'fe',
            'Effective belt pull P/v',
            power / speed,
            quantity: Quantity.force,
            sig: 4,
          ),
        );
      }
      if (c < (d1 + d2) / 2) {
        w.add(
          'Pulleys overlap: centre distance is less than the sum of the radii.',
        );
      } else if (c < big) {
        notes.add(
          'Centre distance is below the larger pulley Ø; makers usually advise C ≥ D.',
        );
      }
      if (c > 3 * (d1 + d2)) {
        notes.add(
          'Centre distance above 3·(D + d): long spans tend to whip; check with the belt maker.',
        );
      }
      if (wrap < 120 * math.pi / 180) {
        w.add(
          'Wrap angle below 120°: rated power per belt falls sharply (arc-of-contact factor).',
        );
      }
      if (speed > 30) {
        w.add(
          'Belt speed above 30 m/s: beyond classical V-belt limits; check the belt and pulley rating.',
        );
      }
    }

    out.insertAll(0, [
      ToolOutput(
        'ratio',
        'Speed ratio i (no slip)',
        ratio,
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput(
        'n2',
        'Driven speed n₂',
        n2,
        quantity: Quantity.rotSpeed,
        level: OutputLevel.primary,
        sig: 5,
      ),
    ]);
    if (power > 0) {
      out.addAll([
        ToolOutput(
          't1',
          'Driver torque T₁',
          power / (2 * math.pi * n1 / 60),
          quantity: Quantity.torque,
          sig: 4,
        ),
        ToolOutput(
          't2',
          'Driven torque T₂',
          power * eff / (2 * math.pi * n2 / 60),
          quantity: Quantity.torque,
          sig: 4,
        ),
      ]);
    }
    return ToolResult(out, warnings: w, notes: notes);
  },
  formula: '''Belt (pitch Ø d small, D large, centre distance C):
  i = D_driven/D_driver,  n₂ = n₁·D_driver/D_driven·(1 − s)
  β = asin((D − d)/(2C))
  wrap on small pulley θ = π − 2β
  L = 2C·cos β + π(D + d)/2 + β(D − d)        (exact, Shigley 17-1)
  L ≈ 2C + π(D + d)/2 + (D − d)²/(4C)          (approximate)
  C from L: exact equation solved numerically;
  C ≈ ¼{[L − π(D + d)/2] + √([L − π(D + d)/2]² − 2(D − d)²)}
  belt speed v = π·D_driver·n₁/60

Gears:  i = z₂/z₁,  n₂ = n₁·z₁/z₂

Torques:  T₁ = P/ω₁,  T₂ = η·P/ω₂,  ω = 2π·n/60
Belt effective pull  F_e = P/v''',
  references: [
    'Shigley\'s Mechanical Engineering Design, 10th ed., §17-2 Eq. (17-1) (open-belt geometry) and Example 17-1',
    'ISO 4184 / ISO 1081 (V-belt datum lengths and datum diameters)',
    'ISO 1122-1 (gear ratio u = z₂/z₁)',
  ],
  assumptions: [
    'Open (uncrossed) belt on two pulleys; diameters are pitch/datum diameters.',
    'Speed ratio ignores belt slip and creep unless a slip % is entered.',
    'Driven torque includes the entered efficiency; driver torque does not.',
  ],
  cases: const [
    ToolCase(
      'Shigley Example 17-1: 6 in / 18 in pulleys, C = 96 in, 1750 rpm',
      source:
          'Shigley 10th ed. Ex. 17-1: θ_d = 3.0165 rad (172.83°), V = 2749 ft/min; L 230.07 in by Eq. 17-1 (hand calc)',
      numbers: {
        'd1': (6, 'in'),
        'd2': (18, 'in'),
        'c': (96, 'in'),
        'n1': (1750, 'rpm'),
      },
      expect: {
        'wrap': (172.833, '-'),
        'v': (2748.9, 'ft/min'),
        'l': (230.074, 'in'),
        'ratio': (3, '-'),
      },
      relTol: 2e-4,
    ),
    ToolCase(
      'V-belt 150 / 300 mm, C = 600 mm, 1480 rpm, 11 kW',
      source:
          'Hand calc (ref_cases.py): L 1916.25 mm, wrap 165.64°, v 11.624 m/s, T₁ 70.97 N·m, T₂ 141.95 N·m, F_e 946.3 N',
      numbers: {
        'd1': (150, 'mm'),
        'd2': (300, 'mm'),
        'c': (600, 'mm'),
        'n1': (1480, 'rpm'),
        'power': (11, 'kW'),
      },
      expect: {
        'n2': (740, 'rpm'),
        'l': (1916.246, 'mm'),
        'lapprox': (1916.233, 'mm'),
        'wrap': (165.6385, '-'),
        'v': (11.6239, 'm/s'),
        't1': (70.9745, 'N.m'),
        't2': (141.949, 'N.m'),
        'fe': (946.33, 'N'),
      },
      relTol: 2e-5,
    ),
    ToolCase(
      'Centre distance for a 1600 mm belt on 125 / 250 mm pulleys',
      source:
          'Independent bisection of Shigley Eq. 17-1 (ref_cases.py): C 501.577 mm; approximate form 501.582 mm',
      choices: {'solve': 'ctr'},
      numbers: {
        'd1': (125, 'mm'),
        'd2': (250, 'mm'),
        'l': (1600, 'mm'),
        'n1': (960, 'rpm'),
      },
      expect: {
        'c': (501.5767, 'mm'),
        'capprox': (501.5818, 'mm'),
        'wrap': (165.6839, '-'),
        'n2': (480, 'rpm'),
      },
      relTol: 2e-5,
    ),
    ToolCase(
      'Gear pair 20 / 60 teeth, 1480 rpm, 15 kW, η = 98 %',
      source: 'Hand calc: i 3, n₂ 493.33 rpm, T₁ 96.783 N·m, T₂ 284.54 N·m',
      choices: {'drive': 'gear'},
      numbers: {
        'z1': (20, '-'),
        'z2': (60, '-'),
        'n1': (1480, 'rpm'),
        'power': (15, 'kW'),
        'eff': (98, '%'),
      },
      expect: {
        'ratio': (3, '-'),
        'n2': (493.3333, 'rpm'),
        't1': (96.7834, 'N.m'),
        't2': (284.5432, 'N.m'),
      },
      relTol: 2e-5,
    ),
  ],
);
