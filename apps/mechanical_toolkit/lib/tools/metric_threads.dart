/// ISO metric coarse threads M6–M36 and bolt property classes.
library;

import 'dart:math' as math;

/// One ISO metric coarse thread (ISO 261 / ISO 724) with the head and hole
/// sizes VDI 2230 uses for its tightening-torque table. Lengths in mm.
class MetricThread {
  const MetricThread(this.d, this.p, this.dw, this.dh);

  /// Nominal (major) diameter.
  final double d;

  /// Pitch, coarse series (ISO 261).
  final double p;

  /// Head bearing face outer Ø: hex head ISO 4014/4017 d_w min.
  /// Checked by reproducing VDI 2230 Part 1 tightening torques (≤ 1 %).
  final double dw;

  /// Clearance hole, medium series (ISO 273).
  final double dh;

  String get name => 'M${d.toStringAsFixed(0)}';

  /// Pitch diameter d2 = d − 0.649519·P (ISO 724).
  double get d2 => d - 0.6495191 * p;

  /// Minor diameter d3 of the bolt = d − 1.226869·P (ISO 898-1, H/6 root).
  double get d3 => d - 1.2268687 * p;

  /// Stress diameter d_s = (d2 + d3)/2.
  double get ds => (d2 + d3) / 2;

  /// Tensile stress area A_s = π/4·d_s² (ISO 898-1 §9.1.6.1), mm².
  double get as => math.pi / 4 * ds * ds;
}

const List<MetricThread> metricCoarse = [
  MetricThread(6, 1.0, 8.88, 6.6),
  MetricThread(8, 1.25, 11.63, 9),
  MetricThread(10, 1.5, 14.63, 11),
  MetricThread(12, 1.75, 16.63, 13.5),
  MetricThread(14, 2.0, 19.64, 15.5),
  MetricThread(16, 2.0, 22.49, 17.5),
  MetricThread(18, 2.5, 25.34, 20),
  MetricThread(20, 2.5, 28.19, 22),
  MetricThread(22, 2.5, 31.71, 24),
  MetricThread(24, 3.0, 33.61, 26),
  MetricThread(27, 3.0, 38.0, 30),
  MetricThread(30, 3.5, 42.75, 33),
  MetricThread(33, 3.5, 46.55, 36),
  MetricThread(36, 4.0, 51.11, 39),
];

MetricThread threadByName(String name) => metricCoarse.firstWhere(
  (t) => t.name == name,
  orElse: () => metricCoarse[5],
);

/// Bolt property class: minimum strengths in MPa.
class BoltGrade {
  const BoltGrade(this.id, this.label, this.proof, this.rp, this.rm);
  final String id;
  final String label;

  /// Proof-load stress S_p (ISO 898-1 Table 3/5); stainless: R_p0.2.
  final double Function(double d) proof;

  /// Lower yield / 0.2 % proof strength R_p0.2 min.
  final double Function(double d) rp;

  /// Tensile strength R_m min.
  final double Function(double d) rm;

  bool get stainless => id.startsWith('A');
}

final List<BoltGrade> boltGrades = [
  // ISO 898-1:2013 Table 3: 8.8 changes at d = 16 mm.
  BoltGrade(
    '8.8',
    '8.8 (ISO 898-1)',
    (d) => d <= 16 ? 580 : 600,
    (d) => d <= 16 ? 640 : 660,
    (d) => d <= 16 ? 800 : 830,
  ),
  BoltGrade('10.9', '10.9 (ISO 898-1)', (d) => 830, (d) => 940, (d) => 1040),
  BoltGrade('12.9', '12.9 (ISO 898-1)', (d) => 970, (d) => 1100, (d) => 1220),
  // ISO 3506-1: no proof-load stress; the 0.2 % load (A_s·R_p0.2) is used.
  BoltGrade('A70', 'A2-70 / A4-70', (d) => 450, (d) => 450, (d) => 700),
  BoltGrade('A80', 'A4-80 (stainless)', (d) => 600, (d) => 600, (d) => 800),
];
