# LoopCal – Instrument Toolkit · V1 scope

**Status:** DRAFT scope lock — built 10 Nov 2026; awaiting FFL I&C engineer validation
against plant numbers (plan §4 step 3) before release.

Seven tools (V1 hard cap). Every tool ships with its formula sheet, cited standard,
and ≥ 3 worked cases that run in `flutter test` (a failing case fails the build).

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | 4–20 mA scaler (linear / √, NE 43 status) | IEC 60381-1, ISA-50.00.01, NAMUR NE 43 | Hand calculations (7 cases) |
| 2 | 5-point transmitter calibration (as-found/as-left, pass/fail) | ISA-51.1 (% of span), IEC 61298-2 | Hand calculations (4 cases) |
| 3 | Thermocouple & RTD tables (B E J K N R S T; Pt100/500/1000; CJC; tolerance classes) | NIST SRD 60 ITS-90 reference functions; IEC 60584-1; IEC 60751 | Published NIST / IEC 60751 table values (17 cases) |
| 4 | Pressure & head converter (gauge ↔ abs, liquid column) | BIPM SI Brochure, NIST SP 811 | Exact definitions (4 cases) |
| 5 | DP level transmitter range (dry leg, wet leg, dual seals) | Lipták IEH Vol. 1; maker application notes | Hand calculations (3 cases) |
| 6 | Orifice DP ↔ flow | ISO 5167-1/-2 (Reader-Harris/Gallagher C, ε, pressure loss, validity limits) | Independent implementation: `fluids` 1.3.1 (6 cases, match ≤ 2e-5) |
| 7 | Control valve Cv/Kv | IEC 60534-2-1 / ISA-75.01.01 (choked, flashing, Y, Fγ) | IEC 60534-2-1 Annex example + `fluids` 1.3.1 (5 cases) |

## Research notes

- **Thermocouple coefficients** are generated (`tool/gen_tc_coefficients.py`) from NIST SRD 60
  data (public domain). Type K's exponential term a0 = 0.1185976 **mV** (= 118.5976 µV in NIST's
  µV tables) — some hobby code copies it with the wrong unit; our K-type cases at 100, 400,
  1000 and −100 °C match NIST tables to ±0.6 µV.
- **Signal → temperature** solves the reference function directly (bisection), not NIST's
  approximate inverse polynomials, so forward and inverse agree exactly.
- **Thermocouple / RTD tolerance classes:** secondary sources disagree on some edge values
  (e.g. type T/E ranges, class AA coefficient 0.0017 vs 0.00171). The app uses the values
  found in the majority of maker tables and says "verify against IEC 60584-1 Table 12" —
  **FFL validator to confirm against the purchased standards.**
- **Orifice:** while generating references, `fluids` applied gas expansibility to water when
  κ was passed; the app's test harness caught the 1.4 % gap. Liquid references now use ε = 1.
- **Control valve:** the liquid case reproduces the IEC 60534-2-1 Annex worked example
  (Kv ≈ 165 → Cv 190.7). Gas sizing uses N9 with standard flow at 0 °C / 101.325 kPa.

## Open items for the FFL validator

1. Provide 3 real plant cases per tool (tag, inputs, expected result) — add them as `ToolCase`s.
2. Confirm IEC 60584-1 tolerance table entries for types T, E, R, S, B.
3. Confirm FFL's inH₂O convention (4 °C vs 68 °F) for DP transmitter ranging.
4. Confirm whether square-root extraction is done in the transmitter or the DCS (affects tool 1/2 usage notes).
