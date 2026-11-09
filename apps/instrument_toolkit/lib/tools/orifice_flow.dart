import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// ISO 5167-2:2003 Reader-Harris/Gallagher discharge coefficient.
double rhgC({
  required double D, // m
  required double beta,
  required double reD,
  required String taps,
}) {
  final dMm = D * 1000;
  final (l1, l2) = switch (taps) {
    'corner' => (0.0, 0.0),
    'dd2' => (1.0, 0.47),
    _ => (25.4 / dMm, 25.4 / dMm), // flange
  };
  final a = math.pow(19000 * beta / reD, 0.8).toDouble();
  final m2 = 2 * l2 / (1 - beta);
  final b4 = math.pow(beta, 4).toDouble();
  var c =
      0.5961 +
      0.0261 * beta * beta -
      0.216 * math.pow(beta, 8) +
      0.000521 * math.pow(1e6 * beta / reD, 0.7) +
      (0.0188 + 0.0063 * a) * math.pow(beta, 3.5) * math.pow(1e6 / reD, 0.3) +
      (0.043 + 0.080 * math.exp(-10 * l1) - 0.123 * math.exp(-7 * l1)) *
          (1 - 0.11 * a) *
          b4 /
          (1 - b4) -
      0.031 * (m2 - 0.8 * math.pow(m2, 1.1)) * math.pow(beta, 1.3);
  if (dMm < 71.12) c += 0.011 * (0.75 - beta) * (2.8 - dMm / 25.4);
  return c;
}

/// ISO 5167-2:2003 §5.3.2.2 expansibility factor.
double orificeEpsilon(double beta, double p1, double dp, double kappa) {
  final p2 = p1 - dp;
  return 1 -
      (0.351 + 0.256 * math.pow(beta, 4) + 0.93 * math.pow(beta, 8)) *
          (1 - math.pow(p2 / p1, 1 / kappa));
}

class OrificeSolution {
  OrificeSolution(this.qm, this.dp, this.c, this.eps, this.reD);
  final double qm, dp, c, eps, reD;
}

/// Mass flow from DP (iterating on Reynolds number).
OrificeSolution orificeFlow({
  required double D,
  required double d,
  required double dp,
  required double rho,
  required double mu,
  required String taps,
  double eps = 1,
}) {
  final beta = d / D;
  final k =
      eps *
      math.pi /
      4 *
      d *
      d *
      math.sqrt(2 * dp * rho) /
      math.sqrt(1 - math.pow(beta, 4));
  var c = 0.6;
  var reD = 1e6;
  for (var i = 0; i < 100; i++) {
    final qm = c * k;
    reD = 4 * qm / (math.pi * mu * D);
    final next = rhgC(D: D, beta: beta, reD: reD, taps: taps);
    if ((next - c).abs() < 1e-12) {
      c = next;
      break;
    }
    c = next;
  }
  final qm = c * k;
  return OrificeSolution(qm, dp, c, eps, 4 * qm / (math.pi * mu * D));
}

/// DP for a given mass flow (Re is known directly from the flow; ε depends
/// on DP, so iterate on DP for gases).
OrificeSolution orificeDp({
  required double D,
  required double d,
  required double qm,
  required double rho,
  required double mu,
  required String taps,
  double? p1,
  double? kappa,
}) {
  final beta = d / D;
  final reD = 4 * qm / (math.pi * mu * D);
  final c = rhgC(D: D, beta: beta, reD: reD, taps: taps);
  var eps = 1.0;
  var dp = 0.0;
  for (var i = 0; i < 100; i++) {
    final x =
        qm * math.sqrt(1 - math.pow(beta, 4)) / (c * eps * math.pi / 4 * d * d);
    final next = x * x / (2 * rho);
    if ((next - dp).abs() < 1e-9 * next) {
      dp = next;
      break;
    }
    dp = next;
    if (p1 != null && kappa != null) {
      if (dp >= p1) {
        throw ToolInputError(
          'Flow too high for this orifice: DP would exceed p1.',
        );
      }
      eps = orificeEpsilon(beta, p1, dp, kappa);
    }
  }
  return OrificeSolution(qm, dp, c, eps, reD);
}

