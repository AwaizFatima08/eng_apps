import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final concentrationTool = ToolDef(
  id: 'concentration',
  title: 'Concentration converter',
  summary:
      'Molarity, normality, g/L, mg/L, ppm (w/w), % w/v and % w/w from one '
      'value, using molar mass, equivalents per mole and solution density.',
  icon: Icons.swap_horiz,
  keywords: [
    'molarity',
    'normality',
    'ppm',
    'mg/l',
    'percent',
    'w/v',
    'w/w',
    'mmol',
    'equivalent',
    'convert',
    'unit',
  ],
  inputs: [
    const ChoiceInput(
      'from',
      'Value is in',
      options: [
        ChoiceOption('M', 'mol/L (M)'),
        ChoiceOption('mM', 'mmol/L'),
        ChoiceOption('N', 'eq/L (N)'),
        ChoiceOption('gL', 'g/L'),
        ChoiceOption('mgL', 'mg/L'),
        ChoiceOption('ppm', 'ppm w/w (mg/kg)'),
        ChoiceOption('wv', '% w/v (g/100 mL)'),
        ChoiceOption('ww', '% w/w'),
      ],
    ),
    const NumberInput(
      'x',
      'Value',
      quantity: Quantity.dimensionless,
      initial: 0.1,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'mw',
      'Molar mass (g/mol)',
      quantity: Quantity.dimensionless,
      initial: 39.997,
      min: 0,
      minInclusive: false,
      help:
          'Of the species the concentration is expressed as (e.g. as N 14.007, as CaCO₃ 100.09).',
    ),
    const NumberInput(
      'z',
      'Equivalents per mole z',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help:
          'For normality: HCl, NaOH 1; H₂SO₄, CaCO₃, Na₂CO₃ 2; H₃PO₄ 1–3 (depends on end point).',
    ),
    const NumberInput(
      'rho',
      'Solution density',
      quantity: Quantity.density,
      units: ('g/cm3', 'g/cm3'),
      initial: 1000,
      min: 0,
      minInclusive: false,
      help: 'Needed only for ppm w/w and % w/w. Dilute aqueous ≈ 1.000.',
    ),
  ],
  compute: (v) {
    final x = v.n('x'), mw = v.n('mw'), z = v.n('z'), rho = v.n('rho');
    // c = mass concentration in kg/m³ (= g/L).
    final c = switch (v.c('from')) {
      'M' => x * mw,
      'mM' => x * mw / 1000,
      'N' => x * mw / z,
      'gL' => x,
      'mgL' => x / 1000,
      'ppm' => x * 1e-6 * rho,
      'wv' => x * 10,
      'ww' => x / 100 * rho,
      _ => throw ToolInputError('Unknown unit'),
    };
    final ww = c / rho; // mass fraction
    if (ww > 1) {
      throw ToolInputError(
        'Mass fraction above 100 %: check the value and density.',
      );
    }
    final molL = c / mw; // g/L ÷ g/mol
    final from = v.c('from');
    final dens = from == 'ppm' || from == 'ww';
    return ToolResult(
      [
        ToolOutput(
          'M',
          'Molarity',
          molL * 1000,
          quantity: Quantity.molarConc,
          sig: 6,
        ),
        ToolOutput('N', 'Normality (eq/L)', molL * z, sig: 6),
        ToolOutput(
          'gL',
          'Mass conc.',
          c,
          quantity: Quantity.massConc,
          units: ('g/L', 'g/L'),
          sig: 6,
        ),
        ToolOutput(
          'mgL',
          'Mass conc.',
          c,
          quantity: Quantity.massConc,
          fixedUnit: 'mg/L',
          sig: 6,
        ),
        ToolOutput('ppm', 'ppm w/w (mg/kg)', ww * 1e6, sig: 6),
        ToolOutput(
          'wv',
          '% w/v (g/100 mL)',
          c / 1000,
          quantity: Quantity.percent,
          sig: 6,
        ),
        ToolOutput('ww', '% w/w', ww, quantity: Quantity.percent, sig: 6),
      ],
      warnings: [
        if (!dens && (rho - 1000).abs() < 1e-9 && ww > 0.01)
          'Above 1 % with density 1.000: ppm w/w and % w/w need the real '
              'solution density.',
      ],
      notes: [
        'In water analysis "ppm" usually means mg/L; it equals mg/kg only '
            'when the density is 1.000 g/mL.',
      ],
    );
  },
  formula: '''Everything goes through the mass concentration
c [g/L] (MW in g/mol, ρ in g/L = g/mL × 1000):
  from mol/L:   c = M·MW
  from eq/L:    c = N·MW / z
  from mg/L:    c = (mg/L) / 1000
  from ppm w/w: c = ppm·10⁻⁶·ρ
  from % w/v:   c = 10·(% w/v)
  from % w/w:   c = (% w/w)/100·ρ

Then:
  M = c / MW        N = z·M
  % w/v = c / 10    % w/w = 100·c / ρ
  ppm w/w = 10⁶·c / ρ''',
  references: [
    'IUPAC Green Book (Quantities, Units and Symbols in Physical Chemistry, 3rd ed.), §2.10 — amount and mass concentration, mass fraction',
    'Standard Methods for the Examination of Water and Wastewater, 1050 B — expression of results (mg/L vs mg/kg)',
    'Vogel\'s Textbook of Quantitative Chemical Analysis, 6th ed., ch. 10 (normality and equivalents)',
  ],
  assumptions: [
    'Normality uses a fixed z per mole; it depends on the reaction and end point (e.g. H₃PO₄, Na₂CO₃).',
    'Volume-based units refer to the solution volume at its measurement temperature.',
  ],
  cases: [
    const ToolCase(
      '0.1 M NaOH (MW 40.00)',
      source: 'Hand calculation: 4.000 g/L = 4000 mg/L = 0.400 % w/v',
      numbers: {'x': (0.1, '-'), 'mw': (40.0, '-'), 'rho': (1.0, 'g/cm3')},
      expect: {
        'gL': (4.0, 'g/L'),
        'mgL': (4000, 'mg/L'),
        'wv': (0.4, '%'),
        'N': (0.1, '-'),
        'ppm': (4000, '-'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      '98 % w/w H₂SO₄, 1.84 g/mL',
      source:
          'Hand calculation (refs.py): 1803.2 g/L, 18.385 M, 36.770 N '
          '(textbook "conc. H₂SO₄ ≈ 18 M")',
      choices: {'from': 'ww'},
      numbers: {
        'x': (98, '-'),
        'mw': (98.08, '-'),
        'z': (2, '-'),
        'rho': (1.84, 'g/cm3'),
      },
      expect: {
        'gL': (1803.2, 'g/L'),
        'M': (18.38499, 'mol/L'),
        'N': (36.76998, '-'),
        'wv': (180.32, '%'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      '500 ppm as CaCO₃ in dilute water',
      source:
          'Hand calculation (refs.py): 500 mg/L; 500/100.09 = 4.9955 mmol/L; '
          '0.0099910 N',
      choices: {'from': 'ppm'},
      numbers: {
        'x': (500, '-'),
        'mw': (100.09, '-'),
        'z': (2, '-'),
        'rho': (1.0, 'g/cm3'),
      },
      expect: {
        'mgL': (500, 'mg/L'),
        'M': (4.995504, 'mmol/L'),
        'N': (0.00999101, '-'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      '37 % w/w HCl, 1.19 g/mL',
      source: 'Hand calculation (refs.py): 440.3 g/L, 12.0762 M',
      choices: {'from': 'ww'},
      numbers: {'x': (37, '-'), 'mw': (36.46, '-'), 'rho': (1.19, 'g/cm3')},
      expect: {'gL': (440.3, 'g/L'), 'M': (12.07625, 'mol/L')},
      relTol: 1e-6,
    ),
    const ToolCase(
      '1.5 g/L in a brine of density 1.05',
      source:
          'Hand calculation (refs.py): % w/w = 1.5/1050 × 100 = 0.142857 %; '
          'ppm w/w = 1428.57',
      choices: {'from': 'gL'},
      numbers: {'x': (1.5, '-'), 'mw': (58.44, '-'), 'rho': (1.05, 'g/cm3')},
      expect: {'ww': (0.1428571, '%'), 'ppm': (1428.571, '-')},
      relTol: 1e-6,
    ),
  ],
);
