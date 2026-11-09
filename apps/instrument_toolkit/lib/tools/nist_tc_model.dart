import 'dart:math' as math;

/// One range of a NIST ITS-90 reference function:
/// E = Σ c[i]·t^i  (+ a0·exp(a1·(t − a2)²) for type K above 0 °C).
class TcRange {
  const TcRange(this.lo, this.hi, this.coeffs, this.exp);
  final double lo;
  final double hi;

  /// Ascending powers of t, E in mV.
  final List<double> coeffs;
  final (double, double, double)? exp;

  double emf(double t) {
    var e = 0.0;
    for (var i = coeffs.length - 1; i >= 0; i--) {
      e = e * t + coeffs[i];
    }
    final x = exp;
    if (x != null) e += x.$1 * math.exp(x.$2 * (t - x.$3) * (t - x.$3));
    return e;
  }
}

class TcReference {
  const TcReference(this.type, this.composition, this.ranges);
  final String type;
  final String composition;
  final List<TcRange> ranges;

  double get tMin => ranges.first.lo;
  double get tMax => ranges.last.hi;

  /// Lowest temperature from which E(t) is single-valued. Type B has a
  /// minimum near 21 °C, so its inverse is limited to t ≥ 50 °C.
  double get inverseMin => type == 'B' ? 50 : tMin;

  /// EMF in mV vs a 0 °C reference junction.
  double emf(double t) {
    for (final r in ranges) {
      if (t <= r.hi) return r.emf(t);
    }
    return ranges.last.emf(t);
  }

  /// Temperature for an EMF (vs 0 °C), solved on the reference function
  /// itself (bisection), so it is exact to the function rather than to
  /// NIST's approximate inverse polynomials.
  double temperature(double emfMv) {
    var lo = inverseMin, hi = tMax;
    if (emfMv < emf(lo) || emfMv > emf(hi)) return double.nan;
    for (var i = 0; i < 200 && hi - lo > 1e-9; i++) {
      final mid = (lo + hi) / 2;
      if (emf(mid) < emfMv) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }
}