final orificeFlowTool = ToolDef(
  id: 'orifice_flow',
  title: 'Orifice DP ⇄ flow (ISO 5167-2)',
  summary:
      'Concentric square-edged orifice: flow from differential pressure or DP '
      'from flow, with Reader-Harris/Gallagher C, gas expansibility and pressure loss.',
  icon: Icons.water,
  keywords: [
    'orifice',
    'flow',
    'dp',
    'iso 5167',
    'beta',
    'discharge coefficient',
    'flange taps',
    'corner',
    'flowmeter',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('dp2q', 'Flow from DP'),
        ChoiceOption('q2dp', 'DP from flow'),
      ],
    ),
    const ChoiceInput(
      'fluid',
      'Fluid',
      options: [
        ChoiceOption('liquid', 'Liquid'),
        ChoiceOption('gas', 'Gas / steam'),
      ],
    ),
    const ChoiceInput(
      'taps',
      'Pressure tappings',
      initial: 'flange',
      options: [
        ChoiceOption('flange', 'Flange'),
        ChoiceOption('corner', 'Corner'),
        ChoiceOption('dd2', 'D and D/2'),
      ],
    ),
    const NumberInput(
      'D',
      'Pipe internal diameter D',
      quantity: Quantity.length,
      initial: 0.1023,
      min: 0,
      minInclusive: false,
      help: 'Actual ID at flowing conditions (e.g. 4" Sch 40 = 102.3 mm).',
    ),
    const NumberInput(
      'd',
      'Orifice bore d',
      quantity: Quantity.length,
      initial: 0.05,
      min: 0,
      minInclusive: false,
    ),
    NumberInput(
      'dp',
      'Differential pressure ΔP',
      quantity: Quantity.pressureDiff,
      initial: 25000,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'dp2q',
    ),
    NumberInput(
      'qm',
      'Mass flow',
      quantity: Quantity.massFlow,
      initial: 20000 / 3600,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'q2dp',
    ),
    const NumberInput(
      'rho',
      'Density at upstream tapping ρ₁',
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
      help:
          'Water 20 °C ≈ 1.0 cP; natural gas ≈ 0.011 cP; steam ≈ 0.015–0.025 cP.',
    ),
    NumberInput(
      'p1',
      'Upstream pressure p₁',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 2.0e6,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'kappa',
      'Isentropic exponent κ',
      quantity: Quantity.dimensionless,
      initial: 1.3,
      min: 1,
      help: 'Air 1.40, natural gas ≈ 1.30, superheated steam ≈ 1.30.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
  ],
  compute: (v) {
    final D = v.n('D'), d = v.n('d'), rho = v.n('rho'), mu = v.n('mu');
    final taps = v.c('taps');
    if (d >= D) throw ToolInputError('Bore d must be smaller than pipe ID D.');
    final beta = d / D;
    final gas = v.c('fluid') == 'gas';
    final p1 = gas ? v.n('p1') : null;
    final kappa = gas ? v.n('kappa') : null;
    late OrificeSolution s;
    if (v.c('mode') == 'dp2q') {
      final dp = v.n('dp');
      if (gas && dp >= p1!) {
        throw ToolInputError('ΔP must be less than the absolute p₁.');
      }
      final eps = gas ? orificeEpsilon(beta, p1!, dp, kappa!) : 1.0;
      s = orificeFlow(
        D: D,
        d: d,
        dp: dp,
        rho: rho,
        mu: mu,
        taps: taps,
        eps: eps,
      );
    } else {
      s = orificeDp(
        D: D,
        d: d,
        qm: v.n('qm'),
        rho: rho,
        mu: mu,
        taps: taps,
        p1: p1,
        kappa: kappa,
      );
    }

    final w = <String>[];
    final dMm = D * 1000;
    if (d < 0.0125) w.add('d < 12.5 mm: outside ISO 5167-2 limits.');
    if (dMm < 50 || dMm > 1000) {
      w.add('D outside 50 … 1000 mm: outside ISO 5167-2 limits.');
    }
    if (beta < 0.1 || beta > 0.75) {
      w.add('β = ${formatNumber(beta, sig: 3)} outside 0.10 … 0.75.');
    }
    final reMin = switch (taps) {
      'flange' => math.max(5000, 170 * beta * beta * dMm),
      _ => beta <= 0.56 ? 5000.0 : 16000 * beta * beta,
    };
    if (s.reD < reMin) {
      w.add(
        'Re_D = ${formatNumber(s.reD, sig: 3)} below the ISO limit ${formatNumber(reMin.toDouble(), sig: 3)}: C is not valid.',
      );
    }
    if (gas && (p1! - s.dp) / p1 < 0.75) {
      w.add(
        'p₂/p₁ < 0.75: expansibility equation is outside its validity range.',
      );
    }
    final b4 = math.pow(beta, 4).toDouble();
    final root = math.sqrt(1 - b4 * (1 - s.c * s.c));
    final loss = (root - s.c * beta * beta) / (root + s.c * beta * beta) * s.dp;

    final flowMode = v.c('mode') == 'dp2q';
    return ToolResult(
      [
        ToolOutput(
          'qm',
          'Mass flow qm',
          s.qm,
          quantity: Quantity.massFlow,
          sig: 6,
          level: flowMode ? OutputLevel.primary : OutputLevel.normal,
        ),
        ToolOutput(
          'qv',
          'Volume flow at ρ₁',
          s.qm / rho,
          quantity: Quantity.volumeFlow,
          sig: 6,
        ),
        ToolOutput(
          'dp',
          'Differential pressure ΔP',
          s.dp,
          quantity: Quantity.pressureDiff,
          sig: 6,
          level: flowMode ? OutputLevel.normal : OutputLevel.primary,
        ),
        ToolOutput('C', 'Discharge coefficient C', s.c, sig: 5),
        ToolOutput('eps', 'Expansibility ε', s.eps, sig: 5),
        ToolOutput('beta', 'Diameter ratio β', beta, sig: 4),
        ToolOutput('Re', 'Pipe Reynolds number Re_D', s.reD, sig: 4),
        ToolOutput(
          'loss',
          'Permanent pressure loss',
          loss,
          quantity: Quantity.pressureDiff,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'Uncertainty of C per ISO 5167-2 is about 0.5–0.7 % for 0.2 ≤ β ≤ 0.6 with the required straight lengths.',
      ],
    );
  },
  formula: '''Mass flow (ISO 5167-1 eq. 1):
  qm = C / √(1 − β⁴) · ε · (π/4)·d² · √(2·ΔP·ρ₁)
  β = d / D,   Re_D = 4·qm / (π·μ·D)

Discharge coefficient (Reader-Harris/Gallagher, ISO 5167-2):
  C = 0.5961 + 0.0261β² − 0.216β⁸
      + 0.000521(10⁶β/Re_D)^0.7
      + (0.0188 + 0.0063A)·β^3.5·(10⁶/Re_D)^0.3
      + (0.043 + 0.080e^(−10L₁) − 0.123e^(−7L₁))
        ·(1 − 0.11A)·β⁴/(1 − β⁴)
      − 0.031(M₂′ − 0.8M₂′^1.1)·β^1.3
  A = (19000β/Re_D)^0.8,  M₂′ = 2L₂′/(1 − β)
  + 0.011(0.75 − β)(2.8 − D/25.4) when D < 71.12 mm
  Corner: L₁ = L₂′ = 0
  D–D/2:  L₁ = 1, L₂′ = 0.47
  Flange: L₁ = L₂′ = 25.4 / D[mm]

Expansibility (gas):
  ε = 1 − (0.351 + 0.256β⁴ + 0.93β⁸)·[1 − (p₂/p₁)^(1/κ)]

Permanent pressure loss:
  Δϖ = (√(1−β⁴(1−C²)) − Cβ²)/(√(1−β⁴(1−C²)) + Cβ²) · ΔP

C depends on Re_D, so flow is found by iteration.''',
  references: [
    'ISO 5167-1:2022 Measurement of fluid flow by means of pressure differential devices — General',
    'ISO 5167-2:2022 / 2003 Orifice plates (Reader-Harris/Gallagher equation)',
    'Cross-checked against the open-source "fluids" library (C. Bell), ISO 5167 orifice model',
  ],
  assumptions: [
    'Concentric square-edged orifice, single-phase fully developed flow, straight lengths per ISO 5167-2.',
    'ρ₁ and μ are at flowing conditions at the upstream tap; D and d at flowing temperature.',
    'Drain/vent holes, edge sharpness and roughness corrections are not included.',
  ],
  cases: [
    const ToolCase(
      'Water, 4" Sch 40, d = 50 mm, ΔP 250 mbar, flange',
      source:
          'fluids 1.3.1 ISO 5167 orifice (ε = 1): 31 140.9 kg/h, C = 0.605543',
      numbers: {
        'D': (102.3, 'mm'),
        'd': (50, 'mm'),
        'dp': (250, 'mbar'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {'qm': (31140.86, 'kg/h'), 'C': (0.605543, '-')},
      relTol: 2e-5,
    ),
    const ToolCase(
      'Same, corner taps',
      source: 'fluids 1.3.1 (ε = 1): 31 178.3 kg/h, C = 0.606272',
      choices: {'taps': 'corner'},
      numbers: {
        'D': (102.3, 'mm'),
        'd': (50, 'mm'),
        'dp': (250, 'mbar'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {'qm': (31178.32, 'kg/h'), 'C': (0.606272, '-')},
      relTol: 2e-5,
    ),
    const ToolCase(
      'Same, D and D/2 taps',
      source: 'fluids 1.3.1 (ε = 1): 31 136.8 kg/h, C = 0.605464',
      choices: {'taps': 'dd2'},
      numbers: {
        'D': (102.3, 'mm'),
        'd': (50, 'mm'),
        'dp': (250, 'mbar'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {'qm': (31136.80, 'kg/h'), 'C': (0.605464, '-')},
      relTol: 2e-5,
    ),
    const ToolCase(
      'Natural gas, 8" (202.7 mm), d = 120 mm, 20 bar a, ΔP 200 mbar',
      source: 'fluids 1.3.1: 20 612.5 kg/h, C = 0.60402, ε = 0.99695',
      choices: {'fluid': 'gas'},
      numbers: {
        'D': (202.7, 'mm'),
        'd': (120, 'mm'),
        'dp': (200, 'mbar'),
        'rho': (15.5, 'kg/m3'),
        'mu': (0.011, 'cP'),
        'p1': (20, 'bar'),
        'kappa': (1.3, '-'),
      },
      expect: {
        'qm': (20612.52, 'kg/h'),
        'C': (0.604018, '-'),
        'eps': (0.996947, '-'),
      },
      relTol: 2e-5,
    ),
    const ToolCase(
      'Small pipe 2" (52.5 mm) — small-D correction',
      source: 'fluids 1.3.1 (ε = 1): 7 383.05 kg/h, C = 0.613755',
      numbers: {
        'D': (52.5, 'mm'),
        'd': (30, 'mm'),
        'dp': (100, 'mbar'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {'qm': (7383.054, 'kg/h'), 'C': (0.613755, '-')},
      relTol: 2e-5,
    ),
    const ToolCase(
      'Inverse: 20 t/h water → ΔP',
      source: 'fluids 1.3.1 (ε = 1): ΔP = 10 276.2 Pa',
      choices: {'mode': 'q2dp'},
      numbers: {
        'D': (102.3, 'mm'),
        'd': (50, 'mm'),
        'qm': (20000, 'kg/h'),
        'rho': (998.2, 'kg/m3'),
        'mu': (1.002, 'cP'),
      },
      expect: {'dp': (10276.23, 'Pa')},
      relTol: 5e-5,
    ),
  ],
);
