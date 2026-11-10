import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const double _ft = 0.3048;

final fallClearanceTool = ToolDef(
  id: 'fall_clearance',
  title: 'Fall clearance (lanyard / SRL)',
  summary:
      'Free fall and the clearance needed below the work surface for an '
      'energy-absorbing lanyard or a self-retracting lifeline, against the space available.',
  icon: Icons.height,
  keywords: [
    'fall',
    'fall arrest',
    'clearance',
    'lanyard',
    'shock absorber',
    'energy absorber',
    'srl',
    'self-retracting',
    'yo-yo',
    'harness',
    'd-ring',
    'anchor',
    'z359',
    'work at height',
  ],
  inputs: [
    const ChoiceInput(
      'device',
      'Connector',
      options: [
        ChoiceOption('lanyard', 'EA lanyard'),
        ChoiceOption('srl', 'Self-retracting (SRL)'),
      ],
    ),
    NumberInput(
      'len',
      'Lanyard length (incl. connectors)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.8,
      min: 0,
      minInclusive: false,
      max: 6,
      visibleWhen: (v) => v.c('device') == 'lanyard',
    ),
    NumberInput(
      'dd',
      'Deceleration distance (absorber)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.07,
      min: 0,
      max: 3,
      help:
          'From the absorber label. OSHA max 1.07 m (3.5 ft); Z359.13: ≤ 1.2 m '
          '(48 in) for 6-ft free fall, ≤ 1.5 m (60 in) for 12-ft free fall.',
      visibleWhen: (v) => v.c('device') == 'lanyard',
    ),
    NumberInput(
      'ad',
      'SRL arrest distance (maker)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.07,
      min: 0,
      max: 5,
      help:
          'From the SRL label/manual. Z359.14-2021 overhead limit 1.07 m (42 in); '
          'foot-level arrest distance is maker-declared (often 2–3 m).',
      visibleWhen: (v) => v.c('device') == 'srl',
    ),
    const NumberInput(
      'ha',
      'Anchor height above work surface',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.5,
      min: 0,
      max: 10,
      help:
          '0 = anchor at foot level. D-ring level is the D-ring height below.',
    ),
    const NumberInput(
      'hd',
      'D-ring height above feet',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 1.5,
      min: 0.5,
      max: 2.5,
      help: 'Typically 1.5 m (5 ft) for an average worker.',
    ),
    const NumberInput(
      'stretch',
      'Harness stretch + D-ring shift',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 0.3,
      min: 0,
      max: 1,
      help: 'Typically 0.3 m (1 ft) — use the harness maker\'s value.',
    ),
    const NumberInput(
      'swing',
      'Swing-fall allowance',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 0,
      min: 0,
      max: 5,
      help: 'Extra drop when working away from the line below the anchor.',
    ),
    const NumberInput(
      'sf',
      'Safety margin',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 0.9,
      min: 0,
      max: 3,
      help:
          'Commonly 0.5–1 m (1.5–3 ft); follow FFL\'s fall-protection procedure.',
    ),
    const NumberInput(
      'avail',
      'Clearance available below surface',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 6,
      min: 0,
      help:
          'From the work surface down to the ground or the first obstruction.',
    ),
  ],
  compute: (v) {
    final lanyard = v.c('device') == 'lanyard';
    final ha = v.n('ha'), hd = v.n('hd'), s = v.n('stretch');
    final swing = v.n('swing'), sf = v.n('sf'), avail = v.n('avail');
    final w = <String>[];
    final double ff, arrest;
    if (lanyard) {
      ff = (v.n('len') - (ha - hd)).clamp(0.0, double.infinity);
      arrest = v.n('dd');
      if (ff > 12 * _ft + 1e-9) {
        w.add(
          'Free fall above 3.66 m (12 ft): no Z359.13 absorber is rated for this '
          '— raise the anchor or shorten the lanyard.',
        );
      } else if (ff > 6 * _ft + 1e-9) {
        w.add(
          'Free fall above 1.8 m (6 ft): OSHA 1910.140(d)(2)(ii) allows this '
          'only with a system designed and tested for it (e.g. a Z359.13 '
          '12-ft free-fall absorber) keeping the arrest force ≤ 8 kN.',
        );
      }
      if (arrest > 3.5 * _ft + 1e-9) {
        w.add(
          'Deceleration distance above 1.07 m (3.5 ft), the OSHA '
          '1910.140(d)(1)(ii) limit for a personal fall arrest system.',
        );
      }
    } else {
      ff = (hd - ha).clamp(0.0, double.infinity);
      arrest = v.n('ad');
      if (ha < hd - 1e-9) {
        w.add(
          'Anchor below the D-ring (foot-level / leading-edge tie-off): use a '
          'Class 2 (SRL-LE) device and its foot-level arrest distance.',
        );
      }
    }
    final req = ff + arrest + s + swing + sf;
    final spare = avail - req;
    final ok = spare >= -1e-9;
    final outs = <ToolOutput>[
      ToolOutput(
        'req',
        'Clearance needed below surface',
        req,
        quantity: Quantity.length,
        units: ('m', 'ft'),
        level: OutputLevel.primary,
        sig: 4,
      ),
      ToolOutput.text(
        'status',
        'Verdict',
        ok
            ? 'Clearance OK'
            : 'NOT enough clearance — worker would strike below',
        level: ok ? OutputLevel.ok : OutputLevel.fail,
      ),
      ToolOutput(
        'spare',
        'Available − needed',
        spare,
        quantity: Quantity.length,
        units: ('m', 'ft'),
        level: ok ? OutputLevel.ok : OutputLevel.fail,
        sig: 3,
      ),
      ToolOutput(
        'ff',
        'Free fall distance',
        ff,
        quantity: Quantity.length,
        units: ('m', 'ft'),
        sig: 4,
      ),
    ];
    if (lanyard) {
      outs.add(
        ToolOutput(
          'anchor',
          'Clearance needed below anchor',
          req + ha,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 4,
        ),
      );
    }
    return ToolResult(
      outs,
      warnings: w,
      notes: [
        'Plan the rescue too: suspension after arrest must be short '
            '(OSHA 1910.140(c)(21)).',
      ],
    );
  },
  formula: '''All heights from the work surface (up = +).
h_A anchor height, h_D D-ring height above feet.

Energy-absorbing lanyard (length L, deceleration DD):
  Free fall  FF = L − (h_A − h_D)          (≥ 0)
  Needed below surface = FF + DD + S + swing + SF
  Needed below anchor  = above + h_A

Self-retracting lifeline (arrest distance AD):
  FF = h_D − h_A if anchor below the D-ring, else 0
  Needed below surface = FF + AD + S + swing + SF

S = harness stretch + D-ring shift, SF = safety margin.
OK when available clearance ≥ needed.''',
  references: [
    'ANSI/ASSP Z359.13-2013 Personal energy absorbers and energy-absorbing lanyards (6 ft / 12 ft free fall, 48 / 60 in deployment)',
    'ANSI/ASSP Z359.14-2021 Self-retracting devices (Class 1 / Class 2, 42 in max arrest distance overhead)',
    'OSHA 29 CFR 1910.140(d)(1)(i)–(ii), (d)(2)(ii), (c)(21): 8 kN arrest force, deceleration ≤ 3.5 ft, free fall ≤ 6 ft, prompt rescue',
    'FallTech "Fall clearance: how to calculate safe distances" and WC Safety clearance worked examples',
  ],
  assumptions: [
    'Vertical fall; swing falls only through the allowance entered.',
    'Lanyard length includes connectors; anchorage and its deflection rigid (add horizontal lifeline sag separately).',
    'Device values (DD, AD, stretch) from the maker\'s label for the worker\'s weight.',
  ],
  cases: [
    const ToolCase(
      'FallTech EAL example: 6 ft lanyard, anchor at D-ring',
      source:
          'FallTech worked example: 6 + 3½ + 1 + 5 + 1½ = 17 ft below the anchor',
      numbers: {
        'len': (6, 'ft'),
        'dd': (3.5, 'ft'),
        'ha': (5, 'ft'),
        'hd': (5, 'ft'),
        'stretch': (1, 'ft'),
        'swing': (0, 'ft'),
        'sf': (1.5, 'ft'),
        'avail': (20, 'ft'),
      },
      expect: {'anchor': (17, 'ft'), 'req': (12, 'ft'), 'ff': (6, 'ft')},
      expectText: {'status': 'OK'},
    ),
    const ToolCase(
      'WC Safety: 6 ft lanyard, 3 ft safety factor',
      source:
          'WC Safety reference: 6 + 3.5 + 5 + 1 + 3 = 18.5 ft below D-ring anchor',
      numbers: {
        'len': (6, 'ft'),
        'dd': (3.5, 'ft'),
        'ha': (5, 'ft'),
        'hd': (5, 'ft'),
        'stretch': (1, 'ft'),
        'swing': (0, 'ft'),
        'sf': (3, 'ft'),
        'avail': (12, 'ft'),
      },
      expect: {
        'anchor': (18.5, 'ft'),
        'req': (13.5, 'ft'),
        'spare': (-1.5, 'ft'),
      },
      expectText: {'status': 'NOT enough'},
    ),
    const ToolCase(
      'FallTech SRL overhead with 4 ft swing allowance',
      source: 'FallTech worked example: 3½ + 1 + 1½ + 4 = 10 ft below surface',
      choices: {'device': 'srl'},
      numbers: {
        'ad': (3.5, 'ft'),
        'ha': (7, 'ft'),
        'hd': (5, 'ft'),
        'stretch': (1, 'ft'),
        'swing': (4, 'ft'),
        'sf': (1.5, 'ft'),
        'avail': (10, 'ft'),
      },
      expect: {'req': (10, 'ft'), 'ff': (0, 'ft')},
      expectText: {'status': 'OK'},
      absTol: 1e-9,
    ),
    const ToolCase(
      'FallTech SRL foot-level tie-off',
      source:
          'FallTech terms 8½ + 1 + 1½ + 5 + 4 sum to 20 ft (article prints 19 ft '
          '— arithmetic slip; hand sum used)',
      choices: {'device': 'srl'},
      numbers: {
        'ad': (8.5, 'ft'),
        'ha': (0, 'ft'),
        'hd': (5, 'ft'),
        'stretch': (1, 'ft'),
        'swing': (4, 'ft'),
        'sf': (1.5, 'ft'),
        'avail': (25, 'ft'),
      },
      expect: {'req': (20, 'ft'), 'ff': (5, 'ft')},
      expectWarning: 'foot-level',
    ),
    const ToolCase(
      'Foot-level 1.8 m lanyard, 12-ft absorber, metric',
      source:
          'Hand calc: FF = 1.8 + 1.5 = 3.3 m; needed 3.3 + 1.5 + 0.3 + 0.6 = '
          '5.7 m > 5 m available',
      numbers: {
        'len': (1.8, 'm'),
        'dd': (1.5, 'm'),
        'ha': (0, 'm'),
        'hd': (1.5, 'm'),
        'stretch': (0.3, 'm'),
        'swing': (0, 'm'),
        'sf': (0.6, 'm'),
        'avail': (5, 'm'),
      },
      expect: {'ff': (3.3, 'm'), 'req': (5.7, 'm'), 'spare': (-0.7, 'm')},
      expectText: {'status': 'NOT enough'},
      expectWarning: '6 ft',
    ),
  ],
);
