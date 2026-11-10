import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// SKF bearing factor b_f and recommended limits of A = n·d_m (mm/min) for
/// C/P ≥ 15, ≈ 8, ≈ 4 (SKF Bearing maintenance handbook, Table 7; same
/// table in the Rolling bearings catalogue). 0 = not recommended (NA).
class _Bf {
  const _Bf(
    this.label,
    this.bf,
    this.limits, {
    this.fullComplement = false,
    this.thrust = false,
    this.spherical = false,
  });
  final String label;
  final double bf;
  final List<double> limits;
  final bool fullComplement, thrust, spherical;
}

const Map<String, _Bf> _types = {
  'dgbb': _Bf('Deep groove ball', 1, [500e3, 400e3, 300e3]),
  'acbb': _Bf('Angular contact ball', 1, [500e3, 400e3, 300e3]),
  'sabb': _Bf('Self-aligning ball', 1, [500e3, 400e3, 300e3]),
  'crb_nl': _Bf('Cyl. roller, non-locating', 1.5, [450e3, 300e3, 150e3]),
  'crb_l': _Bf('Cyl. roller, locating', 2, [300e3, 200e3, 100e3]),
  'crb_ax': _Bf('Cyl. roller, constant axial load', 4, [200e3, 120e3, 60e3]),
  'crb_fc': _Bf('Cyl. roller, full complement', 4, [
    0,
    0,
    20e3,
  ], fullComplement: true),
  'trb': _Bf('Tapered roller', 2, [350e3, 300e3, 200e3]),
  'srb_a': _Bf('Spherical roller 213/222/238/239', 2, [
    350e3,
    200e3,
    100e3,
  ], spherical: true),
  'srb_b': _Bf('Spherical roller 223/23x/24x', 2, [
    250e3,
    150e3,
    80e3,
  ], spherical: true),
  'srb_241': _Bf('Spherical roller 241', 2, [
    150e3,
    80e3,
    50e3,
  ], spherical: true),
  'srb_ax': _Bf('Spherical roller, Fa/Fr > e', 6, [
    150e3,
    50e3,
    30e3,
  ], spherical: true),
  'carb': _Bf('CARB with cage', 2, [350e3, 200e3, 100e3]),
  'tbb': _Bf('Thrust ball', 2, [200e3, 150e3, 100e3], thrust: true),
  'crtb': _Bf('Cyl. roller thrust', 10, [100e3, 60e3, 30e3], thrust: true),
  'srtb': _Bf('Spherical roller thrust', 4, [200e3, 120e3, 60e3], thrust: true),
};

/// Base interval at 70 °C, read from SKF Diagram 1. The three lines are
/// straight on the semi-log chart: t_f = t₀·10^(−A·b_f / 400 000) with
/// t₀ = 32 000 / 16 000 / 6 400 h for C/P ≥ 15 / ≈ 8 / ≈ 4. Fitted to the
/// chart's vector paths: within 2 % over 0–800 000 mm/min.
double skfBaseInterval(double abf, String load) {
  final t0 = switch (load) {
    'cp8' => 16000.0,
    'cp4' => 6400.0,
    _ => 32000.0,
  };
  return t0 * math.pow(10, -abf / 400000).toDouble();
}

