# TitraLab – Lab Toolkit · V1 scope

**Status:** DRAFT scope lock — built 10 Nov 2026; awaiting FFL QC lab chemist validation
against plant numbers (plan §4 step 3) before release.

Seven tools (V1 hard cap). Every tool ships with its formula sheet, cited standard,
and ≥ 3 worked cases that run in `flutter test` (a failing case fails the build).
Expected values were computed independently of the Dart code by a Python reference
script (`refs.py`, Python 3 + scipy 1.17.1 + iapws 1.5.5, kept outside the repo in the
build session's scratchpad `lab/` folder) or taken from published tables.

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | Dilution & solution prep (C₁V₁ = C₂V₂; mass of solid with purity; volume of conc. acid/base from % w/w + density; M, N or g/L target) | Harris QCA ch. 1; Vogel ch. 10; ISO 6353 (reagent assay) | Hand calculations (7 cases) |
| 2 | Concentration converter (mol/L, mmol/L, eq/L, g/L, mg/L, ppm w/w, % w/v, % w/w) | IUPAC Green Book §2.10; SM 1050 B | Hand calculations (5 cases) |
| 3 | Titration & Kjeldahl N (assay % or mg/L with blank, factor, aliquot; Kjeldahl direct/back-titration, as urea / as NH₃; titrant standardisation) | ISO 5315:1984, ISO 1592:1977 (withdrawn), AOAC 955.04 / 2001.11, SM 2320 B | SM 2320 B formula + hand calculations (6 cases) |
| 4 | Density & temperature (water density, pycnometer with air buoyancy, correction to reference T with γ) | Tanaka et al. 2001 (CIPM), ISO 3507 / ASTM D1217, OIML R 111 | Tanaka eq. evaluated in Python, cross-checked with IAPWS-95 (`iapws`); hand calculations (8 cases) |
| 5 | Moisture & loss on ignition (weighings; wet ⇄ dry basis; result to dry/stated moisture basis) | ISO 11465 cl. 7, ASTM D2216, ASTM D7348, AOAC 950.01 | Hand calculations (6 cases) |
| 6 | Replicate statistics (mean, s, RSD, u = s/√n, Student-t CI 95/99 %, Grubbs high/low with straggler/outlier verdict) | ISO 5725-2 §7.3.4 + Table 5, GUM §4.2, Grubbs & Beck 1972 | ISO 5725-2 Table 5 values (via Harvey, *Analytical Chemistry 2.1* Table 16.7.1), scipy t quantiles, Python `statistics` (6 cases) |
| 7 | Water hardness & conductivity (TH from Ca/Mg; mmol/L, °dH, °fH, gpg, °e; EC → 25 °C linear α; TDS = k·EC) | SM 2340 B, SM 2510 B, SM 1030 E, ISO 7888, ASTM D5391 | SM formulas + published conversion table (Wikipedia "Hard water") + hand calculations (7 cases) |

## Research notes

- **Water density (tool 4).** Tanaka et al., *Metrologia* 38 (2001) 301, eq. 1 with
  a1 = −3.983035 °C, a2 = 301.797 °C, a3 = 522528.9 °C², a4 = 69.34881 °C,
  a5 = 999.974950 kg/m³; air-saturation correction eq. 3 (−4.612×10⁻³ + 0.106×10⁻³·t kg/m³,
  0–25 °C). Checked against IAPWS-95 at 101.325 kPa: |Δ| ≤ 1.2 ppm over 0–40 °C,
  5 ppm at 50 °C, 18 ppm at 60 °C, 88 ppm at 80 °C. The app accepts 0–80 °C and warns
  above 40 °C (outside Tanaka's stated range).
- **Why not ASTM D1250 (tool 4).** The petroleum VCF tables (API MPMS 11.1 / ASTM D1250,
  ISO 91) have product-group constants and differing 1980 vs 2004 rounding/iteration
  rules; reproducing them without the purchased standard and its test data risks a
  4th-decimal disagreement on fuel receipts. Out of scope for V1 (see open items).
  The solution correction uses a user-supplied mean expansion coefficient γ —
  defensible and transparent, but not a property table.
- **Pycnometer.** ρs = (ms/mw)(ρw − ρa) + ρa, ρa = 1.2 kg/m³ (OIML R 111); volume uses
  steel weights at 8000 kg/m³. Relative density T/T is reported as the plain mass ratio.
- **Grubbs critical values (tool 6).** Computed exactly as
  G = (n−1)/√n·√(t²/(n−2+t²)), t = t(1 − α/(2n), n − 2), with Student t from the
  regularised incomplete beta function (no lookup table). This reproduces the values
  quoted for ISO 5725-2 Table 5 (n = 10: 2.290 / 2.482; n = 40: 3.036 / 3.381).
  **Discrepancies found:**
  - ISO's "5 %" and "1 %" columns are **two-sided** levels; ASTM E178 tabulates the same
    numbers under one-sided 2.5 % and 0.5 % headings. Mixing the two tables gives a test
    twice as strict/lenient as intended.
  - Harvey's LibreTexts table lists n = 15, α = 1 % as **2.755** (same as n = 14); the
    formula and other tables give **2.806** — a transcription error in that source.
  - For n = 3 the tables print 1.155 at both levels; the exact 5 % value is 1.15430
    (1 % value 1.15468 rounds to 1.155). The case allows this rounding.
  - ISO 5725-2 only tabulates n ≤ 40; the app uses the formula above 40 and warns.
- **Kjeldahl (tool 3).** ISO 5315 (fertilizers) and ISO 1592 (urea, withdrawn) absorb
  NH₃ in excess standard H₂SO₄ and back-titrate with NaOH; with a blank the absorbing
  acid cancels and %N = (Vb − Vs)·N·f·14.007·DF·100/(W·1000). The boric-acid (direct)
  variant (AOAC 2001.11 style) uses (Vs − Vb). N = 14.007 (CIAAW conventional);
  "as urea" factor 60.056/28.014 = 2.1438, "as NH₃" 17.031/14.007 = 1.2159. AOAC method
  numbers were taken from secondary sources — validator to confirm the edition in use.
- **Conductivity (tool 7).** The 2 %/°C linear coefficient is the common instrument
  default; SM 2510 B gives 0.0191 for KCl solutions. ISO 7888 itself uses a non-linear
  f25 table for natural waters (not implemented). For < 10 µS/cm (boiler feed,
  condensate, demin) the app warns that linear compensation is invalid (ASTM D5391).
  The SM 2510 B coefficient could not be confirmed from a primary text online — flagged.
- **Hardness (tool 7).** SM 2340 B factors 2.497 and 4.118 are used as printed (exact
  ratios 100.09/40.08 = 2.4973, 100.09/24.31 = 4.1172; difference ≤ 0.02 %). °fH is
  exactly 10 mg/L CaCO₃, so 1 mmol/L = 10.009 °fH (some tables round to 10.0 or say
  "1 °fH = 0.1 mmol/L").
- **Template limitations.** No quantity for molar mass (g/mol), normality (eq/L),
  equivalent mass (g/eq), ppm w/w or expansion coefficient: these are dimensionless
  inputs with the unit in the label. The temperature coefficient α uses `percent` with
  "per °C" in the label. `plant_core` was not modified.

## Open items for the FFL validator

1. Provide 3 real lab cases per tool (sample, inputs, reported result) — add them as `ToolCase`s.
2. Confirm the Kjeldahl/total-N method FFL uses for urea and DAP (ISO 5315, AOAC 955.04,
   PS/national standard) and whether results are reported as-is or dry basis.
3. Confirm Grubbs practice: ISO 5725-2 two-sided levels (as implemented) vs ASTM E178.
4. Confirm the conductivity temperature coefficient used for cooling water (2.0 % vs
   1.91 %) and the TDS factor k for FFL's raw/cooling water; decide whether ISO 7888
   non-linear compensation is needed.
5. Decide whether fuel-oil/diesel density correction (ASTM D1250 / ISO 91) is needed in a
   later version; if so, supply the edition and its test data.
6. Confirm moisture methods (oven vs Karl Fischer for urea; drying temperature for DAP)
   — the tool only does the arithmetic.
