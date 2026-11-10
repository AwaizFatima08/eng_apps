import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// ISO 10816-3:2009 Table A.1 / ISO 20816-3:2022 Annex A: zone boundaries,
/// broadband r.m.s. velocity (mm/s) on bearing housings: (A/B, B/C, C/D).
const Map<String, (double, double, double)> _zones = {
  'g1-rigid': (2.3, 4.5, 7.1),
  'g1-flex': (3.5, 7.1, 11.0),
  'g2-rigid': (1.4, 2.8, 4.5),
  'g2-flex': (2.3, 4.5, 7.1),
};

final vibrationSeverityTool = ToolDef(
  id: 'vibration_severity',
  title: 'Vibration severity (ISO 20816-3)',
  summary:
      'Zone A / B / C / D for industrial machines from 15 kW (pumps, fans, '
      'motors, compressors) by machine group and support, with peak, '
      'peak-to-peak and in/s conversion.',
  icon: Icons.vibration,
  keywords: [
    'vibration',
    'iso 10816',
    'iso 20816',
    'severity',
    'zone',
    'velocity',
    'rms',
    'mm/s',
    'in/s',
    'alarm',
    'trip',
    'condition monitoring',
  ],
  inputs: [
    const ChoiceInput(
      'group',
      'Machine group',
      options: [
        ChoiceOption('g1', 'Group 1 (>300 kW)'),
        ChoiceOption('g2', 'Group 2 (15–300 kW)'),
      ],
      help:
          'Group 1: 300 kW–50 MW, or electric machines with shaft height ≥ 315 mm. Group 2: 15–300 kW, or shaft height 160–315 mm.',
    ),
    const ChoiceInput(
      'support',
      'Support',
      options: [
        ChoiceOption('rigid', 'Rigid'),
        ChoiceOption('flex', 'Flexible'),
      ],
      help:
          'Rigid if the lowest machine-plus-support natural frequency in the measured direction is at least 25 % above the main running frequency.',
    ),
    const NumberInput(
      'value',
      'Measured velocity',
      quantity: Quantity.dimensionless,
      initial: 3.0,
      min: 0,
    ),
    const ChoiceInput(
      'kind',
      'Reading is',
      options: [
        ChoiceOption('rms', 'mm/s RMS'),
        ChoiceOption('pk', 'mm/s peak'),
        ChoiceOption('pp', 'mm/s peak-to-peak'),
        ChoiceOption('ipspk', 'in/s peak'),
        ChoiceOption('ipsrms', 'in/s RMS'),
      ],
    ),
    const NumberInput(
      'n',
      'Running speed',
      quantity: Quantity.rotSpeed,
      initial: 1480,
      min: 0,
      minInclusive: false,
    ),
  ],
  compute: (v) {
    final x = v.n('value');
    const r2 = math.sqrt2;
    final rms = switch (v.c('kind')) {
      'pk' => x / r2,
      'pp' => x / (2 * r2),
      'ipspk' => x * 25.4 / r2,
      'ipsrms' => x * 25.4,
      _ => x,
    };
    final (ab, bc, cd) = _zones['${v.c('group')}-${v.c('support')}']!;
    final (zone, level, text) = rms <= ab
        ? ('A', OutputLevel.ok, 'Zone A: newly commissioned machine condition')
        : rms <= bc
        ? (
            'B',
            OutputLevel.ok,
            'Zone B: acceptable for unrestricted long-term operation',
          )
        : rms <= cd
        ? (
            'C',
            OutputLevel.warn,
            'Zone C: unsatisfactory for long-term operation; plan corrective action',
          )
        : ('D', OutputLevel.fail, 'Zone D: severe enough to cause damage');
    final n = v.n('n');
    final w = <String>[];
    final notes = <String>[
      'Conversions assume a single sinusoid (peak = √2·RMS). For broadband signals the true RMS from the analyser is the right input.',
      'Typical settings (operational-limits clause of ISO 10816-3 / 20816-3): ALARM = baseline + 25 % of the B/C boundary, usually not above 1.25 × B/C; TRIP usually not above 1.25 × C/D.',
    ];
    if (n < 120) {
      w.add(
        'Below 120 rpm the machine is outside the scope of ISO 10816-3 / 20816-3.',
      );
    } else if (n < 600) {
      notes.add(
        'Below 600 rpm measure over 2–1000 Hz and also check the displacement criteria of Annex A.',
      );
    } else {
      notes.add(
        'Measure broadband velocity over 10–1000 Hz on the bearing housings.',
      );
    }
    if (n > 30000) {
      w.add(
        'Above 30 000 rpm the machine is outside the scope of ISO 20816-3.',
      );
    }
    return ToolResult(
      [
        ToolOutput.text('zone', 'Zone $zone', text, level: level),
        ToolOutput(
          'rms',
          'Velocity, mm/s RMS',
          rms,
          sig: 4,
          level: OutputLevel.primary,
        ),
        ToolOutput('ipspk', 'Equivalent, in/s peak', rms * r2 / 25.4, sig: 3),
        ToolOutput('ab', 'A/B boundary, mm/s RMS', ab, sig: 3),
        ToolOutput('bc', 'B/C boundary, mm/s RMS', bc, sig: 3),
        ToolOutput('cd', 'C/D boundary, mm/s RMS', cd, sig: 3),
        ToolOutput(
          'ratio',
          'Reading / B/C boundary',
          rms / bc,
          quantity: Quantity.percent,
          sig: 3,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''v_rms = v_pk/√2 = v_pp/(2√2)        (pure sinusoid)
1 in/s = 25.4 mm/s

Zone boundaries, mm/s RMS (A/B · B/C · C/D):
  Group 1, rigid      2.3 · 4.5 · 7.1
  Group 1, flexible   3.5 · 7.1 · 11.0
  Group 2, rigid      1.4 · 2.8 · 4.5
  Group 2, flexible   2.3 · 4.5 · 7.1
A reading equal to a boundary is taken in the lower zone.''',
  references: [
    'ISO 20816-3:2022 Annex A (zone boundaries for broadband velocity) and its guidance on setting ALARM and TRIP values',
    'ISO 10816-3:2009 Table A.1 (same velocity boundaries) — superseded by ISO 20816-3',
  ],
  assumptions: [
    'Broadband velocity measured on bearing housings in the radial direction at normal operating speed and load.',
    'Values are evaluation guides; the machine builder\'s or contract limits take precedence.',
    'Pumps with integral drivers and machines under ISO 20816 parts 2, 4, 5, 7, 8 have their own limits.',
  ],
  cases: const [
    ToolCase(
      'Group 2, rigid, 3.0 mm/s RMS',
      source:
          'ISO 10816-3:2009 Table A.1: group 2 rigid boundaries 1.4 / 2.8 / 4.5 mm/s → zone C',
      choices: {'group': 'g2', 'support': 'rigid', 'kind': 'rms'},
      numbers: {'value': (3.0, '-')},
      expect: {'rms': (3.0, '-'), 'bc': (2.8, '-'), 'cd': (4.5, '-')},
      expectText: {'zone': 'Zone C'},
    ),
    ToolCase(
      'Group 1, flexible, 0.25 in/s peak',
      source:
          'Hand conversion 0.25·25.4/√2 = 4.490 mm/s RMS; Table A.1 group 1 flexible 3.5 / 7.1 / 11 → zone B',
      choices: {'group': 'g1', 'support': 'flex', 'kind': 'ipspk'},
      numbers: {'value': (0.25, '-')},
      expect: {'rms': (4.4901, '-'), 'ab': (3.5, '-')},
      expectText: {'zone': 'Zone B'},
      relTol: 1e-4,
    ),
    ToolCase(
      'Group 1, rigid, 12 mm/s peak-to-peak',
      source:
          'Hand conversion 12/(2√2) = 4.243 mm/s RMS; Table A.1 group 1 rigid 2.3 / 4.5 / 7.1 → zone B',
      choices: {'group': 'g1', 'support': 'rigid', 'kind': 'pp'},
      numbers: {'value': (12, '-')},
      expect: {'rms': (4.2426, '-')},
      expectText: {'zone': 'Zone B'},
      relTol: 1e-4,
    ),
    ToolCase(
      'Group 2, flexible, 8 mm/s RMS',
      source:
          'ISO 10816-3:2009 Table A.1: group 2 flexible C/D = 7.1 mm/s → zone D',
      choices: {'group': 'g2', 'support': 'flex', 'kind': 'rms'},
      numbers: {'value': (8, '-')},
      expect: {'cd': (7.1, '-')},
      expectText: {'zone': 'Zone D'},
    ),
    ToolCase(
      'Group 2, rigid, exactly 2.8 mm/s (boundary), 400 rpm',
      source:
          'Table A.1 B/C = 2.8 mm/s; boundary value taken in the lower zone → B',
      choices: {'group': 'g2', 'support': 'rigid', 'kind': 'rms'},
      numbers: {'value': (2.8, '-'), 'n': (400, 'rpm')},
      expectText: {'zone': 'Zone B'},
    ),
  ],
);
