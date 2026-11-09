import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final dpLevelTool = ToolDef(
  id: 'dp_level',
  title: 'DP level transmitter range',
  summary:
      'LRV/URV for a DP level transmitter with open tank / dry leg, wet leg or '
      'dual remote seals, including zero suppression and elevation.',
  icon: Icons.water_drop,
  keywords: [
    'level',
    'dp',
    'wet leg',
    'dry leg',
    'remote seal',
    'capillary',
    'suppression',
    'elevation',
    'lrv',
    'urv',
    'range',
  ],
  inputs: [
    const ChoiceInput(
      'config',
      'Installation',
      options: [
        ChoiceOption('dry', 'Open tank / dry leg'),
        ChoiceOption('wet', 'Wet leg (LP filled)'),
        ChoiceOption('seal', 'Dual remote seals'),
      ],
    ),
    const NumberInput(
      'lmin',
      'Level at 0 % (above HP tap)',
      quantity: Quantity.length,
      initial: 0,
      min: 0,
    ),
    const NumberInput(
      'lmax',
      'Level at 100 % (above HP tap)',
      quantity: Quantity.length,
      initial: 2,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'sgp',
      'Process liquid SG',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
    ),
    NumberInput(
      'h',
      'Distance HP tap → LP tap (or seal → seal)',
      quantity: Quantity.length,
      initial: 3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('config') != 'dry',
    ),
    NumberInput(
      's',
      'HP tap height above transmitter',
      quantity: Quantity.length,
      initial: 0.5,
      help:
          'Positive if the transmitter is below the HP tap (zero suppression). HP impulse line full of process liquid.',
      visibleWhen: (v) => v.c('config') != 'seal',
    ),
    NumberInput(
      'sgf',
      'Wet-leg / capillary fill SG',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help: 'Water 1.0; silicone DC200 ≈ 0.93; glycerine-water ≈ 1.1–1.2.',
      visibleWhen: (v) => v.c('config') != 'dry',
    ),
    const NumberInput(
      'reading',
      'Transmitter reading (to check level)',
      quantity: Quantity.pressureDiff,
      initial: 14709.975,
      help: 'Optional: a live DP reading converted back to level.',
    ),
  ],
  compute: (v) {
    final config = v.c('config');
    final lmin = v.n('lmin'), lmax = v.n('lmax'), sgp = v.n('sgp');
    if (lmax <= lmin) {
      throw ToolInputError('Level at 100 % must be above level at 0 %.');
    }
    final s = config == 'seal' ? 0.0 : v.n('s');
    final h = config == 'dry' ? 0.0 : v.n('h');
    final sgf = config == 'dry' ? 0.0 : v.n('sgf');
    const k = rhoWaterConv * gStd; // Pa per metre of SG-1 liquid

    // DP(L) = HP side head − LP side head, both relative to the transmitter.
    double dp(double l) => switch (config) {
      'wet' => k * (sgp * (l + s) - sgf * (s + h)),
      'seal' => k * (sgp * l - sgf * h),
      _ => k * sgp * (l + s),
    };
    final lrv = dp(lmin), urv = dp(lmax);
    final span = urv - lrv;
    final reading = v.n('reading');
    final frac = (reading - lrv) / span;
    final level = lmin + frac * (lmax - lmin);
    final w = <String>[];
    if (config != 'dry' && lmax > h) {
      w.add(
        'Level at 100 % is above the LP tap/seal: the LP side would be flooded.',
      );
    }
    final zero = lrv.abs() < 1e-6
        ? 'True zero'
        : lrv > 0
        ? 'Zero suppression (LRV > 0)'
        : 'Zero elevation (LRV < 0)';
    return ToolResult(
      [
        ToolOutput(
          'lrv',
          'LRV (at 0 %, 4 mA)',
          lrv,
          quantity: Quantity.pressureDiff,
          level: OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput(
          'urv',
          'URV (at 100 %, 20 mA)',
          urv,
          quantity: Quantity.pressureDiff,
          level: OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput(
          'span',
          'Calibrated span',
          span,
          quantity: Quantity.pressureDiff,
          sig: 6,
        ),
        ToolOutput.text('zero', 'Range type', zero),
        ToolOutput(
          'level',
          'Level at the reading',
          level,
          quantity: Quantity.length,
          sig: 5,
        ),
        ToolOutput(
          'pct',
          'Level at the reading, % of range',
          frac,
          quantity: Quantity.percent,
          sig: 4,
        ),
        ToolOutput(
          'ma',
          'Output at the reading',
          4 + 16 * frac,
          quantity: Quantity.current,
          sig: 5,
        ),
      ],
      warnings: w,
      notes: [
        'Vapour-space pressure cancels on a closed tank only if the LP side is connected to it.',
      ],
    );
  },
  formula: '''Heads in metres × SG, converted with ρw·g = 1000 × 9.80665 Pa/m.
L = level above the HP tap (or HP seal); s = HP tap above transmitter;
H = vertical distance HP tap → LP tap (seal → seal).

Open tank / dry leg:
  DP = SGp·(L + s)
Wet leg (LP impulse line full of fill liquid down to transmitter):
  DP = SGp·(L + s) − SGf·(s + H)
Dual remote seals, same fill both capillaries:
  DP = SGp·L − SGf·H         (transmitter height cancels)

LRV = DP(L at 0 %),  URV = DP(L at 100 %)
Level from reading:  L = Lmin + (DP − LRV)/(URV − LRV)·(Lmax − Lmin)''',
  references: [
    'B. G. Lipták, Instrument Engineers\' Handbook Vol. 1, ch. 3 (DP level, wet/dry legs)',
    'Emerson/Rosemount and Yokogawa DP level application notes (remote seal ranging)',
  ],
  assumptions: [
    'Fill liquids at the temperature the SGs refer to; temperature change shifts the zero.',
    'HP impulse line (if any) full of process liquid; seal diaphragm effects ignored.',
  ],
  cases: [
    const ToolCase(
      'Open tank, water, 0–2 m, transmitter 0.5 m below tap',
      source: 'LRV = 0.5 mH₂O = 49.033 mbar; URV = 2.5 mH₂O = 245.17 mbar',
      numbers: {
        'lmin': (0, 'm'),
        'lmax': (2, 'm'),
        'sgp': (1, '-'),
        's': (0.5, 'm'),
        'reading': (147.1, 'mbar'),
      },
      expect: {
        'lrv': (49.03325, 'mbar'),
        'urv': (245.1663, 'mbar'),
        'level': (1.0, 'm'),
      },
      expectText: {'zero': 'suppression'},
      relTol: 5e-4,
    ),
    const ToolCase(
      'Wet leg, SG 0.8, taps 3 m apart, transmitter at HP tap',
      source: 'LRV = −3 mH₂O = −294.20 mbar; URV = −0.6 mH₂O = −58.840 mbar',
      choices: {'config': 'wet'},
      numbers: {
        'lmin': (0, 'm'),
        'lmax': (3, 'm'),
        'sgp': (0.8, '-'),
        'h': (3, 'm'),
        's': (0, 'm'),
        'sgf': (1, '-'),
      },
      expect: {
        'lrv': (-294.1995, 'mbar'),
        'urv': (-58.8399, 'mbar'),
        'span': (235.3596, 'mbar'),
      },
      expectText: {'zero': 'elevation'},
    ),
    const ToolCase(
      'Dual seals, SG 1.1, silicone 0.93, seals 5 m apart',
      source: 'LRV = −4.65 mH₂O = −456.01 mbar; URV = 0.85 mH₂O = 83.357 mbar',
      choices: {'config': 'seal'},
      numbers: {
        'lmin': (0, 'm'),
        'lmax': (5, 'm'),
        'sgp': (1.1, '-'),
        'h': (5, 'm'),
        'sgf': (0.93, '-'),
      },
      expect: {'lrv': (-456.0092, 'mbar'), 'urv': (83.3565, 'mbar')},
    ),
  ],
);
