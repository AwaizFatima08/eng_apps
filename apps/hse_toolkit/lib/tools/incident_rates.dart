import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

const double _osha = 200000; // 100 full-time workers × 2000 h
const double _mill = 1000000; // ILO / common LTIFR base

final incidentRatesTool = ToolDef(
  id: 'incident_rates',
  title: 'Incident rates (TRIR, LTIFR)',
  summary:
      'TRIR, DART and lost-time rates per 200 000 h (OSHA/BLS) and frequency '
      'and severity rates per 1 000 000 h (ILO).',
  icon: Icons.query_stats,
  keywords: [
    'trir',
    'trcf',
    'ltifr',
    'ltir',
    'dart',
    'severity',
    'frequency',
    'incident rate',
    'injury',
    'kpi',
    'iso 45001',
    'ilo',
    'man-hours',
  ],
  inputs: [
    const NumberInput(
      'hours',
      'Hours worked (all employees)',
      quantity: Quantity.dimensionless,
      unitSuffix: 'h',
      initial: 1000000,
      min: 0,
      minInclusive: false,
      help:
          'Actual hours worked in the period (exclude leave and holidays); '
          'include contractors if their cases are counted.',
    ),
    const NumberInput(
      'rec',
      'Recordable cases (OSHA 300)',
      quantity: Quantity.dimensionless,
      initial: 10,
      min: 0,
      help: 'Fatalities + lost-time + restricted/transfer + medical treatment.',
    ),
    const NumberInput(
      'dart',
      'DART cases (away + restricted)',
      quantity: Quantity.dimensionless,
      initial: 5,
      min: 0,
    ),
    const NumberInput(
      'lti',
      'Lost-time injuries (LTI)',
      quantity: Quantity.dimensionless,
      initial: 3,
      min: 0,
      help:
          'Cases with at least one full day away after the injury day (incl. fatalities).',
    ),
    const NumberInput(
      'days',
      'Days lost',
      quantity: Quantity.dimensionless,
      unitSuffix: 'days',
      initial: 120,
      min: 0,
      help:
          'Calendar days away counted in this period (OSHA caps a case at 180).',
    ),
    const NumberInput(
      'workers',
      'Average number of workers',
      quantity: Quantity.dimensionless,
      initial: 0,
      min: 0,
      help:
          'Optional — for the ILO incidence rate per 1000 workers (0 = skip).',
    ),
  ],
  compute: (v) {
    final h = v.n('hours'), rec = v.n('rec'), dart = v.n('dart');
    final lti = v.n('lti'), days = v.n('days'), workers = v.n('workers');
    final w = <String>[];
    if (dart > rec) {
      w.add('DART cases exceed recordable cases — DART is a subset.');
    }
    if (lti > rec) {
      w.add('LTIs exceed recordable cases — an LTI is also recordable.');
    }
    if (lti > dart && dart > 0) {
      w.add('LTIs exceed DART cases — days-away cases are part of DART.');
    }
    if (days > 0 && lti == 0) {
      w.add('Days lost entered but no lost-time injury.');
    }
    if (h < 200000) {
      w.add(
        'Fewer than 200 000 h: one case moves the rates a lot — report '
        'rolling 12-month figures.',
      );
    }
    return ToolResult(
      [
        ToolOutput(
          'trir',
          'TRIR (per 200 000 h)',
          rec * _osha / h,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'ltifr',
          'LTIFR (per 1 000 000 h)',
          lti * _mill / h,
          level: OutputLevel.primary,
          sig: 4,
        ),
        ToolOutput(
          'dartr',
          'DART rate (per 200 000 h)',
          dart * _osha / h,
          sig: 4,
        ),
        ToolOutput('ltir', 'LTIR (per 200 000 h)', lti * _osha / h, sig: 4),
        ToolOutput('trifr', 'TRIFR (per 1 000 000 h)', rec * _mill / h, sig: 4),
        ToolOutput(
          'sev',
          'Severity rate (days per 1 000 000 h)',
          days * _mill / h,
          sig: 4,
        ),
        ToolOutput(
          'lwdr',
          'Lost-day rate (days per 200 000 h)',
          days * _osha / h,
          sig: 4,
        ),
        ToolOutput(
          'avg',
          'Average days lost per LTI',
          lti > 0 ? days / lti : double.nan,
          sig: 4,
        ),
        ToolOutput(
          'inc',
          'ILO incidence (LTI per 1000 workers)',
          workers > 0 ? lti / workers * 1000 : double.nan,
          sig: 4,
        ),
      ],
      warnings: w,
      notes: [
        'Compare rates only on the same base and the same case definitions. '
            'ISO 45001 requires performance monitoring (cl. 9.1) but sets no '
            'formula — state the base in every report.',
      ],
    );
  },
  formula: '''OSHA / BLS (base 200 000 h = 100 workers × 40 h × 50 wk):
  TRIR = recordable cases × 200 000 / hours
  DART = DART cases × 200 000 / hours
  LTIR = LTI × 200 000 / hours
  Lost-day rate = days lost × 200 000 / hours

ILO (16th ICLS, 1998) and common LTIFR (base 1 000 000 h):
  Frequency rate (LTIFR) = LTI × 1 000 000 / hours
  TRIFR = recordable cases × 1 000 000 / hours
  Severity rate = days lost × 1 000 000 / hours
  Incidence rate = LTI × 1000 / workers

TRIR × 5 = TRIFR (same cases).''',
  references: [
    'US BLS "How to compute a firm\'s incidence rate" (200 000 h base, worked example)',
    'OSHA 29 CFR 1904 recordkeeping (recordable, DART, 180-day cap 1904.7(b)(3)(vii))',
    'ILO Resolution concerning statistics of occupational injuries, 16th ICLS (1998); ILOSTAT frequency and severity rate definitions',
    'ISO 45001:2018 cl. 9.1 (monitoring, measurement) — no rate formula prescribed',
  ],
  assumptions: [
    'Case definitions (recordable, LTI, DART) follow the site\'s system; OSHA counts calendar days, many ILO users count scheduled workdays.',
    'Hours are actual hours worked, not paid hours.',
  ],
  cases: [
    const ToolCase(
      'BLS example: ABC Company, 7 cases, 400 000 h',
      source:
          'BLS worked example: TRIR = 7 × 200 000 / 400 000 = 3.5; DART 3 cases ⇒ 1.5',
      numbers: {
        'hours': (400000, '-'),
        'rec': (7, '-'),
        'dart': (3, '-'),
        'lti': (2, '-'),
        'days': (30, '-'),
      },
      expect: {'trir': (3.5, '-'), 'dartr': (1.5, '-'), 'trifr': (17.5, '-')},
    ),
    const ToolCase(
      '1 000 000 h, 10 recordable, 3 LTI, 120 days',
      source:
          'Hand calc: TRIR 2.0, LTIFR 3.0, LTIR 0.6, severity 120, lost-day rate '
          '24, 40 days per LTI',
      numbers: {
        'hours': (1000000, '-'),
        'rec': (10, '-'),
        'dart': (5, '-'),
        'lti': (3, '-'),
        'days': (120, '-'),
      },
      expect: {
        'trir': (2.0, '-'),
        'ltifr': (3.0, '-'),
        'ltir': (0.6, '-'),
        'trifr': (10.0, '-'),
        'sev': (120, '-'),
        'lwdr': (24, '-'),
        'avg': (40, '-'),
      },
    ),
    const ToolCase(
      'ILO style: 250 workers × 300 days × 8 h, 4 LTI, 90 days',
      source:
          'ILOSTAT formulas: hours = 600 000; frequency 6.667, severity 150 per '
          '10⁶ h; incidence 4/250 × 1000 = 16',
      numbers: {
        'hours': (600000, '-'),
        'rec': (6, '-'),
        'dart': (4, '-'),
        'lti': (4, '-'),
        'days': (90, '-'),
        'workers': (250, '-'),
      },
      expect: {
        'ltifr': (6.66667, '-'),
        'sev': (150, '-'),
        'inc': (16, '-'),
        'trir': (2.0, '-'),
      },
      relTol: 1e-5,
    ),
    const ToolCase(
      'Inconsistent counts are flagged',
      source: 'Definition check (OSHA 1904): an LTI is a recordable case',
      numbers: {
        'hours': (500000, '-'),
        'rec': (1, '-'),
        'dart': (2, '-'),
        'lti': (2, '-'),
        'days': (10, '-'),
      },
      expect: {'ltifr': (4.0, '-'), 'trir': (0.4, '-')},
      expectWarning: 'LTIs exceed recordable',
    ),
  ],
);
