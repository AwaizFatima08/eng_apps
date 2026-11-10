import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Average-end-area volume (any spacing).
double endAreaVolume(List<double> ch, List<double> a) {
  var v = 0.0;
  for (var i = 0; i < ch.length - 1; i++) {
    v += (ch[i + 1] - ch[i]) * (a[i] + a[i + 1]) / 2;
  }
  return v;
}

/// Prismoidal rule (Simpson's 1/3) for equally spaced sections. With an
/// even number of sections the last strip is added by end areas.
double prismoidalVolume(double d, List<double> a) {
  final n = a.length;
  final m = n.isOdd ? n : n - 1; // sections covered by Simpson
  var s = a[0] + a[m - 1];
  for (var i = 1; i < m - 1; i++) {
    s += (i.isOdd ? 4 : 2) * a[i];
  }
  var v = d / 3 * s;
  if (m < n) v += d * (a[n - 2] + a[n - 1]) / 2;
  return v;
}

final earthworkTool = ToolDef(
  id: 'earthwork',
  title: 'Earthwork volume',
  summary:
      'Cut or fill volume from cross-section areas at chainages: average end '
      'area and prismoidal (Simpson) rule, with swell and shrinkage.',
  icon: Icons.terrain,
  keywords: [
    'earthwork',
    'cut',
    'fill',
    'excavation',
    'embankment',
    'chainage',
    'cross section',
    'end area',
    'prismoidal',
    'simpson',
    'swell',
    'bulking',
    'shrinkage',
    'compaction',
    'road',
  ],
  inputs: [
    const ListInput(
      'ch',
      'Chainages',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: [0, 20, 40, 60, 80],
      minCount: 2,
      maxCount: 200,
      help: 'In increasing order, one per cross-section.',
    ),
    const ListInput(
      'area',
      'Cross-section areas',
      quantity: Quantity.area,
      units: ('m2', 'ft2'),
      initial: [12.5, 18.2, 22.4, 16.8, 10.3],
      minCount: 2,
      maxCount: 200,
      min: 0,
      help:
          'Same order and count as the chainages. Run cut and fill separately.',
    ),
    const ChoiceInput(
      'method',
      'Method',
      initial: 'prism',
      options: [
        ChoiceOption('prism', 'Prismoidal (Simpson)'),
        ChoiceOption('ea', 'Average end area'),
      ],
    ),
    const NumberInput(
      'swell',
      'Swell (bank → loose)',
      quantity: Quantity.percent,
      initial: 0.25,
      min: 0,
      max: 1,
      help:
          'Common earth ≈ 25 %, clay 30–40 %, sand/gravel 10–15 %, blasted rock 50–65 %.',
    ),
    const NumberInput(
      'shrink',
      'Shrinkage (bank → compacted)',
      quantity: Quantity.percent,
      initial: 0.10,
      min: -0.5,
      max: 0.9,
      help:
          'Common earth ≈ 10 %, clay 10–20 %, sand 12 %. Rock gains volume: enter negative.',
    ),
  ],
  compute: (v) {
    final ch = v.l('ch'), a = v.l('area');
    if (ch.length != a.length) {
      throw ToolInputError(
        'Enter one area per chainage (${ch.length} chainages, ${a.length} areas).',
      );
    }
    for (var i = 1; i < ch.length; i++) {
      if (ch[i] <= ch[i - 1]) {
        throw ToolInputError(
          'Chainages must increase from one section to the next.',
        );
      }
    }
    final n = ch.length;
    final d = ch[1] - ch[0];
    var equal = true;
    for (var i = 1; i < n; i++) {
      if (((ch[i] - ch[i - 1]) - d).abs() > 1e-6 * d) equal = false;
    }
    final vEa = endAreaVolume(ch, a);
    final w = <String>[];
    final wantPrism = v.c('method') == 'prism';
    double? vPr;
    if (equal && n >= 3) {
      vPr = prismoidalVolume(d, a);
      if (n.isEven && wantPrism) {
        w.add(
          'Even number of sections ($n): Simpson used on the first ${n - 1}, '
          'end area on the last strip. Add a section for a full prismoidal result.',
        );
      }
    } else if (wantPrism) {
      w.add(
        n < 3
            ? 'Prismoidal rule needs at least 3 sections: average end area used.'
            : 'Sections are not equally spaced: prismoidal (Simpson) rule not valid, '
                  'average end area used.',
      );
    }
    final bank = wantPrism && vPr != null ? vPr : vEa;
    final swell = v.n('swell'), shrink = v.n('shrink');
    return ToolResult(
      [
        ToolOutput(
          'len',
          'Length',
          ch.last - ch.first,
          quantity: Quantity.length,
          units: ('m', 'ft'),
        ),
        ToolOutput(
          'vea',
          'Average end area',
          vEa,
          quantity: Quantity.volume,
          units: ('m3', 'yd3'),
          sig: 6,
        ),
        if (vPr != null)
          ToolOutput(
            'vpr',
            'Prismoidal (Simpson)',
            vPr,
            quantity: Quantity.volume,
            units: ('m3', 'yd3'),
            sig: 6,
          ),
        if (vPr != null)
          ToolOutput(
            'corr',
            'Prismoidal correction',
            vEa - vPr,
            quantity: Quantity.volume,
            units: ('m3', 'yd3'),
            sig: 4,
          ),
        ToolOutput(
          'bank',
          'Bank (in-situ) volume',
          bank,
          quantity: Quantity.volume,
          units: ('m3', 'yd3'),
          level: OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput(
          'loose',
          'Loose (haul) volume',
          bank * (1 + swell),
          quantity: Quantity.volume,
          units: ('m3', 'yd3'),
          level: OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput(
          'compact',
          'Compacted volume',
          bank * (1 - shrink),
          quantity: Quantity.volume,
          units: ('m3', 'yd3'),
          sig: 6,
        ),
        ToolOutput('lf', 'Load factor 1/(1+swell)', 1 / (1 + swell), sig: 4),
      ],
      warnings: w,
      notes: [
        'Prismoidal correction = end area − prismoidal; end areas usually over-estimate cut.',
        'Fill to place: compacted volume needed ÷ (1 − shrinkage) = bank volume to borrow.',
      ],
    );
  },
  formula: '''Sections A₁ … Aₙ at chainages x₁ … xₙ

Average end area (any spacing):
  V = Σ (xᵢ₊₁ − xᵢ)·(Aᵢ + Aᵢ₊₁)/2
  equal spacing d: V = d·[(A₁ + Aₙ)/2 + A₂ + … + Aₙ₋₁]

Prismoidal rule (Simpson's 1/3), equal spacing d,
odd number of sections:
  V = d/3 · [A₁ + Aₙ + 4(A₂ + A₄ + …) + 2(A₃ + A₅ + …)]
  even count: last strip by end areas

Prismoidal correction  C = V_end area − V_prismoidal

Swell s and shrinkage k (fractions of bank volume):
  Loose     = Bank × (1 + s)
  Compacted = Bank × (1 − k)
  Load factor = 1/(1 + s)''',
  references: [
    'N. N. Basak, Surveying and Levelling, 2nd ed., ch. 8 "Computation of Volume" (trapezoidal and prismoidal formulae, worked problems)',
    'B. C. Punmia, Surveying Vol. 1, ch. on areas and volumes (prismoidal rule needs an odd number of sections)',
    'R. L. Peurifoy et al., Construction Planning, Equipment and Methods, 9th ed., ch. 4 (swell, shrinkage, load factor)',
    'Caterpillar Performance Handbook, "Mining and Earthmoving" (typical swell / load factors)',
  ],
  assumptions: [
    'Areas are measured on vertical planes normal to the centre line (no curvature correction).',
    'Simpson\'s rule assumes the ground varies smoothly between sections (prismoid).',
    'Swell and shrinkage are site averages; confirm by field density tests.',
  ],
  cases: [
    const ToolCase(
      'Basak ch. 8 pb-4: contour areas at 5 m',
      source:
          'Basak, Surveying and Levelling, ch. 8 problem 4: trapezoidal 330 375 m³, prismoidal 330 250 m³',
      lists: {
        'ch': ([0, 5, 10, 15, 20], 'm'),
        'area': ([2050, 8400, 16300, 24600, 31500], 'm2'),
      },
      numbers: {'swell': (25, '%'), 'shrink': (10, '%')},
      expect: {
        'vea': (330375, 'm3'),
        'vpr': (330250, 'm3'),
        'corr': (125, 'm3'),
        'loose': (412812.5, 'm3'),
        'compact': (297225, 'm3'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Basak ch. 8 pb-1: 7 sections at 40 m',
      source:
          'Basak ch. 8 problem 1: trapezoidal 5096.775 m³, prismoidal 5143.25 m³',
      choices: {'method': 'ea'},
      lists: {
        'ch': ([0, 40, 80, 120, 160, 200, 240], 'm'),
        'area': (
          [10.215, 14.84375, 28.43375, 34.375, 23.63375, 16.23375, 9.58375],
          'm2',
        ),
      },
      expect: {
        'vea': (5096.775, 'm3'),
        'vpr': (5143.25, 'm3'),
        'bank': (5096.775, 'm3'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Basak ch. 8 pb-3: 7 sections at 50 m',
      source: 'Basak ch. 8 problem 3: prismoidal 5472.125 m³',
      lists: {
        'ch': ([0, 50, 100, 150, 200, 250, 300], 'm'),
        'area': (
          [26.25, 11.5625, 8.5025, 15.9225, 22.44, 30.9225, 6.5625],
          'm2',
        ),
      },
      expect: {'bank': (5472.125, 'm3')},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Even number of sections (6 at 20 m)',
      source:
          'Python hand calc: Simpson on 5 + end area on last strip = 4020 m³; end area 4180 m³; loose ×1.30 = 5226 m³',
      lists: {
        'ch': ([0, 20, 40, 60, 80, 100], 'm'),
        'area': ([38, 62, 74, 18, 22, 28], 'm2'),
      },
      numbers: {'swell': (30, '%'), 'shrink': (12, '%')},
      expect: {
        'vea': (4180, 'm3'),
        'bank': (4020, 'm3'),
        'loose': (5226, 'm3'),
        'compact': (3537.6, 'm3'),
      },
      expectWarning: 'Even number',
      relTol: 1e-9,
    ),
    const ToolCase(
      'Unequal spacing falls back to end areas',
      source: 'Hand calc: 20·15 + 25·16.5 + 15·12 = 892.5 m³',
      lists: {
        'ch': ([0, 20, 45, 60], 'm'),
        'area': ([12, 18, 15, 9], 'm2'),
      },
      expect: {'bank': (892.5, 'm3')},
      expectWarning: 'not equally spaced',
      relTol: 1e-9,
    ),
  ],
);
