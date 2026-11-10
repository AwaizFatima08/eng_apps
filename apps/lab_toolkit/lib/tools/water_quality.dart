import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Molar masses (g/mol) used by Standard Methods 2340 for hardness.
const double kMCaCO3 = 100.09;
const double kMCaO = 56.08;

/// mg/L as CaCO₃ per unit of each hardness scale.
const double kMgLPerDH = 10 * kMCaCO3 / kMCaO; // 1 °dH = 10 mg CaO/L
const double kMgLPerFH = 10; // 1 °fH = 10 mg CaCO₃/L
const double kMgLPerGpg = 64.79891 / 3.785411784; // grain per US gallon
const double kMgLPerClark = 64.79891 / 4.54609; // grain per imperial gallon

final waterQualityTool = ToolDef(
  id: 'water_quality',
  title: 'Water hardness & conductivity',
  summary:
      'Total hardness as CaCO₃ from Ca and Mg, °dH/°fH/gpg conversions, '
      'conductivity compensated to 25 °C and TDS ≈ k·EC for boiler and '
      'cooling water.',
  icon: Icons.opacity,
  keywords: [
    'hardness',
    'calcium',
    'magnesium',
    'caco3',
    'dh',
    'fh',
    'gpg',
    'grains',
    'tds',
    'conductivity',
    'ec',
    'temperature compensation',
    'boiler',
    'cooling water',
    'demin',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('hard', 'Hardness from Ca, Mg'),
        ChoiceOption('units', 'Hardness units'),
        ChoiceOption('ec', 'Conductivity & TDS'),
      ],
    ),
    NumberInput(
      'ca',
      'Calcium Ca',
      quantity: Quantity.massConc,
      initial: 40e-3,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'hard',
    ),
    NumberInput(
      'mg',
      'Magnesium Mg',
      quantity: Quantity.massConc,
      initial: 12e-3,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'hard',
    ),
    ChoiceInput(
      'hu',
      'Value is in',
      options: const [
        ChoiceOption('caco3', 'mg/L as CaCO₃'),
        ChoiceOption('mmol', 'mmol/L (Ca + Mg)'),
        ChoiceOption('dh', '°dH (German)'),
        ChoiceOption('fh', '°fH (French)'),
        ChoiceOption('gpg', 'gpg (grain/US gal)'),
        ChoiceOption('e', '°e (Clark)'),
      ],
      visibleWhen: (v) => v.c('mode') == 'units',
    ),
    NumberInput(
      'hx',
      'Hardness value',
      quantity: Quantity.dimensionless,
      initial: 100,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'units',
    ),
    NumberInput(
      'ec',
      'Conductivity measured',
      quantity: Quantity.conductivity,
      initial: 0.12, // 1200 µS/cm
      min: 0,
      minInclusive: false,
      help: 'Uncompensated reading (meter set to "no compensation").',
      visibleWhen: (v) => v.c('mode') == 'ec',
    ),
    NumberInput(
      't',
      'Sample temperature',
      quantity: Quantity.temperature,
      initial: 30,
      min: 0,
      max: 60,
      visibleWhen: (v) => v.c('mode') == 'ec',
    ),
    NumberInput(
      'alpha',
      'Temp. coefficient α (per °C)',
      quantity: Quantity.percent,
      initial: 0.02,
      min: 0,
      max: 0.1,
      help: 'Natural/cooling water ≈ 2.0 %; KCl standards 1.91 % (SM 2510 B).',
      visibleWhen: (v) => v.c('mode') == 'ec',
    ),
    NumberInput(
      'k',
      'TDS factor k',
      quantity: Quantity.dimensionless,
      initial: 0.65,
      min: 0,
      minInclusive: false,
      max: 1.5,
      help:
          'TDS (mg/L) ÷ EC (µS/cm). 0.55–0.7 for natural waters (SM 1030 E); '
          'best found from a gravimetric TDS of your own water.',
      visibleWhen: (v) => v.c('mode') == 'ec',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final w = <String>[];
    if (mode == 'ec') {
      final ec = v.n('ec'), t = v.n('t'), a = v.n('alpha');
      final den = 1 + a * (t - 25);
      if (den <= 0) throw ToolInputError('α·(T − 25) gives a factor ≤ 0.');
      final ec25 = ec / den;
      final us = ec25 * 1e4; // S/m → µS/cm
      final tds = v.n('k') * us; // mg/L
      if (us < 10) {
        w.add(
          'High-purity water (< 10 µS/cm): linear α is invalid — use the '
          'meter\'s pure-water compensation (ASTM D5391) or measure at 25 °C.',
        );
      }
      if ((t - 25).abs() > 10) {
        w.add(
          'More than 10 °C from 25 °C: linear compensation error grows; '
          'measure nearer 25 °C.',
        );
      }
      final k = v.n('k');
      if (k < 0.55 || k > 0.7) {
        w.add('k outside the 0.55–0.7 range usual for natural waters.');
      }
      return ToolResult(
        [
          ToolOutput(
            'ec25',
            'Conductivity at 25 °C',
            ec25,
            quantity: Quantity.conductivity,
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput(
            'tds',
            'TDS (estimate)',
            tds * 1e-3,
            quantity: Quantity.massConc,
            units: ('mg/L', 'mg/L'),
            sig: 4,
          ),
          ToolOutput('f', 'Factor EC25 / ECT', 1 / den, sig: 5),
        ],
        warnings: w,
        notes: [
          'TDS from conductivity is an estimate; the reference method is '
              'gravimetric (SM 2540 C, dried at 180 °C).',
        ],
      );
    }

    late double th; // mg/L as CaCO₃
    final out = <ToolOutput>[];
    if (mode == 'hard') {
      final ca = v.n('ca') * 1e3, mg = v.n('mg') * 1e3; // mg/L
      final cah = 2.497 * ca, mgh = 4.118 * mg;
      th = cah + mgh;
      out.addAll([
        ToolOutput(
          'th',
          'Total hardness as CaCO₃',
          th * 1e-3,
          quantity: Quantity.massConc,
          units: ('mg/L', 'mg/L'),
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput(
          'cah',
          'Ca hardness as CaCO₃',
          cah * 1e-3,
          quantity: Quantity.massConc,
          units: ('mg/L', 'mg/L'),
          sig: 5,
        ),
        ToolOutput(
          'mgh',
          'Mg hardness as CaCO₃',
          mgh * 1e-3,
          quantity: Quantity.massConc,
          units: ('mg/L', 'mg/L'),
          sig: 5,
        ),
      ]);
    } else {
      final x = v.n('hx');
      th = switch (v.c('hu')) {
        'mmol' => x * kMCaCO3,
        'dh' => x * kMgLPerDH,
        'fh' => x * kMgLPerFH,
        'gpg' => x * kMgLPerGpg,
        'e' => x * kMgLPerClark,
        _ => x,
      };
      out.add(
        ToolOutput(
          'th',
          'Hardness as CaCO₃',
          th * 1e-3,
          quantity: Quantity.massConc,
          units: ('mg/L', 'mg/L'),
          level: OutputLevel.primary,
          sig: 5,
        ),
      );
    }
    out.addAll([
      ToolOutput(
        'mmol',
        'Ca + Mg',
        th / kMCaCO3, // mmol/L = mol/m³ (base)
        quantity: Quantity.molarConc,
        units: ('mmol/L', 'mmol/L'),
        sig: 5,
      ),
      ToolOutput('dh', '°dH', th / kMgLPerDH, sig: 5),
      ToolOutput('fh', '°fH', th / kMgLPerFH, sig: 5),
      ToolOutput('gpg', 'gpg (US)', th / kMgLPerGpg, sig: 5),
      ToolOutput('e', '°e (Clark)', th / kMgLPerClark, sig: 5),
    ]);
    return ToolResult(
      out,
      warnings: w,
      notes: [
        if (mode == 'hard')
          'Ca and Mg as the element (mg/L), e.g. by ICP/AAS or EDTA titration.',
        '1 °dH = 10 mg CaO/L; 1 °fH = 10 mg CaCO₃/L; 1 gpg = 1 grain CaCO₃ per US gallon.',
      ],
    );
  },
  formula: '''Hardness from Ca and Mg (mg/L, SM 2340 B):
  TH [mg/L CaCO₃] = 2.497·[Ca] + 4.118·[Mg]
  (2.497 = 100.09/40.08; 4.118 = 100.09/24.31)
  mmol/L (Ca + Mg) = TH / 100.09

Scales (mg/L as CaCO₃ per unit):
  °dH  = 10 × 100.09/56.08     = 17.848
  °fH  = 10
  gpg  = 64.79891 mg / 3.785411784 L = 17.118
  °e   = 64.79891 mg / 4.54609 L     = 14.254

Conductivity, linear compensation to 25 °C:
  κ25 = κT / [1 + α·(T − 25)]
TDS estimate (κ in µS/cm, TDS in mg/L):
  TDS = k · κ25''',
  references: [
    'Standard Methods for the Examination of Water and Wastewater, 2340 B — hardness by calculation (2.497 Ca + 4.118 Mg)',
    'Standard Methods 2510 B — conductivity, laboratory method; κ25 = κm/[1 + 0.0191(t − 25)] for KCl',
    'Standard Methods 1030 E — checking correctness of analyses: TDS/EC ratio 0.55–0.7',
    'ISO 7888:1985 Water quality — Determination of electrical conductivity (results reported at 25 °C)',
    'ASTM D5391 Electrical conductivity of flowing high-purity water (pure-water compensation)',
    'NIST SP 811 / BIPM: grain = 64.79891 mg; US gallon 3.785411784 L; imperial gallon 4.54609 L',
  ],
  assumptions: [
    'Hardness = Ca + Mg only (Sr, Ba, Fe, Mn ignored).',
    'Linear temperature coefficient α constant over the range; ISO 7888 uses a non-linear factor table for natural waters.',
    'k depends on the ionic make-up of the water and must be verified for each water type.',
  ],
  cases: [
    const ToolCase(
      'Ca 40.08, Mg 24.31 mg/L (1 mmol/L each)',
      source:
          'SM 2340 B formula, hand calculation: 100.080 + 100.109 = '
          '200.188 mg/L as CaCO₃',
      numbers: {'ca': (40.08, 'mg/L'), 'mg': (24.31, 'mg/L')},
      expect: {
        'th': (200.1883, 'mg/L'),
        'cah': (100.0798, 'mg/L'),
        'mgh': (100.1086, 'mg/L'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      'Ca 80, Mg 12 mg/L',
      source:
          'SM 2340 B, hand calculation (refs.py): 249.176 mg/L = 2.4895 mmol/L '
          '= 13.961 °dH = 24.918 °fH = 14.556 gpg',
      numbers: {'ca': (80, 'mg/L'), 'mg': (12, 'mg/L')},
      expect: {
        'th': (249.176, 'mg/L'),
        'mmol': (2.489519, 'mmol/L'),
        'dh': (13.96122, '-'),
        'fh': (24.9176, '-'),
        'gpg': (14.55632, '-'),
      },
      relTol: 1e-6,
    ),
    const ToolCase(
      '1 mmol/L in the other scales',
      source:
          'Published conversion table (e.g. Wikipedia "Hardness of water"): '
          '1 mmol/L = 100.09 mg/L = 5.608 °dH = 10.01 °fH = 5.847 gpg = '
          '7.022 °e',
      choices: {'mode': 'units', 'hu': 'mmol'},
      numbers: {'hx': (1, '-')},
      expect: {
        'th': (100.09, 'mg/L'),
        'dh': (5.608, '-'),
        'fh': (10.009, '-'),
        'gpg': (5.847, '-'),
        'e': (7.022, '-'),
      },
      relTol: 2e-4,
    ),
    const ToolCase(
      '10 gpg → mg/L',
      source:
          'Definition: 10 × 64.79891/3.785411784 = 171.181 mg/L; 9.5912 °dH',
      choices: {'mode': 'units', 'hu': 'gpg'},
      numbers: {'hx': (10, '-')},
      expect: {'th': (171.1806, 'mg/L'), 'dh': (9.591177, '-')},
      relTol: 1e-6,
    ),
    const ToolCase(
      '1200 µS/cm at 30 °C, α 2 %, k 0.65',
      source: 'Hand calculation: 1200/1.10 = 1090.91 µS/cm; TDS 709.09 mg/L',
      choices: {'mode': 'ec'},
      numbers: {
        'ec': (1200, 'uS/cm'),
        't': (30, 'C'),
        'alpha': (2, '%'),
        'k': (0.65, '-'),
      },
      expect: {'ec25': (1090.909, 'uS/cm'), 'tds': (709.0909, 'mg/L')},
      relTol: 1e-6,
    ),
    const ToolCase(
      '500 µS/cm at 18 °C, SM 2510 B α 1.91 %',
      source:
          'SM 2510 B formula, hand calculation: 500/[1 + 0.0191(18 − 25)] = '
          '577.167 µS/cm; k 0.55 → 317.44 mg/L',
      choices: {'mode': 'ec'},
      numbers: {
        'ec': (500, 'uS/cm'),
        't': (18, 'C'),
        'alpha': (1.91, '%'),
        'k': (0.55, '-'),
      },
      expect: {'ec25': (577.1673, 'uS/cm'), 'tds': (317.442, 'mg/L')},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Condensate 2 µS/cm: pure-water warning',
      source: 'Hand calculation: 2/1.1 = 1.8182 µS/cm; ASTM D5391 scope',
      choices: {'mode': 'ec'},
      numbers: {'ec': (2, 'uS/cm'), 't': (30, 'C'), 'alpha': (2, '%')},
      expect: {'ec25': (1.818182, 'uS/cm')},
      expectWarning: 'High-purity',
      relTol: 1e-6,
    ),
  ],
);
