import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plant_core/plant_core.dart';

/// ln Γ(x) for x > 0 (Lanczos, g = 7, n = 9; |rel. error| < 1e-15).
double lnGamma(double x) {
  const c = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    return math.log(math.pi / math.sin(math.pi * x)) - lnGamma(1 - x);
  }
  x -= 1;
  var a = c[0];
  final t = x + 7.5;
  for (var i = 1; i < 9; i++) {
    a += c[i] / (x + i);
  }
  return 0.5 * math.log(2 * math.pi) +
      (x + 0.5) * math.log(t) -
      t +
      math.log(a);
}

/// Continued fraction for the incomplete beta (modified Lentz).
double _betacf(double a, double b, double x) {
  const tiny = 1e-300;
  var c = 1.0;
  var d = 1 - (a + b) * x / (a + 1);
  if (d.abs() < tiny) d = tiny;
  d = 1 / d;
  var h = d;
  for (var m = 1; m <= 1000; m++) {
    final m2 = 2 * m;
    var aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2));
    d = 1 + aa * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aa / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    h *= d * c;
    aa = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1));
    d = 1 + aa * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aa / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    final del = d * c;
    h *= del;
    if ((del - 1).abs() < 1e-15) break;
  }
  return h;
}

/// Regularised incomplete beta I_x(a, b).
double incBeta(double x, double a, double b) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  final bt = math.exp(
    lnGamma(a + b) -
        lnGamma(a) -
        lnGamma(b) +
        a * math.log(x) +
        b * math.log(1 - x),
  );
  if (x < (a + 1) / (a + b + 2)) return bt * _betacf(a, b, x) / a;
  return 1 - bt * _betacf(b, a, 1 - x) / b;
}

