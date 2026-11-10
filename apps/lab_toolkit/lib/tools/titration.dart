import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// IUPAC conventional atomic weight of nitrogen (CIAAW 2021 abridged).
const double kArN = 14.007;

/// Urea CO(NH₂)₂ and NH₃ molar masses, g/mol (CIAAW conventional weights).
const double kMUrea = 60.056;
const double kMNH3 = 17.031;

bool _m(ToolValues v, String mode) => v.c('mode') == mode;

final titrationTool = ToolDef(
  id: 'titration',
  title: 'Titration & Kjeldahl N',
  summary:
      'Assay % or mg/L from a titre with blank, normality factor and '
      'aliquot; Kjeldahl total nitrogen (direct or back-titration); '
      'standardisation of a titrant.',
  icon: Icons.colorize,
  keywords: [
    'titration',
    'titre',
    'burette',
    'assay',
    'kjeldahl',
    'nitrogen',
    'urea',
    'ammonia',
    'blank',
    'factor',
    'aliquot',
    'standardise',
    'standardize',
    'normality',
    'alkalinity',
    'back titration',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('assay', 'Assay / content'),
        ChoiceOption('kjel', 'Kjeldahl total N'),
        ChoiceOption('std', 'Standardise titrant'),
      ],
    ),
    ChoiceInput(
      'ktype',
      'Kjeldahl titration',
      options: const [
        ChoiceOption('direct', 'Boric acid (direct)'),
        ChoiceOption('back', 'Back-titration'),
      ],
      help:
          'Direct: NH₃ absorbed in boric acid, titrated with standard acid. '
          'Back: NH₃ absorbed in excess standard acid, the excess titrated '
          'with NaOH (ISO 5315 / ISO 1592).',
      visibleWhen: (v) => _m(v, 'kjel'),
    ),
    ChoiceInput(
      'stype',
      'Sample taken by',
      options: const [
        ChoiceOption('mass', 'Mass (→ % w/w)'),
        ChoiceOption('vol', 'Volume (→ mg/L)'),
      ],
      visibleWhen: (v) => _m(v, 'assay'),
    ),
    const NumberInput(
      'vs',
      'Titre, sample Vs',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 16.45e-6,
      min: 0,
    ),
    const NumberInput(
      'vb',
      'Titre, blank Vb',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 0.05e-6,
      min: 0,
      help: 'Reagent blank carried through the whole procedure (0 if none).',
    ),
    NumberInput(
      'cn',
      'Titrant normality N (eq/L)',
      quantity: Quantity.dimensionless,
      initial: 0.2,
      min: 0,
      minInclusive: false,
      help:
          'Nominal value; the factor f below corrects it. For back-'
          'titration this is the NaOH.',
      visibleWhen: (v) => !_m(v, 'std'),
    ),
    NumberInput(
      'f',
      'Normality factor f',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 0,
      minInclusive: false,
      help: 'f = actual ÷ nominal normality, from standardisation.',
      visibleWhen: (v) => !_m(v, 'std'),
    ),
    NumberInput(
      'ew',
      'Equivalent mass of analyte (g/eq)',
      quantity: Quantity.dimensionless,
      initial: 52.994,
      min: 0,
      minInclusive: false,
      help:
          'MW ÷ z. Na₂CO₃ 52.994; NaOH 39.997; NH₃ 17.031; H₂SO₄ 49.04; '
          'CaCO₃ 50.04 (alkalinity/hardness by SM uses 50.00).',
      visibleWhen: (v) => _m(v, 'assay'),
    ),
    NumberInput(
      'w',
      'Sample mass W',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 0.1e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) =>
          _m(v, 'kjel') || (_m(v, 'assay') && v.c('stype') == 'mass'),
    ),
    NumberInput(
      'vsam',
      'Sample volume',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 100e-6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _m(v, 'assay') && v.c('stype') == 'vol',
    ),
    NumberInput(
      'wstd',
      'Primary standard mass',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 0.5105e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _m(v, 'std'),
    ),
    NumberInput(
      'ews',
      'Equiv. mass of standard (g/eq)',
      quantity: Quantity.dimensionless,
      initial: 204.22,
      min: 0,
      minInclusive: false,
      help:
          'KHP (for NaOH) 204.22; Na₂CO₃ (for acids, methyl orange) 52.994; '
          'THAM/Tris 121.14; sulfamic acid 97.09.',
      visibleWhen: (v) => _m(v, 'std'),
    ),
    NumberInput(
      'ps',
      'Purity of standard',
      quantity: Quantity.percent,
      initial: 1,
      min: 0,
      max: 1,
      minInclusive: false,
      visibleWhen: (v) => _m(v, 'std'),
    ),
    NumberInput(
      'cnom',
      'Nominal normality (eq/L)',
      quantity: Quantity.dimensionless,
      initial: 0.1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => _m(v, 'std'),
    ),
    const NumberInput(
      'vt',
      'Made up to (flask)',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 100e-6,
      min: 0,
      minInclusive: false,
      help:
          'If an aliquot of a made-up solution is titrated. Set flask = '
          'aliquot when the whole sample is titrated.',
    ),
    const NumberInput(
      'va',
      'Aliquot titrated',
      quantity: Quantity.volume,
      units: ('mL', 'mL'),
      initial: 100e-6,
      min: 0,
      minInclusive: false,
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final vs = v.n('vs') * 1e6, vb = v.n('vb') * 1e6; // mL
    final vt = v.n('vt'), va = v.n('va');
    if (va > vt) {
      throw ToolInputError('Aliquot cannot be larger than the flask volume.');
    }
    final df = vt / va;
    final w = <String>[];

    if (mode == 'std') {
      final net = vs - vb;
      if (net <= 0) throw ToolInputError('Blank titre is not below the titre.');
      final meq = v.n('wstd') * 1000 * v.n('ps') / v.n('ews') * 1000 / df;
      final n = meq / net;
      final f = n / v.n('cnom');
      if ((f - 1).abs() > 0.05) {
        w.add(
          'Factor differs from 1 by more than 5 %: check the standard, '
          'its drying, or remake the titrant.',
        );
      }
      if (net < 10) {
        w.add(
          'Titre below 10 mL: burette reading error is above ~0.2 % — '
          'weigh more standard.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'N',
            'Actual normality (eq/L)',
            n,
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput('f', 'Normality factor f', f, sig: 5),
          ToolOutput('meq', 'Standard taken (meq)', meq, sig: 5),
        ],
        warnings: w,
        notes: [
          'Standardise in triplicate; the replicates should agree to ≤ 0.1 % '
              '(use the Statistics tool).',
        ],
      );
    }

    final nf = v.n('cn') * v.n('f');
    final back = mode == 'kjel' && v.c('ktype') == 'back';
    final net = back ? vb - vs : vs - vb;
    if (net < 0) {
      throw ToolInputError(
        back
            ? 'Back-titration: the sample titre must be below the blank titre.'
            : 'Blank titre is larger than the sample titre.',
      );
    }
    final meq = net * nf; // mL × eq/L = meq (in the aliquot)

    if (mode == 'kjel') {
      final wMg = v.n('w') * 1e6; // kg → mg
      final pctN = meq * kArN * df / wMg; // fraction (mg N / mg sample)
      if (pctN > 0.4665) {
        w.add(
          'N above 46.65 % (pure urea): check sample mass, titre and '
          'normality.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'N',
            'Total nitrogen',
            pctN,
            quantity: Quantity.percent,
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput(
            'urea',
            'As urea',
            pctN * kMUrea / (2 * kArN),
            quantity: Quantity.percent,
            sig: 5,
          ),
          ToolOutput(
            'nh3',
            'As NH₃',
            pctN * kMNH3 / kArN,
            quantity: Quantity.percent,
            sig: 5,
          ),
          ToolOutput('meq', 'Net titrant (meq)', meq, sig: 5),
          ToolOutput('df', 'Aliquot factor', df, sig: 5),
        ],
        warnings: w,
        notes: [
          '"As urea" assumes all N is urea N; "as NH₃" assumes all is '
              'ammoniacal. Biuret and other N compounds are counted as N.',
        ],
      );
    }

    // Assay
    final ew = v.n('ew');
    if (v.c('stype') == 'vol') {
      final mgL = meq * ew * df * 1000 / (v.n('vsam') * 1e6); // mg/L
      return ToolResult([
        ToolOutput(
          'mgL',
          'Content',
          mgL * 1e-3,
          quantity: Quantity.massConc,
          units: ('mg/L', 'mg/L'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput('meq', 'Net titrant (meq)', meq, sig: 5),
        ToolOutput('df', 'Aliquot factor', df, sig: 5),
      ], warnings: w);
    }
    final pct = meq * ew * df / (v.n('w') * 1e6); // mg / mg
    if (pct > 1.005) {
      w.add(
        'Result above 100.5 %: check the equivalent mass, factor and '
        'sample mass.',
      );
    }
    return ToolResult([
      ToolOutput(
        'pct',
        'Assay',
        pct,
        quantity: Quantity.percent,
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput('meq', 'Net titrant (meq)', meq, sig: 5),
      ToolOutput('df', 'Aliquot factor', df, sig: 5),
    ], warnings: w);
  },
  formula: '''V in mL, N in eq/L (= meq/mL), W in g,
f = normality factor, DF = V_flask / V_aliquot.

Assay, weighed sample:
  % = (Vs − Vb)·N·f·E·DF·100 / (W·1000)     E = MW/z, g/eq
Assay, measured volume V_sample (mL):
  mg/L = (Vs − Vb)·N·f·E·DF·1000 / V_sample
  (SM 2320 B alkalinity: A·N·50 000 / mL sample)

Kjeldahl total nitrogen:
  direct (boric acid, titrate with acid):
    %N = (Vs − Vb)·N·f·14.007·DF·100 / (W·1000)
  back-titration (excess std acid, titrate with NaOH):
    %N = (Vb − Vs)·N·f·14.007·DF·100 / (W·1000)
  as urea = %N × 60.056 / 28.014 (= 2.1438)
  as NH₃  = %N × 17.031 / 14.007 (= 1.2159)

Standardisation with a primary standard:
  N = W_std·P·1000 / (E_std·(Vs − Vb)·DF)
  f = N / N_nominal''',
  references: [
    'ISO 5315:1984 Fertilizers — Determination of total nitrogen content — Titrimetric method after distillation (back-titration of excess standard acid)',
    'ISO 1592:1977 Urea for industrial use — Determination of nitrogen content — Titrimetric method after distillation (withdrawn; same principle)',
    'AOAC Official Method 955.04 Nitrogen (Total) in Fertilizers, Kjeldahl Method; AOAC 2001.11 (boric acid absorption, direct titration)',
    'Standard Methods 2320 B (alkalinity, titration method), calculation clause',
    'Vogel\'s Textbook of Quantitative Chemical Analysis, 6th ed., ch. 10 (primary standards: KHP, Na₂CO₃)',
    'CIAAW/IUPAC conventional atomic weights: N 14.007, C 12.011, H 1.008, O 15.999',
  ],
  assumptions: [
    'All titres are read at the end point and corrected for burette calibration if required.',
    'The blank uses the same reagents and volumes as the sample.',
    'For back-titration the same volume of absorbing acid is used in the blank and the sample, so its normality cancels.',
    'Equivalent mass E is for the reaction at the chosen end point.',
  ],
  cases: [
    const ToolCase(
      'Kjeldahl, boric acid, urea 0.1 g, 0.2 N acid',
      source:
          'Hand calculation (refs.py): (16.45 − 0.05) × 0.2 × 14.007 × 100 / '
          '(0.1 × 1000) = 45.943 % N; as urea 98.492 %',
      choices: {'mode': 'kjel'},
      numbers: {
        'vs': (16.45, 'mL'),
        'vb': (0.05, 'mL'),
        'cn': (0.2, '-'),
        'f': (1, '-'),
        'w': (0.1, 'g'),
        'vt': (100, 'mL'),
        'va': (100, 'mL'),
      },
      expect: {
        'N': (45.94296, '%'),
        'urea': (98.49184, '%'),
        'nh3': (55.86168, '%'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      'Kjeldahl, back-titration, 2.5 g in 250 mL, 50 mL aliquot',
      source:
          'Hand calculation (refs.py) per ISO 5315 principle: (49.80 − 17.00) '
          '× 0.5 × 0.998 × 14.007 × 5 × 100 / 2500 = 45.851 % N',
      choices: {'mode': 'kjel', 'ktype': 'back'},
      numbers: {
        'vs': (17.00, 'mL'),
        'vb': (49.80, 'mL'),
        'cn': (0.5, '-'),
        'f': (0.998, '-'),
        'w': (2.5, 'g'),
        'vt': (250, 'mL'),
        'va': (50, 'mL'),
      },
      expect: {'N': (45.85107, '%'), 'df': (5, '-')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Soda ash assay with 0.1 N HCl, f = 1.0123',
      source:
          'Hand calculation (refs.py): 46.25 × 0.1 × 1.0123 × 52.994 × 100 / '
          '250 = 99.245 %',
      numbers: {
        'vs': (46.30, 'mL'),
        'vb': (0.05, 'mL'),
        'cn': (0.1, '-'),
        'f': (1.0123, '-'),
        'ew': (52.994, '-'),
        'w': (0.25, 'g'),
      },
      expect: {'pct': (99.24478, '%')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Alkalinity, 100 mL sample, 0.02 N H₂SO₄, 12.4 mL',
      source:
          'Standard Methods 2320 B formula: 12.4 × 0.02 × 50 000 / 100 = '
          '124 mg/L as CaCO₃',
      choices: {'stype': 'vol'},
      numbers: {
        'vs': (12.4, 'mL'),
        'vb': (0, 'mL'),
        'cn': (0.02, '-'),
        'f': (1, '-'),
        'ew': (50.0, '-'),
        'vsam': (100, 'mL'),
      },
      expect: {'mgL': (124, 'mg/L')},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Assay with aliquot: 2 g in 250 mL, 25 mL titrated',
      source:
          'Hand calculation (refs.py): 18.10 × 0.1 × 0.9987 × 17.031 × 10 × '
          '100 / 2000 = 15.393 %',
      numbers: {
        'vs': (18.20, 'mL'),
        'vb': (0.10, 'mL'),
        'cn': (0.1, '-'),
        'f': (0.9987, '-'),
        'ew': (17.031, '-'),
        'w': (2.0, 'g'),
        'vt': (250, 'mL'),
        'va': (25, 'mL'),
      },
      expect: {'pct': (15.39302, '%'), 'df': (10, '-')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Standardise 0.1 N NaOH with 0.5105 g KHP',
      source:
          'Hand calculation (refs.py): 0.5105 × 0.9995 × 1000 / (204.22 × '
          '24.82) = 0.100665 N; f = 1.00665',
      choices: {'mode': 'std'},
      numbers: {
        'vs': (24.85, 'mL'),
        'vb': (0.03, 'mL'),
        'wstd': (0.5105, 'g'),
        'ews': (204.22, '-'),
        'ps': (99.95, '%'),
        'cnom': (0.1, '-'),
      },
      expect: {'N': (0.100665, '-'), 'f': (1.00665, '-')},
      relTol: 1e-5,
    ),
  ],
);
