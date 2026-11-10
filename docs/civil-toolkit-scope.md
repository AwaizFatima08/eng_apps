# BeamBook – Civil Toolkit · V1 scope

**Status:** DRAFT scope lock. Built 10 Nov 2026. Awaiting validation by the FFL civil engineer
against plant numbers (plan §4 step 3) before release.

The app has six tools (V1 cap: 7). Every tool ships with its formula sheet, cited standard,
and at least 3 worked cases that run in `flutter test`. A failing case fails the build. Expected
values come from tables, textbook examples or an independent Python hand calculation that was
written from the published case formulas, not from the Dart code.

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | Beam shear, moment & deflection (simple, cantilever, fixed-fixed, propped; point load + UDL) | Macaulay double integration; checked against AISC Manual Table 3-23 / Roark Table 8.1; Ec per ACI 318-19 19.2.2.1; limits ACI Table 24.2.2, IBC 1604.3 (2L for cantilevers) | AISC cases 1, 8, 12, 14, 15, 18, 19, 21 evaluated in a Python script and superposed on a 200 000-point grid (6 cases) |
| 2 | Concrete mix & quantity (volume, rectangle or circular column; 1:1.5:3, 1:2:4, 1:3:6, custom) | Dry-volume factor 1.54 (practice value), cement 1440 kg/m³, 50 kg bags, w/c by mass; IS 456 Table 9 nominal mixes | Published site example (1 m³ of 1:1.5:3 = 8.06 bags) + Python hand calc (5 cases) |
| 3 | Steel section weight (rebar #3–#11 and 10–32 mm, round, square, plate, pipe, angle) | π d²/4·ρ (d²/162 rule shown); ASME B36.10M weight formula; EN 10056-1 angle area with root/toe radii | ASTM A615 Table 1, BS 4449 Table 4, ASME B36.10M table weights, British Steel EA data sheet (9 cases) |
| 4 | Footing / pad sizing (square, B for given L, check B × L) | ACI 318-19 13.3.1.1; gross q_a minus pad + soil weight; e = M/N, kern B/6; no-tension triangular pressure 2N/(3L(B/2 − e)) | Python hand calc, including a closed-form quadratic for sizing with moment (6 cases) |
| 5 | Earthwork volume (chainage and area lists) | Average end area; prismoidal (Simpson 1/3) with odd/equal-spacing checks; swell/shrinkage | Basak, *Surveying and Levelling* ch. 8 problems 1, 3, 4 + hand calcs for even and unequal spacing (5 cases) |
| 6 | Paint & coating quantity (area, pipe, tank shell + flat/cone roof) | TSR = VS%·10/DFT µm; PSR = TSR·(1 − loss); WFT; ISO 12944-5, ISO 3233-1, SSPC-PA 2; API 650 cone slope | Data-sheet rule example, 1604 ft²/gal constant, Python hand calc (4 cases) |

Hand-calc scripts are in `beam_hand.py` and `other_hand.py`, in the session scratchpad
(`civil/`). They were not committed. They can be added to `tool/` if the validator wants them
in the repo.

## Research notes

- **Beam:** the tool solves EI·y″ = M with Macaulay brackets, so a point load and a UDL are
  exact when superposed. Max moment is found at the supports, under P, or at the zero-shear
  points (all exact). Max deflection is found by a 400-point scan plus golden-section search.
  The Python reference uses the AISC table formulas in their own coordinates (simple or free end
  on the left), so it is independent of the app's method. The AISC propped-cantilever UDL
  deflection "wL⁴/185EI" is rounded: the exact coefficient is 1/184.6. The cases use the exact
  value (0.52266 mm against 0.52163 mm from the rounded formula).
- **E presets:** steel is 200 GPa. AISC uses 29 000 ksi = 199.9 GPa, a 0.05 % difference.
  Concrete uses Ec = 4700√fc′ MPa (ACI 318-19 19.2.2.1(b), normalweight). For concrete the tool
  always warns that gross I ignores cracking (I_e, ACI 24.2.3.5) and long-term λΔ (24.2.4).
- **Dry-volume factor: sources disagree.** Secondary sources (Indian and Pakistani civil blogs,
  estimating notes) give 1.54 most often. They also give 1.52 (often linked to IS practice),
  1.50–1.57, and 1.57. No code gives a value. It is an editable input (default 1.54), and the tool
  warns outside 1.50–1.57. **FFL validator to confirm the value FFL estimators use.**
- **Cement bag volume:** 50 kg / 1440 kg/m³ = 0.0347 m³ = 1.226 cft. Pakistani site practice
  often rounds this to "1.25 cft per bag". Using 1.25 cft gives 1.9 % fewer bags. The tool keeps
  density as an input and shows the bag volume in cft. **Validator to confirm.**
- **Nominal mixes:** IS 456 Table 9 defines nominal mixes by kg of aggregate per 50 kg bag. The
  1:1.5:3 / 1:2:4 / 1:3:6 labels are the traditional volume equivalents. ACI 318 (and the
  Building Code of Pakistan, which refers to it) expects designed mixes. The tool says so in a note.
- **Rebar:** the app uses ASTM nominal diameters (n/8 in; #9–#11 per Table 1). π d²/4·7850
  matches ASTM table weights to ≤ 0.11 % (ASTM bases them on 490 lb/ft³ = 7849 kg/m³) and
  BS 4449 masses to ≤ 0.04 %. The d²/162 rule is 0.12 % high (7850·π/4·10⁻⁶ = 1/162.2). It is
  shown as a note.
- **Pipe:** the geometric formula equals ASME B36.10M's W = 0.0246615(D − t)t (kg/m) and
  10.69(D − t)t (lb/ft). It matches table weights (NPS 4 and 12) within 0.15 %.
- **Angles:** EN 10056-1 area is t(2a − t) + 0.2146(r₁² − 2r₂²), with r₂ = r₁/2 in the standard.
  Generalised here to unequal legs as t(a + b − t). Sharp corners (r = 0) read about 1 % light.
  The results match the British Steel data sheet (150×150×15, 120×120×10) to 3 significant figures.
- **Footing:** the plan's A = (P + W)/q_a is solved exactly as A = P/(q_a − w), with w the pad
  plus soil weight per m². With a moment, the pad and soil weight is added to N before e = M/N.
  q_a is taken as **gross**. Textbooks differ on gross versus net allowable (Das uses net
  q_net = q_gross − γDf in places). A wrong choice changes the area by roughly γ·Df / q_a.
  **Validator to confirm how FFL soil reports state q_a.**
- **Earthwork:** for an even number of sections, Simpson's rule is applied to the first n − 1 and
  end areas to the last strip (Punmia/Basak practice), with a warning. For unequal spacing the
  tool falls back to end areas, with a warning. Basak's printed answers are reproduced exactly.
- **Coating loss convention: sources disagree.** Data sheets use PSR = TSR × (1 − loss). Some
  estimators instead add wastage (× (1 + loss)), which gives less paint (30 %: ×1.30 against
  ×1.43). Some makers quote a "consumption factor" CF = 1/(1 − loss), and some literature calls
  1/CF the "loss factor". The app defines loss as the **fraction of paint lost** and uses
  (1 − loss). **Validator to confirm FFL's paint-estimating convention.**

## Template limitations (plant_core not edited)

- There is no unit-weight quantity (kN/m³ ⇄ pcf). Footing γc and γs are dimensionless inputs
  with a "kN/m³" suffix, so imperial users must convert (150 pcf = 23.6 kN/m³).
- There is no spreading-rate quantity (m²/L ⇄ ft²/gal). The tool gives two dimensionless outputs,
  in m²/L and ft²/gal.
- `Units.byId` silently falls back to the first unit for an unknown id. All case unit ids were
  checked by hand.

## Open items for the FFL validator

1. Provide 3 real plant cases per tool (tag, inputs, expected result). They will be added as
   `ToolCase`s.
2. Confirm the dry-volume factor (1.52 / 1.54 / 1.57) and the bag volume (1.226 against
   1.25 cft) used at FFL.
3. Confirm whether soil reports give gross or net allowable bearing pressure, and whether
   partial contact (e > B/6) is accepted for wind or seismic combinations at FFL.
4. Confirm the deflection limits to offer (L/360 live, L/240 total, L/180 roofs; 2L for
   cantilevers) and whether pipe-rack or crane-girder limits (e.g. L/600–L/1000) are needed.
5. Confirm the paint loss convention and typical FFL loss percentages per application method.
6. Decide whether to add a cracked-section I_e (ACI 24.2.3.5) option for concrete beams in V2.
