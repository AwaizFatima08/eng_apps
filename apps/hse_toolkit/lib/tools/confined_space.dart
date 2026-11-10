import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final confinedSpaceTool = ToolDef(
  id: 'confined_space',
  title: 'Confined-space purge time',
  summary:
      'Air changes per hour, purge time to a safe concentration and the fan '
      'flow needed, from the dilution equation with a mixing factor.',
  icon: Icons.air,
  keywords: [
    'confined space',
    'purge',
    'ventilation',
    'air changes',
    'ach',
    'dilution',
    'blower',
    'fan',
    'vessel entry',
    'lel',
    '1910.146',
  ],
  inputs: [
    const NumberInput(
      'vol',
      'Space volume V',
      quantity: Quantity.volume,
      initial: 50,
      min: 0,
      minInclusive: false,
      help: 'Free internal volume of the vessel, tank or pit.',
    ),
    const NumberInput(
      'q',
      'Fresh-air flow Q (delivered)',
      quantity: Quantity.volumeFlow,
      units: ('m3/h', 'cfm'),
      initial: 1000 / 3600,
      min: 0,
      minInclusive: false,
      help:
          'Use the blower curve at the real duct length and bends, not the '
          'free-air rating.',
    ),
    const NumberInput(
      'k',
      'Mixing factor K (1 = perfect)',
      quantity: Quantity.dimensionless,
      initial: 3,
      min: 1,
      max: 10,
      help:
          '1 ideal mixing; ~3 good (duct to far end); 5–10 poor (baffles, '
          'dead corners, heavy vapours). Q_eff = Q / K.',
    ),
    const NumberInput(
      'c0',
      'Initial concentration C₀',
      quantity: Quantity.dimensionless,
      unitSuffix: 'ppm or %LEL',
      initial: 1000,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'c',
      'Target concentration C',
      quantity: Quantity.dimensionless,
      unitSuffix: 'same unit',
      initial: 10,
      min: 0,
      minInclusive: false,
      help:
          'e.g. below 10 % of the OEL, or below 10 %LEL (many permits use '
          '≤ 10 %LEL for entry, 1910.146(b) "hazardous atmosphere").',
    ),
    const NumberInput(
      'tallow',
      'Time available for purging',
      quantity: Quantity.time,
      units: ('min', 'min'),
      initial: 20 * 60,
      min: 0,
      minInclusive: false,
      help: 'Gives the fan flow needed to finish in this time.',
    ),
  ],
  compute: (v) {
    final vol = v.n('vol'), q = v.n('q'), k = v.n('k');
    final c0 = v.n('c0'), c = v.n('c'), tAllow = v.n('tallow');
    if (c >= c0) {
      throw ToolInputError(
        'Target concentration must be below the initial concentration.',
      );
    }
    final ratio = math.log(c0 / c);
    final ach = q / vol * 3600; // per hour
    final nChanges = k * ratio; // air changes needed
    final t = k * vol / q * ratio; // s
    final qReq = k * vol * ratio / tAllow; // m³/s
    final w = <String>[];
    if (k < 2) {
      w.add(
        'K below 2 assumes near-perfect mixing — rarely true in a real '
        'vessel; confirm by gas testing at several points.',
      );
    }
    if (ach < 3) {
      w.add('Fewer than 3 air changes per hour: purging will be very slow.');
    }
    return ToolResult(
      [
        ToolOutput(
          't',
          'Purge time',
          t,
          quantity: Quantity.time,
          units: ('min', 'min'),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'ach',
          'Air changes per hour',
          ach,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput('n', 'Air changes needed', nChanges, sig: 4),
        ToolOutput(
          'qreq',
          'Flow for time available',
          qReq,
          quantity: Quantity.volumeFlow,
          units: ('m3/h', 'cfm'),
          sig: 4,
        ),
        ToolOutput(
          'qeff',
          'Effective flow Q / K',
          q / k,
          quantity: Quantity.volumeFlow,
          units: ('m3/h', 'cfm'),
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'The calculation never replaces gas testing: test O₂, LEL and toxics '
            'before entry and keep ventilating continuously (OSHA '
            '1910.146(c)(5)(ii)(E)–(F)).',
        'Oxygen deficiency: enter the deficit (20.9 − O₂ %) as C₀ and C.',
      ],
    );
  },
  formula: '''Dilution (purge) equation, no further release:
  C(t) = C₀ · exp(−Q·t / (K·V))
  t = (K·V / Q) · ln(C₀ / C)
  Air changes needed  N = K · ln(C₀ / C)
  Air changes per hour  ACH = Q / V   (per h)
  Flow for a time t_a:  Q = K·V·ln(C₀/C) / t_a

K = mixing factor (ACGIH Industrial Ventilation:
Q' = Q / K, K = 1 perfect mixing, up to 10 poor).''',
  references: [
    'ACGIH Industrial Ventilation: A Manual of Recommended Practice for Design, ch. "General industrial ventilation" (purge equation, K factor)',
    'OSHA 29 CFR 1910.146 (permit-required confined spaces), (c)(5)(ii) continuous forced-air ventilation',
    'NIOSH 80-106 Criteria for a recommended standard: working in confined spaces (ventilation)',
    'HSE L101 Safe work in confined spaces (ACoP), ventilation and testing',
  ],
  assumptions: [
    'Fresh air is clean (C = 0) and no contaminant is still being released (sludge, residues, welding fumes keep releasing — the purge never finishes).',
    'Well-defined volume with uniform mixing apart from the K factor.',
    'Flow is the delivered flow at the space, after duct losses.',
  ],
  cases: [
    const ToolCase(
      '50 m³, 1000 m³/h, ideal mixing, 1000 → 10 ppm',
      source:
          'Hand calc: ACH = 20; t = 0.05 h · ln 100 = 13.816 min; N = 4.605',
      numbers: {
        'vol': (50, 'm3'),
        'q': (1000, 'm3/h'),
        'k': (1, '-'),
        'c0': (1000, '-'),
        'c': (10, '-'),
      },
      expect: {'ach': (20, '-'), 't': (13.8155, 'min'), 'n': (4.60517, '-')},
      expectWarning: 'perfect mixing',
      relTol: 1e-4,
    ),
    const ToolCase(
      '1000 ft³ tank, 500 cfm, K = 3, 50 → 5 %LEL',
      source:
          'Hand calc: ACH = 30; t = 3·1000/500·ln 10 = 13.816 min; N = 6.908',
      numbers: {
        'vol': (1000, 'ft3'),
        'q': (500, 'cfm'),
        'k': (3, '-'),
        'c0': (50, '-'),
        'c': (5, '-'),
      },
      expect: {'ach': (30, '-'), 't': (13.8155, 'min'), 'n': (6.90776, '-')},
      relTol: 1e-4,
    ),
    const ToolCase(
      'Fan flow for 30 m³, K = 5, 200 → 10 ppm in 20 min',
      source: 'Hand calc: Q = 5·30·ln 20 / (1/3 h) = 1348.08 m³/h',
      numbers: {
        'vol': (30, 'm3'),
        'q': (1000, 'm3/h'),
        'k': (5, '-'),
        'c0': (200, '-'),
        'c': (10, '-'),
        'tallow': (20, 'min'),
      },
      expect: {'qreq': (1348.08, 'm3/h')},
      relTol: 1e-4,
    ),
    const ToolCase(
      '99.9 % reduction at K = 1 needs ≈ 7 air changes',
      source:
          'Classic rule: N = ln(1000) = 6.908 air changes (ACGIH purge equation)',
      numbers: {
        'vol': (10, 'm3'),
        'q': (100, 'm3/h'),
        'k': (1, '-'),
        'c0': (1000, '-'),
        'c': (1, '-'),
      },
      expect: {'n': (6.90776, '-'), 't': (41.4465, 'min')},
      relTol: 1e-4,
    ),
  ],
);
