/// IAPWS-IF97 core for regions 1, 2 and 4 (IAPWS R7-97(2012)).
///
/// All inputs and outputs are SI: T in K, p in Pa, h in J/kg, s and cp in
/// J/(kg·K), v in m³/kg. Coefficients live in `if97_data.dart` (generated
/// and checked against the release text). Region 3 (near-critical, T > 350 °C
/// above the B23 line) and region 5 (T > 800 °C) are not implemented; callers
/// get an [If97RangeError] instead of an extrapolated value.
library;

import 'dart:math' as math;

import 'if97_data.dart';

/// Specific gas constant of water, Eq. (1): 0.461 526 kJ/(kg·K).
const double if97R = 461.526;

/// Critical point, Eqs. (2) and (3).
const double if97Tc = 647.096; // K
const double if97Pc = 22.064e6; // Pa

/// Region 1/2 upper temperature of the low-T part and the B23 start (350 °C).
const double if97T13 = 623.15; // K
const double if97Tmin = 273.15; // K
const double if97Tmax2 = 1073.15; // K (top of region 2)
const double if97Pmax = 100e6; // Pa

class If97RangeError implements Exception {
  If97RangeError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Properties at one state point.
class If97State {
  const If97State(this.v, this.h, this.s, this.cp, this.region);
  final double v; // m³/kg
  final double h; // J/kg
  final double s; // J/(kg·K)
  final double cp; // J/(kg·K)
  final int region;
}

double _pow(double x, int n) => math.pow(x, n).toDouble();

/// Region 1 (compressed liquid), Eq. (7) and Table 3.
If97State if97Region1(double tK, double pPa) {
  final pi = pPa / 16.53e6, tau = 1386 / tK;
  final a = 7.1 - pi, b = tau - 1.222;
  var g = 0.0, gp = 0.0, gt = 0.0, gtt = 0.0;
  for (var k = 0; k < 34; k++) {
    final n = if97R1N[k], i = if97R1I[k], j = if97R1J[k];
    g += n * _pow(a, i) * _pow(b, j);
    gp += -n * i * _pow(a, i - 1) * _pow(b, j);
    gt += n * _pow(a, i) * j * _pow(b, j - 1);
    gtt += n * _pow(a, i) * j * (j - 1) * _pow(b, j - 2);
  }
  return If97State(
    pi * gp * if97R * tK / pPa,
    tau * gt * if97R * tK,
    (tau * gt - g) * if97R,
    -tau * tau * gtt * if97R,
    1,
  );
}

/// Region 2 (vapour), Eqs. (15)–(17) and Table 12.
If97State if97Region2(double tK, double pPa) {
  final pi = pPa / 1e6, tau = 540 / tK;
  var g0 = math.log(pi), g0t = 0.0, g0tt = 0.0;
  for (var k = 0; k < 9; k++) {
    final n = if97R2N0[k], j = if97R2J0[k];
    g0 += n * _pow(tau, j);
    g0t += n * j * _pow(tau, j - 1);
    g0tt += n * j * (j - 1) * _pow(tau, j - 2);
  }
  final b = tau - 0.5;
  var gr = 0.0, grp = 0.0, grt = 0.0, grtt = 0.0;
  for (var k = 0; k < 43; k++) {
    final n = if97R2N[k], i = if97R2I[k], j = if97R2J[k];
    gr += n * _pow(pi, i) * _pow(b, j);
    grp += n * i * _pow(pi, i - 1) * _pow(b, j);
    grt += n * _pow(pi, i) * j * _pow(b, j - 1);
    grtt += n * _pow(pi, i) * j * (j - 1) * _pow(b, j - 2);
  }
  return If97State(
    pi * (1 / pi + grp) /* γ°π = 1/π */ * if97R * tK / pPa,
    tau * (g0t + grt) * if97R * tK,
    (tau * (g0t + grt) - (g0 + gr)) * if97R,
    -tau * tau * (g0tt + grtt) * if97R,
    2,
  );
}

/// Saturation pressure, Eq. (30). Valid 273.15 K … Tc.
double if97Psat(double tK) {
  final n = if97R4N;
  final th = tK + n[8] / (tK - n[9]);
  final a = th * th + n[0] * th + n[1];
  final b = n[2] * th * th + n[3] * th + n[4];
  final c = n[5] * th * th + n[6] * th + n[7];
  final x = 2 * c / (-b + math.sqrt(b * b - 4 * a * c));
  return _pow(x, 4) * 1e6;
}

/// Saturation temperature, Eq. (31). Valid 611.213 Pa … pc.
double if97Tsat(double pPa) {
  final n = if97R4N;
  final be = math.pow(pPa / 1e6, 0.25).toDouble();
  final e = be * be + n[2] * be + n[5];
  final f = n[0] * be * be + n[3] * be + n[6];
  final g = n[1] * be * be + n[4] * be + n[7];
  final d = 2 * g / (-f - math.sqrt(f * f - 4 * e * g));
  return (n[9] + d - math.sqrt(_pow(n[9] + d, 2) - 4 * (n[8] + n[9] * d))) / 2;
}

/// B23 boundary pressure for a temperature, Eq. (5).
double if97PB23(double tK) {
  final n = if97B23N;
  return (n[0] + n[1] * tK + n[2] * tK * tK) * 1e6;
}

/// Lowest saturation pressure covered (at 273.15 K) and the highest one
/// reachable with regions 1 and 2 (at 623.15 K).
final double if97PsatMin = if97Psat(if97Tmin);
final double if97PsatMax = if97Psat(if97T13);

/// Single-phase properties at (T, p); picks region 1 or 2.
If97State if97State(double tK, double pPa) {
  if (tK < if97Tmin) {
    throw If97RangeError('Below 0 °C: outside IAPWS-IF97.');
  }
  if (tK > if97Tmax2) {
    throw If97RangeError(
      'Above 800 °C: region 5 of IAPWS-IF97 is not included in this tool.',
    );
  }
  if (pPa > if97Pmax) {
    throw If97RangeError('Above 100 MPa: outside IAPWS-IF97.');
  }
  if (tK <= if97T13) {
    return pPa >= if97Psat(tK) ? if97Region1(tK, pPa) : if97Region2(tK, pPa);
  }
  if (tK <= 863.15 && pPa > if97PB23(tK)) {
    throw If97RangeError(
      'Near-critical state (IF97 region 3: above 350 °C and above the B23 '
      'line). Not included in this tool.',
    );
  }
  return if97Region2(tK, pPa);
}
