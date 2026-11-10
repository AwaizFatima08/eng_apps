import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

double _log10(double x) => math.log(x) / math.ln10;

/// Representative metabolic rates (W, 70 kg / 1.8 m² worker):
/// ACGIH TLV Table 3 work categories = ISO 7243:2017 classes 0–4.
const Map<String, double> _workRate = {
  'rest': 115,
  'light': 180,
  'moderate': 300,
  'heavy': 415,
  'vheavy': 520,
};

/// Clothing adjustment values, °C (ACGIH TLV heat stress Table 1;
/// OSHA Technical Manual Sec. III Ch. 4).
const Map<String, double> _cav = {
  'work': 0,
  'cover': 0,
  'double': 3,
  'sms': 0.5,
  'polyolefin': 1,
  'vapour': 11,
};

final wbgtHeatTool = ToolDef(
  id: 'wbgt_heat',
  title: 'WBGT heat stress (ISO 7243)',
  summary:
      'WBGT with or without solar load, clothing adjustment, and the '
      'reference limit for the work rate (ISO 7243:2017 = ACGIH TLV / action limit).',
  icon: Icons.thermostat,
  keywords: [
    'wbgt',
    'heat',
    'heat stress',
    'iso 7243',
    'acgih',
    'tlv',
    'action limit',
    'cav',
    'clothing',
    'acclimatised',
    'acclimatized',
    'globe',
    'wet bulb',
  ],
  inputs: [
    const ChoiceInput(
      'solar',
      'Location',
      options: [
        ChoiceOption('no', 'No solar load (indoor)'),
        ChoiceOption('yes', 'Solar load (outdoor)'),
      ],
    ),
    const NumberInput(
      'tnw',
      'Natural wet-bulb temperature t_nw',
      quantity: Quantity.temperature,
      initial: 25,
      min: -20,
      max: 60,
    ),
    const NumberInput(
      'tg',
      'Black globe temperature t_g',
      quantity: Quantity.temperature,
      initial: 35,
      min: -20,
      max: 120,
      help:
          '150 mm black globe (ISO 7243 Annex B); other globes need correction (Annex C).',
    ),
    NumberInput(
      'ta',
      'Air (dry-bulb) temperature t_a',
      quantity: Quantity.temperature,
      initial: 32,
      min: -20,
      max: 70,
      help: 'Shaded dry-bulb temperature.',
      visibleWhen: (v) => v.c('solar') == 'yes',
    ),
    const ChoiceInput(
      'work',
      'Work rate',
      initial: 'moderate',
      options: [
        ChoiceOption('rest', 'Resting (115 W)'),
        ChoiceOption('light', 'Light (180 W)'),
        ChoiceOption('moderate', 'Moderate (300 W)'),
        ChoiceOption('heavy', 'Heavy (415 W)'),
        ChoiceOption('vheavy', 'Very heavy (520 W)'),
        ChoiceOption('measured', 'Measured / estimated M'),
      ],
      help:
          'Time-weighted average over the hour. Rest = sitting; light = '
          'hand/arm work, driving; moderate = normal walking, light '
          'pushing; heavy = shovelling, carrying, fast walking.',
    ),
    NumberInput(
      'm',
      'Metabolic rate M (1-h average)',
      quantity: Quantity.power,
      units: ('W', 'W'),
      initial: 300,
      min: 50,
      minInclusive: false,
      max: 1000,
      help:
          'Whole-body W for a 1.8 m² person (W/m² × 1.8). Scale by weight/70 kg '
          'for heavy workers (ACGIH).',
      visibleWhen: (v) => v.c('work') == 'measured',
    ),
    const ChoiceInput(
      'acclim',
      'Worker',
      options: [
        ChoiceOption('yes', 'Acclimatised'),
        ChoiceOption('no', 'Not acclimatised'),
      ],
    ),
    const ChoiceInput(
      'cloth',
      'Clothing (CAV)',
      options: [
        ChoiceOption('work', 'Work clothes (0)'),
        ChoiceOption('cover', 'Cotton coveralls (0)'),
        ChoiceOption('sms', 'SMS polypropylene (+0.5)'),
        ChoiceOption('polyolefin', 'Polyolefin/Tyvek (+1)'),
        ChoiceOption('double', 'Double-layer woven (+3)'),
        ChoiceOption('vapour', 'Vapour-barrier suit (+11)'),
        ChoiceOption('custom', 'Other CAV'),
      ],
    ),
    NumberInput(
      'cav',
      'Clothing adjustment value',
      quantity: Quantity.tempDiff,
      initial: 0,
      min: -2,
      max: 15,
      help: 'Add 1 °C for a hood (ACGIH).',
      visibleWhen: (v) => v.c('cloth') == 'custom',
    ),
  ],
  compute: (v) {
    final tnw = v.n('tnw'), tg = v.n('tg');
    final solar = v.c('solar') == 'yes';
    final wbgt = solar
        ? 0.7 * tnw + 0.2 * tg + 0.1 * v.n('ta')
        : 0.7 * tnw + 0.3 * tg;
    final work = v.c('work');
    final m = work == 'measured' ? v.n('m') : _workRate[work] ?? 300;
    final cloth = v.c('cloth');
    final cav = cloth == 'custom' ? v.n('cav') : _cav[cloth] ?? 0;
    final eff = wbgt + cav;
    final tlv = 56.7 - 11.5 * _log10(m);
    final al = 59.9 - 14.1 * _log10(m);
    final acclim = v.c('acclim') == 'yes';
    final limit = acclim ? tlv : al;
    final margin = limit - eff;
    final w = <String>[];
    if (tnw > tg + 0.05 || (solar && tnw > v.n('ta') + 0.05)) {
      w.add(
        'Natural wet-bulb is above the globe/air temperature — check the '
        'sensors (wick wet? globe in the sun?).',
      );
    }
    if (m < 100 || m > 600) {
      w.add(
        'M is outside 100–600 W, the range of the ISO 7243 / ACGIH reference '
        'curves.',
      );
    }
    if (cloth == 'vapour') {
      w.add(
        'Vapour-barrier clothing: WBGT screening is of limited value — use '
        'physiological monitoring or ISO 7933 (ACGIH). Not valid for fully '
        'encapsulating suits.',
      );
    }
    final over = margin < 0;
    return ToolResult(
      [
        ToolOutput(
          'wbgt',
          'WBGT',
          wbgt,
          quantity: Quantity.temperature,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'eff',
          'WBGT_eff (+ CAV)',
          eff,
          quantity: Quantity.temperature,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'limit',
          acclim ? 'Limit (ref. / TLV)' : 'Limit (ref. / AL)',
          limit,
          quantity: Quantity.temperature,
          sig: 4,
        ),
        ToolOutput(
          'margin',
          'Limit − WBGT_eff',
          margin,
          quantity: Quantity.tempDiff,
          level: over ? OutputLevel.fail : OutputLevel.ok,
          sig: 3,
        ),
        ToolOutput.text(
          'status',
          'Verdict',
          over
              ? 'Above reference limit: reduce heat stress or assess with ISO 7933'
              : 'Within reference limit',
          level: over ? OutputLevel.fail : OutputLevel.ok,
        ),
        ToolOutput(
          'tlv',
          'TLV, acclimatised',
          tlv,
          quantity: Quantity.temperature,
          sig: 4,
        ),
        ToolOutput(
          'al',
          'Action limit, unacclim.',
          al,
          quantity: Quantity.temperature,
          sig: 4,
        ),
        ToolOutput(
          'mused',
          'Metabolic rate used',
          m,
          quantity: Quantity.power,
          units: ('W', 'W'),
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'Limits are 1-hour time-weighted averages for healthy, hydrated '
            'workers. Above the action limit a heat-stress management '
            'programme is needed (ACGIH).',
      ],
    );
  },
  formula: '''ISO 7243:2017 cl. 5
  No solar load:  WBGT = 0.7·t_nw + 0.3·t_g        (1)
  Solar load:     WBGT = 0.7·t_nw + 0.2·t_g + 0.1·t_a   (2)
  WBGT_eff = WBGT + CAV                          (cl. 7)

Reference limits, M in W (ISO 7243 Annex A Fig. A.1
equations = ACGIH TLV / AL = NIOSH REL / RAL):
  Acclimatised:      56.7 − 11.5·lg M
  Not acclimatised:  59.9 − 14.1·lg M

Work classes: rest 115, light 180, moderate 300,
heavy 415, very heavy 520 W (ISO classes 0–4).''',
  references: [
    'ISO 7243:2017 Ergonomics of the thermal environment — WBGT, cl. 5 (eq. 1, 2), cl. 7, Annex A, Annex F (CAV)',
    'ACGIH TLVs and BEIs (2021): Heat stress and strain — TLV and action limit, Tables 1 & 3',
    'NIOSH 2016-106 Criteria for a recommended standard: occupational exposure to heat (REL / RAL)',
    'OSHA Technical Manual Section III Chapter 4 (heat), clothing adjustments',
  ],
  assumptions: [
    'WBGT is the 1-h representative value; average head/abdomen/ankle readings first if the field is not uniform (ISO 7243 cl. 9.1).',
    'Limits use the reference equations, not the rounded ISO Table A.1 values (which differ by up to ~1 °C for unacclimatised workers).',
    'CAVs are the ACGIH values; check ISO 7243 Annex F for other garments.',
  ],
  cases: [
    const ToolCase(
      'ASSP worked example: M = 270 W, acclimatised',
      source:
          'Ricketts, PSJ Aug 2022 "Math Toolbox": TLV = 28.74 °C, AL = 25.62 °C; '
          'WBGT 0.7·25 + 0.3·35 = 28.0 by hand',
      choices: {'work': 'measured'},
      numbers: {'tnw': (25, 'C'), 'tg': (35, 'C'), 'm': (270, 'W')},
      expect: {
        'wbgt': (28.0, 'C'),
        'tlv': (28.74, 'C'),
        'al': (25.62, 'C'),
        'limit': (28.74, 'C'),
      },
      expectText: {'status': 'Within'},
      absTol: 0.006,
    ),
    const ToolCase(
      'ASSP example: M = 481 W outdoors, acclimatised',
      source:
          'Ricketts, PSJ Aug 2022: TLV(481 W) = 25.86 °C; WBGT = 0.7·24 + '
          '0.2·40 + 0.1·32 = 28.0 by hand ⇒ above',
      choices: {'work': 'measured', 'solar': 'yes'},
      numbers: {
        'tnw': (24, 'C'),
        'tg': (40, 'C'),
        'ta': (32, 'C'),
        'm': (481, 'W'),
      },
      expect: {'wbgt': (28.0, 'C'), 'limit': (25.86, 'C')},
      expectText: {'status': 'Above'},
      absTol: 0.006,
    ),
    const ToolCase(
      'Resting, unacclimatised, double-layer clothing',
      source:
          'Ricketts, PSJ Aug 2022: AL(115 W) = 30.84 °C; CAV example WBGT 25 + 3 '
          '= 28 °C',
      choices: {'work': 'rest', 'acclim': 'no', 'cloth': 'double'},
      numbers: {'tnw': (22, 'C'), 'tg': (32, 'C')},
      expect: {
        'wbgt': (25.0, 'C'),
        'eff': (28.0, 'C'),
        'limit': (30.84, 'C'),
        'margin': (2.84, 'K'),
      },
      absTol: 0.006,
    ),
    const ToolCase(
      'Vapour-barrier coveralls, light work',
      source:
          'Ricketts, PSJ Aug 2022: WBGT 20 + CAV 11 = 31 °C; TLV(180 W) = '
          '30.764 °C by hand',
      choices: {'work': 'light', 'cloth': 'vapour'},
      numbers: {'tnw': (17, 'C'), 'tg': (27, 'C')},
      expect: {'eff': (31.0, 'C'), 'limit': (30.764, 'C')},
      expectText: {'status': 'Above'},
      expectWarning: 'physiological monitoring',
      absTol: 0.001,
    ),
    const ToolCase(
      'M = 400 W: ISO 2017 reference values 27 / 23 °C',
      source:
          'LSI-Lastem Heat Shield note (ISO 7243:2017 / ACGIH): 27 °C acclimatised, '
          '23 °C not acclimatised at 400 W (rounded)',
      choices: {'work': 'measured', 'acclim': 'no'},
      numbers: {'tnw': (20, 'C'), 'tg': (25, 'C'), 'm': (400, 'W')},
      expect: {'tlv': (27, 'C'), 'al': (23, 'C'), 'wbgt': (21.5, 'C')},
      absTol: 0.25,
    ),
  ],
);
