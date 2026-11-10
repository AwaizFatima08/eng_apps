import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final pumpTool = ToolDef(
  id: 'pump',
  title: 'Pump head, NPSHa & power',
  summary:
      'Centrifugal pump: differential head ⇄ pressure, hydraulic and shaft '
      'power, and NPSH available with margin against NPSHr.',
  icon: Icons.settings_input_component,
  keywords: [
    'pump',
    'head',
    'npsh',
    'npsha',
    'npshr',
    'cavitation',
    'suction',
    'power',
    'kw',
    'efficiency',
    'motor',
    'hydraulic institute',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculate',
      options: [
        ChoiceOption('dp2h', 'Head from ΔP'),
        ChoiceOption('h2dp', 'ΔP from head'),
      ],
    ),
    NumberInput(
      'dp',
      'Pump differential pressure',
      quantity: Quantity.pressureDiff,
      units: ('bar', 'psi'),
      initial: 5e5,
      min: 0,
      minInclusive: false,
      help: 'Discharge minus suction pressure at the pump flanges.',
      visibleWhen: (v) => v.c('mode') == 'dp2h',
    ),
    NumberInput(
      'h',
      'Pump differential head',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 50,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('mode') == 'h2dp',
    ),
    const NumberInput(
      'q',
      'Flow (at pumping temperature)',
      quantity: Quantity.volumeFlow,
      initial: 100 / 3600,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'rho',
      'Liquid density ρ',
      quantity: Quantity.density,
      initial: 998.2,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'eta',
      'Pump efficiency η',
      quantity: Quantity.percent,
      initial: 0.75,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'From the pump curve at the duty point.',
    ),
    const NumberInput(
      'etam',
      'Motor efficiency',
      quantity: Quantity.percent,
      initial: 0.95,
      min: 0,
      max: 1,
      minInclusive: false,
      help: 'IE3 motors ≈ 93–96 % above 30 kW.',
    ),
    const NumberInput(
      'ps',
      'Pressure on suction liquid surface',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 101325,
      min: 0,
      help:
          'Open tank: local atmospheric pressure. Closed vessel: vessel pressure (absolute).',
    ),
    const NumberInput(
      'pv',
      'Vapour pressure at pumping T',
      quantity: Quantity.pressure,
      unitSuffix: 'abs',
      initial: 2339,
      min: 0,
      help:
          'Water: 20 °C 0.0234 bar, 60 °C 0.199 bar, 100 °C 1.013 bar. Boiling liquid: equal to the vessel pressure.',
    ),
    const NumberInput(
      'z',
      'Liquid level above pump centreline',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 2,
      help:
          'Negative for a suction lift (level below the pump). Use the lowest operating level.',
    ),
    const NumberInput(
      'hf',
      'Suction line friction loss',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 0.5,
      min: 0,
      help:
          'Head loss from the vessel to the pump suction flange (pipes, strainer, valves), in metres of liquid.',
    ),
    const NumberInput(
      'npshr',
      'NPSHr (NPSH3) from the pump curve',
      quantity: Quantity.length,
      units: ('m', 'ft'),
      initial: 3,
      min: 0,
      help: 'Enter 0 to skip the margin check.',
    ),
  ],
  compute: (v) {
    final q = v.n('q'), rho = v.n('rho');
    final rg = rho * gStd;
    final h2dp = v.c('mode') == 'h2dp';
    final h = h2dp ? v.n('h') : v.n('dp') / rg;
    final dp = h * rg;
    final ph = rg * q * h;
    final shaft = ph / v.n('eta');
    final motor = shaft / v.n('etam');
    final ps = v.n('ps'), pv = v.n('pv');
    final npsha = (ps - pv) / rg + v.n('z') - v.n('hf');
    final npshr = v.n('npshr');
    final w = <String>[];
    if (pv > ps) {
      w.add(
        'Vapour pressure above the surface pressure: the liquid would flash.',
      );
    }
    if (npsha <= 0) {
      w.add('NPSHa ≤ 0: the liquid boils at the pump suction.');
    }
    final out = <ToolOutput>[
      ToolOutput(
        'h',
        'Differential head',
        h,
        quantity: Quantity.length,
        units: ('m', 'ft'),
        sig: 5,
        level: h2dp ? OutputLevel.normal : OutputLevel.primary,
      ),
      ToolOutput(
        'dp',
        'Differential pressure',
        dp,
        quantity: Quantity.pressureDiff,
        units: ('bar', 'psi'),
        sig: 5,
        level: h2dp ? OutputLevel.primary : OutputLevel.normal,
      ),
      ToolOutput('ph', 'Hydraulic power', ph, quantity: Quantity.power, sig: 5),
      ToolOutput(
        'shaft',
        'Shaft power',
        shaft,
        quantity: Quantity.power,
        sig: 5,
        level: OutputLevel.primary,
      ),
      ToolOutput(
        'motor',
        'Motor input power',
        motor,
        quantity: Quantity.power,
        sig: 5,
      ),
      ToolOutput(
        'npsha',
        'NPSH available',
        npsha,
        quantity: Quantity.length,
        units: ('m', 'ft'),
        sig: 5,
        level: OutputLevel.primary,
      ),
    ];
    if (npshr > 0) {
      final margin = npsha - npshr;
      final ratio = npsha / npshr;
      final OutputLevel lv;
      if (margin <= 0) {
        lv = OutputLevel.fail;
        w.add('NPSHa ≤ NPSHr: the pump will cavitate (≥ 3 % head drop).');
      } else if (ratio < 1.1) {
        lv = OutputLevel.warn;
        w.add(
          'NPSHa/NPSHr below 1.1, the minimum margin ratio in ANSI/HI 9.6.1. '
          'Many services need 1.3–2.0+: check with the pump vendor.',
        );
      } else {
        lv = OutputLevel.ok;
      }
      out.addAll([
        ToolOutput(
          'margin',
          'NPSH margin (NPSHa − NPSHr)',
          margin,
          quantity: Quantity.length,
          units: ('m', 'ft'),
          sig: 4,
          level: lv,
        ),
        ToolOutput('ratio', 'NPSH margin ratio', ratio, sig: 3, level: lv),
      ]);
    }
    return ToolResult(
      out,
      warnings: w,
      notes: [
        'Head ⇄ pressure uses g = 9.80665 m/s² and the density at pumping temperature.',
      ],
    );
  },
  formula: '''Head ⇄ pressure:
  H = ΔP / (ρ·g)          ΔP = ρ·g·H

Power:
  Hydraulic  P_h = ρ·g·Q·H  ( = Q·ΔP )
  Shaft      P_s = P_h / η
  Motor      P_m = P_s / η_motor

NPSH available (from the suction-vessel surface):
  NPSHa = (p_surface,abs − p_vap)/(ρ·g) + z − h_f,s
  z    = liquid level above pump centreline (− for lift)
  h_f,s = suction line friction loss (m of liquid)

Margin:
  NPSHa − NPSHr,  ratio NPSHa / NPSHr
  ANSI/HI 9.6.1: ratio ≥ 1.1 minimum; 1.3–2.0+ by service''',
  references: [
    'ANSI/HI 1.3 Rotodynamic centrifugal pumps — design and application (head, power, NPSH definitions)',
    'ANSI/HI 9.6.1 Rotodynamic pumps — guideline for NPSH margin (NPSHA/NPSH3 ratios)',
    'API 610 / ISO 13709 §6.1 (NPSH3 basis of NPSHR, datum at impeller centreline)',
    'Perry\'s Chemical Engineers\' Handbook, 9th ed., §10 (pump head, NPSH and power)',
  ],
  assumptions: [
    'Incompressible liquid; density at pumping temperature.',
    'Velocity head in the suction vessel neglected (stagnant surface); velocity heads at the flanges included only through the entered ΔP.',
    'For horizontal pumps the datum is the shaft centreline; vertical pumps use the first-stage impeller eye (API 610).',
  ],
  cases: [
    const ToolCase(
      'Duty point: ΔP 5 bar, 100 m³/h water, η 75 %, motor 95 %',
      source:
          'Hand calculation (ref_pump.py): H = ΔP/(ρg) = 51.0778 m; '
          'P_h = Q·ΔP = 13.8889 kW exactly; shaft 18.5185 kW; motor 19.4932 kW',
      numbers: {
        'dp': (5, 'bar'),
        'q': (100, 'm3/h'),
        'rho': (998.2, 'kg/m3'),
        'eta': (75, '%'),
        'etam': (95, '%'),
      },
      expect: {
        'h': (51.07775059997637, 'm'),
        'ph': (13.888888888888889, 'kW'),
        'shaft': (18.51851851851852, 'kW'),
        'motor': (19.49317738791423, 'kW'),
      },
      relTol: 1e-9,
    ),
    const ToolCase(
      'Head 100 m → ΔP, SG 0.85, 50 m³/h, η 70 %',
      source:
          'Hand calculation: ΔP = 850 × 9.80665 × 100 = 833 565.25 Pa; '
          'P_h = 11.5773 kW; shaft 16.5390 kW',
      choices: {'mode': 'h2dp'},
      numbers: {
        'h': (100, 'm'),
        'q': (50, 'm3/h'),
        'rho': (850, 'kg/m3'),
        'eta': (70, '%'),
      },
      expect: {'dp': (833565.25, 'Pa'), 'shaft': (16538.993055555555, 'W')},
      relTol: 1e-9,
    ),
    const ToolCase(
      'NPSHa, 10 ft suction lift, water 68 °F, open tank',
      source:
          'Pumps & Systems, "Calculate NPSHa for a suction lift condition", '
          'Example 2: 34 − 0.78 − 10 − 3.2 ≈ 20 ft (19.974 ft with the '
          'article\'s 2.31 ft/psi; differs from exact ρg by 0.06 %)',
      numbers: {
        'ps': (14.7, 'psi'),
        'pv': (0.33889, 'psi'),
        'rho': (62.32, 'lb/ft3'),
        'z': (-10, 'ft'),
        'hf': (3.2, 'ft'),
        'npshr': (0, 'm'),
      },
      expect: {'npsha': (19.9742, 'ft')},
      relTol: 1e-3,
    ),
    const ToolCase(
      'NPSHa, 10 ft flooded suction (same tank)',
      source:
          'Pumps & Systems NPSHa article, Example 1: ≈ 40 ft '
          '(39.974 ft with 2.31 ft/psi)',
      numbers: {
        'ps': (14.7, 'psi'),
        'pv': (0.33889, 'psi'),
        'rho': (62.32, 'lb/ft3'),
        'z': (10, 'ft'),
        'hf': (3.2, 'ft'),
        'npshr': (0, 'm'),
      },
      expect: {'npsha': (39.9742, 'ft')},
      relTol: 1e-3,
    ),
    const ToolCase(
      'Boiling liquid in a drum: NPSHa = z − h_f < NPSHr',
      source:
          'Hand calculation: p_surface = p_vap, so NPSHa = 3 − 0.5 = 2.5 m; '
          'margin −0.5 m → cavitation',
      numbers: {
        'ps': (5, 'bar'),
        'pv': (5, 'bar'),
        'z': (3, 'm'),
        'hf': (0.5, 'm'),
        'npshr': (3, 'm'),
      },
      expect: {
        'npsha': (2.5, 'm'),
        'margin': (-0.5, 'm'),
        'ratio': (0.8333333333333334, '-'),
      },
      relTol: 1e-9,
      expectWarning: 'cavitate',
    ),
  ],
);
