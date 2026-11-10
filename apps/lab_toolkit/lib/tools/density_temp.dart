import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Density of air-free SMOW water at 101.325 kPa, kg/m³ (t in °C).
/// Tanaka, Girard, Davis, Peuto & Bignell, Metrologia 38 (2001) 301, eq. 1;
/// stated validity 0–40 °C (CIPM recommended table).
double waterDensityTanaka(double t) {
  const a1 = -3.983035, a2 = 301.797, a3 = 522528.9, a4 = 69.34881;
  const a5 = 999.974950;
  return a5 * (1 - (t + a1) * (t + a1) * (t + a2) / (a3 * (t + a4)));
}

/// Air-saturation correction Δρ = s0 + s1·t (kg/m³), Tanaka 2001 eq. 3,
/// stated for 0–25 °C.
double airSaturationCorr(double t) => -4.612e-3 + 0.106e-3 * t;

final densityTempTool = ToolDef(
  id: 'density_temp',
  title: 'Density & temperature',
  summary:
      'Water density at any lab temperature (Tanaka/CIPM 2001), liquid '
      'density by pycnometer with air buoyancy, and correction of a '
      'solution density to a reference temperature.',
  icon: Icons.thermostat,
  keywords: [
    'density',
    'specific gravity',
    'sg',
    'relative density',
    'water',
    'tanaka',
    'cipm',
    'pycnometer',
    'temperature correction',
    'expansion',
    'hydrometer',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('water', 'Water density at T'),
        ChoiceOption('pyc', 'Pycnometer'),
        ChoiceOption('lin', 'Correct to ref. temp.'),
      ],
    ),
    NumberInput(
      't',
      'Temperature',
      quantity: Quantity.temperature,
      initial: 20,
      min: 0,
      max: 80,
      help: 'Pycnometer: temperature of both the water and sample fillings.',
      visibleWhen: (v) => v.c('mode') != 'lin',
    ),
    ChoiceInput(
      'air',
      'Water',
      options: const [
        ChoiceOption('free', 'Air-free (boiled)'),
        ChoiceOption('sat', 'Air-saturated'),
      ],
      visibleWhen: (v) => v.c('mode') != 'lin',
    ),
    NumberInput(
      'm0',
      'Pycnometer empty',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 25.1234e-3,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'pyc',
    ),
    NumberInput(
      'm1',
      'Filled with water',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 50.0987e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'pyc',
    ),
    NumberInput(
      'm2',
      'Filled with sample',
      quantity: Quantity.mass,
      units: ('g', 'g'),
      initial: 52.6543e-3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'pyc',
    ),
    NumberInput(
      'rhoa',
      'Air density',
      quantity: Quantity.density,
      initial: 1.2,
      min: 0,
      max: 1.4,
      help:
          '1.2 kg/m³ is the conventional value (OIML R 111); use 0 to '
          'ignore buoyancy.',
      visibleWhen: (v) => v.c('mode') == 'pyc',
    ),
    NumberInput(
      'rhot',
      'Density measured at T',
      quantity: Quantity.density,
      units: ('g/cm3', 'g/cm3'),
      initial: 1105,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'lin',
    ),
    NumberInput(
      'tm',
      'Measurement temperature T',
      quantity: Quantity.temperature,
      initial: 35,
      visibleWhen: (v) => v.c('mode') == 'lin',
    ),
    NumberInput(
      'tref',
      'Reference temperature',
      quantity: Quantity.temperature,
      initial: 20,
      visibleWhen: (v) => v.c('mode') == 'lin',
    ),
    NumberInput(
      'gamma',
      'Expansion coeff. γ (10⁻⁶/°C)',
      quantity: Quantity.dimensionless,
      initial: 450,
      min: 0,
      max: 3000,
      help:
          'Mean volumetric expansion of the liquid between T and the '
          'reference. Water at 20–35 °C ≈ 300; salt/urea solutions ≈ 300–'
          '600. Best: measure the same solution at two temperatures.',
      visibleWhen: (v) => v.c('mode') == 'lin',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final w = <String>[];
    if (mode == 'lin') {
      final rhot = v.n('rhot'), dt = v.n('tm') - v.n('tref');
      final g = v.n('gamma') * 1e-6;
      final rho = rhot * (1 + g * dt);
      if (dt.abs() > 15) {
        w.add(
          '|T − Tref| above 15 °C: a constant γ becomes inaccurate — measure '
          'nearer the reference temperature.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'rho',
            'Density at reference T',
            rho,
            quantity: Quantity.density,
            units: ('g/cm3', 'g/cm3'),
            level: OutputLevel.primary,
            sig: 6,
          ),
          ToolOutput(
            'corr',
            'Correction',
            rho - rhot,
            quantity: Quantity.density,
            units: ('g/cm3', 'g/cm3'),
            sig: 4,
          ),
        ],
        warnings: w,
        notes: [
          'A glass hydrometer read away from its calibration temperature '
              'also needs a glass-expansion correction (ISO 649-1, ≈ 25×10⁻⁶ /°C for soda-lime).',
        ],
      );
    }

    final t = v.n('t');
    final sat = v.c('air') == 'sat';
    final rhow = waterDensityTanaka(t) + (sat ? airSaturationCorr(t) : 0);
    if (t > 40) {
      w.add(
        'Above 40 °C: outside the Tanaka/CIPM range. Deviation from IAPWS-95 '
        'is about 5 ppm at 50 °C, 18 ppm at 60 °C and 90 ppm at 80 °C.',
      );
    }
    if (sat && t > 25) {
      w.add('Air-saturation correction is stated for 0–25 °C only.');
    }
    if (mode == 'water') {
      return ToolResult(
        [
          ToolOutput(
            'rho',
            'Water density',
            rhow,
            quantity: Quantity.density,
            units: ('g/cm3', 'g/cm3'),
            level: OutputLevel.primary,
            sig: 7,
          ),
          ToolOutput('sv', 'Volume of 1 g (mL)', 1000 / rhow, sig: 7),
        ],
        warnings: w,
        notes: [
          'For standard mean ocean water (SMOW) at 101.325 kPa. Ordinary '
              'deionised water differs by a few ppm (isotopes).',
        ],
      );
    }

    // Pycnometer
    final m0 = v.n('m0'), m1 = v.n('m1'), m2 = v.n('m2');
    final mw = m1 - m0, ms = m2 - m0;
    if (mw <= 0 || ms <= 0) {
      throw ToolInputError('Filled masses must exceed the empty mass.');
    }
    final rhoa = v.n('rhoa');
    final ratio = ms / mw;
    final rho = ratio * (rhow - rhoa) + rhoa;
    return ToolResult(
      [
        ToolOutput(
          'rho',
          'Sample density at T',
          rho,
          quantity: Quantity.density,
          units: ('g/cm3', 'g/cm3'),
          level: OutputLevel.primary,
          sig: 6,
        ),
        ToolOutput('ratio', 'Relative density T/T', ratio, sig: 6),
        ToolOutput(
          'rhow',
          'Water density at T',
          rhow,
          quantity: Quantity.density,
          units: ('g/cm3', 'g/cm3'),
          sig: 7,
        ),
        ToolOutput(
          'vol',
          'Pycnometer volume',
          mw * (1 - rhoa / 8000) / (rhow - rhoa),
          quantity: Quantity.volume,
          units: ('mL', 'mL'),
          sig: 6,
        ),
      ],
      warnings: w,
      notes: [
        'Relative density T/T is the simple mass ratio (no buoyancy); the '
            'density includes the air-buoyancy correction.',
      ],
    );
  },
  formula: '''Water (Tanaka et al. 2001, CIPM), t in °C:
  ρw = a5·[1 − (t + a1)²(t + a2) / (a3·(t + a4))]
  a1 = −3.983035 °C   a2 = 301.797 °C
  a3 = 522528.9 °C²   a4 = 69.34881 °C
  a5 = 999.974950 kg/m³
  air-saturated: + (−4.612×10⁻³ + 0.106×10⁻³·t) kg/m³

Pycnometer (both fillings at t, weighed in air):
  ms = m₂ − m₀,  mw = m₁ − m₀
  ρs = (ms/mw)·(ρw − ρa) + ρa
  V  = mw·(1 − ρa/8000)/(ρw − ρa)   (steel weights 8000 kg/m³)

Correction to a reference temperature (constant γ):
  ρ(Tref) = ρ(T)·[1 + γ·(T − Tref)]''',
  references: [
    'M. Tanaka et al., "Recommended table for the density of water between 0 °C and 40 °C based on recent experimental reports", Metrologia 38 (2001) 301–309, eq. 1 and 3 (CIPM)',
    'IAPWS-95 formulation (via iapws 1.5.5) used as an independent cross-check: |Δ| ≤ 1.2 ppm over 0–40 °C',
    'ISO 3507:1999 Laboratory glassware — Pyknometers; ASTM D1217 (density by Bingham pycnometer, air-buoyancy correction)',
    'OIML R 111-1 (conventional air density 1.2 kg/m³, reference weight density 8000 kg/m³)',
    'ISO 649-1 Laboratory glassware — Density hydrometers (glass expansion)',
  ],
  assumptions: [
    'Atmospheric pressure (compressibility of water ignored: ≈ 0.046 ppm/kPa).',
    'Pycnometer weighings are balance readings in air; the pycnometer volume is the same at both fillings.',
    'The linear correction uses a mean γ for that solution; it is not a property table.',
    'Petroleum products (ASTM D1250 / API MPMS 11.1 VCF tables) are not covered.',
  ],
  cases: [
    const ToolCase(
      'Water at 20 °C, air-free',
      source:
          'Tanaka 2001 eq. 1 in Python: 998.2067 kg/m³ (IAPWS-95: 998.2072)',
      numbers: {'t': (20, 'C')},
      expect: {'rho': (998.20675, 'kg/m3')},
      relTol: 2e-7,
    ),
    const ToolCase(
      'Water at 4 °C (near maximum density)',
      source: 'Tanaka 2001 eq. 1: 999.97495 kg/m³ (IAPWS-95: 999.97487)',
      numbers: {'t': (4, 'C')},
      expect: {'rho': (999.97495, 'kg/m3')},
      relTol: 2e-7,
    ),
    const ToolCase(
      'Water at 35 °C',
      source: 'Tanaka 2001 eq. 1: 994.03260 kg/m³ (IAPWS-95: 994.03331)',
      numbers: {'t': (35, 'C')},
      expect: {'rho': (994.0326, 'kg/m3')},
      relTol: 2e-7,
    ),
    const ToolCase(
      'Air-saturated water at 25 °C',
      source:
          'Tanaka 2001 eq. 1 + eq. 3: 997.04702 − 0.00196 = 997.04506 kg/m³',
      choices: {'air': 'sat'},
      numbers: {'t': (25, 'C')},
      expect: {'rho': (997.04506, 'kg/m3')},
      relTol: 2e-7,
    ),
    const ToolCase(
      'Pycnometer at 20 °C, buoyancy 1.2 kg/m³',
      source:
          'Hand calculation (refs.py): 27.5309/24.9753 × (998.2067 − 1.2) + '
          '1.2 = 1100.2256 kg/m³; buoyancy-corrected volume 25.04652 mL',
      choices: {'mode': 'pyc'},
      numbers: {
        't': (20, 'C'),
        'm0': (25.1234, 'g'),
        'm1': (50.0987, 'g'),
        'm2': (52.6543, 'g'),
        'rhoa': (1.2, 'kg/m3'),
      },
      expect: {
        'rho': (1100.22556, 'kg/m3'),
        'ratio': (1.1023251, '-'),
        'vol': (25.046524, 'mL'),
      },
      relTol: 1e-7,
    ),
    const ToolCase(
      'Pycnometer at 25 °C, dense solution',
      source: 'Hand calculation (refs.py): 1247.7488 kg/m³',
      choices: {'mode': 'pyc'},
      numbers: {
        't': (25, 'C'),
        'm0': (20.5, 'g'),
        'm1': (30.487, 'g'),
        'm2': (33.0012, 'g'),
        'rhoa': (1.2, 'kg/m3'),
      },
      expect: {'rho': (1247.74879, 'kg/m3')},
      relTol: 1e-7,
    ),
    const ToolCase(
      'Solution 1.1050 g/cm³ at 35 °C → 20 °C, γ = 450×10⁻⁶',
      source: 'Hand calculation: 1.1050 × (1 + 450e-6 × 15) = 1.112459 g/cm³',
      choices: {'mode': 'lin'},
      numbers: {
        'rhot': (1.105, 'g/cm3'),
        'tm': (35, 'C'),
        'tref': (20, 'C'),
        'gamma': (450, '-'),
      },
      expect: {'rho': (1.11245875, 'g/cm3')},
      relTol: 1e-8,
    ),
    const ToolCase(
      'Measured cold: 1.3200 at 15 °C → 20 °C, γ = 520×10⁻⁶',
      source: 'Hand calculation: 1.3200 × (1 − 520e-6 × 5) = 1.316568 g/cm³',
      choices: {'mode': 'lin'},
      numbers: {
        'rhot': (1.32, 'g/cm3'),
        'tm': (15, 'C'),
        'tref': (20, 'C'),
        'gamma': (520, '-'),
      },
      expect: {'rho': (1.316568, 'g/cm3')},
      relTol: 1e-8,
    ),
  ],
);
