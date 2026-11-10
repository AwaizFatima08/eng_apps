import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// Peak sun hours (kWh/m²/day on the optimally tilted plane) from the World
/// Bank Global Solar Atlas v2 (Solargis long-term average, fetched 10 Nov
/// 2026): (annual mean, lowest month, tilt °, lowest month name).
const Map<String, (double, double, int, String)> pakistanPsh = {
  'khi': (5.94, 4.34, 27, 'Aug'),
  'hyd': (6.21, 5.35, 26, 'Jul'),
  'lhr': (5.08, 3.54, 28, 'Jan'),
  'fsd': (5.21, 3.63, 28, 'Jan'),
  'mux': (5.65, 4.01, 28, 'Jan'),
  'isb': (5.38, 3.89, 30, 'Jan'),
  'pew': (5.20, 3.77, 30, 'Jan'),
  'uet': (6.77, 5.58, 32, 'Jan'),
};

/// Battery presets: (usable depth of discharge, round-trip efficiency).
const Map<String, (double, double)> batteryPresets = {
  'lfp': (0.80, 0.95),
  'pb': (0.50, 0.80),
};

final solarSizerTool = ToolDef(
  id: 'solar_sizer',
  title: 'Solar array & battery sizer',
  summary:
      'Number of PV panels for a daily energy need, battery bank Ah for the '
      'autonomy days (lithium or lead-acid presets) and inverter size, with '
      'Global Solar Atlas sun hours for Pakistani cities.',
  icon: Icons.solar_power,
  keywords: [
    'solar',
    'pv',
    'panel',
    'array',
    'battery',
    'lifepo4',
    'lithium',
    'lead acid',
    'inverter',
    'off grid',
    'hybrid',
    'peak sun hours',
    'psh',
    'pakistan',
  ],
  inputs: [
    const NumberInput(
      'e',
      'Daily load energy',
      quantity: Quantity.energy,
      initial: 10 * 3.6e6,
      min: 0,
      minInclusive: false,
      units: ('kWh', 'kWh'),
      help: 'Sum of (power × hours) of every load per day, at the AC side.',
    ),
    const ChoiceInput(
      'site',
      'Site (sun hours)',
      initial: 'lhr',
      options: [
        ChoiceOption('khi', 'Karachi'),
        ChoiceOption('hyd', 'Hyderabad'),
        ChoiceOption('lhr', 'Lahore'),
        ChoiceOption('fsd', 'Faisalabad'),
        ChoiceOption('mux', 'Multan'),
        ChoiceOption('isb', 'Islamabad'),
        ChoiceOption('pew', 'Peshawar'),
        ChoiceOption('uet', 'Quetta'),
        ChoiceOption('custom', 'Enter value'),
      ],
    ),
    ChoiceInput(
      'basis',
      'Design month',
      options: const [
        ChoiceOption('worst', 'Worst month'),
        ChoiceOption('annual', 'Annual average'),
      ],
      help: 'Off-grid: worst month. Grid-tied/net metering: annual average.',
      visibleWhen: (v) => v.c('site') != 'custom',
    ),
    NumberInput(
      'psh',
      'Peak sun hours',
      quantity: Quantity.dimensionless,
      unitSuffix: 'h/day',
      initial: 5,
      min: 0.5,
      max: 10,
      help: 'kWh/m²/day on the array plane (Global Solar Atlas GTI, PVGIS).',
      visibleWhen: (v) => v.c('site') == 'custom',
    ),
    const NumberInput(
      'wp',
      'Panel rating',
      quantity: Quantity.power,
      initial: 550,
      min: 1,
      units: ('W', 'W'),
      unitSuffix: 'p',
    ),
    const NumberInput(
      'kpv',
      'PV derate factor',
      quantity: Quantity.percent,
      initial: 0.77,
      min: 0.3,
      max: 1,
      help:
          'Share of nameplate Wp delivered at the PV output: PVWatts default '
          '14 % losses (soiling, wiring, mismatch, ageing…) × ≈ 0.90 for hot '
          'cells in Pakistan ≈ 0.77.',
    ),
    const NumberInput(
      'inv',
      'Inverter efficiency',
      quantity: Quantity.percent,
      initial: 0.95,
      min: 0.5,
      max: 1,
    ),
    const NumberInput(
      'margin',
      'Design margin',
      quantity: Quantity.dimensionless,
      initial: 1.0,
      min: 1,
      max: 2,
      help: 'Multiplier on the array, e.g. 1.1 for load growth.',
    ),
    const NumberInput(
      'days',
      'Battery autonomy',
      quantity: Quantity.dimensionless,
      unitSuffix: 'days',
      initial: 1,
      min: 0,
      max: 10,
      help: '0 = no battery (grid-tied). Load-shedding backup: hours ÷ 24.',
    ),
    NumberInput(
      'vb',
      'Battery bank voltage',
      quantity: Quantity.voltageV,
      initial: 48,
      min: 1,
      help: '12, 24, 48 V, or a high-voltage lithium stack.',
      visibleWhen: (v) => v.n('days') > 0,
    ),
    ChoiceInput(
      'chem',
      'Battery type',
      options: const [
        ChoiceOption('lfp', 'LiFePO4 (80 % DoD)'),
        ChoiceOption('pb', 'Lead-acid (50 % DoD)'),
        ChoiceOption('custom', 'Enter DoD & efficiency'),
      ],
      visibleWhen: (v) => v.n('days') > 0,
    ),
    NumberInput(
      'dod',
      'Usable depth of discharge',
      quantity: Quantity.percent,
      initial: 0.7,
      min: 0.1,
      max: 1,
      visibleWhen: (v) => v.n('days') > 0 && v.c('chem') == 'custom',
    ),
    NumberInput(
      'beff',
      'Battery round-trip efficiency',
      quantity: Quantity.percent,
      initial: 0.85,
      min: 0.5,
      max: 1,
      visibleWhen: (v) => v.n('days') > 0 && v.c('chem') == 'custom',
    ),
    const NumberInput(
      'peak',
      'Peak simultaneous load',
      quantity: Quantity.power,
      initial: 3000,
      min: 0,
      units: ('W', 'W'),
    ),
  ],
  compute: (v) {
    final e = v.n('e') / 3600; // Wh/day
    final site = v.c('site');
    final custom = site == 'custom';
    final city = pakistanPsh[site];
    final worst = v.c('basis') == 'worst';
    final psh = custom ? v.n('psh') : (worst ? city!.$2 : city!.$1);
    final wp = v.n('wp'), kpv = v.n('kpv'), inv = v.n('inv');
    final days = v.n('days');
    final hasBattery = days > 0;
    final chem = v.c('chem');
    final (dod, beff) = !hasBattery
        ? (1.0, 1.0)
        : chem == 'custom'
        ? (v.n('dod'), v.n('beff'))
        : batteryPresets[chem]!;

    final arrayWp = e * v.n('margin') / (psh * kpv * inv * beff);
    final panels = (arrayWp / wp - 1e-9).ceil();
    final vb = hasBattery ? v.n('vb') : double.nan;
    final ah = hasBattery ? e * days / (vb * dod * inv) : 0.0;
    final peak = v.n('peak');

    final w = <String>[];
    final notes = <String>[
      if (!custom)
        'Sun hours: Global Solar Atlas, ${worst ? 'lowest month (${city!.$4})' : 'annual mean'} '
            '${formatNumber(psh, sig: 3)} kWh/m²/day at ${city!.$3}° tilt, facing south.',
      'Battery losses are applied to all energy (as if every kWh were '
          'cycled): conservative where daytime loads run straight from PV.',
      'Check string voltage against the inverter/MPPT window at the coldest '
          'morning (Voc rises ≈ 0.3 %/°C) — not done here.',
    ];
    if (!custom && !worst && hasBattery) {
      w.add(
        'Annual average sun hours with a battery: winter/monsoon output will '
        'fall short — use the worst month for off-grid.',
      );
    }
    if (hasBattery && chem == 'pb' && days < 1) {
      notes.add('Lead-acid life falls sharply if cycled deeper than 50 %.');
    }
    if (hasBattery && vb <= 24 && ah > 400) {
      w.add(
        'Over 400 Ah at ${formatNumber(vb)} V: a higher bank voltage cuts current and cable size.',
      );
    }
    if (peak > 0) {
      notes.add(
        'Motors (pumps, compressors, ACs) start at 3–6 × running power: '
        'check the inverter surge rating.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'panels',
          'Number of panels',
          panels.toDouble(),
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'kwp',
          'Array size',
          panels * wp,
          quantity: Quantity.power,
          units: ('kW', 'kW'),
          sig: 4,
        ),
        ToolOutput(
          'arraywp',
          'Array needed (exact)',
          arrayWp,
          quantity: Quantity.power,
          units: ('kW', 'kW'),
          sig: 4,
        ),
        ToolOutput('psh', 'Sun hours used, h/day', psh, sig: 3),
        if (hasBattery) ...[
          ToolOutput(
            'ah',
            'Battery capacity, Ah',
            ah,
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput(
            'kwh',
            'Battery nominal energy',
            ah * vb * 3600,
            quantity: Quantity.energy,
            units: ('kWh', 'kWh'),
            sig: 4,
          ),
        ],
        ToolOutput(
          'inverter',
          'Inverter rating (≥ 1.25 × peak)',
          peak * 1.25,
          quantity: Quantity.power,
          units: ('kW', 'kW'),
          level: OutputLevel.primary,
          sig: 3,
        ),
      ],
      warnings: w,
      notes: notes,
    );
  },
  formula: '''Array (Wp) = E · margin / (PSH · k_PV · η_inv · η_bat)
  E      daily load energy, Wh/day (AC)
  PSH    peak sun hours on the array plane, h/day
         (= kWh/m²/day at 1 kW/m²)
  k_PV   PV derate (temperature, soiling, wiring, mismatch)
  η_bat  battery round-trip efficiency (1 if no battery)
Panels = ⌈ Array / panel Wp ⌉

Battery (Ah) = E · days / (V_bank · DoD · η_inv)
Inverter ≥ 1.25 × peak simultaneous load (typical)

Presets: LiFePO4 DoD 80 %, η 95 %;
         lead-acid DoD 50 %, η 80 % (typical)''',
  references: [
    'World Bank / ESMAP Global Solar Atlas v2 (Solargis), GTI at optimum tilt, long-term averages for each city',
    'NREL PVWatts v8 documentation (14 % default system losses, 96 % inverter efficiency)',
    'SEIAPI / PPA, Off-Grid PV Power Systems — System Design Guidelines (2012), battery and MPPT array worked example',
    'IEC 62548 (PV array design requirements); IEC 61427-1 (batteries for PV)',
  ],
  assumptions: [
    'Daily energy and sun hours are averages for the design month; no partial shading.',
    'Battery presets are typical practice, not maker data: use the battery datasheet DoD and cycle life.',
    'Sun hours differ between datasets: PVGIS-ERA5 is 7–11 % higher than Global Solar Atlas in Punjab and KP (winter haze), so GSA is used.',
  ],
  cases: [
    const ToolCase(
      'SEIAPI example: 1779 Wh/day, PSH 5, 80 W modules, 24 V, 5 days',
      source:
          'SEIAPI Off-Grid PV Design Guidelines (2012) worked example: 9 × 80 W '
          '(720 Wp), battery 529 Ah at 70 % DoD. Their factors entered here: '
          'k_PV = 0.95·0.95·0.85·0.97·0.95, η_bat 0.8, margin 1.1, DC loads',
      choices: {'site': 'custom', 'chem': 'custom'},
      numbers: {
        'e': (1779, 'Wh'),
        'psh': (5, '-'),
        'wp': (80, 'W'),
        'kpv': (70.6916, '%'),
        'inv': (100, '%'),
        'margin': (1.1, '-'),
        'days': (5, '-'),
        'vb': (24, 'V'),
        'dod': (70, '%'),
        'beff': (80, '%'),
      },
      expect: {'panels': (9, '-'), 'kwp': (720, 'W'), 'ah': (529.46, '-')},
    ),
    const ToolCase(
      'Lahore, worst month, 10 kWh/day, 550 W, LiFePO4 48 V, 1 day',
      source:
          'Global Solar Atlas Lahore GTI lowest month (Jan) 3.54; hand calc: '
          '10000/(3.54·0.77·0.95·0.95) = 4065 Wp → 8 panels; '
          '10000/(48·0.8·0.95) = 274.12 Ah',
      numbers: {'e': (10, 'kWh')},
      expect: {
        'arraywp': (4064.98, 'W'),
        'panels': (8, '-'),
        'ah': (274.123, '-'),
        'kwh': (13.1579, 'kWh'),
        'inverter': (3750, 'W'),
      },
    ),
    const ToolCase(
      'Karachi grid-tied, annual mean, 20 kWh/day, no battery',
      source:
          'Global Solar Atlas Karachi GTI annual 5.94; hand calc: '
          '20000/(5.94·0.77·0.95) = 4602.9 Wp → 9 × 550 W',
      choices: {'site': 'khi', 'basis': 'annual'},
      numbers: {'e': (20, 'kWh'), 'days': (0, '-'), 'peak': (5000, 'W')},
      expect: {
        'arraywp': (4602.88, 'W'),
        'panels': (9, '-'),
        'inverter': (6250, 'W'),
      },
    ),
    const ToolCase(
      'Multan, worst month, lead-acid 24 V, 2 days, 6 kWh/day',
      source:
          'Global Solar Atlas Multan GTI lowest month (Jan) 4.01; hand '
          'calc: 6000/(4.01·0.77·0.95·0.80) = 2556.8 Wp → 5 panels; '
          '6000·2/(24·0.5·0.95) = 1052.6 Ah',
      choices: {'site': 'mux', 'chem': 'pb'},
      numbers: {'e': (6, 'kWh'), 'days': (2, '-'), 'vb': (24, 'V')},
      expect: {
        'arraywp': (2556.83, 'W'),
        'panels': (5, '-'),
        'ah': (1052.63, '-'),
      },
      expectWarning: '400 Ah',
    ),
  ],
);
