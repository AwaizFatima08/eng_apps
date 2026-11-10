import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// ISO 281:2007 Table 12 — life modification factor for reliability a1.
const Map<String, double> isoA1 = {
  '90': 1.0,
  '95': 0.64,
  '96': 0.55,
  '97': 0.47,
  '98': 0.37,
  '99': 0.25,
  '99.2': 0.22,
  '99.4': 0.19,
  '99.6': 0.16,
  '99.8': 0.12,
  '99.9': 0.093,
  '99.92': 0.087,
  '99.94': 0.080,
  '99.95': 0.077,
};

final bearingLifeTool = ToolDef(
  id: 'bearing_life',
  title: 'Bearing L10 life (ISO 281)',
  summary:
      'Basic rating life L10 and L10h of rolling bearings, modified life Lnm '
      'with the reliability factor a1 and a user aISO, and the C needed for a '
      'target life.',
  icon: Icons.donut_large,
  keywords: [
    'bearing',
    'l10',
    'life',
    'iso 281',
    'rating life',
    'dynamic load',
    'equivalent load',
    'reliability',
    'a1',
    'aiso',
    'skf',
    'ball',
    'roller',
  ],
  inputs: [
    const ChoiceInput(
      'type',
      'Bearing type',
      options: [
        ChoiceOption('ball', 'Ball (p = 3)'),
        ChoiceOption('roller', 'Roller (p = 10/3)'),
      ],
    ),
    const NumberInput(
      'c',
      'Basic dynamic load rating C',
      quantity: Quantity.force,
      initial: 55.3e3,
      min: 0,
      minInclusive: false,
      help: 'From the bearing maker\'s table for the exact designation.',
    ),
    const NumberInput(
      'fr',
      'Radial load F_r',
      quantity: Quantity.force,
      initial: 3e3,
      min: 0,
    ),
    const NumberInput(
      'fa',
      'Axial load F_a',
      quantity: Quantity.force,
      initial: 0,
      min: 0,
    ),
    const NumberInput(
      'x',
      'Radial factor X',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      help:
          'From the maker\'s table. Pure radial load or F_a/F_r ≤ e: X = 1, Y = 0.',
    ),
    const NumberInput(
      'y',
      'Axial factor Y',
      quantity: Quantity.dimensionless,
      initial: 0,
      min: 0,
    ),
    const NumberInput(
      'n',
      'Speed n',
      quantity: Quantity.rotSpeed,
      initial: 1480,
      min: 0,
      minInclusive: false,
    ),
    ChoiceInput(
      'rel',
      'Reliability',
      options: [
        for (final k in isoA1.keys) ChoiceOption(k, '$k %  (a1 = ${isoA1[k]})'),
      ],
    ),
    const NumberInput(
      'aiso',
      'Life modification factor a_ISO',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0.1,
      max: 50,
      help:
          'From the maker\'s method (lubrication κ, contamination e_C, fatigue limit). 1 = basic life.',
    ),
    const NumberInput(
      'target',
      'Required life (for C needed)',
      quantity: Quantity.time,
      initial: 40000 * 3600.0,
      min: 0,
      minInclusive: false,
      help:
          'Typical: 8 h/day machines 20 000–30 000 h; continuous 24 h plant 40 000–50 000 h.',
    ),
  ],
  compute: (v) {
    final roller = v.c('type') == 'roller';
    final p = roller ? 10 / 3 : 3.0;
    final c = v.n('c'), fr = v.n('fr'), fa = v.n('fa');
    final x = v.n('x'), y = v.n('y'), n = v.n('n');
    final a1 = isoA1[v.c('rel')] ?? 1.0;
    final aiso = v.n('aiso');
    final load = x * fr + y * fa;
    if (load <= 0) {
      throw ToolInputError('Equivalent load P is zero: enter a load and X/Y.');
    }
    final l10 = math.pow(c / load, p).toDouble(); // million revolutions
    final revPerHour = 60 * n;
    final l10h = l10 * 1e6 / revPerHour; // hours
    final lnm = a1 * aiso * l10;
    final lnmh = a1 * aiso * l10h;
    final targetH = v.n('target') / 3600;
    final cReq =
        load * math.pow(targetH * revPerHour / 1e6 / (a1 * aiso), 1 / p);

    final w = <String>[];
    final notes = <String>[];
    if (load > 0.5 * c) {
      w.add(
        'P > 0.5·C: very heavy load, outside the usual range of the life equation — consult the bearing maker.',
      );
    }
    if (fa > 0 && y == 0) {
      w.add('Axial load entered but Y = 0: the axial load is ignored.');
    }
    if (load < fr * 0.999 && fr > 0) {
      w.add('P is less than F_r: check X and Y from the maker\'s table.');
    }
    if (n < 10) {
      notes.add(
        'Below about 10 rpm the bearing should be checked on the static rating C₀ (ISO 76) instead.',
      );
    }
    if (load < 0.01 * c) {
      notes.add(
        'Very light load (P < 0.01·C): risk of roller/ball skidding; check the maker\'s minimum load.',
      );
    }
    notes.add(
      'Lnm uses a1 = $a1 for ${v.c('rel')} % reliability (ISO 281:2007).',
    );
    return ToolResult(
      [
        ToolOutput(
          'p',
          'Equivalent load P',
          load,
          quantity: Quantity.force,
          sig: 4,
        ),
        ToolOutput('cp', 'Load ratio C/P', c / load, sig: 4),
        ToolOutput('l10', 'L10 (million rev)', l10, sig: 5),
        ToolOutput(
          'l10h',
          'L10h',
          l10h * 3600,
          quantity: Quantity.time,
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput('lnm', 'Lnm (million rev)', lnm, sig: 5),
        ToolOutput(
          'lnmh',
          'Lnmh = a1·a_ISO·L10h',
          lnmh * 3600,
          quantity: Quantity.time,
          level: lnmh >= targetH ? OutputLevel.ok : OutputLevel.warn,
          sig: 5,
        ),
        ToolOutput(
          'creq',
          'C for required life',
          cReq,
          quantity: Quantity.force,
          level: cReq <= c ? OutputLevel.ok : OutputLevel.warn,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''P = X·F_r + Y·F_a
L10 = (C/P)^p   [10⁶ rev]      p = 3 ball, 10/3 roller
L10h = 10⁶/(60·n) · L10   [h]
Lnm = a1·a_ISO·L10

a1 (ISO 281:2007 Table 12):
  90 % 1 · 95 % 0.64 · 96 % 0.55 · 97 % 0.47 · 98 % 0.37
  99 % 0.25 · 99.2 % 0.22 · 99.4 % 0.19 · 99.6 % 0.16
  99.8 % 0.12 · 99.9 % 0.093 · 99.92 % 0.087
  99.94 % 0.080 · 99.95 % 0.077
  (= 0.95·[ln(100/S)/ln(100/90)]^(2/3) + 0.05)

C needed = P·(L_h·60·n/10⁶ / (a1·a_ISO))^(1/p)''',
  references: [
    'ISO 281:2007 §6.2 (L10 = (C/P)^p), §6.1 (P = X·F_r + Y·F_a), Table 12 (a1)',
    'SKF Rolling bearings catalogue (PUB BU/P1 17000) — "Selecting bearing size", rating life equations',
    'Shigley\'s Mechanical Engineering Design, 10th ed., §11-3 Example 11-1',
  ],
  assumptions: [
    'C, X, Y and a_ISO come from the bearing maker for the exact bearing.',
    'Constant load and speed; for duty cycles use the maker\'s mean-load method.',
    'a_ISO is entered, not calculated (it needs viscosity ratio κ, e_C and P_u).',
  ],
  cases: const [
    ToolCase(
      'Shigley Example 11-1: C needed for 5000 h at 1725 rpm, 2 kN, ball',
      source:
          'Shigley 10th ed. Ex. 11-1: C10 = 2·(5000·60·1725/10⁶)^(1/3) = 16.06 kN (book rounds to 16.1 kN)',
      numbers: {
        'c': (20, 'kN'),
        'fr': (2, 'kN'),
        'n': (1725, 'rpm'),
        'target': (5000, 'h'),
      },
      expect: {'creq': (16.057, 'kN')},
      relTol: 3e-4,
    ),
    ToolCase(
      'Roller, C = 100 kN, P = 10 kN, 1000 rpm',
      source: 'Hand calc: L10 = 10^(10/3) = 2154.43 ×10⁶ rev, L10h 35 907 h',
      choices: {'type': 'roller'},
      numbers: {'c': (100, 'kN'), 'fr': (10, 'kN'), 'n': (1000, 'rpm')},
      expect: {'l10': (2154.435, '-'), 'l10h': (35907.2, 'h')},
      relTol: 1e-5,
    ),
    ToolCase(
      'Ball, C = 55.3 kN, F_r 3 kN, F_a 1.5 kN, X 0.56, Y 1.6, 1480 rpm, 99 %',
      source:
          'Hand calc: P 4.08 kN, L10 2490.0 ×10⁶ rev, L10h 28 040 h; a1(99 %) = 0.25 (ISO 281:2007 Table 12) → L1h 7010 h',
      choices: {'rel': '99'},
      numbers: {
        'c': (55.3, 'kN'),
        'fr': (3, 'kN'),
        'fa': (1.5, 'kN'),
        'x': (0.56, '-'),
        'y': (1.6, '-'),
        'n': (1480, 'rpm'),
      },
      expect: {
        'p': (4.08, 'kN'),
        'l10': (2489.975, '-'),
        'l10h': (28040.3, 'h'),
        'lnmh': (7010.1, 'h'),
      },
      relTol: 2e-5,
    ),
    ToolCase(
      'Ball, C/P = 10, 3000 rpm, 95 %, a_ISO = 2, required 20 000 h',
      source:
          'Hand calc: L10h 5555.6 h; a1(95 %) 0.64 → Lnmh 7111.1 h; C needed 56.462 kN',
      choices: {'rel': '95'},
      numbers: {
        'c': (40, 'kN'),
        'fr': (4, 'kN'),
        'n': (3000, 'rpm'),
        'aiso': (2, '-'),
        'target': (20000, 'h'),
      },
      expect: {
        'l10h': (5555.56, 'h'),
        'lnmh': (7111.11, 'h'),
        'creq': (56.4622, 'kN'),
      },
      relTol: 2e-5,
    ),
  ],
);
