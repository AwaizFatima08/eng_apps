import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

// IEC 60534-2-1 Table 1 constants for Kv with Q in m³/h, p in kPa.
const double _n1 = 0.1;
const double _n9 = 24.6; // standard volume flow at 0 °C, 101.325 kPa
const double _rho0 = 999.1; // water at 15 °C, kg/m³
const double kvToCv = 1.156;
const double _rGas = 8.314462618; // J/(mol·K)

final controlValveTool = ToolDef(
  id: 'control_valve',
  title: 'Control valve Cv / Kv (IEC 60534)',
  summary:
      'Required valve flow coefficient for liquid or gas service, with choked-flow, '
      'flashing and cavitation checks.',
  icon: Icons.tune,
  keywords: [
    'cv',
    'kv',
    'valve sizing',
    'iec 60534',
    'isa 75',
    'choked',
    'cavitation',
    'flashing',
    'fl',
    'xt',
  ],
  inputs: [
    const ChoiceInput(
      'fluid',
      'Service',
      options: [
        ChoiceOption('liquid', 'Liquid'),
        ChoiceOption('gas', 'Gas / vapour'),
      ],
    ),
    const NumberInput(
      'p1',
      'Inlet pressure p₁',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 680e3,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'p2',
      'Outlet pressure p₂',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 220e3,
      min: 0,
    ),
    NumberInput(
      'q',
      'Liquid flow (at flowing conditions)',
      quantity: Quantity.volumeFlow,
      initial: 0.1,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'rho',
      'Liquid density ρ₁',
      quantity: Quantity.density,
      initial: 965.4,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'pv',
      'Vapour pressure p_v',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 70.1e3,
      min: 0,
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'pc',
      'Critical pressure p_c',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 22120e3,
      min: 0,
      minInclusive: false,
      help: 'Water 221.2 bar.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'fl',
      'Liquid pressure recovery factor F_L',
      quantity: Quantity.dimensionless,
      initial: 0.9,
      min: 0.3,
      max: 1,
      help:
          'From the valve data. Typical globe 0.85–0.9, butterfly 0.55–0.7, ball 0.55–0.75.',
      visibleWhen: (v) => v.c('fluid') == 'liquid',
    ),
    NumberInput(
      'qn',
      'Gas flow (standard, 0 °C & 1 atm)',
      quantity: Quantity.stdGasFlow,
      initial: 0.724,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      't1',
      'Inlet temperature T₁',
      quantity: Quantity.temperature,
      initial: 159.85,
      min: -273.15,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'mw',
      'Molecular mass M',
      quantity: Quantity.dimensionless,
      initial: 44.01,
      min: 0,
      minInclusive: false,
      unitSuffix: 'kg/kmol',
      help: 'Air 28.96, natural gas ≈ 17–19, CO₂ 44.01, steam 18.02, N₂ 28.01.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'z',
      'Compressibility Z at inlet',
      quantity: Quantity.dimensionless,
      initial: 0.988,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'gamma',
      'Specific heat ratio γ',
      quantity: Quantity.dimensionless,
      initial: 1.30,
      min: 1,
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
    NumberInput(
      'xt',
      'Pressure differential ratio factor x_T',
      quantity: Quantity.dimensionless,
      initial: 0.6,
      min: 0.05,
      max: 1,
      help:
          'From the valve data. Typical globe 0.6–0.75, butterfly 0.2–0.4, ball 0.15–0.55.',
      visibleWhen: (v) => v.c('fluid') == 'gas',
    ),
  ],
  compute: (v) {
    final p1 = v.n('p1'), p2 = v.n('p2');
    if (p2 >= p1) {
      throw ToolInputError('Outlet pressure must be below inlet pressure.');
    }
    final p1k = p1 / 1000, dpk = (p1 - p2) / 1000;
    final w = <String>[];
    final notes = <String>[
      'Assumes fully turbulent flow (F_R = 1) and valve size = line size (F_P = 1). '
          'Select a valve whose rated Cv puts this duty at roughly 20–80 % travel.',
    ];

    if (v.c('fluid') == 'liquid') {
      final qh = v.n('q') * 3600, rho = v.n('rho'), pv = v.n('pv') / 1000;
      final pc = v.n('pc') / 1000, fl = v.n('fl');
      if (pv >= p1k) {
        throw ToolInputError(
          'Vapour pressure must be below p₁ (liquid would flash at the inlet).',
        );
      }
      final ff = 0.96 - 0.28 * math.sqrt(pv / pc);
      final dpChoked = fl * fl * (p1k - ff * pv);
      final choked = dpk >= dpChoked;
      final dpSizing = choked ? dpChoked : dpk;
      final kv = qh / _n1 * math.sqrt((rho / _rho0) / dpSizing);
      final flashing = p2 / 1000 < pv;
      final xFz =
          dpk /
          (p1k - pv); // pressure differential ratio vs incipient cavitation
      String regime;
      OutputLevel level;
      if (flashing) {
        regime =
            'Flashing (p₂ < p_v) — erosion risk, check trim and outlet velocity';
        level = OutputLevel.fail;
      } else if (choked) {
        regime = 'Choked — fully developed cavitation';
        level = OutputLevel.fail;
      } else if (xFz > 0.5 * fl * fl) {
        regime = 'Not choked — cavitation possible, check valve x_Fz';
        level = OutputLevel.warn;
      } else {
        regime = 'Not choked';
        level = OutputLevel.ok;
      }
      if (choked) {
        w.add(
          'Flow is choked: more ΔP will not give more flow. Sized with ΔP_max.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'cv',
            'Required Cv (US)',
            kv * kvToCv,
            level: OutputLevel.primary,
            sig: 5,
          ),
          ToolOutput('kv', 'Required Kv (m³/h, bar)', kv, sig: 5),
          ToolOutput.text('regime', 'Flow regime', regime, level: level),
          ToolOutput(
            'dp',
            'Actual ΔP',
            dpk * 1000,
            quantity: Quantity.pressureDiff,
            sig: 5,
          ),
          ToolOutput(
            'dpmax',
            'Choked ΔP limit F_L²(p₁ − F_F·p_v)',
            dpChoked * 1000,
            quantity: Quantity.pressureDiff,
            sig: 5,
          ),
          ToolOutput('ff', 'Critical pressure ratio factor F_F', ff, sig: 4),
        ],
        warnings: w,
        notes: notes,
      );
    }

    final t1 = v.n('t1') + 273.15, mw = v.n('mw'), z = v.n('z');
    final gamma = v.n('gamma'), xt = v.n('xt');
    final qn = v.n('qn') * 3600; // Nm³/h
    final fg = gamma / 1.4;
    final x = dpk / p1k;
    final xChoke = fg * xt;
    final choked = x >= xChoke;
    final xs = choked ? xChoke : x;
    final y = 1 - xs / (3 * xChoke);
    final kv = qn / (_n9 * p1k * y) * math.sqrt(mw * t1 * z / xs);
    final rho1 = p1 * mw / 1000 / (z * _rGas * t1);
    final rhoN = 101325 * mw / 1000 / (_rGas * 273.15);
    if (choked) {
      w.add(
        'Flow is choked (x ≥ F_γ·x_T): sized at the choked limit, Y = 2/3.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'cv',
          'Required Cv (US)',
          kv * kvToCv,
          level: OutputLevel.primary,
          sig: 5,
        ),
        ToolOutput('kv', 'Required Kv (m³/h, bar)', kv, sig: 5),
        ToolOutput.text(
          'regime',
          'Flow regime',
          choked ? 'Choked (sonic)' : 'Not choked',
          level: choked ? OutputLevel.warn : OutputLevel.ok,
        ),
        ToolOutput('x', 'Pressure drop ratio x = Δp/p₁', x, sig: 4),
        ToolOutput('xchoke', 'Choked limit F_γ·x_T', xChoke, sig: 4),
        ToolOutput('y', 'Expansion factor Y', y, sig: 4),
        ToolOutput(
          'w',
          'Mass flow',
          v.n('qn') * rhoN,
          quantity: Quantity.massFlow,
          sig: 5,
        ),
        ToolOutput(
          'rho1',
          'Inlet density ρ₁',
          rho1,
          quantity: Quantity.density,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''IEC 60534-2-1 (ISA-75.01.01), turbulent, F_P = 1
Kv in m³/h at 1 bar ΔP;  Cv = 1.156 · Kv

Liquid:
  F_F = 0.96 − 0.28·√(p_v / p_c)
  ΔP_max = F_L² · (p₁ − F_F·p_v)       choked if ΔP ≥ ΔP_max
  Kv = Q / N₁ · √((ρ₁/ρ₀) / ΔP_sizing)
  N₁ = 0.1 (Q m³/h, p kPa),  ρ₀ = 999.1 kg/m³ (water 15 °C)
  Flashing when p₂ < p_v

Gas / vapour:
  x = Δp / p₁,   F_γ = γ / 1.40
  choked if x ≥ F_γ·x_T  → x_sizing = F_γ·x_T
  Y = 1 − x_sizing / (3·F_γ·x_T)        (2/3 ≤ Y ≤ 1)
  Kv = Q_n / (N₉·p₁·Y) · √(M·T₁·Z / x_sizing)
  N₉ = 24.6 (Q_n m³/h at 0 °C & 101.325 kPa, p kPa, T K)''',
  references: [
    'IEC 60534-2-1:2011 Industrial-process control valves — Flow capacity — Sizing equations',
    'ANSI/ISA-75.01.01-2012 Flow equations for sizing control valves',
    'Cross-checked against the open-source "fluids" library (C. Bell), IEC 60534 model',
  ],
  assumptions: [
    'Fully turbulent flow (F_R = 1): check viscous liquids and very small valves separately.',
    'No reducers/expanders (F_P = 1, x_TP = x_T, F_LP = F_L).',
    'Cavitation hint uses 0.5·F_L² as a screening value; use the valve maker\'s x_Fz for noise/damage checks.',
  ],
  cases: [
    const ToolCase(
      'IEC 60534-2-1 Annex example: water, non-choked',
      source: 'IEC example (Kv ≈ 165) → Cv 190.73; fluids 1.3.1 agrees',
      numbers: {
        'p1': (680, 'kPa'),
        'p2': (220, 'kPa'),
        'q': (360, 'm3/h'),
        'rho': (965.4, 'kg/m3'),
        'pv': (70.1, 'kPa'),
        'pc': (22120, 'kPa'),
        'fl': (0.9, '-'),
      },
      expect: {'cv': (190.7348, '-'), 'kv': (165.0, '-')},
      relTol: 2e-4,
      expectText: {'regime': 'Not choked'},
    ),
    const ToolCase(
      'Water, choked (1000 → 100 kPa a, p_v 90 kPa)',
      source: 'fluids 1.3.1 size_control_valve_l: Cv 75.124, choked',
      numbers: {
        'p1': (1000, 'kPa'),
        'p2': (100, 'kPa'),
        'q': (180, 'm3/h'),
        'rho': (965.4, 'kg/m3'),
        'pv': (90, 'kPa'),
        'pc': (22120, 'kPa'),
        'fl': (0.9, '-'),
      },
      expect: {'cv': (75.1236, '-')},
      relTol: 2e-4,
      expectText: {'regime': 'Choked'},
      expectWarning: 'choked',
    ),
    const ToolCase(
      'CO₂ gas, non-choked (IEC example conditions)',
      source: 'fluids 1.3.1 size_control_valve_g: Cv 49.676, Y 0.67446',
      choices: {'fluid': 'gas'},
      numbers: {
        'p1': (680, 'kPa'),
        'p2': (310, 'kPa'),
        'qn': (2606.4, 'Nm3/h'),
        't1': (433, 'K'),
        'mw': (44.01, '-'),
        'z': (0.988, '-'),
        'gamma': (1.30, '-'),
        'xt': (0.60, '-'),
      },
      expect: {'cv': (49.6765, '-'), 'y': (0.674460, '-')},
      relTol: 2e-4,
    ),
    const ToolCase(
      'CO₂ gas, small ΔP',
      source: 'fluids 1.3.1: Cv 77.510, Y 0.92961',
      choices: {'fluid': 'gas'},
      numbers: {
        'p1': (680, 'kPa'),
        'p2': (600, 'kPa'),
        'qn': (2606.4, 'Nm3/h'),
        't1': (433, 'K'),
        'mw': (44.01, '-'),
        'z': (0.988, '-'),
        'gamma': (1.30, '-'),
        'xt': (0.60, '-'),
      },
      expect: {'cv': (77.5105, '-'), 'y': (0.929613, '-')},
      relTol: 2e-4,
    ),
    const ToolCase(
      'CO₂ gas, choked (10 → 2 bar a)',
      source: 'fluids 1.3.1: Cv 33.773, Y = 2/3',
      choices: {'fluid': 'gas'},
      numbers: {
        'p1': (1000, 'kPa'),
        'p2': (200, 'kPa'),
        'qn': (2606.4, 'Nm3/h'),
        't1': (433, 'K'),
        'mw': (44.01, '-'),
        'z': (0.988, '-'),
        'gamma': (1.30, '-'),
        'xt': (0.60, '-'),
      },
      expect: {'cv': (33.7730, '-'), 'y': (0.666667, '-')},
      relTol: 2e-4,
      expectText: {'regime': 'Choked'},
    ),
  ],
);
