import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'iso286_data.dart';

/// (upper, lower) deviation in µm for a shaft letter/grade at step [i].
(double, double) shaftDeviations(String letter, int grade, int i) {
  final it = itGrades[grade]![i].toDouble();
  if (letter == 'js') return (it / 2, -it / 2);
  final fd = shaftFundamental[letter]![i].toDouble();
  if ('cdefgh'.contains(letter)) return (fd, fd - it);
  final ei = letter == 'k' && (grade < 4 || grade > 7) ? 0.0 : fd;
  return (ei + it, ei);
}

/// (upper, lower) deviation in µm for a hole letter/grade (D–H, JS only).
(double, double) holeDeviations(String letter, int grade, int i) {
  final it = itGrades[grade]![i].toDouble();
  if (letter == 'JS') return (it / 2, -it / 2);
  final ei = -shaftFundamental[letter.toLowerCase()]![i].toDouble();
  return (ei + it, ei);
}

const _fits = {
  'H7/g6': ('H', 7, 'g', 6),
  'H7/h6': ('H', 7, 'h', 6),
  'H7/js6': ('H', 7, 'js', 6),
  'H7/k6': ('H', 7, 'k', 6),
  'H7/n6': ('H', 7, 'n', 6),
  'H7/p6': ('H', 7, 'p', 6),
  'H7/s6': ('H', 7, 's', 6),
  'H8/f7': ('H', 8, 'f', 7),
  'H9/d9': ('H', 9, 'd', 9),
  'H11/c11': ('H', 11, 'c', 11),
};

const _grades = [
  ChoiceOption('5', 'IT5'),
  ChoiceOption('6', 'IT6'),
  ChoiceOption('7', 'IT7'),
  ChoiceOption('8', 'IT8'),
  ChoiceOption('9', 'IT9'),
  ChoiceOption('10', 'IT10'),
  ChoiceOption('11', 'IT11'),
];

bool _custom(ToolValues v) => v.c('fit') == 'custom';

