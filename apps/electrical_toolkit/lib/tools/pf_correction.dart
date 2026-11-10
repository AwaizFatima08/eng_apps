import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final pfCorrectionTool = ToolDef(
  id: 'pf_correction',
  title: 'Power-factor correction',
  summary:
      'Capacitor kvar to raise the power factor of a 3-phase load, the '
      'capacitance per phase for star and delta banks, and the reduction in '
      'line current and I²R losses.',
  icon: Icons.battery_charging_full,
  keywords: [
    'power factor',
    'pfc',
    'capacitor',
    'kvar',
    'capacitor bank',
    'reactive',
    'tan phi',
    'apfc',
  ],
  inputs: [
    const NumberInput(
      'p',
      'Real power P',
      quantity: Quantity.power,
      initial: 500e3,
      min: 0,
      minInclusive: false,
      units: ('kW', 'kW'),
    ),
    const NumberInput(
      'pf1',
      'Existing power factor',
      quantity: Quantity.dimensionless,
      initial: 0.75,
      min: 0.1,
      max: 1,
      minInclusive: false,
      help: 'Lagging (inductive) load.',
    ),
    const NumberInput(
      'pf2',
      'Target power factor',
      quantity: Quantity.dimensionless,
      initial: 0.95,
      min: 0.1,
      max: 1,
      help: 'Lagging. DISCO tariffs penalise below 0.90 (check NEPRA terms).',
    ),
    const NumberInput(
      'v',
      'Line-to-line voltage',
      quantity: Quantity.voltageV,
      initial: 400,
      min: 0,
      minInclusive: false,
      help:
          'Voltage at the bank. Capacitor units are usually rated higher '
          '(e.g. 440–480 V on a 400 V system, or more with detuning reactors).',
    ),
    const NumberInput(
      'f',
      'Frequency',
      quantity: Quantity.frequency,
      initial: 50,
      min: 1,
    ),
  ],
  compute: (v) {
    final p = v.n('p'), pf1 = v.n('pf1'), pf2 = v.n('pf2');
    final u = v.n('v'), f = v.n('f');
    if (pf2 <= pf1) {
      throw ToolInputError(
        'Target power factor must be above the existing one.',
      );
    }
    final t1 = math.tan(math.acos(pf1)), t2 = math.tan(math.acos(pf2));
    final qc = p * (t1 - t2);
    final w = 2 * math.pi * f;
    final cDelta = qc / (3 * w * u * u);
    final cStar = qc / (w * u * u);
    final r3 = math.sqrt(3);
    final i1 = p / (r3 * u * pf1), i2 = p / (r3 * u * pf2);
    final warn = <String>[];
    if (pf2 > 0.98) {
      warn.add(
        'Target above 0.98: risk of leading power factor at light load — use '
        'an automatic (stepped) bank.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'qc',
          'Capacitor rating Qc',
          qc,
          quantity: Quantity.reactivePower,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput('k', 'kvar per kW (tanφ₁ − tanφ₂)', t1 - t2, sig: 4),
        ToolOutput(
          'cdelta',
          'Delta bank: C per phase',
          cDelta,
          quantity: Quantity.capacitance,
          sig: 4,
        ),
        ToolOutput(
          'cstar',
          'Star bank: C per phase',
          cStar,
          quantity: Quantity.capacitance,
          sig: 4,
        ),
        ToolOutput(
          'ic',
          'Bank line current',
          qc / (r3 * u),
          quantity: Quantity.currentA,
          sig: 4,
        ),
        ToolOutput(
          'i1',
          'Line current before',
          i1,
          quantity: Quantity.currentA,
          sig: 4,
        ),
        ToolOutput(
          'i2',
          'Line current after',
          i2,
          quantity: Quantity.currentA,
          level: OutputLevel.ok,
          sig: 4,
        ),
        ToolOutput(
          'red',
          'Current reduction',
          1 - i2 / i1,
          quantity: Quantity.percent,
          sig: 3,
        ),
        ToolOutput(
          'loss',
          'I²R loss reduction',
          1 - (pf1 / pf2) * (pf1 / pf2),
          quantity: Quantity.percent,
          sig: 3,
        ),
        ToolOutput(
          's2',
          'Apparent power after',
          p / pf2,
          quantity: Quantity.apparentPower,
          sig: 4,
        ),
      ],
      warnings: warn,
      notes: [
        'Capacitor kvar is quoted at its rated voltage: Q scales with (U/Urated)². '
            'A 440 V unit on 400 V gives (400/440)² = 83 % of its rating.',
        'With drives or other harmonic loads use a detuned bank (e.g. 7 % or '
            '14 % reactor) and check for resonance (IEC 61921, IEC 60831-1).',
      ],
    );
  },
  formula: '''Qc = P · (tan φ₁ − tan φ₂),   φ = acos(cos φ)

Capacitance per phase (U = line voltage, ω = 2πf):
  Delta bank:  C = Qc / (3 · ω · U²)
  Star bank:   C = Qc / (ω · U²)      (= 3 × the delta value)
Bank current   Ic = Qc / (√3 · U)

Line current   I = P / (√3 · U · cos φ)
Current after / before = cos φ₁ / cos φ₂
I²R loss after / before = (cos φ₁ / cos φ₂)²''',
  references: [
    'Schneider Electric, Electrical Installation Guide, ch. L (power factor correction: Qc = P(tanφ − tanφ′), kvar/kW table)',
    'IEC 60831-1 (shunt power capacitors for a.c. systems ≤ 1 kV); IEC 61921 (PFC banks)',
    'Eskom, Power Factor Sizing Guide (kvar/kW multiplier table)',
  ],
  assumptions: [
    'Balanced 3-phase load at constant real power; sinusoidal supply.',
    'Bank rated at the stated voltage and frequency.',
  ],
  cases: [
    const ToolCase(
      '500 kW from 0.75 to 0.95 at 400 V',
      source:
          'Eskom multiplier table: 0.75 → 0.95 = 0.553 kvar/kW → 276.5 kvar; '
          'hand calc 276.62 kvar, C Δ = 1834.4 µF, I 962.25 → 759.67 A',
      numbers: {
        'p': (500, 'kW'),
        'pf1': (0.75, '-'),
        'pf2': (0.95, '-'),
        'v': (400, 'V'),
      },
      expect: {
        'qc': (276.6165, 'kvar'),
        'k': (0.553, '-'),
        'cdelta': (1834.37, 'uF'),
        'cstar': (5503.11, 'uF'),
        'i1': (962.250, 'A'),
        'i2': (759.671, 'A'),
      },
      relTol: 1e-3,
    ),
    const ToolCase(
      'Multiplier 0.75 → 0.93',
      source: 'Eskom multiplier table (and EIG ch. L table): 0.487 kvar/kW',
      numbers: {'p': (100, 'kW'), 'pf1': (0.75, '-'), 'pf2': (0.93, '-')},
      expect: {'k': (0.487, '-'), 'qc': (48.7, 'kvar')},
      relTol: 1.5e-3,
    ),
    const ToolCase(
      '200 kW from 0.70 to 0.98 at 415 V',
      source:
          'Hand calc: Qc = 163.43 kvar; C Δ = 1006.84 µF; current −28.57 %; '
          'loss −48.98 %',
      numbers: {
        'p': (200, 'kW'),
        'pf1': (0.7, '-'),
        'pf2': (0.98, '-'),
        'v': (415, 'V'),
      },
      expect: {
        'qc': (163.4291, 'kvar'),
        'cdelta': (1006.844, 'uF'),
        'red': (28.5714, '%'),
        'loss': (48.9796, '%'),
      },
    ),
    const ToolCase(
      '11 kV, 1 MW from 0.80 to 0.95',
      source:
          'Hand calc: Qc = 421.32 kvar; star C = 11.083 µF; I 65.61 → 55.25 A',
      numbers: {
        'p': (1000, 'kW'),
        'pf1': (0.8, '-'),
        'pf2': (0.95, '-'),
        'v': (11, 'kV'),
      },
      expect: {
        'qc': (421.3159, 'kvar'),
        'cstar': (11.0834, 'uF'),
        'i2': (55.2488, 'A'),
      },
    ),
  ],
);
