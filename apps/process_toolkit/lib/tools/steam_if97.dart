import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'if97.dart';

const double _k0 = 273.15;

List<ToolOutput> _single(
  String id,
  String label,
  If97State st, {
  bool p = false,
}) => [
  ToolOutput(
    'h$id',
    'h $label',
    st.h,
    quantity: Quantity.specEnergy,
    sig: 7,
    level: p ? OutputLevel.primary : OutputLevel.normal,
  ),
  ToolOutput('s$id', 's $label', st.s, quantity: Quantity.specEntropy, sig: 7),
  ToolOutput('v$id', 'v $label', st.v, quantity: Quantity.specVolume, sig: 7),
];

final steamTool = ToolDef(
  id: 'steam_if97',
  title: 'Steam tables (IAPWS-IF97)',
  summary:
      'Water and steam properties: saturation by T or P, compressed liquid and '
      'superheated steam by P and T — h, s, v, cp, Tsat.',
  icon: Icons.cloud,
  keywords: [
    'steam',
    'water',
    'iapws',
    'if97',
    'enthalpy',
    'entropy',
    'saturation',
    'superheat',
    'boiler',
    'condensate',
    'specific volume',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('pt', 'By P and T'),
        ChoiceOption('satT', 'Saturation by T'),
        ChoiceOption('satP', 'Saturation by P'),
      ],
    ),
    NumberInput(
      'p',
      'Pressure',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 40e5,
      min: 0,
      minInclusive: false,
      help: 'Absolute pressure = gauge + local atmospheric (≈ 1.013 bar).',
      visibleWhen: (v) => v.c('mode') != 'satT',
    ),
    NumberInput(
      't',
      'Temperature',
      quantity: Quantity.temperature,
      initial: 400,
      min: 0,
      visibleWhen: (v) => v.c('mode') != 'satP',
    ),
    NumberInput(
      'x',
      'Steam quality (dryness) x',
      quantity: Quantity.percent,
      initial: 1,
      min: 0,
      max: 1,
      help: '0 % = saturated liquid, 100 % = dry saturated steam.',
      visibleWhen: (v) => v.c('mode') != 'pt',
    ),
  ],
  compute: (v) {
    final mode = v.c('mode');
    final w = <String>[];
    try {
      if (mode == 'pt') {
        final tK = v.n('t') + _k0, p = v.n('p');
        final st = if97State(tK, p);
        final out = <ToolOutput>[];
        final String phase;
        if (st.region == 1) {
          phase = 'Compressed liquid';
        } else if (tK > if97Tc && p > if97Pc) {
          phase = 'Supercritical fluid';
        } else {
          phase = 'Superheated steam';
        }
        out.add(
          ToolOutput.text(
            'phase',
            'Phase',
            '$phase (IF97 region ${st.region})',
          ),
        );
        out.addAll(_single('', '', st, p: true));
        out.addAll([
          ToolOutput(
            'rho',
            'Density ρ',
            1 / st.v,
            quantity: Quantity.density,
            sig: 7,
          ),
          ToolOutput('cp', 'cp', st.cp, quantity: Quantity.specEntropy, sig: 6),
        ]);
        if (p >= if97PsatMin && p <= if97Pc) {
          final ts = if97Tsat(p);
          out.add(
            ToolOutput(
              'tsat',
              'Tsat at this P',
              ts - _k0,
              quantity: Quantity.temperature,
              sig: 7,
            ),
          );
          final dT = tK - ts;
          out.add(
            ToolOutput(
              'dt',
              dT >= 0 ? 'Superheat' : 'Subcooling',
              dT.abs(),
              quantity: Quantity.tempDiff,
              sig: 5,
            ),
          );
          if (dT.abs() < 0.05) {
            w.add(
              'Within 0.05 K of saturation: liquid or vapour is ambiguous. '
              'Use a saturation mode with the steam quality.',
            );
          }
        } else if (p > if97Pc) {
          out.add(
            ToolOutput.text(
              'tsat',
              'Tsat at this P',
              'none (above critical pressure 220.64 bar)',
            ),
          );
        }
        return ToolResult(out, warnings: w);
      }

      // Saturation (region 4 with regions 1 and 2 for the two phases).
      final double tK, p;
      if (mode == 'satT') {
        tK = v.n('t') + _k0;
        if (tK > if97T13) {
          throw If97RangeError(
            'Saturation above 350 °C lies in IF97 region 3 (not included). '
            'Maximum: 350 °C / 165.29 bar a.',
          );
        }
        p = if97Psat(tK);
      } else {
        p = v.n('p');
        if (p < if97PsatMin) {
          throw If97RangeError(
            'Below 611.2 Pa (0 °C saturation): outside IAPWS-IF97.',
          );
        }
        if (p > if97PsatMax) {
          throw If97RangeError(
            'Saturation above 165.29 bar a (350 °C) lies in IF97 region 3 '
            '(not included).',
          );
        }
        tK = if97Tsat(p);
      }
      final liq = if97Region1(tK, p), vap = if97Region2(tK, p);
      final x = v.n('x');
      double mix(double f, double g) => f + x * (g - f);
      return ToolResult(
        [
          if (mode == 'satT')
            ToolOutput(
              'psat',
              'Psat',
              p,
              quantity: Quantity.pressure,
              sig: 7,
              level: OutputLevel.primary,
            )
          else
            ToolOutput(
              'tsat',
              'Tsat',
              tK - _k0,
              quantity: Quantity.temperature,
              sig: 7,
              level: OutputLevel.primary,
            ),
          ToolOutput(
            'h',
            'h at quality x',
            mix(liq.h, vap.h),
            quantity: Quantity.specEnergy,
            sig: 7,
            level: OutputLevel.primary,
          ),
          ToolOutput(
            's',
            's at quality x',
            mix(liq.s, vap.s),
            quantity: Quantity.specEntropy,
            sig: 7,
          ),
          ToolOutput(
            'v',
            'v at quality x',
            mix(liq.v, vap.v),
            quantity: Quantity.specVolume,
            sig: 7,
          ),
          ..._single('f', '(sat. liquid)', liq),
          ..._single('g', '(sat. vapour)', vap),
          ToolOutput(
            'hfg',
            'Latent heat hfg',
            vap.h - liq.h,
            quantity: Quantity.specEnergy,
            sig: 7,
          ),
        ],
        warnings: w,
        notes: [
          'Saturated phases use IF97 regions 1 and 2 at (Tsat, Psat) as the release specifies.',
        ],
      );
    } on If97RangeError catch (e) {
      throw ToolInputError(e.message);
    }
  },
  formula: '''IAPWS-IF97 (R7-97(2012)); R = 0.461 526 kJ/(kg·K)

Region 1 (liquid), Eq. (7):  π = p/16.53 MPa, τ = 1386 K/T
  γ = Σ nᵢ (7.1 − π)^Iᵢ (τ − 1.222)^Jᵢ      (34 terms)
Region 2 (vapour), Eq. (15): π = p/1 MPa, τ = 540 K/T
  γ = ln π + Σ n°ᵢ τ^J°ᵢ + Σ nᵢ π^Iᵢ (τ − 0.5)^Jᵢ  (9 + 43)

  v = π·γπ·RT/p     h = τ·γτ·RT
  s = (τ·γτ − γ)·R  cp = −τ²·γττ·R

Region 4 (saturation), Eqs. (29)–(31):
  θ = T + n₉/(T − n₁₀)
  ps = [2C / (−B + √(B² − 4AC))]⁴
  Ts from β = ps^¼ (backward Eq. 31)

Boundary 2–3 (B23), Eq. (5):
  p = n₁ + n₂T + n₃T²  [MPa, K]

Wet steam:  h = hf + x·(hg − hf)  (same for s, v)''',
  references: [
    'IAPWS R7-97(2012), Revised Release on the IAPWS Industrial Formulation 1997 for the Thermodynamic Properties of Water and Steam — Eqs. (5), (7), (15)–(17), (30), (31); Tables 1, 2, 10, 11, 34',
    'Verification: IF97 release Tables 5, 15, 35 and 36 (computer-program verification values)',
    'Cross-checked against the Python "iapws" 1.5.5 package and CoolProp 8.0 IF97 backend',
  ],
  assumptions: [
    'Pure water (no dissolved salts or non-condensables).',
    'Covers 0–800 °C up to 100 MPa except the near-critical region 3 (above 350 °C and above the B23 line, e.g. 400 °C at > 300 bar). Saturation only up to 350 °C (165.3 bar a).',
    'Saturation properties at exactly the saturation line take the liquid (region 1) or vapour (region 2) side as the release does.',
  ],
  cases: [
    const ToolCase(
      'Region 1: 300 K, 3 MPa',
      source: 'IAPWS-IF97 Table 5, column 1',
      numbers: {'p': (3, 'MPa'), 't': (300, 'K')},
      expect: {
        'v': (0.100215168e-2, 'm3/kg'),
        'h': (115.331273, 'kJ/kg'),
        's': (0.392294792, 'kJ/kgK'),
        'cp': (4.17301218, 'kJ/kgK'),
      },
      expectText: {'phase': 'Compressed liquid'},
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Region 1: 300 K, 80 MPa',
      source: 'IAPWS-IF97 Table 5, column 2',
      numbers: {'p': (80, 'MPa'), 't': (300, 'K')},
      expect: {
        'v': (0.971180894e-3, 'm3/kg'),
        'h': (184.142828, 'kJ/kg'),
        's': (0.368563852, 'kJ/kgK'),
        'cp': (4.01008987, 'kJ/kgK'),
      },
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Region 1: 500 K, 3 MPa',
      source: 'IAPWS-IF97 Table 5, column 3',
      numbers: {'p': (3, 'MPa'), 't': (500, 'K')},
      expect: {
        'v': (0.120241800e-2, 'm3/kg'),
        'h': (975.542239, 'kJ/kg'),
        's': (2.58041912, 'kJ/kgK'),
        'cp': (4.65580682, 'kJ/kgK'),
      },
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Region 2: 300 K, 0.0035 MPa',
      source: 'IAPWS-IF97 Table 15, column 1',
      numbers: {'p': (0.0035, 'MPa'), 't': (300, 'K')},
      expect: {
        'v': (39.4913866, 'm3/kg'),
        'h': (2549.91145, 'kJ/kg'),
        's': (8.52238967, 'kJ/kgK'),
        'cp': (1.91300162, 'kJ/kgK'),
      },
      expectText: {'phase': 'Superheated'},
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Region 2: 700 K, 0.0035 MPa',
      source: 'IAPWS-IF97 Table 15, column 2',
      numbers: {'p': (0.0035, 'MPa'), 't': (700, 'K')},
      expect: {
        'v': (92.3015898, 'm3/kg'),
        'h': (3335.68375, 'kJ/kg'),
        's': (10.1749996, 'kJ/kgK'),
        'cp': (2.08141274, 'kJ/kgK'),
      },
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Region 2: 700 K, 30 MPa',
      source: 'IAPWS-IF97 Table 15, column 3',
      numbers: {'p': (30, 'MPa'), 't': (700, 'K')},
      expect: {
        'v': (0.542946619e-2, 'm3/kg'),
        'h': (2631.49474, 'kJ/kg'),
        's': (5.17540298, 'kJ/kgK'),
        'cp': (10.3505092, 'kJ/kgK'),
      },
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Saturation pressure at 500 K',
      source: 'IAPWS-IF97 Table 35: ps = 2.63889776 MPa',
      choices: {'mode': 'satT'},
      numbers: {'t': (500, 'K')},
      expect: {'psat': (2.63889776, 'MPa')},
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Saturation temperature at 1 MPa',
      source: 'IAPWS-IF97 Table 36: Ts = 453.035632 K',
      choices: {'mode': 'satP'},
      numbers: {'p': (1, 'MPa')},
      expect: {'tsat': (453.035632, 'K')},
      relTol: 5e-9, // table values are rounded to 9 digits
    ),
    const ToolCase(
      'Wet steam: 10 bar a, quality 90 %',
      source:
          'iapws 1.5.5 and CoolProp 8.0 IF97 (agree to 1e-12): Tsat 453.0356 K, '
          'hf 762.6828, hg 2777.1195, h 2575.6759 kJ/kg, s 6.140324 kJ/(kg·K)',
      choices: {'mode': 'satP'},
      numbers: {'p': (10, 'bar'), 'x': (90, '%')},
      expect: {
        'tsat': (453.0356323914666, 'K'),
        'hf': (762.6828443354104, 'kJ/kg'),
        'hg': (2777.119537684662, 'kJ/kg'),
        'h': (2575.6758683497374, 'kJ/kg'),
        's': (6.140324231806867, 'kJ/kgK'),
        'v': (0.17502671926919286, 'm3/kg'),
        'vg': (0.1943488843273919, 'm3/kg'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Saturation at 150 °C',
      source:
          'iapws 1.5.5 / CoolProp 8.0 IF97: Psat 4.761014 bar a, hfg 2113.668 kJ/kg',
      choices: {'mode': 'satT'},
      numbers: {'t': (150, 'C')},
      expect: {
        'psat': (0.476101381081492, 'MPa'),
        'hfg': (2113.6675824745193, 'kJ/kg'),
        'vg': (0.39250241376100764, 'm3/kg'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'HP steam 105 bar a, 510 °C',
      source:
          'iapws 1.5.5 / CoolProp 8.0 IF97: h 3394.856 kJ/kg, s 6.604055, '
          'v 0.0316644 m³/kg, Tsat 314.606 °C',
      numbers: {'p': (105, 'bar'), 't': (510, 'C')},
      expect: {
        'h': (3394.856256452474, 'kJ/kg'),
        's': (6.604054978373595, 'kJ/kgK'),
        'v': (0.03166443573345756, 'm3/kg'),
        'cp': (2.5882565007701404, 'kJ/kgK'),
        'tsat': (314.60584838479247, 'C'),
        'dt': (195.39415161520753, 'K'),
      },
      expectText: {'phase': 'Superheated'},
      relTol: 1e-9,
    ),
  ],
);