final greaseIntervalTool = ToolDef(
  id: 'grease_interval',
  title: 'Regreasing interval (SKF)',
  summary:
      'Relubrication interval t_f for grease-lubricated rolling bearings by the '
      'SKF method (speed factor n·d_m, bearing factor b_f, load), with '
      'temperature and shaft adjustments and the grease quantity G_p.',
  icon: Icons.opacity,
  keywords: [
    'grease',
    'lubrication',
    'relubrication',
    'regreasing',
    'interval',
    'skf',
    'bearing',
    'ndm',
    'speed factor',
    'bf',
    'grease quantity',
  ],
  inputs: [
    ChoiceInput(
      'type',
      'Bearing type (b_f)',
      options: [
        for (final e in _types.entries)
          ChoiceOption(e.key, '${e.value.label} (${formatNumber(e.value.bf)})'),
      ],
    ),
    const NumberInput(
      'd',
      'Bore d',
      quantity: Quantity.length,
      initial: 0.080,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'od',
      'Outside Ø D',
      quantity: Quantity.length,
      initial: 0.170,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'b',
      'Width B (thrust: height H)',
      quantity: Quantity.length,
      initial: 0.039,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'n',
      'Speed n',
      quantity: Quantity.rotSpeed,
      initial: 1500,
      min: 0,
      minInclusive: false,
    ),
    const ChoiceInput(
      'load',
      'Load ratio C/P',
      options: [
        ChoiceOption('cp15', 'C/P ≥ 15 (light)'),
        ChoiceOption('cp8', 'C/P ≈ 8 (moderate)'),
        ChoiceOption('cp4', 'C/P ≈ 4 (heavy)'),
      ],
      help: 'Between lines, take the lower C/P line (shorter interval).',
    ),
    const NumberInput(
      'temp',
      'Bearing operating temperature',
      quantity: Quantity.temperature,
      initial: 70,
      min: -40,
      max: 200,
      help: 'Outer ring temperature. Base chart is for 70 °C.',
    ),
    const ChoiceInput(
      'shaft',
      'Shaft',
      options: [
        ChoiceOption('h', 'Horizontal'),
        ChoiceOption('v', 'Vertical (× 0.5)'),
      ],
    ),
    const ChoiceInput(
      'ring',
      'Rotating ring',
      options: [
        ChoiceOption('inner', 'Inner ring'),
        ChoiceOption('outer', 'Outer ring (use D)'),
      ],
    ),
    const NumberInput(
      'kx',
      'Extra reduction factor',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0.05,
      max: 1,
      help:
          'For heavy contamination, water, vibration/shock or P > 0.15·C. SKF says "reduce" but gives no number; plant practice often uses 0.3–0.7.',
    ),
    const ChoiceInput(
      'feed',
      'Grease enters',
      options: [
        ChoiceOption('side', 'From the side'),
        ChoiceOption('ring', 'Through the ring (W33)'),
      ],
    ),
  ],
  compute: (v) {
    final t = _types[v.c('type')] ?? _types['dgbb']!;
    final d = v.n('d') * 1000, od = v.n('od') * 1000, b = v.n('b') * 1000;
    if (od <= d) {
      throw ToolInputError('Outside Ø must be larger than the bore.');
    }
    final n = v.n('n');
    final load = v.c('load');
    final li = switch (load) {
      'cp8' => 1,
      'cp4' => 2,
      _ => 0,
    };
    final dm = (d + od) / 2;
    final outer = v.c('ring') == 'outer';
    final a = n * (outer ? od : dm);
    final abf = a * t.bf;
    var tf = skfBaseInterval(abf, load);
    if (t.fullComplement) tf /= 10;

    final temp = v.n('temp');
    double fT;
    if (temp >= 70) {
      fT = math.pow(2, -(temp - 70) / 15).toDouble();
    } else if (t.fullComplement || t.thrust) {
      fT = 1; // SKF: do not extend for full-complement and thrust bearings
    } else {
      fT = math.min(2, math.pow(2, (70 - temp) / 15).toDouble());
    }
    final fShaft = v.c('shaft') == 'v' ? 0.5 : 1.0;
    final kx = v.n('kx');
    final tAdj = tf * fT * fShaft * kx;
    final tRec = math.min(tAdj, 30000.0);
    final gp = (v.c('feed') == 'ring' ? 0.002 : 0.005) * od * b; // g

    final w = <String>[];
    final notes = <String>[];
    final limit = t.limits[li];
    if (limit == 0) {
      w.add(
        'SKF does not recommend a full-complement bearing at this C/P; use a caged bearing.',
      );
    } else if (a > limit) {
      w.add(
        'Speed factor A = ${formatNumber(a, sig: 3)} mm/min exceeds SKF\'s recommended limit '
        '${formatNumber(limit, sig: 3)} for this type and load: consider oil lubrication.',
      );
    }
    if (abf > 800000) {
      w.add(
        'A·b_f is beyond the SKF chart (800 000 mm/min): result is extrapolated.',
      );
    }
    if (tAdj > 30000) {
      w.add(
        'Interval over 30 000 h: grease ageing governs; SKF advises not to rely on more than 30 000 h.',
      );
    }
    if (temp > 100) {
      notes.add(
        'Check that the temperature is below the grease\'s high temperature performance limit (HTPL).',
      );
    }
    if (t.spherical && dm > 800) {
      w.add(
        'Spherical roller bearings with d_m > 800 mm have lower SKF speed limits (not in this table).',
      );
    }
    if (d > 300) {
      notes.add(
        'Bore over 300 mm: SKF advises a shorter, strictly controlled interval (consult SKF).',
      );
    }
    if (t.fullComplement) {
      notes.add(
        'Full-complement bearing: chart value divided by 10 (SKF note).',
      );
    }
    if (tRec < 4380) {
      notes.add(
        'Interval under about 6 months: replenishment works; for very short intervals consider an automatic lubricator.',
      );
    }
    notes.add(
      'Cylindrical roller bearings with J, JA, JB, MA, MB, ML, MP or PHA cages: halve the interval (SKF).',
    );

    const h = 3600.0;
    return ToolResult(
      [
        ToolOutput(
          'trec',
          'Recommended interval',
          tRec * h,
          quantity: Quantity.time,
          level: OutputLevel.primary,
          sig: 3,
        ),
        ToolOutput(
          'gp',
          'Grease quantity G_p',
          gp * 1e-3,
          quantity: Quantity.mass,
          units: ('g', 'lb'),
          level: OutputLevel.primary,
          sig: 3,
        ),
        ToolOutput(
          'tadj',
          'Adjusted t_f (uncapped)',
          tAdj * h,
          quantity: Quantity.time,
          sig: 4,
        ),
        ToolOutput(
          'tf',
          'Base t_f at 70 °C',
          tf * h,
          quantity: Quantity.time,
          sig: 4,
        ),
        ToolOutput('a', 'Speed factor A (mm/min)', a, sig: 4),
        ToolOutput('abf', 'A·b_f (mm/min)', abf, sig: 4),
        ToolOutput('ft', 'Temperature factor', fT, sig: 3),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''d_m = (d + D)/2,  A = n·d_m   (outer-ring rotation: A = n·D)
Base interval at 70 °C (SKF Diagram 1, straight lines on log scale):
  t_f = t₀ · 10^(−A·b_f / 400 000)  [h]
  t₀ = 32 000 (C/P ≥ 15), 16 000 (C/P ≈ 8), 6 400 (C/P ≈ 4)
  full-complement bearings: t_f / 10
Adjustments (SKF Table 8):
  temperature  × 2^(−(T − 70)/15) above 70 °C
               × 2^((70 − T)/15) below 70 °C, at most × 2
               (no extension for thrust / full-complement)
  vertical shaft × 0.5;  extra factor for contamination, vibration
  recommended = min(adjusted, 30 000 h)
Grease quantity:
  G_p = 0.005·D·B  [g]  from the side
  G_p = 0.002·D·B  [g]  through the outer/inner ring (W33)''',
  references: [
    'SKF Bearing maintenance handbook (PUB 10000/2 EN), Grease lubrication: Diagram 1, Table 7 (b_f, A limits), Table 8 (adjustments), G_p equations',
    'SKF Rolling bearings catalogue (PUB BU/P1 17000 EN), Lubrication — Relubrication intervals (same diagram and tables)',
  ],
  assumptions: [
    'Good-quality lithium-soap / mineral-oil grease, clean conditions, inner-ring rotation (SKF chart basis).',
    'Chart line fitted from the vector drawing of SKF Diagram 1 (deviation < 2 % from the drawn lines).',
    'Intermediate C/P values: use the lower line (conservative); the chart has only three lines.',
  ],
  cases: const [
    ToolCase(
      '6316 deep groove ball, 1500 rpm, C/P ≥ 15, 70 °C',
      source:
          'SKF Diagram 1 digitised from the handbook PDF vector path (skf_digitize.py): A·b_f 187 500 → t_f 10 839 h; G_p = 0.005·170·39 = 33.15 g',
      numbers: {
        'd': (80, 'mm'),
        'od': (170, 'mm'),
        'b': (39, 'mm'),
        'n': (1500, 'rpm'),
        'temp': (70, 'C'),
      },
      expect: {
        'a': (187500, '-'),
        'tf': (10839, 'h'),
        'trec': (10839, 'h'),
        'gp': (33.15, 'g'),
      },
      relTol: 2e-2,
    ),
    ToolCase(
      '22220 spherical roller (series 222), 1000 rpm, C/P ≈ 8, 85 °C, W33 feed',
      source:
          'Digitised SKF Diagram 1 C/P≈8 line: A·b_f 280 000 → 3154 h; halved for +15 °C → 1577 h; G_p = 0.002·180·46 = 16.56 g',
      choices: {'type': 'srb_a', 'load': 'cp8', 'feed': 'ring'},
      numbers: {
        'd': (100, 'mm'),
        'od': (180, 'mm'),
        'b': (46, 'mm'),
        'n': (1000, 'rpm'),
        'temp': (85, 'C'),
      },
      expect: {
        'abf': (280000, '-'),
        'tf': (3154, 'h'),
        'tadj': (1577, 'h'),
        'gp': (16.56, 'g'),
      },
      relTol: 2e-2,
    ),
    ToolCase(
      'NU 2214 cylindrical roller (non-locating), 2000 rpm, 100 °C, vertical shaft',
      source:
          'Digitised SKF Diagram 1: A·b_f 292 500 → 5909 h; × 2^(−2) × 0.5 → 738.7 h',
      choices: {'type': 'crb_nl', 'shaft': 'v'},
      numbers: {
        'd': (70, 'mm'),
        'od': (125, 'mm'),
        'b': (31, 'mm'),
        'n': (2000, 'rpm'),
        'temp': (100, 'C'),
      },
      expect: {'tf': (5909, 'h'), 'tadj': (738.7, 'h'), 'ft': (0.25, '-')},
      relTol: 2e-2,
    ),
    ToolCase(
      '6205 at 40 °C: extension capped at × 2 and 30 000 h',
      source:
          'Digitised SKF Diagram 1: A 38 500 → 25 636 h; × 2 (Table 8 maximum) = 51 272 h → recommended 30 000 h',
      numbers: {
        'd': (25, 'mm'),
        'od': (52, 'mm'),
        'b': (15, 'mm'),
        'n': (1000, 'rpm'),
        'temp': (40, 'C'),
      },
      expect: {'tadj': (51272, 'h'), 'trec': (30000, 'h'), 'ft': (2, '-')},
      expectWarning: '30 000 h',
      relTol: 2e-2,
    ),
    ToolCase(
      '6205, outer-ring rotation, 1000 rpm, 70 °C',
      source: 'SKF Table 8: A = n·D = 52 000; digitised Diagram 1 → 23 712 h',
      choices: {'ring': 'outer'},
      numbers: {
        'd': (25, 'mm'),
        'od': (52, 'mm'),
        'b': (15, 'mm'),
        'n': (1000, 'rpm'),
        'temp': (70, 'C'),
      },
      expect: {'a': (52000, '-'), 'tf': (23712, 'h')},
      relTol: 2e-2,
    ),
  ],
);
