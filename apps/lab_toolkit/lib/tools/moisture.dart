import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final moistureTool = ToolDef(
  id: 'moisture',
  title: 'Moisture & loss on ignition',
  summary:
      'Gravimetric moisture or LOI from dish/crucible weighings, wet-basis ⇄ '
      'dry-basis conversion, and reporting a result on a dry or stated '
      'moisture basis.',
  icon: Icons.local_fire_department,
  keywords: [
    'moisture',
    'water content',
    'loi',
    'loss on ignition',
    'ash',
    'residue',
    'dry matter',
    'dry basis',
    'wet basis',
    'as received',
    'gravimetric',
    'oven',
    'crucible',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('grav', 'From weighings'),
        ChoiceOption('conv', 'Wet ⇄ dry basis'),
        ChoiceOption('res', 'Result to dry basis'),
      ],
    ),
    ChoiceInput(
      'test',
      'Test',
      options: const [
        ChoiceOption('moist', 'Moisture (drying)'),
        ChoiceOption('loi', 'LOI (ignition)'),
      ],
      visibleWhen: (v) => v.c('mode') == 'grav',
    ),
    NumberInput(
      'm0',
      'Dish / crucible tare m₀',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 30.1234e-3,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'grav',
    ),
    NumberInput(
      'm1',
      'Dish + sample before m₁',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 40.1234e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'grav',
    ),
    NumberInput(
      'm2',
      'Dish + residue after m₂',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 39.6234e-3,
      min: 0,
      minInclusive: false,
      help: 'After drying/ignition to constant mass, cooled in a desiccator.',
      visibleWhen: (v) => v.c('mode') == 'grav',
    ),
    ChoiceInput(
      'from',
      'Known value',
      options: const [
        ChoiceOption('wb', 'Wet basis (as is)'),
        ChoiceOption('db', 'Dry basis'),
      ],
      visibleWhen: (v) => v.c('mode') == 'conv',
    ),
    NumberInput(
      'mc',
      'Moisture content',
      quantity: Quantity.percent,
      initial: 0.2,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'conv',
    ),
    NumberInput(
      'x',
      'Result as received (any unit)',
      quantity: Quantity.dimensionless,
      initial: 46.1,
      help: '% w/w, mg/kg … of any constituent other than water.',
      visibleWhen: (v) => v.c('mode') == 'res',
    ),
    NumberInput(
      'mar',
      'Moisture of the sample (wet basis)',
      quantity: Quantity.percent,
      initial: 0.004,
      min: 0,
      max: 1,
      visibleWhen: (v) => v.c('mode') == 'res',
    ),
    NumberInput(
      'mref',
      'Report at moisture (wet basis)',
      quantity: Quantity.percent,
      initial: 0,
      min: 0,
      max: 1,
      help: '0 % = dry basis.',
      visibleWhen: (v) => v.c('mode') == 'res',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final w = <String>[];
    if (mode == 'conv') {
      final mc = v.n('mc');
      late double wb, db;
      if (v.c('from') == 'wb') {
        if (mc >= 1) {
          throw ToolInputError('Wet-basis moisture must be below 100 %.');
        }
        wb = mc;
        db = mc / (1 - mc);
      } else {
        db = mc;
        wb = mc / (1 + mc);
      }
      return ToolResult([
        ToolOutput(
          'wb',
          'Wet basis',
          wb,
          quantity: Quantity.percent,
          level: v.c('from') == 'db' ? OutputLevel.primary : OutputLevel.normal,
          sig: 5,
        ),
        ToolOutput(
          'db',
          'Dry basis',
          db,
          quantity: Quantity.percent,
          level: v.c('from') == 'wb' ? OutputLevel.primary : OutputLevel.normal,
          sig: 5,
        ),
        ToolOutput(
          'dm',
          'Dry matter',
          1 - wb,
          quantity: Quantity.percent,
          sig: 5,
        ),
      ]);
    }

    if (mode == 'res') {
      final mar = v.n('mar'), mref = v.n('mref');
      if (mar >= 1 || mref >= 1) {
        throw ToolInputError('Moisture must be below 100 %.');
      }
      final f = (1 - mref) / (1 - mar);
      return ToolResult(
        [
          ToolOutput(
            'y',
            'Result on new basis',
            v.n('x') * f,
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput('f', 'Conversion factor', f, sig: 6),
        ],
        notes: [
          'Not valid for the water content itself — use Wet ⇄ dry basis.',
        ],
      );
    }

    final m0 = v.n('m0'), m1 = v.n('m1'), m2 = v.n('m2');
    final sample = m1 - m0;
    if (sample <= 0) {
      throw ToolInputError('m₁ must be larger than the tare m₀.');
    }
    if (m2 < m0) {
      throw ToolInputError('m₂ is below the tare: residue would be negative.');
    }
    final residue = m2 - m0;
    final loss = m1 - m2;
    final wb = loss / sample;
    final loi = v.c('test') == 'loi';
    if (loss < 0) {
      w.add(
        loi
            ? 'Mass gained on ignition (e.g. oxidation of metals or sulfides): '
                  'the result is negative.'
            : 'Mass gained on drying: check the balance and desiccator.',
      );
    }
    if (sample < 1e-3) {
      w.add('Test portion below 1 g: weighing error may be significant.');
    }
    return ToolResult(
      [
        ToolOutput(
          'wb',
          loi ? 'LOI' : 'Moisture (wet basis)',
          wb,
          quantity: Quantity.percent,
          level: OutputLevel.primary,
          sig: 5,
        ),
        if (!loi)
          ToolOutput(
            'db',
            'Moisture (dry basis)',
            residue > 0 ? loss / residue : double.nan,
            quantity: Quantity.percent,
            sig: 5,
          ),
        ToolOutput(
          'res',
          loi ? 'Residue / ash' : 'Dry matter',
          residue / sample,
          quantity: Quantity.percent,
          sig: 5,
        ),
        ToolOutput(
          'loss',
          'Mass lost',
          loss,
          quantity: Quantity.mass,
          units: ('g', 'g'),
          sig: 5,
        ),
        ToolOutput(
          'sample',
          'Test portion',
          sample,
          quantity: Quantity.mass,
          units: ('g', 'g'),
          sig: 6,
        ),
      ],
      warnings: w,
      notes: [
        'Drying temperature/time and ignition temperature come from the '
            'product method (e.g. urea moisture is normally by Karl Fischer).',
      ],
    );
  },
  formula: '''Weighings (balance readings, same dish):
  test portion   = m₁ − m₀
  loss           = m₁ − m₂
  residue        = m₂ − m₀

  wet basis  w = (m₁ − m₂)/(m₁ − m₀) × 100
  dry basis  u = (m₁ − m₂)/(m₂ − m₀) × 100
  dry matter / ash = (m₂ − m₀)/(m₁ − m₀) × 100

Basis conversion (fractions):
  u = w / (1 − w)        w = u / (1 + u)

Result on another moisture basis:
  x_new = x_as-received × (1 − M_new)/(1 − M_as-received)
  dry basis: M_new = 0''',
  references: [
    'ISO 11465:1993 Soil quality — Determination of dry matter and water content on a mass basis — Gravimetric method, clause 7 (dry-matter and dry-basis water content formulas)',
    'ASTM D2216 Laboratory determination of water (moisture) content (water content on dry-mass basis)',
    'ASTM D7348 Loss on ignition (LOI) of solid combustion residues; ISO 1171 Solid mineral fuels — Determination of ash',
    'AOAC Official Method 950.01 Water in fertilizers (drying method); ISO 760 Karl Fischer method for water',
  ],
  assumptions: [
    'Dried / ignited to constant mass; only water (or volatiles) is lost.',
    'Buoyancy and dish moisture uptake ignored (same dish weighed each time).',
  ],
  cases: [
    const ToolCase(
      'Oven moisture: 10 g sample loses 0.5 g',
      source:
          'ISO 11465 formulas, hand calculation: 5.000 % wet, 5.2632 % dry '
          'basis, 95.000 % dry matter',
      numbers: {
        'm0': (30.1234, 'g'),
        'm1': (40.1234, 'g'),
        'm2': (39.6234, 'g'),
      },
      expect: {'wb': (5.0, '%'), 'db': (5.263158, '%'), 'res': (95.0, '%')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'LOI: 1.0000 g ignited to 0.6543 g',
      source: 'Hand calculation: LOI 34.570 %, ash 65.430 %',
      choices: {'test': 'loi'},
      numbers: {'m0': (20.0, 'g'), 'm1': (21.0, 'g'), 'm2': (20.6543, 'g')},
      expect: {'wb': (34.57, '%'), 'res': (65.43, '%')},
      relTol: 1e-6,
    ),
    const ToolCase(
      '20 % wet basis → dry basis',
      source: 'Hand calculation: 0.20/0.80 = 25.000 %',
      choices: {'mode': 'conv'},
      numbers: {'mc': (20, '%')},
      expect: {'db': (25.0, '%'), 'dm': (80, '%')},
      relTol: 1e-9,
    ),
    const ToolCase(
      '25 % dry basis → wet basis',
      source: 'Hand calculation: 0.25/1.25 = 20.000 %',
      choices: {'mode': 'conv', 'from': 'db'},
      numbers: {'mc': (25, '%')},
      expect: {'wb': (20.0, '%')},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Urea 46.10 % N at 0.40 % moisture → dry basis',
      source: 'Hand calculation: 46.10/(1 − 0.004) = 46.2851 %',
      choices: {'mode': 'res'},
      numbers: {'x': (46.10, '-'), 'mar': (0.4, '%'), 'mref': (0, '%')},
      expect: {'y': (46.28514, '-')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Result 10 at 12 % moisture → 15 % moisture basis',
      source: 'Hand calculation: 10 × 0.85/0.88 = 9.65909',
      choices: {'mode': 'res'},
      numbers: {'x': (10, '-'), 'mar': (12, '%'), 'mref': (15, '%')},
      expect: {'y': (9.659091, '-')},
      relTol: 1e-6,
    ),
  ],
);
