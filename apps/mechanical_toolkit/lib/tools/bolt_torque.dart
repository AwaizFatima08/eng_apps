import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'metric_threads.dart';

/// Nut factors K from Shigley's Mechanical Engineering Design, Table 8-15.
const Map<String, double> _nutFactors = {
  'k20': 0.20,
  'k30': 0.30,
  'k18': 0.18,
  'k16': 0.16,
  'k12': 0.12,
};

/// VDI 2230 Part 1 Eq. (R2/1)-style table preload: 90 % of R_p0.2 used by
/// the von Mises stress (tension + thread torsion) on the stress section.
double vdiTablePreload(MetricThread t, double rp, double muG) {
  final k = 1.5 * t.d2 / t.ds * (t.p / (math.pi * t.d2) + 1.155 * muG);
  return t.as * 1e-6 * 0.9 * rp / math.sqrt(1 + 3 * k * k);
}

final boltTorqueTool = ToolDef(
  id: 'bolt_torque',
  title: 'Bolt torque & preload',
  summary:
      'Tightening torque and preload for ISO metric coarse threads M6–M36, '
      'classes 8.8 / 10.9 / 12.9 and A2/A4 stainless: nut-factor or '
      'VDI 2230 friction method.',
  icon: Icons.build,
  keywords: [
    'bolt',
    'torque',
    'preload',
    'tightening',
    'vdi 2230',
    'iso 16047',
    'nut factor',
    'friction',
    'proof load',
    'iso 898',
    'stainless',
    'screw',
    'fastener',
  ],
  inputs: [
    ChoiceInput(
      'size',
      'Thread (ISO coarse)',
      initial: 'M16',
      options: [for (final t in metricCoarse) ChoiceOption(t.name, t.name)],
    ),
    ChoiceInput(
      'grade',
      'Property class',
      options: [for (final g in boltGrades) ChoiceOption(g.id, g.label)],
    ),
    const ChoiceInput(
      'basis',
      'Preload',
      options: [
        ChoiceOption('vdi', 'VDI table (ν = 0.9)'),
        ChoiceOption('proof', '% of proof load'),
        ChoiceOption('yield', '% of yield'),
        ChoiceOption('force', 'Enter preload'),
      ],
    ),
    NumberInput(
      'pct',
      'Preload as % of proof / yield load',
      quantity: Quantity.percent,
      initial: 0.75,
      min: 0,
      minInclusive: false,
      max: 1.2,
      help:
          'Shigley: 75 % of proof load for reusable joints, 90 % for permanent ones.',
      visibleWhen: (v) => v.c('basis') == 'proof' || v.c('basis') == 'yield',
    ),
    NumberInput(
      'force',
      'Preload F',
      quantity: Quantity.force,
      initial: 60e3,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('basis') == 'force',
    ),
    const ChoiceInput(
      'method',
      'Torque method',
      options: [
        ChoiceOption('vdi', 'VDI 2230 (µG, µK)'),
        ChoiceOption('nut', 'Nut factor T = K·F·d'),
      ],
    ),
    ChoiceInput(
      'kpreset',
      'Nut factor K (Shigley Table 8-15)',
      options: const [
        ChoiceOption('k20', 'Zinc-plated / as received 0.20'),
        ChoiceOption('k30', 'Black oxide, dry 0.30'),
        ChoiceOption('k18', 'Lubricated 0.18'),
        ChoiceOption('k16', 'Cadmium-plated 0.16'),
        ChoiceOption('k12', 'Anti-seize paste 0.12'),
        ChoiceOption('custom', 'Other K'),
      ],
      visibleWhen: (v) => v.c('method') == 'nut',
    ),
    NumberInput(
      'k',
      'Nut factor K',
      quantity: Quantity.dimensionless,
      initial: 0.2,
      min: 0.05,
      max: 0.5,
      visibleWhen: (v) => v.c('method') == 'nut' && v.c('kpreset') == 'custom',
    ),
    NumberInput(
      'muG',
      'Thread friction µG',
      quantity: Quantity.dimensionless,
      initial: 0.12,
      min: 0.04,
      max: 0.5,
      help:
          'VDI 2230 Table A5 / ISO 16047. Black-oxide or phosphated, lightly oiled '
          '≈ 0.12–0.14; zinc-plated dry 0.12–0.18; MoS₂ paste 0.08–0.10.',
      visibleWhen: (v) => v.c('method') == 'vdi' || v.c('basis') == 'vdi',
    ),
    NumberInput(
      'muK',
      'Head / nut bearing friction µK',
      quantity: Quantity.dimensionless,
      initial: 0.12,
      min: 0.04,
      max: 0.5,
      visibleWhen: (v) => v.c('method') == 'vdi',
    ),
    ChoiceInput(
      'head',
      'Bearing face',
      options: const [
        ChoiceOption('hex', 'Hex head, medium hole'),
        ChoiceOption('custom', 'Enter diameters'),
      ],
      help: 'Hex: d_w min of ISO 4014/4017, hole d_h medium series ISO 273.',
      visibleWhen: (v) => v.c('method') == 'vdi',
    ),
    NumberInput(
      'dw',
      'Bearing face outer Ø d_w',
      quantity: Quantity.length,
      initial: 0.0225,
      min: 0,
      minInclusive: false,
      help: 'Socket head ISO 4762: about the head Ø; washer: washer OD.',
      visibleWhen: (v) => v.c('method') == 'vdi' && v.c('head') == 'custom',
    ),
    NumberInput(
      'dh',
      'Clearance hole Ø d_h',
      quantity: Quantity.length,
      initial: 0.0175,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('method') == 'vdi' && v.c('head') == 'custom',
    ),
  ],
  compute: (v) {
    final t = threadByName(v.c('size'));
    final g = boltGrades.firstWhere(
      (x) => x.id == v.c('grade'),
      orElse: () => boltGrades.first,
    );
    final d = t.d * 1e-3, p = t.p * 1e-3, d2 = t.d2 * 1e-3, ds = t.ds * 1e-3;
    final as = t.as * 1e-6; // m²
    final sp = g.proof(t.d) * 1e6, rp = g.rp(t.d) * 1e6;
    final fProof = as * sp, fYield = as * rp;
    final vdi = v.c('method') == 'vdi';
    final muG = (vdi || v.c('basis') == 'vdi') ? v.n('muG') : 0.0;

    final f = switch (v.c('basis')) {
      'vdi' => vdiTablePreload(t, rp, muG),
      'proof' => v.n('pct') * fProof,
      'yield' => v.n('pct') * fYield,
      _ => v.n('force'),
    };

    final w = <String>[];
    final notes = <String>[];
    final out = <ToolOutput>[
      ToolOutput(
        'f',
        'Preload F',
        f,
        quantity: Quantity.force,
        level: OutputLevel.primary,
        sig: 4,
      ),
    ];

    final sigma = f / as;
    double? sigmaRed;
    if (vdi) {
      final muK = v.n('muK');
      final custom = v.c('head') == 'custom';
      final dw = custom ? v.n('dw') : t.dw * 1e-3;
      final dh = custom ? v.n('dh') : t.dh * 1e-3;
      if (dw <= dh) {
        throw ToolInputError('Bearing face Ø must be larger than the hole Ø.');
      }
      if (dh < d) {
        throw ToolInputError(
          'Clearance hole must not be smaller than the bolt.',
        );
      }
      final dkm = (dw + dh) / 2;
      final mg = f * (0.16 * p + 0.58 * d2 * muG); // thread torque
      final mk = f * dkm / 2 * muK; // bearing-face torque
      final ma = mg + mk;
      // Equivalent stress in the assembly state exactly as VDI 2230 R5
      // (the same expression that defines the table preload at ν = 0.9).
      final k = 1.5 * d2 / ds * (p / (math.pi * d2) + 1.155 * muG);
      sigmaRed = sigma * math.sqrt(1 + 3 * k * k);
      out.addAll([
        ToolOutput(
          'torque',
          'Tightening torque M_A',
          ma,
          quantity: Quantity.torque,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'mg',
          'Thread torque M_G',
          mg,
          quantity: Quantity.torque,
          sig: 4,
        ),
        ToolOutput('keq', 'Equivalent nut factor K', ma / (f * d), sig: 3),
      ]);
      if (muG < 0.08 || muK < 0.08) {
        w.add(
          'µ below 0.08: preload scatter is large and the thread may strip or the bolt yield if the real friction is higher/lower. Use tested values.',
        );
      }
    } else {
      final k = v.c('kpreset') == 'custom'
          ? v.n('k')
          : _nutFactors[v.c('kpreset')] ?? 0.2;
      out.add(
        ToolOutput(
          'torque',
          'Tightening torque T',
          k * f * d,
          quantity: Quantity.torque,
          level: OutputLevel.primary,
          sig: 4,
        ),
      );
      notes.add(
        'K lumps thread and face friction together; the real preload for a given torque can vary by ±25 % or more.',
      );
    }

    final util = (sigmaRed ?? sigma) / rp;
    out.addAll([
      ToolOutput(
        'as',
        'Stress area A_s',
        as,
        quantity: Quantity.area,
        units: ('mm2', 'in2'),
        sig: 4,
      ),
      ToolOutput(
        'sigma',
        'Tensile stress F/A_s',
        sigma,
        quantity: Quantity.stress,
        sig: 4,
      ),
      if (sigmaRed != null)
        ToolOutput(
          'sred',
          'Equivalent stress σ_red',
          sigmaRed,
          quantity: Quantity.stress,
          sig: 4,
        ),
      ToolOutput(
        'nu',
        sigmaRed != null ? 'Yield utilisation ν' : 'F / yield load',
        util,
        quantity: Quantity.percent,
        level: util > 1
            ? OutputLevel.fail
            : util > 0.9
            ? OutputLevel.warn
            : OutputLevel.ok,
        sig: 3,
      ),
      ToolOutput(
        'pproof',
        g.stainless ? 'F / 0.2 % load' : 'F / proof load',
        f / fProof,
        quantity: Quantity.percent,
        sig: 3,
      ),
      ToolOutput(
        'fproof',
        g.stainless ? '0.2 % load A_s·R_p0.2' : 'Proof load A_s·S_p',
        fProof,
        quantity: Quantity.force,
        sig: 4,
      ),
    ]);

    if (util > 1.0001) {
      w.add(
        sigmaRed != null
            ? 'Von Mises stress during tightening exceeds R_p0.2: the bolt yields.'
            : 'Preload exceeds the yield load (torsion from tightening not even included).',
      );
    } else if (sigmaRed == null && util > 0.85) {
      w.add(
        'Tensile stress alone is over 85 % of yield; thread torsion during tightening adds roughly 10–20 % — check with the VDI method.',
      );
    }
    if (!g.stainless && f > fProof * 1.0001) {
      w.add('Preload is above the ISO 898-1 proof load.');
    }
    if (g.stainless && t.d > 24) {
      w.add(
        'ISO 3506-1:2009 gives class 70/80 properties only up to M24; above that they must be agreed with the supplier.',
      );
    }
    notes.add(
      'Torque-wrench tightening scatters preload: VDI 2230 Table A8 gives α_A ≈ 1.4–1.6, so the minimum preload is about F/α_A.',
    );
    return ToolResult(out, warnings: w, notes: notes);
  },
  formula: '''Thread (ISO 724 / ISO 898-1), mm:
  d2 = d − 0.649519·P      d3 = d − 1.226869·P
  A_s = π/4·((d2 + d3)/2)²

Preload options
  F = x·A_s·S_p (proof)  or  x·A_s·R_p0.2 (yield)
  VDI 2230 table preload (ν = 0.9):
    F_M = A_s·0.9·R_p0.2 / √(1 + 3·[1.5·d2/d_s·(P/(π·d2) + 1.155·µG)]²)

Nut-factor method:
  T = K·F·d

VDI 2230 / ISO 16047 friction method:
  M_A = F·(0.16·P + 0.58·d2·µG + D_Km/2·µK)
  D_Km = (d_w + d_h)/2
  M_G = F·(0.16·P + 0.58·d2·µG)     (thread part)
  σ = F/A_s
  σ_red = σ·√(1 + 3·[1.5·d2/d_s·(P/(π·d2) + 1.155·µG)]²)
  ν = σ_red/R_p0.2                 (VDI 2230 R5, assembly state)''',
  references: [
    'VDI 2230 Part 1:2015 §5.4.3 Eq. (R7/4) (tightening torque) and Table A1 (F_M Tab, M_A at ν = 0.9)',
    'ISO 16047:2005 §3 (torque/clamp-force relationship, µth and µb)',
    'ISO 898-1:2013 Table 3 (R_m, R_p0.2, S_p) and Table 4/§9.1.6.1 (stress area A_s)',
    'ISO 3506-1:2009 Table 2 (austenitic stainless classes 70 and 80)',
    'ISO 261 / ISO 724 (coarse pitches, pitch diameter); ISO 273 (medium clearance holes)',
    'Shigley\'s Mechanical Engineering Design, 10th ed., Eq. (8-27) and Table 8-15 (nut factors)',
  ],
  assumptions: [
    'Coarse thread, 60° flank angle; nut of matching strength (thread stripping not checked).',
    'Hex-head bearing Ø = d_w min of ISO 4014/4017 and medium hole of ISO 273, as in the VDI 2230 table.',
    'σ_red is the VDI 2230 assembly-state stress with full thread torsion; it relaxes after tightening.',
    'Stainless "proof" load is the 0.2 % yield load; ISO 3506-1 has no separate proof stress.',
  ],
  cases: const [
    ToolCase(
      'M10 8.8, µG = µK = 0.12, VDI table preload',
      source:
          'VDI 2230 Part 1 Table A1 (via Würth DINO ch. 6 Tab. 5): F_M 29.6 kN, M_A 48 N·m; ν = 0.9 by definition',
      choices: {'size': 'M10', 'grade': '8.8', 'basis': 'vdi', 'method': 'vdi'},
      numbers: {'muG': (0.12, '-'), 'muK': (0.12, '-')},
      expect: {'f': (29.6, 'kN'), 'torque': (48, 'N.m'), 'nu': (90, '%')},
      relTol: 1.2e-2,
    ),
    ToolCase(
      'M16 10.9, µ = 0.12, VDI table preload',
      source: 'VDI 2230 Part 1 Table A1: F_M 118.8 kN, M_A 302 N·m',
      choices: {
        'size': 'M16',
        'grade': '10.9',
        'basis': 'vdi',
        'method': 'vdi',
      },
      numbers: {'muG': (0.12, '-'), 'muK': (0.12, '-')},
      expect: {'f': (118.8, 'kN'), 'torque': (302, 'N.m')},
      relTol: 5e-3,
    ),
    ToolCase(
      'M36 8.8, µ = 0.16, VDI table preload',
      source: 'VDI 2230 Part 1 Table A1: F_M 415 kN, M_A 3054 N·m',
      choices: {'size': 'M36', 'grade': '8.8', 'basis': 'vdi', 'method': 'vdi'},
      numbers: {'muG': (0.16, '-'), 'muK': (0.16, '-')},
      expect: {'f': (415, 'kN'), 'torque': (3054, 'N.m')},
      relTol: 5e-3,
    ),
    ToolCase(
      'M12 8.8, µ = 0.08 (MoS₂), VDI table preload',
      source: 'VDI 2230 Part 1 Table A1: F_M 45.2 kN, M_A 63 N·m',
      choices: {'size': 'M12', 'grade': '8.8', 'basis': 'vdi', 'method': 'vdi'},
      numbers: {'muG': (0.08, '-'), 'muK': (0.08, '-')},
      expect: {'f': (45.2, 'kN'), 'torque': (63, 'N.m')},
      relTol: 1e-2,
    ),
    ToolCase(
      'M20 10.9 at a given preload of 150 kN, µ = 0.12',
      source:
          'VDI 2230 Table A1 ratio M_A/F_M = 592/186 (geometry fixed) → 477.4 N·m',
      choices: {
        'size': 'M20',
        'grade': '10.9',
        'basis': 'force',
        'method': 'vdi',
      },
      numbers: {'force': (150, 'kN'), 'muG': (0.12, '-'), 'muK': (0.12, '-')},
      expect: {'torque': (477.4, 'N.m')},
      relTol: 5e-3,
    ),
    ToolCase(
      'M16 8.8 at 75 % proof load, K = 0.20',
      source:
          'Shigley Eq. (8-27), Table 8-15 K = 0.20; ISO 898-1 A_s 157 mm², S_p 580 MPa → F 68.30 kN, T 218.5 N·m (hand calc)',
      choices: {
        'size': 'M16',
        'grade': '8.8',
        'basis': 'proof',
        'method': 'nut',
        'kpreset': 'k20',
      },
      numbers: {'pct': (75, '%')},
      expect: {
        'f': (68.295, 'kN'),
        'torque': (218.54, 'N.m'),
        'as': (157, 'mm2'),
      },
      relTol: 3e-3,
    ),
    ToolCase(
      'M12 A4-80 at 70 % of yield, anti-seize K = 0.12',
      source:
          'ISO 3506-1 R_p0.2 600 MPa, ISO 898-1 A_s 84.3 mm² → F 35.41 kN, T 50.98 N·m (hand calc)',
      choices: {
        'size': 'M12',
        'grade': 'A80',
        'basis': 'yield',
        'method': 'nut',
        'kpreset': 'k12',
      },
      numbers: {'pct': (70, '%')},
      expect: {'f': (35.406, 'kN'), 'torque': (50.985, 'N.m')},
      relTol: 3e-3,
    ),
  ],
);
