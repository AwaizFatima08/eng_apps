import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

double _log10(double x) => math.log(x) / math.ln10;

/// OSHA 29 CFR 1910.95 Table G-16a reference duration, hours.
double _oshaT(double l) => 8 / math.pow(2, (l - 90) / 5);

final noiseDoseTool = ToolDef(
  id: 'noise_dose',
  title: 'Noise dose & 8-h TWA',
  summary:
      'Daily noise dose and 8-hour level from measured levels and times — '
      'OSHA 5 dB method or ISO 9612 / EU 3 dB method.',
  icon: Icons.hearing,
  keywords: [
    'noise',
    'dose',
    'twa',
    'lex',
    'lep,d',
    'dba',
    'hearing',
    'dosimeter',
    'osha 1910.95',
    'iso 9612',
    '2003/10/ec',
    'exchange rate',
  ],
  inputs: [
    const ChoiceInput(
      'method',
      'Method',
      options: [
        ChoiceOption('osha', 'OSHA 1910.95 (5 dB)'),
        ChoiceOption('iso', 'ISO 9612 / EU (3 dB)'),
      ],
    ),
    const ListInput(
      'levels',
      'A-weighted levels, one per period',
      quantity: Quantity.soundLevel,
      initial: [85, 92, 100],
      min: 0,
      max: 160,
      maxCount: 24,
      help:
          'Lp,A,eq (dB(A), slow response for OSHA) for each task or period of '
          'the shift.',
    ),
    const ListInput(
      'hours',
      'Duration of each period (same order)',
      quantity: Quantity.time,
      units: ('h', 'h'),
      initial: [4 * 3600, 3 * 3600, 1 * 3600],
      min: 0,
      maxCount: 24,
      help: 'Same number of entries as the levels.',
    ),
  ],
  compute: (v) {
    final levels = v.l('levels');
    final hours = [for (final s in v.l('hours')) s / 3600];
    if (levels.length != hours.length) {
      throw ToolInputError(
        'Enter one duration per level (${levels.length} levels, '
        '${hours.length} durations).',
      );
    }
    final total = hours.fold<double>(0, (a, b) => a + b);
    if (total <= 0) throw ToolInputError('Total duration must be above 0 h.');
    final w = <String>[];
    final notes = <String>[];
    if (total > 24) {
      throw ToolInputError('Durations add up to more than 24 h.');
    }
    if ((total - 8).abs() > 0.01) {
      notes.add(
        'Periods add up to ${formatNumber(total, sig: 4)} h; the result is '
        'still normalised to an 8-h day (unmeasured time counts as quiet).',
      );
    }

    if (v.c('method') == 'iso') {
      // ISO 9612:2009 eq. (7)/(8): LEX,8h = 10·lg Σ (Tm/T0)·10^(0.1·Lm).
      var e = 0.0, dose = 0.0;
      for (var i = 0; i < levels.length; i++) {
        e += hours[i] / 8 * math.pow(10, levels[i] / 10);
        dose += hours[i] / 8 * math.pow(10, (levels[i] - 85) / 10);
      }
      if (e <= 0) throw ToolInputError('All durations are zero.');
      final lex = 10 * _log10(e);
      final (String, OutputLevel) status = lex > 87
          ? ('Above exposure limit value 87 dB(A)', OutputLevel.fail)
          : lex >= 85
          ? ('Upper action value 85 dB(A) reached', OutputLevel.fail)
          : lex >= 80
          ? ('Lower action value 80 dB(A) reached', OutputLevel.warn)
          : ('Below lower action value 80 dB(A)', OutputLevel.ok);
      if (lex > 87) {
        w.add(
          'The EU limit value 87 dB(A) applies to the exposure at the ear, '
          'taking hearing protection into account: check the protector '
          'attenuation before deciding.',
        );
      }
      return ToolResult(
        [
          ToolOutput(
            'lex',
            'LEX,8h',
            lex,
            quantity: Quantity.soundLevel,
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput(
            'dose',
            'Dose (100 % = 85 dB(A), 8 h)',
            dose,
            quantity: Quantity.percent,
            level: OutputLevel.primary,
            sig: 4,
          ),
          ToolOutput.text(
            'status',
            'EU 2003/10/EC',
            status.$1,
            level: status.$2,
          ),
          ToolOutput(
            'total',
            'Time entered',
            total * 3600,
            quantity: Quantity.time,
            units: ('h', 'h'),
            sig: 4,
          ),
        ],
        warnings: w,
        notes: [
          ...notes,
          'Peak sound pressure (135/137/140 dB(C) in 2003/10/EC) is not '
              'covered — check it separately.',
        ],
      );
    }

    // OSHA: D = 100·Σ C/T with T = 8/2^((L−90)/5); TWA = 16.61·lg(D/100) + 90.
    double dose(double threshold) {
      var d = 0.0;
      for (var i = 0; i < levels.length; i++) {
        if (levels[i] >= threshold) d += hours[i] / _oshaT(levels[i]);
      }
      return d;
    }

    double twa(double d) => d > 0 ? 16.61 * _log10(d) + 90 : double.nan;
    final dHca = dose(80), dPel = dose(90);
    final twaHca = twa(dHca), twaPel = twa(dPel);
    final (String, OutputLevel) status = dPel > 1 + 1e-9
        ? ('Exceeds PEL 90 dBA (dose > 100 %)', OutputLevel.fail)
        : dHca >= 0.5 - 1e-9
        ? ('Action level 85 dBA reached: HCP', OutputLevel.warn)
        : ('Below action level 85 dBA', OutputLevel.ok);
    if (levels.any((l) => l > 115)) {
      w.add(
        'A level above 115 dBA: OSHA Table G-16 footnote — exposure to '
        'continuous noise above 115 dBA is not permitted.',
      );
    }
    if (dHca == 0) {
      notes.add('Every level is below 80 dBA, so OSHA counts no dose.');
    }
    return ToolResult(
      [
        ToolOutput(
          'dose',
          'Dose (80 dBA threshold)',
          dHca,
          quantity: Quantity.percent,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'twa',
          '8-h TWA (80 dBA threshold)',
          twaHca,
          quantity: Quantity.soundLevel,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'dosePel',
          'Dose (90 dBA threshold, PEL)',
          dPel,
          quantity: Quantity.percent,
          sig: 4,
        ),
        ToolOutput(
          'twaPel',
          '8-h TWA (90 dBA threshold)',
          twaPel,
          quantity: Quantity.soundLevel,
          sig: 4,
        ),
        ToolOutput.text('status', 'OSHA verdict', status.$1, level: status.$2),
        ToolOutput(
          'total',
          'Time entered',
          total * 3600,
          quantity: Quantity.time,
          units: ('h', 'h'),
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        ...notes,
        'Action level (hearing conservation programme) uses the 80 dBA '
            'threshold; PEL compliance uses the 90 dBA threshold (OSHA '
            'Technical Manual Sec. III Ch. 5).',
      ],
    );
  },
  formula: '''OSHA 29 CFR 1910.95 (criterion 90 dBA, exchange 5 dB)
  T = 8 / 2^((L − 90)/5)   h       (Table G-16a)
  D = 100 · Σ Cᵢ / Tᵢ      %       (App. A, I.1)
  TWA = 16.61 · lg(D/100) + 90     (App. A, I.2)
  Levels < 80 dBA ignored for the action level (85 dBA, D = 50 %);
  levels < 90 dBA ignored for the PEL (90 dBA, D = 100 %).

ISO 9612:2009 / EU 2003/10/EC (exchange 3 dB, T₀ = 8 h)
  LEX,8h = 10 · lg Σ (Tᵢ/T₀) · 10^(0.1·Lᵢ)
  Dose = Σ (Tᵢ/8) · 10^((Lᵢ − 85)/10)   (100 % = LEX,8h 85)
  Lower action 80, upper action 85, limit 87 dB(A) (limit at the ear,
  with hearing protection).''',
  references: [
    'OSHA 29 CFR 1910.95 Table G-16 / G-16a, (d)(2)(i), Appendix A (Table A-1)',
    'OSHA Technical Manual Section III Chapter 5 (dosimeter thresholds)',
    'ISO 9612:2009 Acoustics — Determination of occupational noise exposure, task-based method',
    'Directive 2003/10/EC Art. 3 (exposure limit and action values)',
  ],
  assumptions: [
    'Levels are equivalent continuous A-weighted levels for each period (task-based method); sampling uncertainty (ISO 9612 cl. 7) is not added.',
    'Impulse noise and peak levels are not assessed.',
    'Hearing-protector attenuation is not included (enter levels at the ear for the EU limit value check).',
  ],
  cases: [
    const ToolCase(
      'OSHA: 2 h at 100 dBA + 6 h at 85 dBA',
      source:
          'Hand calc from App. A: D = 2/2 + 6/16 = 137.5 %, TWA = 92.297; '
          'PEL dose (≥ 90 only) = 100 %',
      lists: {
        'levels': ([100, 85], 'dBA'),
        'hours': ([2, 6], 'h'),
      },
      expect: {
        'dose': (137.5, '%'),
        'twa': (92.2972, 'dBA'),
        'dosePel': (100, '%'),
        'twaPel': (90, 'dBA'),
      },
      expectText: {'status': 'Action level'},
      relTol: 1e-4,
    ),
    const ToolCase(
      'OSHA Table A-1: 8 h at 85 dBA ⇒ 50 %, 85.0 dB',
      source:
          '1910.95 App. A Table A-1 (50 % ⇒ 85.0) and Table G-16a (85 dB, 16 h)',
      lists: {
        'levels': ([85], 'dBA'),
        'hours': ([8], 'h'),
      },
      expect: {'dose': (50, '%'), 'twa': (85.0, 'dBA')},
      relTol: 1e-4,
    ),
    const ToolCase(
      'OSHA: 1 h at 110 + 7 h at 80 dBA',
      source:
          'Hand calc: D = 1/0.5 + 7/32 = 221.875 %, TWA 95.749; PEL dose 200 % '
          '(Table A-1: 200 % ⇒ 95.0)',
      lists: {
        'levels': ([110, 80], 'dBA'),
        'hours': ([1, 7], 'h'),
      },
      expect: {
        'dose': (221.875, '%'),
        'twa': (95.7489, 'dBA'),
        'dosePel': (200, '%'),
        'twaPel': (95.0, 'dBA'),
      },
      expectText: {'status': 'Exceeds PEL'},
      relTol: 1e-4,
    ),
    const ToolCase(
      'ISO 9612: 4 h at 89 + 4 h at 80 dB(A)',
      source:
          'Hand calc (independent script): LEX,8h = 10·lg(0.5·10^8.9 + '
          '0.5·10^8.0) = 86.505; dose 141.41 %',
      choices: {'method': 'iso'},
      lists: {
        'levels': ([89, 80], 'dBA'),
        'hours': ([4, 4], 'h'),
      },
      expect: {'lex': (86.5047, 'dBA'), 'dose': (141.406, '%')},
      expectText: {'status': 'Upper action'},
      relTol: 1e-4,
    ),
    const ToolCase(
      'ISO 9612: 12-h shift, 2 h at 95 + 10 h at 82 dB(A)',
      source: 'Hand calc (independent script): LEX,8h = 89.951 dB(A)',
      choices: {'method': 'iso'},
      lists: {
        'levels': ([95, 82], 'dBA'),
        'hours': ([2, 10], 'h'),
      },
      expect: {'lex': (89.9506, 'dBA'), 'dose': (312.648, '%')},
      expectText: {'status': 'limit value'},
      expectWarning: 'hearing protection',
      relTol: 1e-4,
    ),
  ],
);
