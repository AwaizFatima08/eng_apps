import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// NAMUR NE 43 status of a 4–20 mA signal.
(String, OutputLevel) namurStatus(double ma) {
  if (ma <= 3.6) {
    return ('Failure (≤ 3.6 mA, NE 43 low alarm)', OutputLevel.fail);
  }
  if (ma >= 21.0) {
    return ('Failure (≥ 21.0 mA, NE 43 high alarm)', OutputLevel.fail);
  }
  if (ma < 3.8) {
    return ('Below measuring range (3.6 … 3.8 mA)', OutputLevel.warn);
  }
  if (ma > 20.5) {
    return ('Above measuring range (20.5 … 21.0 mA)', OutputLevel.warn);
  }
  if (ma < 4.0) {
    return ('Under-range, still valid (3.8 … 4.0 mA)', OutputLevel.warn);
  }
  if (ma > 20.0) {
    return ('Over-range, still valid (20 … 20.5 mA)', OutputLevel.warn);
  }
  return ('Normal (4 … 20 mA)', OutputLevel.ok);
}

final signalScalerTool = ToolDef(
  id: 'signal_scaler',
  title: '4–20 mA scaler',
  summary:
      'Convert loop current to engineering value and back, linear or square-root '
      '(DP flow), with NAMUR NE 43 signal status.',
  icon: Icons.settings_input_component,
  keywords: [
    'ma',
    'milliamp',
    'loop',
    'scaling',
    'lrv',
    'urv',
    'namur',
    'ne43',
    'square root',
    'span',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Convert',
      options: [
        ChoiceOption('ma2pv', 'mA → value'),
        ChoiceOption('pv2ma', 'Value → mA'),
        ChoiceOption('pct2ma', '% → mA'),
      ],
    ),
    const ChoiceInput(
      'transfer',
      'Transfer function',
      options: [
        ChoiceOption('linear', 'Linear'),
        ChoiceOption('sqrt', 'Square root'),
      ],
      help: 'Square root: a DP transmitter on an orifice/venturi, flow ∝ √DP.',
    ),
    const NumberInput(
      'lrv',
      'Lower range value (LRV) — at 4 mA',
      quantity: Quantity.dimensionless,
      initial: 0,
      help: 'In any engineering unit (bar, m³/h, °C …).',
    ),
    const NumberInput(
      'urv',
      'Upper range value (URV) — at 20 mA',
      quantity: Quantity.dimensionless,
      initial: 100,
    ),
    NumberInput(
      'ma',
      'Loop current',
      quantity: Quantity.current,
      initial: 12,
      visibleWhen: (v) => v.c('mode') == 'ma2pv',
    ),
    NumberInput(
      'pv',
      'Engineering value',
      quantity: Quantity.dimensionless,
      initial: 50,
      visibleWhen: (v) => v.c('mode') == 'pv2ma',
    ),
    NumberInput(
      'pct',
      'Percent of span',
      quantity: Quantity.percent,
      initial: 0.5,
      visibleWhen: (v) => v.c('mode') == 'pct2ma',
    ),
    const NumberInput(
      'lo',
      'Signal at 0 %',
      quantity: Quantity.current,
      initial: 4,
      help: 'Change for 0–20 mA (0) or other live-zero ranges.',
    ),
    const NumberInput(
      'hi',
      'Signal at 100 %',
      quantity: Quantity.current,
      initial: 20,
    ),
  ],
  compute: (v) {
    final lrv = v.n('lrv'), urv = v.n('urv'), lo = v.n('lo'), hi = v.n('hi');
    if (urv == lrv) throw ToolInputError('URV must differ from LRV.');
    if (hi <= lo) {
      throw ToolInputError('Signal at 100 % must be above signal at 0 %.');
    }
    final sqrt = v.c('transfer') == 'sqrt';
    final mode = v.c('mode');
    final warnings = <String>[];

    // signalFrac = output fraction of span; pvFrac = measured-value fraction.
    late double signalFrac, pvFrac;
    switch (mode) {
      case 'ma2pv':
        signalFrac = (v.n('ma') - lo) / (hi - lo);
        if (sqrt) {
          if (signalFrac < 0) {
            warnings.add('Signal below 0 % — square-root output clamped to 0.');
          }
          pvFrac = math.sqrt(math.max(0, signalFrac));
        } else {
          pvFrac = signalFrac;
        }
      case 'pv2ma':
        pvFrac = (v.n('pv') - lrv) / (urv - lrv);
        signalFrac = sqrt ? pvFrac * pvFrac * pvFrac.sign : pvFrac;
      default:
        signalFrac = v.n('pct');
        pvFrac = sqrt ? math.sqrt(math.max(0, signalFrac)) : signalFrac;
    }
    final ma = lo + signalFrac * (hi - lo);
    final pv = lrv + pvFrac * (urv - lrv);
    if (sqrt && pvFrac < 0.1 && pvFrac >= 0) {
      warnings.add(
        'Below ~10 % flow the √ curve is very steep: most systems apply a '
        'low-flow cutoff here.',
      );
    }
    final isLiveZero420 = (lo - 4).abs() < 1e-9 && (hi - 20).abs() < 1e-9;
    final status = isLiveZero420 ? namurStatus(ma) : null;
    return ToolResult([
      ToolOutput(
        'pv',
        'Engineering value',
        pv,
        sig: 6,
        level: mode == 'ma2pv' ? OutputLevel.primary : OutputLevel.normal,
      ),
      ToolOutput(
        'ma',
        'Loop current',
        ma,
        quantity: Quantity.current,
        sig: 6,
        level: mode == 'ma2pv' ? OutputLevel.normal : OutputLevel.primary,
      ),
      ToolOutput(
        'pvPct',
        'Measured value, % of range',
        pvFrac,
        quantity: Quantity.percent,
        sig: 5,
      ),
      if (sqrt)
        ToolOutput(
          'sigPct',
          'Signal (DP), % of span',
          signalFrac,
          quantity: Quantity.percent,
          sig: 5,
        ),
      ToolOutput('span', 'Span (URV − LRV)', urv - lrv, sig: 6),
      if (status != null)
        ToolOutput.text('namur', 'NE 43 status', status.$1, level: status.$2),
    ], warnings: warnings);
  },
  formula: '''Linear:
  mA = 4 + 16 × (PV − LRV) / (URV − LRV)
  PV = LRV + (mA − 4) / 16 × (URV − LRV)

Square root (DP flow, transmitter output linear in DP):
  DP fraction  s = (mA − 4) / 16
  Flow  Q = LRV + √s × (URV − LRV)
  mA = 4 + 16 × ((Q − LRV)/(URV − LRV))²

NAMUR NE 43 (4–20 mA):
  3.8 … 20.5 mA  valid measurement (incl. saturation)
  ≤ 3.6 or ≥ 21.0 mA  failure signal''',
  references: [
    'IEC 60381-1 Analogue signals for process control — direct current signals',
    'ISA-50.00.01 Compatibility of analog signals for electronic industrial process instruments',
    'NAMUR NE 43 Standardization of the signal level for failure information of digital transmitters',
  ],
  assumptions: [
    'Square-root mode assumes the transmitter output is linear in DP and the extraction is done in the receiver.',
    'NE 43 status is only shown for a 4–20 mA range.',
  ],
  cases: [
    const ToolCase(
      '12 mA on 0–10 bar',
      source: 'Linear: mid-scale = 5 bar',
      numbers: {'lrv': (0, '-'), 'urv': (10, '-'), 'ma': (12, 'mA')},
      expect: {'pv': (5, '-'), 'pvPct': (50, '%')},
    ),
    const ToolCase(
      '8 mA on −50 … 150 °C',
      source: 'Linear: 25 % of 200 = 50 → 0 °C',
      numbers: {'lrv': (-50, '-'), 'urv': (150, '-'), 'ma': (8, 'mA')},
      expect: {'pv': (0, '-')},
      absTol: 1e-9,
    ),
    const ToolCase(
      '75 m³/h on 0–100 → mA',
      source: 'Linear: 4 + 16 × 0.75 = 16 mA',
      choices: {'mode': 'pv2ma'},
      numbers: {'lrv': (0, '-'), 'urv': (100, '-'), 'pv': (75, '-')},
      expect: {'ma': (16, 'mA')},
    ),
    const ToolCase(
      '√ extraction, 12 mA, 0–100 t/h',
      source: '√0.5 = 0.70711 → 70.711 t/h',
      choices: {'transfer': 'sqrt'},
      numbers: {'lrv': (0, '-'), 'urv': (100, '-'), 'ma': (12, 'mA')},
      expect: {'pv': (70.7107, '-')},
    ),
    const ToolCase(
      '√ inverse, 25 % flow → mA',
      source: '0.25² = 6.25 % DP → 5.0 mA',
      choices: {'transfer': 'sqrt', 'mode': 'pv2ma'},
      numbers: {'lrv': (0, '-'), 'urv': (100, '-'), 'pv': (25, '-')},
      expect: {'ma': (5, 'mA')},
    ),
    const ToolCase(
      '0–20 mA, 5 mA on 0–200',
      source: 'Linear: 25 % → 50',
      numbers: {
        'lo': (0, 'mA'),
        'hi': (20, 'mA'),
        'lrv': (0, '-'),
        'urv': (200, '-'),
        'ma': (5, 'mA'),
      },
      expect: {'pv': (50, '-')},
    ),
    const ToolCase(
      '3.5 mA → NE 43 failure',
      source: 'NAMUR NE 43: ≤ 3.6 mA is a failure signal',
      numbers: {'ma': (3.5, 'mA')},
      expectText: {'namur': 'Failure'},
    ),
  ],
);
