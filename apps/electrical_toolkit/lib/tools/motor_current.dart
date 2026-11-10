import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// IEC 60034-30-1:2014 IE3 minimum nominal efficiency at 50 Hz, %, as
/// (kW, 2-pole, 4-pole, 6-pole). Cross-checked: EU Regulation 2019/1781
/// Annex I Table 2 and ABB technical note 9AKK107319 Table 1 (ABB prints the
/// 18.5 kW 2-pole value as 82.4 — a typo; 92.4 used). 200–1000 kW share one row.
const List<(double, double, double, double)> ie3Table = [
  (0.75, 80.7, 82.5, 78.9),
  (1.1, 82.7, 84.1, 81.0),
  (1.5, 84.2, 85.3, 82.5),
  (2.2, 85.9, 86.7, 84.3),
  (3, 87.1, 87.7, 85.6),
  (4, 88.1, 88.6, 86.8),
  (5.5, 89.2, 89.6, 88.0),
  (7.5, 90.1, 90.4, 89.1),
  (11, 91.2, 91.4, 90.3),
  (15, 91.9, 92.1, 91.2),
  (18.5, 92.4, 92.6, 91.7),
  (22, 92.7, 93.0, 92.2),
  (30, 93.3, 93.6, 92.9),
  (37, 93.7, 93.9, 93.3),
  (45, 94.0, 94.2, 93.7),
  (55, 94.3, 94.6, 94.1),
  (75, 94.7, 95.0, 94.6),
  (90, 95.0, 95.2, 94.9),
  (110, 95.2, 95.4, 95.1),
  (132, 95.4, 95.6, 95.4),
  (160, 95.6, 95.8, 95.6),
  (200, 95.8, 96.0, 95.8),
];

/// IE3 efficiency (fraction) for [kw] and [poles]: the value of the next
/// lower rated output (conservative for intermediate ratings).
double ie3Efficiency(double kw, String poles) {
  if (kw < 0.75 - 1e-9 || kw > 1000 + 1e-9) {
    throw ToolInputError(
      'IE3 values cover 0.75–1000 kW: enter the nameplate efficiency.',
    );
  }
  final row = ie3Table.lastWhere((r) => r.$1 <= kw + 1e-9);
  final pct = switch (poles) {
    '2' => row.$2,
    '6' => row.$4,
    _ => row.$3,
  };
  return pct / 100;
}

/// IEC 60269 preferred fuse ratings, A (used for aM back-up guidance).
const List<double> fuseRatings = [
  2, 4, 6, 10, 16, 20, 25, 32, 40, 50, 63, 80, 100, 125, 160, 200, 250, //
  315, 400, 500, 630, 800, 1000, 1250,
];

