import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Laminar limit used here (Crane TP-410: Re < 2000).
const double reLaminar = 2000;
const double reTurbulent = 4000;

/// Absolute roughness presets in m (Moody 1944 / Crane TP-410 values).
const Map<String, double> roughnessPresets = {
  'cs': 0.045e-3,
  'drawn': 0.0015e-3,
  'galv': 0.15e-3,
  'ci': 0.26e-3,
};

/// Colebrook–White Darcy friction factor, solved by fixed-point iteration
/// on x = 1/√f (converges monotonically for all Re > 0, ε/D ≥ 0).
double colebrook(double re, double relRough) {
  // Swamee–Jain start value.
  final sj =
      0.25 /
      math.pow(
        math.log(relRough / 3.7 + 5.74 / math.pow(re, 0.9)) / math.ln10,
        2,
      );
  var x = 1 / math.sqrt(sj);
  for (var i = 0; i < 200; i++) {
    final next = -2 * math.log(relRough / 3.7 + 2.51 * x / re) / math.ln10;
    if ((next - x).abs() < 1e-14 * x) {
      x = next;
      break;
    }
    x = next;
  }
  return 1 / (x * x);
}

/// Darcy friction factor: 64/Re below [reLaminar], Colebrook above.
double darcyFriction(double re, double relRough) =>
    re < reLaminar ? 64 / re : colebrook(re, relRough);

