import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Target concentration of the solution to be made, as mol/L of the
/// formula unit (normality and g/L are converted using z and MW).
/// Returns mol/L. MW in g/mol.
double _targetMolL(ToolValues v) => switch (v.c('basis')) {
  'N' => v.n('cN') / v.n('z'),
  'gL' => v.n('cg') / v.n('mw'), // kg/m³ = g/L; g/L ÷ g/mol = mol/L
  _ => v.n('cM') / 1000, // base mol/m³ → mol/L
};

bool _prep(ToolValues v) => v.c('mode') != 'dil';

final dilutionTool = ToolDef(
  id: 'dilution',
  title: 'Dilution & solution prep',
  summary:
      'C₁V₁ = C₂V₂, mass of a solid to weigh (purity-corrected) and volume of '
      'a concentrated acid or base from its % w/w and density.',
  icon: Icons.science,
  keywords: [
    'dilution',
    'c1v1',
    'stock',
    'standard solution',
    'molarity',
    'normality',
    'weigh',
    'purity',
    'hcl',
    'h2so4',
    'sulphuric',
    'ammonia',
    'reagent',
    'preparation',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('dil', 'C₁V₁ = C₂V₂'),
        ChoiceOption('solid', 'From a solid'),
        ChoiceOption('acid', 'From conc. reagent'),
      ],
    ),
    // ---- C1V1 = C2V2 ----
    ChoiceInput(
      'solve',
      'Solve for',
      options: const [
        ChoiceOption('v1', 'Stock volume V₁'),
        ChoiceOption('c2', 'Final conc. C₂'),
        ChoiceOption('v2', 'Final volume V₂'),
      ],
      visibleWhen: (v) => v.c('mode') == 'dil',
    ),
    NumberInput(
      'c1',
      'Stock conc. C₁ (any unit)',
      quantity: Quantity.dimensionless,
      initial: 1000,
      min: 0,
      minInclusive: false,
      help: 'mg/L, mol/L, N, % … — C₁ and C₂ must be in the same unit.',
      visibleWhen: (v) => v.c('mode') == 'dil',
    ),
    NumberInput(
      'c2',
      'Final conc. C₂ (same unit)',
      quantity: Quantity.dimensionless,
      initial: 10,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'dil' && v.c('solve') != 'c2',
    ),
    NumberInput(
      'v1',
      'Stock volume V₁',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 1e-6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'dil' && v.c('solve') != 'v1',
    ),
    NumberInput(
      'v2',
      'Final volume V₂',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 100e-6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'dil' && v.c('solve') != 'v2',
    ),
    // ---- prepare from solid / concentrated reagent ----
    ChoiceInput(
      'basis',
      'Target given as',
      options: const [
        ChoiceOption('M', 'Molarity (mol/L)'),
        ChoiceOption('N', 'Normality (eq/L)'),
        ChoiceOption('gL', 'Mass conc. (g/L)'),
      ],
      visibleWhen: _prep,
    ),
    NumberInput(
      'cM',
      'Target molarity',
      quantity: Quantity.molarConc,
      initial: 100, // 0.1 mol/L
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _prep(v) && v.c('basis') == 'M',
    ),
    NumberInput(
      'cN',
      'Target normality (eq/L)',
      quantity: Quantity.dimensionless,
      initial: 0.1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _prep(v) && v.c('basis') == 'N',
    ),
    NumberInput(
      'cg',
      'Target mass conc.',
      quantity: Quantity.massConc,
      units: ('g/L', 'g/L'),
      initial: 1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _prep(v) && v.c('basis') == 'gL',
    ),
    NumberInput(
      'vf',
      'Final volume (flask)',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 1e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: _prep,
    ),
    NumberInput(
      'mw',
      'Molar mass (g/mol)',
      quantity: Quantity.dimensionless,
      initial: 39.997,
      min: 0,
      minInclusive: false,
      help:
          'Of the form actually weighed or sold (hydrate included). NaOH 39.997, '
          'Na₂CO₃ 105.99, HCl 36.46, H₂SO₄ 98.08, NH₃ 17.031, HNO₃ 63.01.',
      visibleWhen: _prep,
    ),
    NumberInput(
      'z',
      'Equivalents per mole z',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help:
          'H⁺ or OH⁻ exchanged in the titration: HCl, NaOH 1; H₂SO₄, Na₂CO₃ 2.',
      visibleWhen: (v) => _prep(v) && v.c('basis') == 'N',
    ),
    NumberInput(
      'purity',
      'Purity / assay of the solid',
      quantity: Quantity.percent,
      initial: 1,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'From the certificate of analysis (100 % if unknown).',
      visibleWhen: (v) => v.c('mode') == 'solid',
    ),
    NumberInput(
      'wpct',
      'Reagent assay (% w/w)',
      quantity: Quantity.percent,
      initial: 0.37,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'Label value: HCl 35–37 %, H₂SO₄ 95–98 %, NH₃ 25 %, HNO₃ 65–69 %.',
      visibleWhen: (v) => v.c('mode') == 'acid',
    ),
    NumberInput(
      'rho',
      'Reagent density',
      quantity: Quantity.density,
      units: ('g/cm3', 'g/cm3'),
      initial: 1190,
      min: 0,
      minInclusive: false,
      help:
          'Label value at 20 °C: HCl 37 % 1.19; H₂SO₄ 98 % 1.84; NH₃ 25 % 0.91.',
      visibleWhen: (v) => v.c('mode') == 'acid',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final w = <String>[];
    if (mode == 'dil') {
      final c1 = v.n('c1');
      late double c2, v1, v2;
      switch (v.c('solve')) {
        case 'c2':
          v1 = v.n('v1');
          v2 = v.n('v2');
          if (v1 > v2) {
            throw ToolInputError('V₁ cannot be larger than the final volume.');
          }
          c2 = c1 * v1 / v2;
        case 'v2':
          c2 = v.n('c2');
          v1 = v.n('v1');
          if (c2 > c1) {
            throw ToolInputError('C₂ above C₁: a dilution cannot concentrate.');
          }
          v2 = c1 * v1 / c2;
        default:
          c2 = v.n('c2');
          v2 = v.n('v2');
          if (c2 > c1) {
            throw ToolInputError('C₂ above C₁: a dilution cannot concentrate.');
          }
          v1 = c2 * v2 / c1;
      }
      final df = v2 / v1;
      if (v1 < 0.1e-6) {
        w.add(
          'V₁ below 0.1 mL: pipetting error is large — use an intermediate '
          'dilution.',
        );
      }
      if (df > 1000) {
        w.add(
          'Dilution factor above 1000 in one step: make it in two or more '
          'serial steps.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'v1',
            'Stock volume V₁',
            v1,
            quantity: Quantity.volume,
            units: ('mL', 'mL'),
            level: v.c('solve') == 'v1'
                ? OutputLevel.primary
                : OutputLevel.normal,
          ),
          ToolOutput(
            'v2',
            'Final volume V₂',
            v2,
            quantity: Quantity.volume,
            units: ('mL', 'mL'),
            level: v.c('solve') == 'v2'
                ? OutputLevel.primary
                : OutputLevel.normal,
          ),
          ToolOutput(
            'c2',
            'Final conc. C₂',
            c2,
            level: v.c('solve') == 'c2'
                ? OutputLevel.primary
                : OutputLevel.normal,
          ),
          ToolOutput('df', 'Dilution factor V₂/V₁', df),
          ToolOutput(
            'dil',
            'Diluent (approx.)',
            v2 - v1,
            quantity: Quantity.volume,
            units: ('mL', 'mL'),
          ),
        ],
        warnings: w,
        notes: [
          'Make up to the mark in a volumetric flask — volumes are not '
              'strictly additive, so "diluent" is only a guide.',
        ],
      );
    }

    final mw = v.n('mw');
    final vf = v.n('vf') * 1000; // m³ → L
    final molL = _targetMolL(v);
    final mol = molL * vf; // mol of formula unit needed
    final soluteG = mol * mw; // g of 100 % substance
    if (mode == 'solid') {
      final m = soluteG / v.n('purity');
      return ToolResult(
        [
          ToolOutput(
            'mass',
            'Mass to weigh',
            m / 1000,
            quantity: Quantity.mass,
            units: ('g', 'g'),
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput(
            'pure',
            'As 100 % substance',
            soluteG / 1000,
            quantity: Quantity.mass,
            units: ('g', 'g'),
          ),
          ToolOutput(
            'molL',
            'Molarity',
            molL * 1000,
            quantity: Quantity.molarConc,
          ),
        ],
        warnings: [
          if (m < 0.1)
            'Less than 100 mg to weigh: balance error may exceed 0.1 % — '
                'make a larger volume and dilute.',
        ],
        notes: [
          'Hygroscopic or CO₂-absorbing solids (NaOH, KOH) cannot be weighed '
              'to their nominal concentration: standardise the solution.',
        ],
      );
    }

    // From concentrated reagent: stock molarity = w·ρ/MW
    final rho = v.n('rho'); // kg/m³ = g/L
    final stockMolL = v.n('wpct') * rho / mw; // mol/L
    if (molL > stockMolL) {
      throw ToolInputError('Target is stronger than the concentrated reagent.');
    }
    final reagentG = soluteG / v.n('wpct');
    final vol = mol / stockMolL; // L
    if (vol < 0.5e-3) {
      w.add(
        'Less than 0.5 mL of reagent: measure by mass (shown) or use an '
        'intermediate dilution.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'vol',
          'Reagent volume to take',
          vol / 1000,
          quantity: Quantity.volume,
          units: ('mL', 'mL'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'rmass',
          'Same, by mass',
          reagentG / 1000,
          quantity: Quantity.mass,
          units: ('g', 'g'),
        ),
        ToolOutput(
          'stockM',
          'Reagent molarity',
          stockMolL * 1000,
          quantity: Quantity.molarConc,
        ),
        if (v.c('basis') == 'N')
          ToolOutput(
            'stockN',
            'Reagent normality (eq/L)',
            stockMolL * v.n('z'),
          ),
        ToolOutput(
          'molL',
          'Target molarity',
          molL * 1000,
          quantity: Quantity.molarConc,
        ),
      ],
      warnings: w,
      notes: [
        'Always add acid to water. Label % w/w and density vary by grade and '
            'lot — standardise the made-up solution before use.',
      ],
    );
  },
  formula: '''Dilution (amount of solute conserved):
  C₁·V₁ = C₂·V₂        DF = V₂ / V₁

From a solid (MW in g/mol, V in L, P = purity fraction):
  m [g] = c·V·MW / P       c in mol/L
  c = N / z                 (normality, z eq/mol)
  c = ρ* / MW               (mass conc. ρ* in g/L)

From a concentrated reagent (w = % w/w as fraction,
ρ = density in g/L, i.e. g/mL × 1000):
  c_stock [mol/L] = w·ρ / MW
  V_reagent = c·V / c_stock
  m_reagent = c·V·MW / w''',
  references: [
    'D. C. Harris, Quantitative Chemical Analysis, 9th ed., ch. 1 (solution preparation, dilution formula)',
    'Vogel\'s Textbook of Quantitative Chemical Analysis, 6th ed., ch. 10 (standard solutions, primary standards)',
    'ISO 6353-1 / ISO 6353-2: Reagents for chemical analysis — general test methods and specifications (assay of commercial reagents)',
  ],
  assumptions: [
    'Concentrations by volume refer to the final made-up volume at the flask\'s reference temperature (20 °C).',
    'Reagent % w/w and density are the label/CoA values at 20 °C.',
    'MW is entered for the species the concentration refers to.',
  ],
  cases: [
    const ToolCase(
      'Dilute 1000 mg/L stock to 10 mg/L in 100 mL',
      source: 'Hand calculation: V₁ = 10 × 100 / 1000 = 1.000 mL; DF 100',
      numbers: {'c1': (1000, '-'), 'c2': (10, '-'), 'v2': (100, 'mL')},
      expect: {'v1': (1.0, 'mL'), 'df': (100, '-'), 'dil': (99, 'mL')},
    ),
    const ToolCase(
      '25 mL of 0.5 M made up to 250 mL',
      source: 'Hand calculation: C₂ = 0.5 × 25 / 250 = 0.05; DF 10',
      choices: {'solve': 'c2'},
      numbers: {'c1': (0.5, '-'), 'v1': (25, 'mL'), 'v2': (250, 'mL')},
      expect: {'c2': (0.05, '-'), 'df': (10, '-')},
    ),
    const ToolCase(
      '0.1 M NaOH, 1 L, 98 % pellets',
      source: 'Hand calculation (refs.py): 0.1 × 1 × 39.997 / 0.98 = 4.08133 g',
      choices: {'mode': 'solid'},
      numbers: {
        'cM': (0.1, 'mol/L'),
        'vf': (1000, 'mL'),
        'mw': (39.997, '-'),
        'purity': (98, '%'),
      },
      expect: {'mass': (4.081327, 'g'), 'pure': (3.9997, 'g')},
      relTol: 1e-5,
    ),
    const ToolCase(
      '0.1 N Na₂CO₃ (z = 2), 500 mL, 99.9 %',
      source:
          'Hand calculation (refs.py): 0.1 × 0.5 × 105.99 / 2 / 0.999 = 2.65240 g',
      choices: {'mode': 'solid', 'basis': 'N'},
      numbers: {
        'cN': (0.1, '-'),
        'z': (2, '-'),
        'vf': (500, 'mL'),
        'mw': (105.99, '-'),
        'purity': (99.9, '%'),
      },
      expect: {'mass': (2.652402, 'g')},
      relTol: 1e-5,
    ),
    const ToolCase(
      '0.1 M HCl, 1 L, from 37 % (1.19 g/mL)',
      source:
          'Hand calculation (refs.py): c = 0.37 × 1190 / 36.46 = 12.076 M '
          '(textbook "conc. HCl ≈ 12 M"); V = 8.2807 mL',
      choices: {'mode': 'acid'},
      numbers: {
        'cM': (0.1, 'mol/L'),
        'vf': (1000, 'mL'),
        'mw': (36.46, '-'),
        'wpct': (37, '%'),
        'rho': (1.19, 'g/cm3'),
      },
      expect: {
        'stockM': (12.07625, 'mol/L'),
        'vol': (8.280718, 'mL'),
        'rmass': (9.854054, 'g'),
      },
      relTol: 1e-5,
    ),
    const ToolCase(
      '0.1 N H₂SO₄, 1 L, from 98 % (1.84 g/mL)',
      source:
          'Hand calculation (refs.py): c = 0.98 × 1840 / 98.079 = 18.385 M '
          '= 36.770 N; V = 2.71958 mL',
      choices: {'mode': 'acid', 'basis': 'N'},
      numbers: {
        'cN': (0.1, '-'),
        'z': (2, '-'),
        'vf': (1000, 'mL'),
        'mw': (98.079, '-'),
        'wpct': (98, '%'),
        'rho': (1.84, 'g/cm3'),
      },
      expect: {
        'stockM': (18.38518, 'mol/L'),
        'stockN': (36.77036, '-'),
        'vol': (2.719582, 'mL'),
      },
      relTol: 1e-5,
    ),
    const ToolCase(
      '2 g/L, 500 mL, 99 % solid',
      source: 'Hand calculation: 2 × 0.5 / 0.99 = 1.01010 g',
      choices: {'mode': 'solid', 'basis': 'gL'},
      numbers: {
        'cg': (2, 'g/L'),
        'vf': (500, 'mL'),
        'mw': (53.49, '-'),
        'purity': (99, '%'),
      },
      expect: {'mass': (1.010101, 'g')},
      relTol: 1e-5,
    ),
  ],
);