/// Student t quantile: the t with upper-tail probability [p] (0 < p < 0.5)
/// for [df] degrees of freedom. Uses P(T > t) = ½·I_{df/(df+t²)}(df/2, ½),
/// solved for x by bisection (I is monotonic in x).
double tUpper(double p, double df) {
  var lo = 0.0, hi = 1.0; // x = df/(df + t²)
  for (var i = 0; i < 200; i++) {
    final mid = (lo + hi) / 2;
    if (0.5 * incBeta(mid, df / 2, 0.5) < p) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final x = (lo + hi) / 2;
  return math.sqrt(df * (1 - x) / x);
}

/// Grubbs single-outlier critical value at two-sided level [alpha], as
/// tabulated in ISO 5725-2:1994 Table 5 (and Grubbs & Beck 1972).
double grubbsCritical(int n, double alpha) {
  final t = tUpper(alpha / (2 * n), (n - 2).toDouble());
  return (n - 1) / math.sqrt(n) * math.sqrt(t * t / (n - 2 + t * t));
}

String _verdict(double g, double g5, double g1) => g > g1
    ? 'Outlier (> 1 % critical)'
    : g > g5
    ? 'Straggler (> 5 % critical)'
    : 'Not an outlier';

OutputLevel _lvl(double g, double g5, double g1) => g > g1
    ? OutputLevel.fail
    : g > g5
    ? OutputLevel.warn
    : OutputLevel.ok;

final statisticsTool = ToolDef(
  id: 'statistics',
  title: 'Replicate statistics',
  summary:
      'Mean, SD, RSD, standard uncertainty (GUM Type A), confidence interval '
      'with Student t, and the Grubbs outlier test (ISO 5725-2).',
  icon: Icons.bar_chart,
  keywords: [
    'statistics',
    'mean',
    'average',
    'standard deviation',
    'sd',
    'rsd',
    'cv',
    'uncertainty',
    'type a',
    'gum',
    'confidence',
    'student',
    't-test',
    'grubbs',
    'outlier',
    'straggler',
    'replicates',
    'precision',
  ],
  inputs: [
    const ListInput(
      'x',
      'Replicate results',
      quantity: Quantity.dimensionless,
      initial: [10.1, 10.3, 10.2, 10.4, 10.2],
      minCount: 2,
      maxCount: 100,
      help: 'Same unit for all values.',
    ),
    const ChoiceInput(
      'conf',
      'Confidence level',
      options: [ChoiceOption('95', '95 %'), ChoiceOption('99', '99 %')],
    ),
  ],
  compute: (v) {
    final x = v.l('x');
    final n = x.length;
    if (n < 2) throw ToolInputError('Enter at least 2 values.');
    final mean = x.reduce((a, b) => a + b) / n;
    var ss = 0.0;
    for (final xi in x) {
      ss += (xi - mean) * (xi - mean);
    }
    final sd = math.sqrt(ss / (n - 1));
    final u = sd / math.sqrt(n);
    final conf = v.c('conf') == '99' ? 0.99 : 0.95;
    final t = tUpper((1 - conf) / 2, (n - 1).toDouble());
    final ci = t * u;
    final xmax = x.reduce(math.max), xmin = x.reduce(math.min);
    final w = <String>[];
    final out = <ToolOutput>[
      ToolOutput('n', 'Number of values n', n.toDouble(), sig: 3),
      ToolOutput('mean', 'Mean', mean, level: OutputLevel.primary, sig: 6),
      ToolOutput('sd', 'Std deviation s', sd, sig: 5),
      ToolOutput(
        'rsd',
        'RSD (CV)',
        mean != 0 ? sd / mean.abs() : double.nan,
        quantity: Quantity.percent,
        sig: 4,
      ),
      ToolOutput('u', 'Std uncertainty s/√n', u, sig: 5),
      ToolOutput('t', 'Student t (n − 1 df)', t, sig: 5),
      ToolOutput('ci', '± half-width t·s/√n', ci, sig: 5),
      ToolOutput('lo', 'Interval low', mean - ci, sig: 6),
      ToolOutput('hi', 'Interval high', mean + ci, sig: 6),
      ToolOutput('range', 'Range', xmax - xmin, sig: 5),
    ];
    if (sd == 0) {
      w.add('All values are equal: s = 0, no outlier test.');
      return ToolResult(out, warnings: w);
    }
    if (n < 3) {
      w.add('Grubbs test needs at least 3 values.');
      return ToolResult(out, warnings: w);
    }
    final gmax = (xmax - mean) / sd, gmin = (mean - xmin) / sd;
    final g5 = grubbsCritical(n, 0.05), g1 = grubbsCritical(n, 0.01);
    if (n > 40) {
      w.add(
        'n > 40: ISO 5725-2 tabulates only n ≤ 40; critical values are from '
        'the same formula.',
      );
    }
    out.addAll([
      ToolOutput('gmax', 'Grubbs G, highest', gmax, sig: 4),
      ToolOutput.text(
        'vmax',
        'Highest value',
        _verdict(gmax, g5, g1),
        level: _lvl(gmax, g5, g1),
      ),
      ToolOutput('gmin', 'Grubbs G, lowest', gmin, sig: 4),
      ToolOutput.text(
        'vmin',
        'Lowest value',
        _verdict(gmin, g5, g1),
        level: _lvl(gmin, g5, g1),
      ),
      ToolOutput('g5', 'G critical, 5 %', g5, sig: 4),
      ToolOutput('g1', 'G critical, 1 %', g1, sig: 4),
    ]);
    return ToolResult(
      out,
      warnings: w,
      notes: [
        'Investigate a straggler or outlier for a technical cause before '
            'removing it; re-run the test once only (ISO 5725-2 §7.3.4).',
      ],
    );
  },
  formula: '''x̄ = Σxᵢ / n
s = √[Σ(xᵢ − x̄)² / (n − 1)]
RSD = s / |x̄| × 100 %
u(x̄) = s / √n                 (GUM 4.2.3, Type A)
CI = x̄ ± t(1−α/2, n−1)·s/√n

Grubbs single-outlier test (ISO 5725-2 §7.3.4):
  G_high = (x_max − x̄)/s     G_low = (x̄ − x_min)/s
  G ≤ G5%          → accepted
  G5% < G ≤ G1%    → straggler
  G > G1%          → statistical outlier
Critical value (two-sided level α):
  G_crit = (n−1)/√n · √[t²/(n − 2 + t²)]
  t = t(1 − α/(2n), n − 2)

t is computed exactly from the incomplete beta function.''',
  references: [
    'ISO 5725-2:1994/2019 Accuracy (trueness and precision) of measurement methods — Part 2, §7.3.4 Grubbs\' test and Table 5 (critical values, n = 3 … 40)',
    'JCGM 100:2008 (GUM) §4.2 Type A evaluation of standard uncertainty',
    'F. E. Grubbs & G. Beck, Technometrics 14 (1972) 847 — extension of the critical-value tables',
    'NIST/SEMATECH e-Handbook of Statistical Methods §1.3.5.17 (Grubbs test, critical-value formula) and §1.3.6.7.2 (t table)',
  ],
  assumptions: [
    'Values are independent results of the same measurand, approximately normally distributed.',
    'Grubbs tests one suspect value at each end; the paired (two-value) Grubbs test is not included.',
  ],
  cases: [
    const ToolCase(
      'Five replicates, 95 %',
      source:
          'Python statistics + scipy 1.17.1: x̄ 10.24, s 0.114018, t 2.776445, '
          '±0.141571',
      lists: {
        'x': ([10.1, 10.3, 10.2, 10.4, 10.2], '-'),
      },
      expect: {
        'mean': (10.24, '-'),
        'sd': (0.1140175, '-'),
        'rsd': (1.113453, '%'),
        'u': (0.0509902, '-'),
        't': (2.776445, '-'),
        'ci': (0.1415715, '-'),
      },
      expectText: {'vmax': 'Not an outlier'},
      relTol: 1e-6,
    ),
    const ToolCase(
      'Ten %N results with one high value: outlier',
      source:
          'ISO 5725-2 Table 5 / Harvey Analytical Chemistry 2.1 Table 16.7.1 '
          '(n = 10: 2.290, 2.482); G = 2.8008 by Python',
      lists: {
        'x': (
          [
            46.12,
            46.15,
            46.10,
            46.14,
            46.11,
            46.13,
            46.16,
            46.12,
            46.14,
            46.45,
          ],
          '-',
        ),
      },
      expect: {
        'g5': (2.290, '-'),
        'g1': (2.482, '-'),
        'gmax': (2.80083, '-'),
        'mean': (46.162, '-'),
      },
      expectText: {'vmax': 'Outlier', 'vmin': 'Not an outlier'},
      relTol: 3e-4,
    ),
    const ToolCase(
      'Seven results: straggler',
      source:
          'ISO 5725-2 Table 5 / Harvey Table 16.7.1 (n = 7: 2.020, 2.139); '
          'G = 2.0461 by Python',
      lists: {
        'x': ([2.10, 2.12, 2.11, 2.13, 2.12, 2.11, 2.168], '-'),
      },
      expect: {'g5': (2.020, '-'), 'g1': (2.139, '-'), 'gmax': (2.04610, '-')},
      expectText: {'vmax': 'Straggler'},
      relTol: 3e-4,
    ),
    const ToolCase(
      'Three results (smallest n)',
      source:
          'ISO 5725-2 Table 5 / Harvey Table 16.7.1 (n = 3: 1.155, 1.155); '
          'scipy t(0.975, 2) = 4.302653. Tables round G5% (exact 1.15430) up to 1.155',
      lists: {
        'x': ([5.0, 5.1, 5.6], '-'),
      },
      expect: {
        'g5': (1.155, '-'),
        'g1': (1.155, '-'),
        't': (4.302653, '-'),
        'ci': (0.7985386, '-'),
      },
      expectText: {'vmax': 'Not an outlier'},
      // Exact 5 % value is 1.15430; the tables print 1.155 for both levels
      // (the 1 % value 1.15468 is at the n = 3 maximum (n−1)/√n = 1.1547).
      relTol: 7e-4,
    ),
    const ToolCase(
      'Ten results at 99 %',
      source: 'scipy 1.17.1: t(0.995, 9) = 3.249836; ±0.00267331',
      choices: {'conf': '99'},
      lists: {
        'x': (
          [
            0.512,
            0.508,
            0.515,
            0.510,
            0.509,
            0.513,
            0.511,
            0.507,
            0.514,
            0.510,
          ],
          '-',
        ),
      },
      expect: {
        'mean': (0.5109, '-'),
        'sd': (0.00260128, '-'),
        't': (3.249836, '-'),
        'ci': (0.00267331, '-'),
      },
      relTol: 1e-5,
    ),
    ToolCase(
      'Forty results (largest tabulated n)',
      source:
          'ISO 5725-2 Table 5, n = 40: 3.036 (5 %), 3.381 (1 %); same from '
          'the t-formula with scipy 1.17.1 (3.03610, 3.38068)',
      lists: {
        'x': ([for (var i = 1; i <= 40; i++) i.toDouble()], '-'),
      },
      expect: {'g5': (3.036, '-'), 'g1': (3.381, '-'), 'mean': (20.5, '-')},
      expectText: {'vmax': 'Not an outlier'},
      relTol: 3e-4,
    ),
  ],
);