final motorCurrentTool = ToolDef(
  id: 'motor_current',
  title: 'Motor current & starter',
  summary:
      'Full-load current of a 3-phase induction motor from kW, voltage, '
      'efficiency (IE3 default) and power factor; DOL and star-delta starting '
      'current; typical overload, breaker, fuse and contactor guidance.',
  icon: Icons.settings,
  keywords: [
    'motor',
    'fla',
    'full load current',
    'ie3',
    'efficiency',
    'dol',
    'star delta',
    'starter',
    'overload',
    'mpcb',
    'contactor',
    'fuse',
  ],
  inputs: [
    const NumberInput(
      'p',
      'Rated output (shaft)',
      quantity: Quantity.power,
      initial: 30000,
      min: 0,
      minInclusive: false,
      units: ('kW', 'hp'),
    ),
    const NumberInput(
      'v',
      'Line voltage',
      quantity: Quantity.voltageV,
      initial: 400,
      min: 0,
      minInclusive: false,
    ),
    const ChoiceInput(
      'poles',
      'Poles (50 Hz speed)',
      initial: '4',
      options: [
        ChoiceOption('2', '2-pole (3000 rpm)'),
        ChoiceOption('4', '4-pole (1500 rpm)'),
        ChoiceOption('6', '6-pole (1000 rpm)'),
      ],
    ),
    const ChoiceInput(
      'effmode',
      'Efficiency',
      options: [
        ChoiceOption('ie3', 'IE3 minimum (typical)'),
        ChoiceOption('user', 'Nameplate value'),
      ],
    ),
    NumberInput(
      'eta',
      'Nameplate efficiency η',
      quantity: Quantity.percent,
      initial: 0.936,
      min: 0.3,
      max: 1,
      minInclusive: false,
      visibleWhen: (v) => v.c('effmode') == 'user',
    ),
    const NumberInput(
      'pf',
      'Power factor cos φ',
      quantity: Quantity.dimensionless,
      initial: 0.84,
      min: 0.3,
      max: 1,
      help:
          'Nameplate. Typical 4-pole IE3: 0.75–0.83 up to 7.5 kW, 0.82–0.84 '
          'for 11–55 kW, 0.85–0.86 from 75 kW; 6/8-pole lower.',
    ),
    const ChoiceInput(
      'start',
      'Starting method',
      options: [
        ChoiceOption('dol', 'Direct on line'),
        ChoiceOption('yd', 'Star-delta'),
      ],
    ),
    const NumberInput(
      'lr',
      'Locked-rotor ratio Is/In',
      quantity: Quantity.dimensionless,
      initial: 7,
      min: 1,
      max: 15,
      help: 'Catalogue value; IE3 motors typically 6–8.',
    ),
  ],
  compute: (v) {
    final p = v.n('p'), u = v.n('v'), pf = v.n('pf'), lr = v.n('lr');
    final kw = p / 1000;
    final eta = v.c('effmode') == 'user'
        ? v.n('eta')
        : ie3Efficiency(kw, v.c('poles'));
    final pin = p / eta;
    final s = pin / pf;
    final iN = s / (math.sqrt(3) * u);
    final yd = v.c('start') == 'yd';
    final iDol = lr * iN;
    final iStart = yd ? iDol / 3 : iDol;
    final ol = yd ? iN / math.sqrt(3) : iN;
    final fuse = fuseRatings.firstWhere(
      (r) => r >= iN - 1e-9,
      orElse: () => double.nan,
    );

    final w = <String>[];
    final notes = <String>[
      'Starter guidance is typical only: select devices from the maker\'s '
          'IEC 60947-4-1 Type 2 coordination tables for this motor.',
      'Use the nameplate current when known; this calculation is for planning.',
    ];
    if (v.c('effmode') == 'ie3') {
      final exact = ie3Table.any((r) => (r.$1 - kw).abs() < 1e-9) || kw >= 200;
      notes.add(
        exact
            ? 'IE3 is a minimum: real IE3 motors are often 0.5–1 % better.'
            : 'Not a standard rating: IE3 value of the next lower rating used.',
      );
    }
    if (yd && kw < 4) {
      w.add('Star-delta is unusual below about 4 kW; DOL is normal.');
    }
    if (yd) {
      notes.add(
        'Star-delta: torque in star is ⅓ of DOL; the load must accelerate '
        'on it. Switch-over transient can approach DOL current.',
      );
    }
    if (pf < 0.7) w.add('cos φ < 0.7 is low for a loaded motor: check input.');
    return ToolResult(
      [
        ToolOutput(
          'in',
          'Full-load current In',
          iN,
          quantity: Quantity.currentA,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput('eta', 'Efficiency used', eta, quantity: Quantity.percent),
        ToolOutput(
          'pin',
          'Electrical input',
          pin,
          quantity: Quantity.power,
          units: ('kW', 'kW'),
          sig: 4,
        ),
        ToolOutput(
          's',
          'Apparent power',
          s,
          quantity: Quantity.apparentPower,
          sig: 4,
        ),
        ToolOutput(
          'idol',
          'DOL starting current',
          iDol,
          quantity: Quantity.currentA,
          sig: 4,
        ),
        ToolOutput(
          'istart',
          yd ? 'Star-delta start current' : 'Starting current',
          iStart,
          quantity: Quantity.currentA,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'ol',
          'Overload relay setting',
          ol,
          quantity: Quantity.currentA,
          sig: 3,
        ),
        ToolOutput.text(
          'olnote',
          'Overload (typical)',
          yd
              ? 'Relay in the delta (phase) circuit: set 0.58 × In. Class 10 '
                    'normal start, 20/30 heavy start.'
              : 'Set to nameplate In. Class 10 normal start, 20/30 heavy '
                    'start (IEC 60947-4-1).',
        ),
        ToolOutput.text(
          'cb',
          'Breaker (typical)',
          'Motor-protection breaker whose Ir range covers In; magnetic '
              'trip about 12–13 × In (≈ ${formatNumber(12 * iN, sig: 3)} A) '
              'must clear the starting inrush.',
        ),
        ToolOutput(
          'fuse',
          'aM fuse, next size ≥ In',
          fuse,
          quantity: Quantity.currentA,
          sig: 4,
        ),
        ToolOutput.text(
          'contactor',
          'Contactors AC-3 (typ.)',
          yd
              ? 'Main and delta ≥ 0.58 × In (${formatNumber(ol, sig: 3)} A), '
                    'star ≥ 0.33 × In (${formatNumber(iN / 3, sig: 3)} A).'
              : 'Line contactor AC-3 ≥ In.',
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''Full-load current (3-phase):
  In = P / (√3 · U · η · cos φ)
  P = rated shaft output, U = line voltage

Input power  Pin = P / η;   S = Pin / cos φ

Starting (typical):
  DOL:         Is = (Is/In) · In
  Star-delta:  Is,YΔ = Is / 3   (winding sees U/√3, line Is/3)
  Overload relay: DOL → In;  in the delta phase circuit → In/√3

η default: IEC 60034-30-1 IE3 minimum, 50 Hz,
next lower rated output for intermediate ratings.''',
  references: [
    'IEC 60034-30-1:2014, Table 2 (IE3 minimum efficiency, 50 Hz); reproduced in EU Regulation 2019/1781 Annex I Table 2',
    'ABB Technical Application Paper No. 7, Three-phase asynchronous motors (In formula, star-delta, trip classes, Annex A worked values)',
    'IEC 60947-4-1 (contactors and motor starters: trip classes 10A/10/20/30, AC-3)',
    'IEC 60269-1/-2 (fuse preferred ratings; aM motor back-up fuses)',
  ],
  assumptions: [
    'Three-phase cage induction motor at rated load, balanced supply at rated voltage and 50 Hz.',
    'Starter, breaker and fuse values are planning guidance, labelled typical — not a coordination study.',
  ],
  cases: [
    const ToolCase(
      'ABB example: 75 kW 4-pole, 415 V, η 95.0 %, cos φ 0.82',
      source: 'ABB Technical Application Paper 7, Annex A Table A2: Ie = 134 A',
      choices: {'effmode': 'user'},
      numbers: {
        'p': (75, 'kW'),
        'v': (415, 'V'),
        'eta': (95.0, '%'),
        'pf': (0.82, '-'),
      },
      expect: {'in': (134, 'A')},
      relTol: 5e-3,
    ),
    const ToolCase(
      '30 kW 4-pole IE3 default, 400 V, cos φ 0.84',
      source:
          'IEC 60034-30-1 IE3 4-pole 30 kW = 93.6 %; hand calc In = 55.07 A, '
          'S = 38.16 kVA (ABB M3BP 200MLA4 catalogue: 54.8 A)',
      numbers: {'p': (30, 'kW'), 'v': (400, 'V'), 'pf': (0.84, '-')},
      expect: {
        'eta': (93.6, '%'),
        'in': (55.0739, 'A'),
        's': (38.1563, 'kVA'),
        'fuse': (63, 'A'),
      },
    ),
    const ToolCase(
      '7.5 kW 4-pole IE3, star-delta, Is/In 6.7',
      source:
          'IE3 4-pole 7.5 kW = 90.4 %; ABB M3BP 132SME4 cos φ 0.79, Is/In 6.7 '
          '(catalogue In 15.6 A). Hand calc: In 15.158 A, DOL 101.56 A, '
          'YΔ 33.85 A, relay 8.75 A',
      choices: {'start': 'yd'},
      numbers: {
        'p': (7.5, 'kW'),
        'v': (400, 'V'),
        'pf': (0.79, '-'),
        'lr': (6.7, '-'),
      },
      expect: {
        'in': (15.1581, 'A'),
        'idol': (101.559, 'A'),
        'istart': (33.8531, 'A'),
        'ol': (8.7515, 'A'),
      },
    ),
    const ToolCase(
      '9 kW 2-pole (non-standard rating) uses 7.5 kW IE3 value',
      source:
          'IE3 2-pole 7.5 kW = 90.1 % (next lower rating); hand calc '
          'In = 9000/(√3·400·0.901·0.86) = 16.765 A',
      choices: {'poles': '2'},
      numbers: {'p': (9, 'kW'), 'v': (400, 'V'), 'pf': (0.86, '-')},
      expect: {'eta': (90.1, '%'), 'in': (16.7648, 'A')},
    ),
  ],
);
