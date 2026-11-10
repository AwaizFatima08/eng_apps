import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const double _ft = 0.3048;
const double _ft2 = _ft * _ft;

/// NFPA 10 Table 6.2.1.1 (Class A): (min single rating, ft² per unit of A).
const Map<String, (int, double)> _classA = {
  'light': (2, 3000),
  'ordinary': (2, 1500),
  'extra': (4, 1000),
};
const double _maxAreaPerExt = 11250; // ft², all hazards
const double _travelA = 75; // ft

/// NFPA 10 Table 6.3.1.1 (Class B, liquids ≤ 6.3 mm deep):
/// (rating for 30 ft travel, rating for 50 ft travel).
const Map<String, (int, int)> _classB = {
  'light': (5, 10),
  'ordinary': (10, 20),
  'extra': (40, 80),
};

final extinguisherTool = ToolDef(
  id: 'extinguisher',
  title: 'Fire extinguisher coverage (NFPA 10)',
  summary:
      'Class A: floor area per extinguisher and number needed for the hazard. '
      'Class B: maximum travel distance for the extinguisher rating.',
  icon: Icons.fire_extinguisher,
  keywords: [
    'fire',
    'extinguisher',
    'nfpa 10',
    'rating',
    'travel distance',
    'class a',
    'class b',
    'hazard',
    'coverage',
    'placement',
    'dcp',
  ],
  inputs: [
    const ChoiceInput(
      'cls',
      'Fire class',
      options: [
        ChoiceOption('a', 'Class A (solids)'),
        ChoiceOption('b', 'Class B (liquids)'),
      ],
    ),
    const ChoiceInput(
      'hazard',
      'Hazard occupancy',
      initial: 'ordinary',
      options: [
        ChoiceOption('light', 'Light (low)'),
        ChoiceOption('ordinary', 'Ordinary (moderate)'),
        ChoiceOption('extra', 'Extra (high)'),
      ],
      help:
          'Light: offices, classrooms. Ordinary: stores, workshops, light '
          'storage. Extra: warehouses with high-piled stock, process areas, '
          'flammable-liquid handling (NFPA 10 cl. 5.4).',
    ),
    NumberInput(
      'ra',
      'Class A rating (the number before "A")',
      quantity: Quantity.dimensionless,
      initial: 4,
      min: 1,
      max: 40,
      help: 'e.g. 4 for a 4-A:80-B:C dry powder unit.',
      visibleWhen: (v) => v.c('cls') == 'a',
    ),
    NumberInput(
      'area',
      'Floor area to protect',
      quantity: Quantity.area,
      units: ('m2', 'ft2'),
      initial: 2000,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('cls') == 'a',
    ),
    NumberInput(
      'rb',
      'Class B rating (the number before "B")',
      quantity: Quantity.dimensionless,
      initial: 40,
      min: 1,
      max: 640,
      visibleWhen: (v) => v.c('cls') == 'b',
    ),
  ],
  compute: (v) {
    final hazard = v.c('hazard');
    final w = <String>[];
    if (v.c('cls') == 'b') {
      final (lo, hi) = _classB[hazard] ?? _classB['ordinary']!;
      final rb = v.n('rb');
      final double travelFt;
      final String status;
      final OutputLevel level;
      if (rb >= hi) {
        travelFt = 50;
        status = 'Rating ≥ $hi-B: travel up to 50 ft';
        level = OutputLevel.ok;
      } else if (rb >= lo) {
        travelFt = 30;
        status = 'Rating ≥ $lo-B: travel up to 30 ft';
        level = OutputLevel.ok;
      } else {
        travelFt = 0;
        status = 'Below basic minimum $lo-B: not acceptable';
        level = OutputLevel.fail;
        w.add(
          'Several smaller extinguishers cannot replace one of the basic '
          'minimum rating (NFPA 10 cl. 6.3.1; some foam units excepted).',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'travel',
            'Max travel distance',
            travelFt * _ft,
            quantity: Quantity.length,
            units: ('m', 'ft'),
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput.text('status', 'Verdict', status, level: level),
        ],
        warnings: w,
        notes: [
          'Applies to spill fires in liquids up to 6.3 mm (¼ in) deep. Deeper '
              'liquids (dip tanks, bunds): NFPA 10 cl. 6.3.2 — about 2 B units '
              'per ft² of liquid surface.',
          'Ratings between the two table values get the 30 ft distance (no '
              'interpolation in the table).',
        ],
      );
    }

    final (minRating, perUnit) = _classA[hazard] ?? _classA['ordinary']!;
    final ra = v.n('ra');
    final areaFt2 = v.n('area') / _ft2;
    final covFt2 = (ra * perUnit).clamp(0.0, _maxAreaPerExt);
    final raw = areaFt2 / covFt2;
    final n = (raw - 1e-9).ceilToDouble().clamp(1.0, double.infinity);
    final okRating = ra >= minRating;
    if (!okRating) {
      w.add(
        'Rating below the minimum single-extinguisher rating $minRating-A for '
        'this hazard (NFPA 10 Table 6.2.1.1).',
      );
    }
    if (ra * perUnit > _maxAreaPerExt) {
      w.add(
        'Coverage capped at 11,250 ft² (1045 m²) per extinguisher: a higher '
        'rating does not reduce the count further.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'n',
          'Minimum number (by area)',
          okRating ? n : double.nan,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'cov',
          'Area per extinguisher',
          covFt2 * _ft2,
          quantity: Quantity.area,
          units: ('m2', 'ft2'),
          sig: 5,
        ),
        ToolOutput(
          'travel',
          'Max travel distance',
          _travelA * _ft,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 4,
        ),
        ToolOutput.text(
          'status',
          'Rating check',
          okRating
              ? 'Rating meets minimum $minRating-A'
              : 'Below minimum $minRating-A: not acceptable',
          level: okRating ? OutputLevel.ok : OutputLevel.fail,
        ),
        ToolOutput('raw', 'Area ÷ coverage', raw, sig: 4),
      ],
      warnings: w,
      notes: [
        'The 75 ft (22.9 m) travel distance usually governs: place units so no '
            'point is farther than that by the actual walking route — the count '
            'by area is a minimum.',
        'Up to half the Class A units may be replaced by 1½ in hose stations '
            '(NFPA 10 cl. 6.2.1). Two 2½-gal water units may count as one 4-A.',
      ],
    );
  },
  formula: '''NFPA 10 Table 6.2.1.1 — Class A
             min rating   ft² per A   max ft²/unit   travel
  Light        2-A          3000        11 250        75 ft
  Ordinary     2-A          1500        11 250        75 ft
  Extra        4-A          1000        11 250        75 ft
  Area per unit = min(rating × ft² per A, 11 250 ft²)
  Number ≥ ceil(floor area / area per unit)

NFPA 10 Table 6.3.1.1 — Class B (≤ ¼ in deep)
             30 ft travel   50 ft travel
  Light         5-B            10-B
  Ordinary     10-B            20-B
  Extra        40-B            80-B
1 ft = 0.3048 m, 1 ft² = 0.0929 m²''',
  references: [
    'NFPA 10 Standard for Portable Fire Extinguishers (2022), Tables 6.2.1.1 and 6.3.1.1, cl. 6.3.2, Annex E',
    'California CCR Title 19 §568 Table 2 and §569 (reproduce the NFPA 10 Class A / B tables)',
    'NFPA 10 fact sheet (2022): 75 ft (22.9 m) Class A, 30–50 ft (9.1–15.25 m) Class B',
  ],
  assumptions: [
    'Hazard classification per NFPA 10 cl. 5.4 is the user\'s judgement.',
    'Class C, D and K placement are not covered (C follows the A/B hazard; K ≤ 30 ft; D ≤ 75 ft).',
    'Count by area is a lower bound; travel distance and building layout decide the final number.',
  ],
  cases: [
    const ToolCase(
      'Ordinary hazard, 4-A units, 45 000 ft²',
      source:
          'Hand calc from NFPA 10 Table 6.2.1.1: 4 × 1500 = 6000 ft²/unit; '
          '45 000/6000 = 7.5 ⇒ 8',
      numbers: {'ra': (4, '-'), 'area': (45000, 'ft2')},
      expect: {'n': (8, '-'), 'cov': (6000, 'ft2'), 'travel': (75, 'ft')},
      expectText: {'status': 'meets'},
    ),
    const ToolCase(
      'Light hazard, 10-A units, 30 000 ft² (11 250 ft² cap)',
      source:
          'Table 6.2.1.1: min(10 × 3000, 11 250) = 11 250 ft²; 30 000/11 250 = 2.67 ⇒ 3',
      choices: {'hazard': 'light'},
      numbers: {'ra': (10, '-'), 'area': (30000, 'ft2')},
      expect: {'n': (3, '-'), 'cov': (11250, 'ft2')},
      expectWarning: '11,250',
    ),
    const ToolCase(
      'Ordinary hazard, 6-A, 2000 m² (metric)',
      source:
          'Hand calc: 6 × 1500 = 9000 ft² = 836.13 m²; 2000/836.13 = 2.39 ⇒ 3',
      numbers: {'ra': (6, '-'), 'area': (2000, 'm2')},
      expect: {'n': (3, '-'), 'cov': (836.127, 'm2'), 'travel': (22.86, 'm')},
    ),
    const ToolCase(
      'Extra hazard with a 2-A unit fails the minimum',
      source: 'NFPA 10 Table 6.2.1.1: extra hazard minimum single rating 4-A',
      choices: {'hazard': 'extra'},
      numbers: {'ra': (2, '-'), 'area': (5000, 'ft2')},
      expect: {'cov': (2000, 'ft2')},
      expectText: {'status': 'Below minimum 4-A'},
      expectWarning: 'minimum single-extinguisher',
    ),
    const ToolCase(
      'Class B, ordinary hazard, 20-B ⇒ 50 ft',
      source:
          'NFPA 10 Table 6.3.1.1 / CCR T19 §569: ordinary 20-B, 50 ft (15.24 m)',
      choices: {'cls': 'b'},
      numbers: {'rb': (20, '-')},
      expect: {'travel': (50, 'ft')},
      expectText: {'status': '50 ft'},
    ),
    const ToolCase(
      'Class B, extra hazard, 40-B ⇒ 30 ft',
      source: 'NFPA 10 Table 6.3.1.1: extra 40-B 30 ft (9.14 m), 80-B 50 ft',
      choices: {'cls': 'b', 'hazard': 'extra'},
      numbers: {'rb': (40, '-')},
      expect: {'travel': (9.144, 'm')},
      expectText: {'status': '30 ft'},
    ),
    const ToolCase(
      'Class B, extra hazard, 20-B is below the minimum',
      source: 'NFPA 10 Table 6.3.1.1: extra hazard basic minimum 40-B',
      choices: {'cls': 'b', 'hazard': 'extra'},
      numbers: {'rb': (20, '-')},
      expect: {'travel': (0, 'm')},
      expectText: {'status': 'Below basic minimum 40-B'},
      expectWarning: 'Several smaller',
      absTol: 1e-12,
    ),
  ],
);
