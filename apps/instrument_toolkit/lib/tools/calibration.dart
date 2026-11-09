import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const _points = [0, 25, 50, 75, 100];

final calibrationTool = ToolDef(
  id: 'calibration_5pt',
  title: '5-point transmitter calibration',
  summary:
      'Applied values and expected mA at 0/25/50/75/100 %, as-found / as-left '
      'errors in % of span, and a pass/fail verdict against your tolerance.',
  icon: Icons.fact_check,
  keywords: [
    'calibration',
    'as found',
    'as left',
    'error',
    'span',
    'tolerance',
    'hart',
    'transmitter',
    '5 point',
  ],
  inputs: [
    const NumberInput(
      'lrv',
      'LRV (input at 0 %)',
      quantity: Quantity.dimensionless,
      initial: 0,
      help: 'In the unit of the applied input (bar, °C, mbar …).',
    ),
    const NumberInput(
      'urv',
      'URV (input at 100 %)',
      quantity: Quantity.dimensionless,
      initial: 10,
    ),
    const ChoiceInput(
      'transfer',
      'Transmitter output',
      options: [
        ChoiceOption('linear', 'Linear'),
        ChoiceOption('sqrt', 'Square root'),
      ],
    ),
    const NumberInput(
      'tol',
      'Tolerance (± % of span)',
      quantity: Quantity.percent,
      initial: 0.0025,
      min: 0,
      minInclusive: false,
      help: 'Usually from the loop data sheet or your calibration procedure.',
    ),
    for (final p in _points)
      NumberInput(
        'm$p',
        'Measured output at $p %',
        quantity: Quantity.current,
        initial: 4 + 16 * p / 100,
      ),
  ],
  compute: (v) {
    final lrv = v.n('lrv'), urv = v.n('urv'), tol = v.n('tol');
    if (urv == lrv) throw ToolInputError('URV must differ from LRV.');
    final sqrt = v.c('transfer') == 'sqrt';
    final outs = <ToolOutput>[];
    var maxErr = 0.0;
    var maxAt = 0;
    for (final p in _points) {
      final frac = p / 100;
      final applied = lrv + frac * (urv - lrv);
      final expectedFrac = sqrt ? math.sqrt(frac) : frac;
      final expected = 4 + 16 * expectedFrac;
      final err = (v.n('m$p') - expected) / 16; // fraction of output span
      if (err.abs() > maxErr.abs()) {
        maxErr = err;
        maxAt = p;
      }
      final level = err.abs() > tol ? OutputLevel.fail : OutputLevel.normal;
      outs.addAll([
        ToolOutput('applied$p', '$p % — apply input', applied, sig: 6),
        ToolOutput(
          'exp$p',
          '$p % — expected output',
          expected,
          quantity: Quantity.current,
          sig: 6,
        ),
        ToolOutput(
          'err$p',
          '$p % — error (% of span)',
          err,
          quantity: Quantity.percent,
          level: level,
          sig: 3,
        ),
      ]);
    }
    final pass = maxErr.abs() <= tol + 1e-12;
    return ToolResult(
      [
        ToolOutput.text(
          'verdict',
          'Verdict',
          pass ? 'PASS' : 'FAIL — adjust and re-test',
          level: pass ? OutputLevel.ok : OutputLevel.fail,
        ),
        ToolOutput(
          'maxErr',
          'Largest error (% of span) at $maxAt %',
          maxErr,
          quantity: Quantity.percent,
          level: OutputLevel.primary,
          sig: 3,
        ),
        ...outs,
      ],
      notes: [
        if (sqrt)
          'Square-root transmitters: below ~10 % the error in % of output span is magnified; '
              'many procedures test 0 % separately or skip it.',
        'Use a reference standard at least 4× more accurate than the tolerance (TUR ≥ 4:1).',
      ],
    );
  },
  formula: '''For each test point p = 0, 25, 50, 75, 100 %:
  Applied input   = LRV + p × (URV − LRV)
  Expected output = 4 + 16 × p            (linear)
                  = 4 + 16 × √p           (square root)
  Error (% span)  = (Measured − Expected) / 16 mA × 100

PASS when |error| ≤ tolerance at every point.''',
  references: [
    'ISA-51.1 Process Instrumentation Terminology (accuracy, % of span)',
    'IEC 61298-2 Process measurement and control devices — tests under reference conditions',
  ],
  assumptions: [
    'Single (upscale) pass; for hysteresis repeat the test downscale and compare.',
    'Output span is 16 mA (4–20 mA).',
  ],
  cases: [
    const ToolCase(
      'Perfect transmitter',
      source: 'All readings equal expected → PASS, 0 %',
      expect: {'maxErr': (0, '%'), 'applied75': (7.5, '-')},
      expectText: {'verdict': 'PASS'},
      absTol: 1e-9,
    ),
    const ToolCase(
      '0–10 bar, 12.03 mA at 50 %',
      source: '+0.03/16 = +0.1875 % > 0.1 % → FAIL',
      numbers: {'tol': (0.1, '%'), 'm50': (12.03, 'mA')},
      expect: {'err50': (0.1875, '%'), 'maxErr': (0.1875, '%')},
      expectText: {'verdict': 'FAIL'},
    ),
    const ToolCase(
      '−1 … 4 bar, slight zero shift',
      source: '−0.02/16 = −0.125 % ≤ 0.25 % → PASS',
      numbers: {
        'lrv': (-1, '-'),
        'urv': (4, '-'),
        'm0': (3.98, 'mA'),
        'm25': (7.98, 'mA'),
      },
      expect: {'applied25': (0.25, '-'), 'err0': (-0.125, '%')},
      expectText: {'verdict': 'PASS'},
    ),
    const ToolCase(
      'Square-root, expected at 25 %',
      source: '4 + 16 × √0.25 = 12 mA',
      choices: {'transfer': 'sqrt'},
      numbers: {
        'm25': (12, 'mA'),
        'm50': (15.3137, 'mA'),
        'm75': (17.8564, 'mA'),
      },
      expect: {'exp25': (12, 'mA'), 'exp50': (15.3137, 'mA')},
      expectText: {'verdict': 'PASS'},
    ),
  ],
);
