import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

final chemicalExposureTool = ToolDef(
  id: 'chemical_exposure',
  title: 'Chemical exposure (TWA, OEL)',
  summary:
      '8-hour TWA from sample results, check against the OEL/TLV, mixture '
      'additive index and ppm ⇄ mg/m³ (ammonia preset).',
  icon: Icons.science,
  keywords: [
    'twa',
    'tlv',
    'oel',
    'pel',
    'wel',
    'exposure',
    'mixture',
    'ammonia',
    'nh3',
    'ppm',
    'mg/m3',
    'brief scala',
    'gas',
    'vapour',
  ],
  inputs: [
    const ChoiceInput(
      'mode',
      'Calculation',
      options: [
        ChoiceOption('twa', 'TWA from samples'),
        ChoiceOption('mix', 'Mixture index Σ C/OEL'),
        ChoiceOption('conv', 'ppm ⇄ mg/m³'),
      ],
    ),
    ListInput(
      'conc',
      'Concentrations (ppm or mg/m³)',
      quantity: Quantity.dimensionless,
      initial: const [20, 30, 15],
      min: 0,
      maxCount: 24,
      help: 'One result per sample period, all in the same unit as the OEL.',
      visibleWhen: (v) => v.c('mode') == 'twa',
    ),
    ListInput(
      'hours',
      'Sample durations (same order)',
      quantity: Quantity.time,
      units: const ('h', 'h'),
      initial: const [3 * 3600, 3 * 3600, 2 * 3600],
      min: 0,
      maxCount: 24,
      visibleWhen: (v) => v.c('mode') == 'twa',
    ),
    NumberInput(
      'oel',
      '8-h OEL / TLV-TWA (same unit)',
      quantity: Quantity.dimensionless,
      initial: 25,
      min: 0,
      minInclusive: false,
      help:
          'Ammonia: ACGIH TLV-TWA 25 ppm (STEL 35), OSHA PEL 50 ppm, UK WEL '
          '25 ppm. Use the limit FFL has adopted.',
      visibleWhen: (v) => v.c('mode') == 'twa',
    ),
    ListInput(
      'mixc',
      'Concentrations Cᵢ',
      quantity: Quantity.dimensionless,
      initial: const [500, 45, 40],
      min: 0,
      maxCount: 12,
      help: 'Each component\'s TWA, in the unit of its own limit.',
      visibleWhen: (v) => v.c('mode') == 'mix',
    ),
    ListInput(
      'mixl',
      'Limits OELᵢ (same order)',
      quantity: Quantity.dimensionless,
      initial: const [1000, 200, 200],
      min: 0,
      maxCount: 12,
      visibleWhen: (v) => v.c('mode') == 'mix',
    ),
    ChoiceInput(
      'dir',
      'Direction',
      options: const [
        ChoiceOption('p2m', 'ppm → mg/m³'),
        ChoiceOption('m2p', 'mg/m³ → ppm'),
      ],
      visibleWhen: (v) => v.c('mode') == 'conv',
    ),
    NumberInput(
      'ppm',
      'Concentration',
      quantity: Quantity.dimensionless,
      unitSuffix: 'ppm',
      initial: 25,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'conv' && v.c('dir') == 'p2m',
    ),
    NumberInput(
      'mgm3',
      'Concentration',
      quantity: Quantity.massConc,
      units: const ('mg/m3', 'mg/m3'),
      initial: 17e-6,
      min: 0,
      visibleWhen: (v) => v.c('mode') == 'conv' && v.c('dir') == 'm2p',
    ),
    NumberInput(
      'mw',
      'Molar mass M',
      quantity: Quantity.dimensionless,
      unitSuffix: 'g/mol',
      initial: 17.031,
      min: 0,
      minInclusive: false,
      help: 'NH₃ 17.031; H₂S 34.08; CO 28.01; Cl₂ 70.90; NO₂ 46.01; CO₂ 44.01.',
      visibleWhen: (v) => v.c('mode') == 'conv',
    ),
    NumberInput(
      'vm',
      'Molar volume of air',
      quantity: Quantity.dimensionless,
      unitSuffix: 'L/mol',
      initial: 24.45,
      min: 20,
      max: 30,
      help:
          '24.45 at 25 °C, 1 atm (ACGIH, OSHA, NIOSH). UK EH40 uses 24.05 '
          '(20 °C). 22.41 at 0 °C.',
      visibleWhen: (v) => v.c('mode') == 'conv',
    ),
  ],
  compute: (v) {
    switch (v.c('mode')) {
      case 'mix':
        final c = v.l('mixc'), l = v.l('mixl');
        if (c.length != l.length) {
          throw ToolInputError(
            'Enter one limit per concentration (${c.length} vs ${l.length}).',
          );
        }
        if (l.any((x) => x <= 0)) {
          throw ToolInputError('Every limit must be above 0.');
        }
        var em = 0.0, worst = 0.0;
        for (var i = 0; i < c.length; i++) {
          final r = c[i] / l[i];
          em += r;
          if (r > worst) worst = r;
        }
        final over = em > 1 + 1e-12;
        return ToolResult(
          [
            ToolOutput(
              'em',
              'Mixture index Σ Cᵢ/OELᵢ',
              em,
              level: OutputLevel.primary,
              sig: 4,
            ),
            ToolOutput.text(
              'status',
              'Verdict',
              over
                  ? 'Exceeds the mixture limit (> 1)'
                  : 'Within the mixture limit (≤ 1)',
              level: over ? OutputLevel.fail : OutputLevel.ok,
            ),
            ToolOutput('worst', 'Largest single Cᵢ/OELᵢ', worst, sig: 4),
          ],
          notes: [
            'Additive rule applies to substances with the same toxic effect / '
                'target organ (ACGIH Appendix E). Independent effects are '
                'assessed one by one.',
          ],
        );
      case 'conv':
        final mw = v.n('mw'), vm = v.n('vm');
        final double ppm, mg;
        if (v.c('dir') == 'm2p') {
          mg = v.n('mgm3') * 1e6; // mg/m³
          ppm = mg * vm / mw;
        } else {
          ppm = v.n('ppm');
          mg = ppm * mw / vm;
        }
        return ToolResult(
          [
            ToolOutput(
              'mg',
              'mg/m³',
              mg * 1e-6,
              quantity: Quantity.massConc,
              units: ('mg/m3', 'mg/m3'),
              level: v.c('dir') == 'p2m'
                  ? OutputLevel.primary
                  : OutputLevel.normal,
              sig: 5,
            ),
            ToolOutput(
              'ppm',
              'ppm (by volume)',
              ppm,
              level: v.c('dir') == 'm2p'
                  ? OutputLevel.primary
                  : OutputLevel.normal,
              sig: 5,
            ),
            ToolOutput('f', 'mg/m³ per ppm', mw / vm, sig: 5),
          ],
          notes: [
            'Gases and vapours only — aerosols and dusts are always in mg/m³.',
          ],
        );
      default:
        final c = v.l('conc');
        final h = [for (final s in v.l('hours')) s / 3600];
        if (c.length != h.length) {
          throw ToolInputError(
            'Enter one duration per concentration (${c.length} vs ${h.length}).',
          );
        }
        final total = h.fold<double>(0, (a, b) => a + b);
        if (total <= 0) {
          throw ToolInputError('Total duration must be above 0 h.');
        }
        if (total > 24) {
          throw ToolInputError('Durations add up to more than 24 h.');
        }
        var ct = 0.0;
        for (var i = 0; i < c.length; i++) {
          ct += c[i] * h[i];
        }
        final oel = v.n('oel');
        final twa8 = ct / 8;
        final avg = ct / total;
        final frac = twa8 / oel;
        // Brief & Scala reduction factor for shifts longer than 8 h.
        final rf = total > 8 ? (8 / total) * (24 - total) / 16 : 1.0;
        final w = <String>[];
        final notes = <String>[
          'Unsampled time in the 8 h is counted as zero exposure '
              '(OSHA 1910.1000(d)(1)). Check short-term peaks against the STEL '
              'separately.',
        ];
        if (total < 8 - 1e-9) {
          w.add(
            'Samples cover only ${formatNumber(total, sig: 3)} h: the TWA assumes '
            'no exposure in the rest of the shift.',
          );
        }
        final (String, OutputLevel) status = frac > 1 + 1e-12
            ? ('Exceeds the 8-h OEL', OutputLevel.fail)
            : frac >= 0.5
            ? ('Above action level (½ OEL)', OutputLevel.warn)
            : ('Below action level (½ OEL)', OutputLevel.ok);
        final outs = <ToolOutput>[
          ToolOutput(
            'twa',
            '8-h TWA',
            twa8,
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput(
            'frac',
            'TWA as % of OEL',
            frac,
            quantity: Quantity.percent,
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput.text('status', 'Verdict', status.$1, level: status.$2),
          ToolOutput('avg', 'Average over sampled time', avg, sig: 4),
          ToolOutput(
            'total',
            'Time sampled',
            total * 3600,
            quantity: Quantity.time,
            units: ('h', 'h'),
            sig: 4,
          ),
        ];
        if (total > 8) {
          outs.addAll([
            ToolOutput('rf', 'Brief & Scala factor', rf, sig: 4),
            ToolOutput('oeladj', 'OEL adjusted for shift', oel * rf, sig: 4),
          ]);
          if (avg > oel * rf) {
            w.add(
              'Extended shift: the shift average is above the Brief & Scala '
              'adjusted OEL (${formatNumber(oel * rf, sig: 3)}).',
            );
          }
          notes.add(
            'Brief & Scala: RF = (8/h)·(24 − h)/16 for a daily shift of h hours; '
            'not for substances with acute (ceiling) effects only.',
          );
        }
        return ToolResult(outs, warnings: w, notes: notes);
    }
  },
  formula: '''8-h TWA (OSHA 1910.1000(d)(1), ACGIH):
  E = Σ Cᵢ·Tᵢ / 8          (T in h, ≤ 24 h in total)
  Action level used here: ½ OEL.
Extended shift h > 8 h (Brief & Scala 1975):
  RF = (8/h) · (24 − h)/16,  OEL_adj = RF · OEL

Mixture (OSHA 1910.1000(d)(2), ACGIH App. E):
  Em = Σ Cᵢ / OELᵢ   — must not exceed 1

ppm ⇄ mg/m³ (gas, ideal):
  mg/m³ = ppm · M / Vm,   Vm = 24.45 L/mol at 25 °C, 1 atm''',
  references: [
    'OSHA 29 CFR 1910.1000(d)(1)–(2) and Table Z-1 (ammonia 50 ppm, 35 mg/m³)',
    'ACGIH TLVs and BEIs: TWA definition, Appendix E (mixtures), ppm ⇄ mg/m³ at 24.45 L/mol',
    'Brief R.S., Scala R.A. (1975) Occupational exposure limits for novel work schedules, AIHA J. 36:467 (also OSHA Technical Manual)',
    'HSE EH40/2005 Workplace exposure limits (20 °C, 24.05 L/mol; ammonia WEL 25 ppm / 18 mg/m³)',
  ],
  assumptions: [
    'Concentrations and the OEL are in the same unit; the tool does not convert inside the TWA or mixture modes.',
    'Sampling and analytical error are not applied (no confidence-limit test).',
    'ppm ⇄ mg/m³ is for gases and vapours at the stated molar volume.',
  ],
  cases: [
    const ToolCase(
      'OSHA 1910.1000(d)(1) example: 150/75/50 ppm',
      source: 'OSHA 1910.1000(d)(1): (2·150 + 2·75 + 4·50)/8 = 81.25 ppm < 100',
      lists: {
        'conc': ([150, 75, 50], '-'),
        'hours': ([2, 2, 4], 'h'),
      },
      numbers: {'oel': (100, '-')},
      expect: {'twa': (81.25, '-'), 'frac': (81.25, '%')},
      expectText: {'status': 'Above action level'},
    ),
    const ToolCase(
      'OSHA 1910.1000(d)(2) mixture example',
      source: 'OSHA 1910.1000(d)(2): 500/1000 + 45/200 + 40/200 = 0.925',
      choices: {'mode': 'mix'},
      lists: {
        'mixc': ([500, 45, 40], '-'),
        'mixl': ([1000, 200, 200], '-'),
      },
      expect: {'em': (0.925, '-'), 'worst': (0.5, '-')},
      expectText: {'status': 'Within'},
    ),
    const ToolCase(
      'Ammonia 25 ppm → mg/m³ at 25 °C',
      source: 'Hand calc 25·17.031/24.45 = 17.414 mg/m³ (ACGIH lists 17 mg/m³)',
      choices: {'mode': 'conv'},
      numbers: {'ppm': (25, '-'), 'mw': (17.031, '-'), 'vm': (24.45, '-')},
      expect: {'mg': (17.4141, 'mg/m3')},
      relTol: 1e-4,
    ),
    const ToolCase(
      'Ammonia OSHA PEL 35 mg/m³ → ppm',
      source:
          'Hand calc 35·24.45/17.031 = 50.247 ppm; OSHA Table Z-1 pairs 35 mg/m³ '
          'with 50 ppm',
      choices: {'mode': 'conv', 'dir': 'm2p'},
      numbers: {'mgm3': (35, 'mg/m3'), 'mw': (17.031, '-'), 'vm': (24.45, '-')},
      expect: {'ppm': (50.2466, '-')},
      relTol: 1e-4,
    ),
    const ToolCase(
      'Ammonia 25 ppm at 20 °C (UK EH40 basis)',
      source: 'Hand calc 25·17.031/24.05 = 17.704 mg/m³ (EH40 lists 18 mg/m³)',
      choices: {'mode': 'conv'},
      numbers: {'ppm': (25, '-'), 'mw': (17.031, '-'), 'vm': (24.05, '-')},
      expect: {'mg': (17.7037, 'mg/m3')},
      relTol: 1e-4,
    ),
    const ToolCase(
      'Ammonia, 12-h shift: 20/30/15 ppm × 4 h each',
      source:
          'Hand calc: TWA = 260/8 = 32.5 ppm (130 % of 25); Brief & Scala RF = '
          '(8/12)(12/16) = 0.5 ⇒ 12.5 ppm',
      lists: {
        'conc': ([20, 30, 15], '-'),
        'hours': ([4, 4, 4], 'h'),
      },
      numbers: {'oel': (25, '-')},
      expect: {
        'twa': (32.5, '-'),
        'frac': (130, '%'),
        'avg': (21.6667, '-'),
        'rf': (0.5, '-'),
        'oeladj': (12.5, '-'),
      },
      expectText: {'status': 'Exceeds'},
      expectWarning: 'Brief & Scala',
      relTol: 1e-4,
    ),
  ],
);
