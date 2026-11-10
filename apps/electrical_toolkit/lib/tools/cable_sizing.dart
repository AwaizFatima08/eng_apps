import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

import 'iec60364_tables.dart';

/// Group-rating factor for [n] multi-core cables/circuits touching, per the
/// IEC 60364-5-52 table that belongs to [method].
double groupFactor(String method, int n) {
  if (n <= 1) return 1;
  switch (method) {
    case 'C':
      return kGroupC[math.min(n, 9) - 1]; // no further reduction above 9
    case 'E':
      if (n > 9) {
        throw ToolInputError(
          'More than 9 cables on one tray is outside B.52.20 — split over '
          'several trays and use the multi-tray factors.',
        );
      }
      // Missing columns (5, 7, 8) take the next larger count: conservative.
      return kGroupTray.firstWhere((e) => e.$1 >= n).$2;
    default:
      if (n > 6) {
        throw ToolInputError(
          'More than 6 buried cables/ducts is outside the B.52.18/19 subset '
          'used here.',
        );
      }
      return (method == 'D1' ? kGroupDuct : kGroupBuried)[n - 2];
  }
}

final cableSizingTool = ToolDef(
  id: 'cable_sizing',
  title: 'Cable sizing & voltage drop',
  summary:
      'Smallest IEC 60364-5-52 conductor size that carries the design current '
      'after temperature, grouping and soil corrections and stays within the '
      'voltage-drop limit. Cu/Al, PVC/XLPE, methods C, E, D1, D2.',
  icon: Icons.cable,
  keywords: [
    'cable',
    'wire',
    'conductor',
    'ampacity',
    'current carrying capacity',
    'voltage drop',
    'iec 60364',
    'derating',
    'grouping',
    'tray',
    'buried',
    'mm2',
  ],
  inputs: [
    const ChoiceInput(
      'system',
      'Circuit',
      options: [
        ChoiceOption('3ph', '3-phase (3 loaded)'),
        ChoiceOption('1ph', '1-phase (2 loaded)'),
      ],
    ),
    const ChoiceInput(
      'cond',
      'Conductor',
      options: [ChoiceOption('Cu', 'Copper'), ChoiceOption('Al', 'Aluminium')],
    ),
    const ChoiceInput(
      'ins',
      'Insulation',
      initial: 'XLPE',
      options: [
        ChoiceOption('PVC', 'PVC (70 °C)'),
        ChoiceOption('XLPE', 'XLPE/EPR (90 °C)'),
      ],
    ),
    const ChoiceInput(
      'method',
      'Installation method',
      initial: 'E',
      help:
          'Multi-core cable. C: clipped direct to a wall or unperforated tray. '
          'E: in free air on a perforated tray or ladder. D1: in a duct in the '
          'ground. D2: laid directly in the ground (0.7 m).',
      options: [
        ChoiceOption('C', 'C – clipped direct'),
        ChoiceOption('E', 'E – perforated tray'),
        ChoiceOption('D1', 'D1 – duct in ground'),
        ChoiceOption('D2', 'D2 – direct buried'),
      ],
    ),
    const NumberInput(
      'ib',
      'Design current Ib',
      quantity: Quantity.currentA,
      initial: 100,
      min: 0,
      minInclusive: false,
    ),
    const NumberInput(
      'len',
      'Route length (one way)',
      quantity: Quantity.length,
      initial: 100,
      min: 0,
      minInclusive: false,
      units: ('m', 'ft'),
    ),
    NumberInput(
      'ull',
      'Line-to-line voltage',
      quantity: Quantity.voltageV,
      initial: 400,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('system') == '3ph',
    ),
    NumberInput(
      'u0',
      'Line-to-neutral voltage',
      quantity: Quantity.voltageV,
      initial: 230,
      min: 0,
      minInclusive: false,
      visibleWhen: (v) => v.c('system') == '1ph',
    ),
    const NumberInput(
      'pf',
      'Load power factor cos φ',
      quantity: Quantity.dimensionless,
      initial: 0.85,
      min: 0,
      max: 1,
      help: 'Motor starting: about 0.3–0.4.',
    ),
    const NumberInput(
      'vdmax',
      'Voltage-drop limit',
      quantity: Quantity.percent,
      initial: 0.05,
      min: 0,
      minInclusive: false,
      max: 0.25,
      help:
          'IEC 60364-5-52 Annex G: from a private LV supply 6 % lighting / 8 % '
          'other; from a public LV supply 3 % / 5 %. Many plants use 5 % '
          'running, 15 % at motor start.',
    ),
    NumberInput(
      'tair',
      'Ambient air temperature',
      quantity: Quantity.temperature,
      initial: 40,
      min: 10,
      help: 'Table B.52.14: 10–60 °C (PVC), 10–80 °C (XLPE).',
      visibleWhen: (v) => v.c('method') == 'C' || v.c('method') == 'E',
    ),
    NumberInput(
      'tground',
      'Ground temperature',
      quantity: Quantity.temperature,
      initial: 30,
      min: 10,
      help: 'At laying depth. Table B.52.15 base is 20 °C.',
      visibleWhen: (v) => v.c('method') == 'D1' || v.c('method') == 'D2',
    ),
    NumberInput(
      'soil',
      'Soil thermal resistivity',
      quantity: Quantity.dimensionless,
      unitSuffix: 'K·m/W',
      initial: 2.5,
      min: 0.5,
      max: 3,
      help:
          'Table B.52.16, 0.5–3 K·m/W; 2.5 is the IEC base (dry soil). Moist '
          'clay ≈ 1, sand ≈ 1.5–3.',
      visibleWhen: (v) => v.c('method') == 'D1' || v.c('method') == 'D2',
    ),
    const NumberInput(
      'group',
      'Circuits grouped (incl. this)',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 1,
      max: 50,
      help:
          'Touching multi-core cables in the same run. C: B.52.17 item 2; '
          'E: B.52.20 (one tray, ≤ 9); D1: B.52.19; D2: B.52.18 (≤ 6). '
          'Count each parallel cable.',
    ),
    const NumberInput(
      'npar',
      'Parallel cables per phase',
      quantity: Quantity.dimensionless,
      initial: 1,
      min: 1,
      max: 8,
    ),
    const NumberInput(
      'x',
      'Cable reactance X',
      quantity: Quantity.resistance,
      unitSuffix: '/km',
      initial: 0.08,
      min: 0,
      units: ('ohm', 'ohm'),
      help: 'Typical multi-core LV cable 0.07–0.09 Ω/km (EIG uses 0.08).',
    ),
  ],
  compute: (v) {
    final threePh = v.c('system') == '3ph';
    final cond = v.c('cond'), ins = v.c('ins'), method = v.c('method');
    final ground = method == 'D1' || method == 'D2';
    final ib = v.n('ib'), len = v.n('len'), pf = v.n('pf');
    final u = threePh ? v.n('ull') : v.n('u0');
    final groupRaw = v.n('group'), nparRaw = v.n('npar');
    if (groupRaw != groupRaw.roundToDouble() ||
        nparRaw != nparRaw.roundToDouble()) {
      throw ToolInputError('Circuit and cable counts must be whole numbers.');
    }
    final group = groupRaw.round(), npar = nparRaw.round();
    if (npar > 1 && group < npar) {
      throw ToolInputError(
        'Parallel cables are grouped with each other: circuits grouped must '
        'be at least the number of parallel cables.',
      );
    }

    // Correction factors.
    final t = ground ? v.n('tground') : v.n('tair');
    final kt = interpTable(ground ? kGroundTemp[ins]! : kAirTemp[ins]!, t);
    if (kt == null) {
      throw ToolInputError(
        '${formatNumber(t)} °C is above the IEC table for $ins '
        '(max ${ins == 'PVC' ? 60 : 80} °C).',
      );
    }
    final ks = ground
        ? interpTable(method == 'D1' ? kSoilDuct : kSoilDirect, v.n('soil'))!
        : 1.0;
    final kg = groupFactor(method, group);
    final k = kt * ks * kg;

    final loaded = threePh ? 3 : 2;
    final amp = iecAmpacity['$ins/$cond/$loaded/$method']!;
    final r20 = cond == 'Cu' ? r20Cu : r20Al;
    final alpha = cond == 'Cu' ? alphaCu : alphaAl;
    final thetaMax = ins == 'PVC' ? 70.0 : 90.0;
    final rFactor = 1 + alpha * (thetaMax - 20);
    final sinPhi = math.sqrt(1 - pf * pf);
    final xKm = v.n('x');
    final ibCable = ib / npar;

    // Voltage drop of one size: b·I·L·(R cos φ + X sin φ), Ω/km × km.
    double vdOf(int i) {
      final rKm = r20[i]! * rFactor;
      final b = threePh ? math.sqrt(3) : 2.0;
      return b * ibCable * (len / 1000) * (rKm * pf + xKm * sinPhi);
    }

    int? iAmp, iVd;
    for (var i = 0; i < cableSizes.length; i++) {
      if (amp[i] == null || r20[i] == null) continue;
      iAmp ??= amp[i]! * k >= ibCable - 1e-9 ? i : null;
      iVd ??= vdOf(i) / u <= v.n('vdmax') + 1e-12 ? i : null;
    }
    if (iAmp == null || iVd == null) {
      throw ToolInputError(
        'No single size up to 300 mm² meets ${iAmp == null ? 'the current' : 'the voltage-drop limit'}'
        ' — increase the parallel cables per phase.',
      );
    }
    final i = math.max(iAmp, iVd);
    final governs = iAmp == iVd
        ? 'Both current and voltage drop'
        : iAmp > iVd
        ? 'Current-carrying capacity'
        : 'Voltage drop';
    final vd = vdOf(i);

    final w = <String>[];
    final notes = <String>[
      'Check the protective device: Ib ≤ In ≤ Iz (IEC 60364-4-43 §433.1), and '
          'short-circuit and earth-fault withstand — not checked here.',
      'Resistance taken at the maximum conductor temperature '
          '(${formatNumber(thetaMax)} °C): voltage drop is slightly conservative.',
    ];
    if (cableSizes[i] >= 185) {
      notes.add(
        'At ≥ 185 mm² skin effect raises AC resistance by a few per cent (not '
        'included); confirm voltage drop with the maker\'s mV/A/m data.',
      );
    }
    if (method == 'E' && group > 1 && const [5, 7, 8].contains(group)) {
      notes.add(
        'B.52.20 has no column for $group cables: the next larger count was used.',
      );
    }
    if (method == 'C' && group > 9) {
      notes.add('B.52.17: no further reduction beyond nine circuits.');
    }
    if (pf < 0.5) {
      w.add(
        'cos φ < 0.5 — fine for a start-up check, unusual for running load.',
      );
    }
    if (npar > 1 && cableSizes[i] < 50) {
      w.add('Parallel cables below 50 mm² are not good practice.');
    }
    return ToolResult(
      [
        ToolOutput(
          'size',
          'Recommended size',
          cableSizes[i] * 1e-6,
          quantity: Quantity.area,
          units: ('mm2', 'mm2'),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput.text('governs', 'Governed by', governs),
        ToolOutput(
          'iz0',
          'Tabulated Iz₀ (per cable)',
          amp[i]!,
          quantity: Quantity.currentA,
          sig: 4,
        ),
        ToolOutput('k', 'Total correction k', k, sig: 4),
        ToolOutput(
          'iz',
          'Corrected Iz (all cables)',
          amp[i]! * k * npar,
          quantity: Quantity.currentA,
          level: OutputLevel.ok,
          sig: 4,
        ),
        ToolOutput(
          'vd',
          'Voltage drop',
          vd,
          quantity: Quantity.voltageV,
          sig: 4,
        ),
        ToolOutput(
          'vdpct',
          'Voltage drop %',
          vd / u,
          quantity: Quantity.percent,
          level: OutputLevel.ok,
          sig: 3,
        ),
        ToolOutput(
          'sizeAmp',
          'Min size for current',
          cableSizes[iAmp] * 1e-6,
          quantity: Quantity.area,
          units: ('mm2', 'mm2'),
          sig: 4,
        ),
        ToolOutput(
          'sizeVd',
          'Min size for volt drop',
          cableSizes[iVd] * 1e-6,
          quantity: Quantity.area,
          units: ('mm2', 'mm2'),
          sig: 4,
        ),
        ToolOutput('kt', 'Temperature factor', kt, sig: 3),
        ToolOutput('kg', 'Grouping factor', kg, sig: 3),
        if (ground) ToolOutput('ks', 'Soil factor', ks, sig: 3),
        ToolOutput(
          'r',
          'R at ${formatNumber(thetaMax)} °C, Ω/km',
          r20[i]! * rFactor,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''Current-carrying capacity (IEC 60364-5-52 Annex B):
  Iz = Iz₀ · kθ · kg · kρ  ≥  Ib / n      (n = parallel cables)
  Iz₀  Tables B.52.2–B.52.5 (C, D1, D2), B.52.10–B.52.13 (E)
  kθ   B.52.14 (air, base 30 °C) / B.52.15 (ground, base 20 °C)
  kg   B.52.17 item 2 (C), B.52.20 (E), B.52.19 (D1), B.52.18 (D2)
  kρ   B.52.16 (soil, base 2.5 K·m/W; D1 and D2 rows differ)
  Between table points kθ and kρ are interpolated linearly.

Voltage drop (IEC 60364-5-52 Annex G):
  3-phase:  ΔU = √3 · I · L · (R cos φ + X sin φ)   (% of U line-line)
  1-phase:  ΔU =  2 · I · L · (R cos φ + X sin φ)   (% of U₀)
  I = Ib / n,  L = route length
  R = R₂₀ · [1 + α₂₀ · (θmax − 20)]
  R₂₀ from IEC 60228 class 2;  α₂₀ = 0.00393 Cu, 0.00403 Al /K
  θmax = 70 °C PVC, 90 °C XLPE

Recommended size = larger of the two smallest standard
sizes meeting Iz and the ΔU limit.''',
  references: [
    'IEC 60364-5-52:2009, Annex B Tables B.52.2–B.52.5, B.52.10–B.52.20; Annex G (voltage drop)',
    'IEC 60228:2004, Table 2 (class 2 conductor resistance at 20 °C)',
    'IEC 60287-1-1, Table 1 (temperature coefficients α₂₀)',
    'Schneider Electric, Electrical Installation Guide, ch. G (cable sizing, ΔU formula, X ≈ 0.08 Ω/km)',
  ],
  assumptions: [
    'Multi-core cables (or twin for 1-phase), one circuit per cable, balanced load, no harmonics: triplen currents in the neutral need B.52 Annex E reduction factors.',
    'Grouped cables touching and similarly loaded; spaced cables carry more.',
    'Values from the 2009 edition; the 2024 amendment (AMD1) has not been checked.',
  ],
  cases: [
    const ToolCase(
      'Cu PVC, method C, 30 °C, 80 A, 20 m',
      source:
          'IEC 60364-5-52 Table B.52.4 col. C: 16 mm² = 76 A < 80 A, 25 mm² = '
          '96 A. ΔU by independent script (IEC 60228 R at 70 °C, X 0.08): '
          '2.166 V',
      choices: {'cond': 'Cu', 'ins': 'PVC', 'method': 'C'},
      numbers: {
        'ib': (80, 'A'),
        'len': (20, 'm'),
        'ull': (400, 'V'),
        'pf': (0.85, '-'),
        'tair': (30, 'C'),
      },
      expect: {'size': (25, 'mm2'), 'iz': (96, 'A'), 'vd': (2.16581, 'V')},
      expectText: {'governs': 'Current'},
    ),
    const ToolCase(
      'Cu PVC, method C, 40 °C, 3 circuits, 100 A',
      source:
          'B.52.14 PVC 40 °C = 0.87; B.52.17 item 2, 3 circuits = 0.79; '
          'Iz₀ needed 145.5 A → B.52.4 col. C 70 mm² (184 A); Iz = 126.46 A',
      choices: {'cond': 'Cu', 'ins': 'PVC', 'method': 'C'},
      numbers: {
        'ib': (100, 'A'),
        'len': (30, 'm'),
        'tair': (40, 'C'),
        'group': (3, '-'),
      },
      expect: {'size': (70, 'mm2'), 'k': (0.6873, '-'), 'iz': (126.4632, 'A')},
    ),
    const ToolCase(
      'Cu XLPE, tray (E), 50 A, 300 m — voltage drop governs',
      source:
          'Independent script: current alone needs 10 mm² (B.52.12, 75 A × '
          '0.91 = 68.25 A, ΔU 13.2 %); ΔU ≤ 5 % first met at 35 mm² '
          '(15.850 V = 3.963 %)',
      numbers: {
        'ib': (50, 'A'),
        'len': (300, 'm'),
        'ull': (400, 'V'),
        'pf': (0.85, '-'),
        'tair': (40, 'C'),
      },
      expect: {
        'size': (35, 'mm2'),
        'sizeAmp': (10, 'mm2'),
        'vd': (15.85014, 'V'),
        'vdpct': (3.96253, '%'),
      },
      expectText: {'governs': 'Voltage drop'},
    ),
    const ToolCase(
      'Al XLPE, direct buried, ground 30 °C, ρ 1.5, 2 circuits, 200 A',
      source:
          'B.52.15 XLPE 30 °C = 0.93; B.52.16 direct 1.5 K·m/W = 1.28; '
          'B.52.18 2 touching = 0.75 → k = 0.8928; B.52.5 Al D2: 150 mm² '
          '(220 A → 196.4 A) fails, 185 mm² = 250 A → Iz 223.2 A',
      choices: {'cond': 'Al', 'method': 'D2'},
      numbers: {
        'ib': (200, 'A'),
        'len': (50, 'm'),
        'tground': (30, 'C'),
        'soil': (1.5, '-'),
        'group': (2, '-'),
      },
      expect: {'size': (185, 'mm2'), 'k': (0.8928, '-'), 'iz': (223.2, 'A')},
    ),
    const ToolCase(
      '1-phase Cu PVC twin, method C, 32 A, 40 m, 230 V',
      source:
          'B.52.2 col. C 4 mm² = 36 A ≥ 32 A; independent script ΔU: 4 mm² '
          '13.48 V (5.86 %) fails 5 %, 6 mm² 9.026 V (3.92 %)',
      choices: {'system': '1ph', 'cond': 'Cu', 'ins': 'PVC', 'method': 'C'},
      numbers: {
        'ib': (32, 'A'),
        'len': (40, 'm'),
        'u0': (230, 'V'),
        'pf': (0.95, '-'),
        'tair': (30, 'C'),
      },
      expect: {'size': (6, 'mm2'), 'sizeAmp': (4, 'mm2'), 'vd': (9.02640, 'V')},
    ),
    const ToolCase(
      'Cu XLPE in ground ducts, 2 parallel cables, 500 A',
      source:
          'B.52.19 2 ducts = 0.85; B.52.15 XLPE 30 °C = 0.93 → k = 0.7905; '
          '250 A per cable → Iz₀ ≥ 316.3 A → B.52.5 D1 240 mm² (324 A); '
          'Iz = 2 × 256.12 = 512.24 A',
      choices: {'method': 'D1'},
      numbers: {
        'ib': (500, 'A'),
        'len': (100, 'm'),
        'tground': (30, 'C'),
        'soil': (2.5, '-'),
        'group': (2, '-'),
        'npar': (2, '-'),
      },
      expect: {'size': (240, 'mm2'), 'k': (0.7905, '-'), 'iz': (512.244, 'A')},
    ),
  ],
);