final pipeFlowTool = ToolDef(
  id: 'pipe_flow',
  title: 'Pipe pressure drop',
  summary:
      'Darcy–Weisbach with the Colebrook friction factor: velocity, Reynolds '
      'number, friction, fittings (ΣK) and elevation ΔP for liquid lines.',
  icon: Icons.linear_scale,
  keywords: [
    'pipe',
    'line',
    'pressure drop',
    'darcy',
    'weisbach',
    'colebrook',
    'moody',
    'friction factor',
    'reynolds',
    'velocity',
    'fittings',
    'line sizing',
    'head loss',
  ],
  inputs: [
    const ChoiceInput(
      'fluid',
      'Fluid',
      options: [
        ChoiceOption('liquid', 'Liquid'),
        ChoiceOption('gas', 'Gas / vapour'),
      ],
    ),
    const ChoiceInput(
      'basis',
      'Flow given as',
      options: [
        ChoiceOption('vol', 'Volume flow'),
        ChoiceOption('mass', 'Mass flow'),
      ],
    ),
    NumberInput(
      'q',
      'Volume flow (actual)',
      quantity: Quantity.volumeFlow,
      initial: 100 / 3600,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('basis') == 'vol',
    ),
    NumberInput(
      'm',
      'Mass flow',
      quantity: Quantity.massFlow,
      initial: 100000 / 3600,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('basis') == 'mass',
    ),
    const NumberInput(
      'd',
      'Pipe internal diameter',
      quantity: Quantity.length,
      initial: 0.15405,
      min: 0,
      minInclusive: false,
      help:
          '6" Sch 40 = 154.05 mm; 4" Sch 40 = 102.26 mm; 2" Sch 40 = 52.50 mm.',
    ),
    const NumberInput(
      'l',
      'Pipe length',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 100,
      min: 0,
    ),
    const ChoiceInput(
      'rough',
      'Pipe material',
      options: [
        ChoiceOption('cs', 'Commercial steel'),
        ChoiceOption('drawn', 'Drawn tube / plastic'),
        ChoiceOption('galv', 'Galvanised steel'),
        ChoiceOption('ci', 'Cast iron'),
        ChoiceOption('custom', 'Custom roughness'),
      ],
    ),
    NumberInput(
      'eps',
      'Absolute roughness ε',
      quantity: Quantity.length,
      units: ('mm', 'in'),
      initial: 0.045e-3,
      min: 0,
      help:
          'Commercial steel 0.045 mm; corroded steel 0.15–1 mm; concrete 0.3–3 mm.',
      visibleWhen: (v) => v.c('rough') == 'custom',
    ),
    const NumberInput(
      'rho',
      'Density ρ (flowing)',
      quantity: Quantity.density,
      initial: 998.2,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'mu',
      'Dynamic viscosity μ',
      quantity: Quantity.viscosity,
      initial: 1.002e-3,
      min: 0,
      minInclusive: false,
      help: 'Water 20 °C 1.0 cP, 80 °C 0.35 cP; natural gas ≈ 0.011 cP.',
    ),
    const NumberInput(
      'k',
      'Fittings ΣK',
      quantity: Quantity.dimensionless,
      initial: 0,
      min: 0,
      help:
          'Sum of loss coefficients (Crane TP-410): 90° LR elbow ≈ 0.3, gate valve open ≈ 0.15, '
          'globe valve ≈ 6, swing check ≈ 2, entrance 0.5, exit 1.0.',
    ),
    const NumberInput(
      'dz',
      'Elevation rise (outlet − inlet)',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 0,
      help: 'Negative if the outlet is lower than the inlet.',
    ),
    NumberInput(
      'p1',
      'Inlet pressure p₁',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 20e5,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
  ],
  compute: (v) {
    final d = v.n('d'), l = v.n('l'), rho = v.n('rho'), mu = v.n('mu');
    final q = v.c('basis') == 'mass' ? v.n('m') / rho : v.n('q');
    final eps = v.c('rough') == 'custom'
        ? v.n('eps')
        : roughnessPresets[v.c('rough')]!;
    final area = math.pi / 4 * d * d;
    final vel = q / area;
    final re = rho * vel * d / mu;
    final rr = eps / d;
    final f = darcyFriction(re, rr);
    final dyn = rho * vel * vel / 2;
    final dpF = f * l / d * dyn;
    final dpK = v.n('k') * dyn;
    final dpZ = rho * gStd * v.n('dz');
    final dp = dpF + dpK + dpZ;
    final w = <String>[];
    final String regime;
    if (re < reLaminar) {
      regime = 'Laminar (f = 64/Re)';
    } else if (re < reTurbulent) {
      regime = 'Transitional (Colebrook used)';
      w.add(
        'Re = ${formatNumber(re, sig: 4)} is transitional (2000–4000): the '
        'friction factor is uncertain. Colebrook (turbulent) is used, which is '
        'conservative.',
      );
    } else {
      regime = 'Turbulent (Colebrook)';
    }
    if (rr > 0.05) {
      w.add('ε/D > 0.05: beyond the Moody chart; Colebrook is extrapolated.');
    }
    if (re > 1e8) w.add('Re > 10⁸: beyond the Moody chart.');
    final out = <ToolOutput>[
      ToolOutput(
        'dp',
        'Total ΔP (p₁ − p₂)',
        dp,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        level: OutputLevel.primary,
        sig: 5,
      ),
      ToolOutput(
        'dpf',
        'Friction ΔP',
        dpF,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        sig: 5,
      ),
      ToolOutput(
        'dpk',
        'Fittings ΔP',
        dpK,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        sig: 5,
      ),
      ToolOutput(
        'dpz',
        'Elevation ΔP',
        dpZ,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        sig: 5,
      ),
      ToolOutput(
        'dp100',
        'Friction ΔP per 100 m',
        l > 0 ? dpF / l * 100 : f / d * dyn * 100,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        sig: 4,
      ),
      ToolOutput(
        'hl',
        'Head loss (friction + ΣK)',
        (dpF + dpK) / (rho * gStd),
        quantity: Quantity.length,
        units: ('m', 'ft'),
        sig: 5,
      ),
      ToolOutput('vel', 'Velocity', vel, quantity: Quantity.velocity, sig: 4),
      ToolOutput('re', 'Reynolds number Re', re, sig: 5),
      ToolOutput('f', 'Darcy friction factor f', f, sig: 5),
      ToolOutput.text('regime', 'Flow regime', regime),
    ];
    if (v.c('fluid') == 'gas') {
      final p1 = v.n('p1');
      if (dp >= p1) {
        throw ToolInputError(
          'ΔP exceeds the inlet pressure: the line is choked or far too small. '
          'Use a compressible-flow method.',
        );
      }
      final ratio = dp / p1;
      out.insert(
        1,
        ToolOutput(
          'p2',
          'Outlet pressure p₂',
          p1 - dp,
          quantity: Quantity.pressure,
          sig: 5,
        ),
      );
      out.insert(
        2,
        ToolOutput(
          'ratio',
          'ΔP / p₁',
          ratio,
          quantity: Quantity.percent,
          sig: 3,
        ),
      );
      if (ratio > 0.4) {
        w.add(
          'Gas: ΔP > 40 % of p₁. The incompressible result is NOT valid; use an '
          'isothermal/adiabatic compressible-flow method (Crane TP-410).',
        );
      } else if (ratio > 0.1) {
        w.add(
          'Gas: ΔP > 10 % of p₁. Re-run with the average density of inlet and '
          'outlet (Crane TP-410); above 40 % use a compressible method.',
        );
      }
    }
    return ToolResult(
      out,
      warnings: w,
      notes: ['Elevation ΔP uses the entered density along the whole rise.'],
    );
  },
  formula: '''Velocity     V = Q / (π·D²/4)
Reynolds     Re = ρ·V·D / μ

Darcy–Weisbach:
  ΔP_friction = f · (L/D) · ρV²/2
  ΔP_fittings = ΣK · ρV²/2
  ΔP_elevation = ρ·g·Δz
  ΔP_total = sum of the three
  Head loss h = (ΔP_friction + ΔP_fittings)/(ρ·g)

Friction factor (Darcy):
  Re < 2000:  f = 64/Re  (Hagen–Poiseuille)
  Re ≥ 2000:  Colebrook–White, solved iteratively
    1/√f = −2·log₁₀( ε/(3.7·D) + 2.51/(Re·√f) )

Roughness presets ε: commercial steel 0.045 mm,
drawn tube/plastic 0.0015 mm, galvanised 0.15 mm,
cast iron 0.26 mm.''',
  references: [
    'Crane Technical Paper No. 410, Flow of Fluids Through Valves, Fittings and Pipe — ch. 1 (Darcy equation, compressible-flow 10 % / 40 % rule), ch. 2 (K values), App. A (roughness)',
    'C. F. Colebrook, J. Inst. Civ. Eng. 11 (1939) 133; L. F. Moody, Trans. ASME 66 (1944) 671 (roughness values)',
    'Perry\'s Chemical Engineers\' Handbook, 9th ed., §6 Fluid dynamics (incompressible pipe flow)',
    'Cross-checked against the open-source "fluids" 1.3.1 library (C. Bell): Colebrook (exact Lambert-W solution) and Darcy–Weisbach',
  ],
  assumptions: [
    'Steady, fully developed, single-phase flow in a round pipe of constant diameter.',
    'Incompressible: density and viscosity constant along the line. For gases this holds only while ΔP < 10 % of p₁.',
    'Fittings entered as total ΣK referenced to the pipe velocity (Crane K method).',
  ],
  cases: [
    const ToolCase(
      'Water 100 m³/h, 6" Sch 40, 100 m, commercial steel',
      source:
          'fluids 1.3.1 (friction_factor Method="Colebrook", exact): Re 228 716, '
          'f 0.0174034, ΔP 12 523.6 Pa',
      numbers: {
        'q': (100, 'm3/h'),
        'd': (154.05, 'mm'),
        'l': (100, 'm'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {
        'vel': (1.4903360697511365, 'm/s'),
        're': (228715.58508620883, '-'),
        'f': (0.017403429331815056, '-'),
        'dp': (12523.598226478132, 'Pa'),
      },
      expectText: {'regime': 'Turbulent'},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Same line + ΣK 5 and 10 m rise',
      source:
          'fluids 1.3.1: ΔP_K = dP_from_K(5) 5 542.76 Pa, ρgΔz 97 889.98 Pa, '
          'total 115 956.3 Pa',
      numbers: {
        'q': (100, 'm3/h'),
        'd': (154.05, 'mm'),
        'l': (100, 'm'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
        'k': (5, '-'),
        'dz': (10, 'm'),
      },
      expect: {
        'dpk': (5542.759044799555, 'Pa'),
        'dpz': (97889.98030000001, 'Pa'),
        'dp': (115956.33757127769, 'Pa'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Laminar oil 100 cP, 5 m³/h, 2" (52.5 mm), 50 m',
      source:
          'Hagen–Poiseuille ΔP = 128·μ·L·Q/(π·D⁴) = 37 244.35 Pa (exact); '
          'fluids 1.3.1 gives the same (f = 64/Re, Re 303.15)',
      numbers: {
        'q': (5, 'm3/h'),
        'd': (52.5, 'mm'),
        'l': (50, 'm'),
        'rho': (900, 'kg/m3'),
        'mu': (100, 'cP'),
      },
      expect: {
        're': (303.15227255599115, '-'),
        'dp': (37244.34931400917, 'Pa'),
      },
      expectText: {'regime': 'Laminar'},
      relTol: 1e-9,
    ),
    const ToolCase(
      'Galvanised 2", water 10 m³/h, 30 m',
      source: 'fluids 1.3.1 Colebrook: f 0.0277513, ΔP 13 031.99 Pa',
      choices: {'rough': 'galv'},
      numbers: {
        'q': (10, 'm3/h'),
        'd': (52.5, 'mm'),
        'l': (30, 'm'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {
        'f': (0.027751292319699222, '-'),
        'dp': (13031.990520846037, 'Pa'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Custom ε 1 mm, 8" (202.72 mm), 300 m³/h, 500 m',
      source: 'fluids 1.3.1 Colebrook: f 0.0304317, ΔP 249 723.3 Pa',
      choices: {'rough': 'custom'},
      numbers: {
        'q': (300, 'm3/h'),
        'd': (202.72, 'mm'),
        'l': (500, 'm'),
        'eps': (1, 'mm'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {
        'f': (0.030431733615937862, '-'),
        'dp': (249723.27701131508, 'Pa'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Gas 5 t/h, 4" (102.26 mm), 1 km, p₁ 10 bar a → ΔP > 10 % warning',
      source:
          'fluids 1.3.1 Colebrook (incompressible): Re 1.572e6, f 0.0165924, '
          'ΔP 149 683.5 Pa = 15 % of p₁ (Crane TP-410 10 % rule)',
      choices: {'fluid': 'gas', 'basis': 'mass'},
      numbers: {
        'm': (5000, 'kg/h'),
        'd': (102.26, 'mm'),
        'l': (1000, 'm'),
        'rho': (15.5, 'kg/m3'),
        'mu': (0.011, 'cP'),
        'p1': (10, 'bar'),
      },
      expect: {
        'f': (0.016592403293536614, '-'),
        'dp': (149683.49108729404, 'Pa'),
        'p2': (850316.508912706, 'Pa'),
      },
      relTol: 1e-9,
      expectWarning: '10 %',
    ),
  ],
);