final isoFitsTool = ToolDef(
  id: 'iso_fits',
  title: 'ISO fits & tolerances (ISO 286)',
  summary:
      'Hole and shaft limits, clearance or interference and fit type for '
      'common hole-basis fits or any D–H/JS hole with c–s shaft, IT5–IT11, '
      'sizes up to 500 mm.',
  icon: Icons.straighten,
  keywords: [
    'fit',
    'tolerance',
    'iso 286',
    'limits',
    'clearance',
    'interference',
    'transition',
    'h7',
    'g6',
    'k6',
    'p6',
    'it grade',
    'press fit',
    'bearing seat',
  ],
  inputs: [
    const NumberInput(
      'size',
      'Nominal size',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.050,
      min: 0,
      minInclusive: false,
      max: 0.5,
    ),
    ChoiceInput(
      'fit',
      'Fit',
      initial: 'H7/k6',
      options: [
        const ChoiceOption('H7/g6', 'H7/g6 sliding'),
        const ChoiceOption('H7/h6', 'H7/h6 locational clearance'),
        const ChoiceOption('H7/js6', 'H7/js6 transition'),
        const ChoiceOption('H7/k6', 'H7/k6 transition'),
        const ChoiceOption('H7/n6', 'H7/n6 transition (tight)'),
        const ChoiceOption('H7/p6', 'H7/p6 light press'),
        const ChoiceOption('H7/s6', 'H7/s6 medium press'),
        const ChoiceOption('H8/f7', 'H8/f7 running'),
        const ChoiceOption('H9/d9', 'H9/d9 loose running'),
        const ChoiceOption('H11/c11', 'H11/c11 loose'),
        const ChoiceOption('custom', 'Other hole / shaft'),
      ],
    ),
    ChoiceInput(
      'hl',
      'Hole letter',
      initial: 'H',
      options: const [
        ChoiceOption('D', 'D'),
        ChoiceOption('E', 'E'),
        ChoiceOption('F', 'F'),
        ChoiceOption('G', 'G'),
        ChoiceOption('H', 'H'),
        ChoiceOption('JS', 'JS'),
      ],
      visibleWhen: _custom,
    ),
    ChoiceInput(
      'hg',
      'Hole grade',
      initial: '7',
      options: _grades,
      visibleWhen: _custom,
    ),
    ChoiceInput(
      'sl',
      'Shaft letter',
      initial: 'h',
      options: const [
        ChoiceOption('c', 'c'),
        ChoiceOption('d', 'd'),
        ChoiceOption('e', 'e'),
        ChoiceOption('f', 'f'),
        ChoiceOption('g', 'g'),
        ChoiceOption('h', 'h'),
        ChoiceOption('js', 'js'),
        ChoiceOption('k', 'k'),
        ChoiceOption('m', 'm'),
        ChoiceOption('n', 'n'),
        ChoiceOption('p', 'p'),
        ChoiceOption('r', 'r'),
        ChoiceOption('s', 's'),
      ],
      visibleWhen: _custom,
    ),
    ChoiceInput(
      'sg',
      'Shaft grade',
      initial: '6',
      options: _grades,
      visibleWhen: _custom,
    ),
  ],
  compute: (v) {
    final mm = v.n('size') * 1000;
    final i = isoStepIndex(mm);
    if (i < 0) throw ToolInputError('Nominal size must be up to 500 mm.');
    final (String hl, int hg, String sl, int sg) = _custom(v)
        ? (v.c('hl'), int.parse(v.c('hg')), v.c('sl'), int.parse(v.c('sg')))
        : _fits[v.c('fit')]!;
    final (es0, ei0) = holeDeviations(hl, hg, i);
    final (es1, ei1) = shaftDeviations(sl, sg, i);
    final cMax = es0 - ei1; // largest hole − smallest shaft
    final cMin = ei0 - es1; // smallest hole − largest shaft
    final type = cMin >= 0
        ? 'Clearance fit'
        : cMax <= 0
        ? 'Interference fit'
        : 'Transition fit';
    final lo = i == 0 ? 0 : isoSteps[i - 1], hi = isoSteps[i];
    const um = 1e-6;
    final w = <String>[];
    final notes = <String>[
      'Size step: over ${formatNumber(lo.toDouble())} up to ${formatNumber(hi)} mm.',
    ];
    if (sl == 'k' && (sg < 4 || sg > 7)) {
      notes.add('k for grades above 7: ei = 0 (ISO 286-1 Table 3).');
    }
    if (mm < 1 && 'cd'.contains(sl)) {
      w.add('ISO 286 does not define c/d shafts below 1 mm.');
    }
    if ((sl == 'js' || hl == 'JS') && (sg >= 7 || hg >= 7)) {
      notes.add(
        'js/JS = ±IT/2 exactly; older tables round odd IT7–IT11 values down to even µm.',
      );
    }
    return ToolResult(
      [
        ToolOutput.text(
          'type',
          'Fit $hl$hg/$sl$sg',
          type,
          level: OutputLevel.primary,
        ),
        ToolOutput(
          'cmax',
          'Max clearance (− = interf.)',
          cMax * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'cmin',
          'Min clearance (− = interf.)',
          cMin * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'hes',
          'Hole upper dev. ES',
          es0 * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          sig: 4,
        ),
        ToolOutput(
          'hei',
          'Hole lower dev. EI',
          ei0 * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          sig: 4,
        ),
        ToolOutput(
          'ses',
          'Shaft upper dev. es',
          es1 * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          sig: 4,
        ),
        ToolOutput(
          'sei',
          'Shaft lower dev. ei',
          ei1 * um,
          quantity: Quantity.length,
          units: ('um', 'mil'),
          sig: 4,
        ),
        ToolOutput(
          'hmax',
          'Hole max',
          (mm + es0 / 1000) / 1000,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 8,
        ),
        ToolOutput(
          'hmin',
          'Hole min',
          (mm + ei0 / 1000) / 1000,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 8,
        ),
        ToolOutput(
          'smax',
          'Shaft max',
          (mm + es1 / 1000) / 1000,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 8,
        ),
        ToolOutput(
          'smin',
          'Shaft min',
          (mm + ei1 / 1000) / 1000,
          quantity: Quantity.length,
          units: ('mm', 'in'),
          sig: 8,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''IT = standard tolerance (ISO 286-1 Table 1)
Shafts:  a–h  es = fundamental deviation,  ei = es − IT
         js   es = +IT/2,  ei = −IT/2
         k–s  ei = fundamental deviation,  es = ei + IT
         (k: ei from the table for IT4–IT7, else 0)
Holes:   D–H  EI = −es(shaft, same letter),  ES = EI + IT
         JS   ±IT/2

Max clearance = ES − ei      Min clearance = EI − es
  Min clearance ≥ 0  → clearance fit
  Max clearance ≤ 0  → interference fit
  otherwise          → transition fit
(negative clearance = interference)''',
  references: [
    'ISO 286-1:2010 Table 1 (IT grades), Tables 2–3 (shaft fundamental deviations), §5.3.2 (hole rule EI = −es for A–H)',
    'ISO 286-2:2010 (tables of limit deviations; used for the worked cases)',
    'ISO 1829 / BS 4500 recommended hole-basis fits',
  ],
  assumptions: [
    'Size steps are "over … up to and including"; the step boundary value belongs to the lower step.',
    'Hole letters J–ZC (which need the Δ rule) are not included.',
    'Limits are at 20 °C (ISO 1); thermal expansion of the parts is not considered.',
  ],
  cases: const [
    ToolCase(
      'Ø25 H7/g6',
      source:
          'ISO 286-2 tables (RoyMech): H7 +21/0, g6 −7/−20 → clearance 41/7 µm',
      choices: {'fit': 'H7/g6'},
      numbers: {'size': (25, 'mm')},
      expect: {
        'hes': (21, 'um'),
        'hei': (0, 'um'),
        'ses': (-7, 'um'),
        'sei': (-20, 'um'),
        'cmax': (41, 'um'),
        'cmin': (7, 'um'),
      },
      expectText: {'type': 'Clearance'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø50 H7/s6',
      source:
          'ISO 286-2 tables (RoyMech): H7 +25/0, s6 +59/+43 → interference 18–59 µm',
      choices: {'fit': 'H7/s6'},
      numbers: {'size': (50, 'mm')},
      expect: {
        'ses': (59, 'um'),
        'sei': (43, 'um'),
        'cmax': (-18, 'um'),
        'cmin': (-59, 'um'),
      },
      expectText: {'type': 'Interference'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø100 H7/k6 (bearing seat)',
      source:
          'ISO 286-2 tables (RoyMech): H7 +35/0, k6 +25/+3 → +32 clearance / 25 interference',
      choices: {'fit': 'H7/k6'},
      numbers: {'size': (100, 'mm')},
      expect: {
        'hes': (35, 'um'),
        'ses': (25, 'um'),
        'sei': (3, 'um'),
        'cmax': (32, 'um'),
        'cmin': (-25, 'um'),
      },
      expectText: {'type': 'Transition'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø400 H9/d9 (step boundary)',
      source:
          'ISO 286-1 Tables 1–2 via RoyMech: 355–400 step, IT9 140, d es −210 → d9 −210/−350; clearance 490/210 µm',
      choices: {'fit': 'H9/d9'},
      numbers: {'size': (400, 'mm')},
      expect: {
        'hes': (140, 'um'),
        'ses': (-210, 'um'),
        'sei': (-350, 'um'),
        'cmax': (490, 'um'),
        'cmin': (210, 'um'),
      },
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø10 H11/c11',
      source:
          'ISO 286-1 via RoyMech: 6–10 step, IT11 90, c −80 → c11 −80/−170; clearance 260/80 µm',
      choices: {'fit': 'H11/c11'},
      numbers: {'size': (10, 'mm')},
      expect: {
        'hes': (90, 'um'),
        'sei': (-170, 'um'),
        'cmax': (260, 'um'),
        'cmin': (80, 'um'),
      },
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø30 H7/js6',
      source: 'ISO 286-2 tables (RoyMech): js6 ±6.5 at 18–30 → +27.5 / −6.5 µm',
      choices: {'fit': 'H7/js6'},
      numbers: {'size': (30, 'mm')},
      expect: {'ses': (6.5, 'um'), 'cmax': (27.5, 'um'), 'cmin': (-6.5, 'um')},
      expectText: {'type': 'Transition'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø150 H7/p6',
      source:
          'ISO 286-2 tables (RoyMech): H7 +40/0, p6 +68/+43 → interference 3–68 µm',
      choices: {'fit': 'H7/p6'},
      numbers: {'size': (150, 'mm')},
      expect: {
        'cmax': (-3, 'um'),
        'cmin': (-68, 'um'),
        'smax': (150.068, 'mm'),
      },
      expectText: {'type': 'Interference'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø40 G7/h6 (custom, shaft-basis)',
      source:
          'ISO 286-1 via RoyMech: G EI = +9 (−es of g), IT7 25 → G7 +34/+9; h6 0/−16 → clearance 50/9 µm',
      choices: {'fit': 'custom', 'hl': 'G', 'hg': '7', 'sl': 'h', 'sg': '6'},
      numbers: {'size': (40, 'mm')},
      expect: {
        'hes': (34, 'um'),
        'hei': (9, 'um'),
        'cmax': (50, 'um'),
        'cmin': (9, 'um'),
      },
      expectText: {'type': 'Clearance'},
      absTol: 1e-6,
    ),
    ToolCase(
      'Ø480 H7/r6 (custom)',
      source:
          'ISO 286-1 via RoyMech: 450–500 step, r ei +132, IT6 40, IT7 63 → interference 69–172 µm',
      choices: {'fit': 'custom', 'hl': 'H', 'hg': '7', 'sl': 'r', 'sg': '6'},
      numbers: {'size': (480, 'mm')},
      expect: {'ses': (172, 'um'), 'cmax': (-69, 'um'), 'cmin': (-172, 'um')},
      expectText: {'type': 'Interference'},
      absTol: 1e-6,
    ),
  ],
);
