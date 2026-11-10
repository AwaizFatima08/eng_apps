# VoltWise – Electrical Toolkit · V1 scope

**Status:** DRAFT scope lock — built 10 Nov 2026; awaiting FFL electrical engineer validation
against plant numbers (plan §4 step 3) before release.

Seven tools (V1 hard cap). Every tool ships with its formula sheet, cited standard,
and ≥ 3 worked cases that run in `flutter test` (a failing case fails the build).
Expected values never come from the app's own code: they are standard-table values,
published worked examples, or an independent Python hand-calculation script.

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | Cable sizing & voltage drop (Cu/Al, PVC/XLPE, methods C, E, D1, D2; 1-ph/3-ph; parallel cables) | IEC 60364-5-52:2009 Annex B Tables B.52.2–5, B.52.10–13 (Iz₀), B.52.14–20 (corrections), Annex G (ΔU); IEC 60228 Table 2 (R₂₀); IEC 60287-1-1 (α₂₀) | Standard tables + independent script (6 cases) |
| 2 | Motor current & starter (In, IE3 default η, DOL / star-delta, overload, MPCB, aM fuse, contactors) | IEC 60034-30-1 Table 2 (IE3, 50 Hz); IEC 60947-4-1; IEC 60269 | ABB TAP 7 Annex A example (75 kW → 134 A); ABB M3BP catalogue data; hand calcs (4 cases) |
| 3 | Transformer current & fault level (FLC both sides, kVA from load, Isc infinite / with source MVA) | Schneider EIG ch. G §4; IEC 60076-5 Table 1; IEC 60909 basis | EIG 400 kVA / 420 V / 4 % example (550 A, 13.7 kA); hand calcs (4 cases) |
| 4 | Three-phase power (V + any two of P, Q, S, pf, I; star/delta phase values) | IEC 60050-131/-141 definitions | Hand calcs (4 cases) |
| 5 | Power-factor correction (kvar, C per phase star/delta, current and loss reduction) | Schneider EIG ch. L; IEC 60831-1, IEC 61921 | Eskom kvar/kW multiplier table (0.553, 0.487); hand calcs (4 cases) |
| 6 | Earth rod resistance (single; in line by λ and by Heppe; hollow square; IEEE 142 factor) | BS 7430:2011 §9.5.3–9.5.8, Tables 2/4; BS 7430:1998 Tables 2/3; IEEE 142-2007 §4.1.3, §4.2 | BS 7430 Annex B worked examples (161.54 Ω, 51.169 Ω, 30.959 Ω); Pangonilo example; hand calc (5 cases) |
| 7 | Solar array & battery sizer (panels, battery Ah, inverter; Pakistani city sun hours) | Global Solar Atlas v2 (GTI, optimum tilt); NREL PVWatts v8 losses; SEIAPI design guideline | SEIAPI 2012 worked example (9 × 80 W, 529 Ah); hand calcs (4 cases) |

`flutter test`: 33 tests (31 worked cases + cap check + smoke test), all passing.

## Research notes

### Cable tables (tool 1)
- **Two independent transcriptions** of every ampacity value used (432 values) and every
  correction factor: (a) Top Cable's PDF, which reproduces the IEC 60364-5-52 Ed. 3 pages as
  scans; (b) TiSoft's typed tables (ti-soft.com, IEC 60364-5-52 help pages). B.52.4 and
  B.52.14–18 were also checked against the Schneider Electrical Installation Guide wiki
  (third source). The Dart table (`lib/tools/iec60364_tables.dart`) was diffed value by value
  against the consensus data after formatting.
- **Disagreements found and how they were resolved — FFL validator to confirm:**
  1. B.52.4 PVC Cu 3-loaded D1 120 mm²: the standard's scan reads **292**, which breaks the
     sequence (169, ?, 217); TiSoft and Schneider give **192**. 192 is used.
  2. B.52.10 PVC Cu 3-loaded method E, 70 and 120 mm²: scan **196 / 276** (also Schneider's
     simplified Table C.52.1) vs TiSoft **198 / 278**. The lower (scan) values are used.
- **Method D1/D2 values are the 2009 edition's**, which are lower than the 2001 "method D"
  column many older guides still print — check which edition a catalogue quotes. Schneider's simplified Fig. G23 "D1/D2" column matches neither and was not used.
- **Grouping:** method C uses B.52.17 item 2 (single layer on wall/unperforated tray, no further
  reduction above 9); method E uses B.52.20 (one perforated tray, touching), which has columns
  for 1, 2, 3, 4, 6 and 9 cables only — 5, 7 and 8 take the next larger count (conservative);
  >9 is refused. The second source for B.52.20 is a Lapp catalogue quoting DIN VDE 0298-4
  Table 22 (same structure and values), not the IEC text itself.
- B.52.16 soil factors differ for ducts (D1) and direct burial (D2); the direct-buried row was
  found in Top Cable and Schneider only (TiSoft lists just the duct row).
- **Resistance:** IEC 60228 class 2 values (Bayka table + Lapp/HELU catalogue data agree),
  corrected to the maximum conductor temperature (70 °C PVC, 90 °C XLPE) — conservative.
  Skin effect not included (a note appears from 185 mm²). Reactance default 0.08 Ω/km (EIG).
- An amendment, IEC 60364-5-52:2009/AMD1:2024, exists; none of the sources reflects it.

### Motors (tool 2)
- IE3 table cross-checked between EU Regulation 2019/1781 Annex I Table 2 (draft annex text)
  and ABB technical note 9AKK107319. ABB prints 18.5 kW 2-pole as 82.4 % — a typo; 92.4 %
  used. IEC 60034-30-1 Ed. 2 (2025) was not checked.
- Intermediate ratings take the next lower rated output's IE3 value (conservative). The
  standard's own interpolation rule was not available to verify.
- Formula vs ABB M3BP catalogue currents differ by up to 3 % (catalogue rounding of η and
  cos φ): 7.5 kW 15.2 vs 15.6 A, 30 kW 55.1 vs 54.8 A, 75 kW 132.5 vs 133 A.
- Starter guidance (OL at In or 0.58·In in delta, magnetic trip ≈ 12–13 × In, AC-3 contactor
  ratings for star-delta, aM fuse ≥ In) is from ABB TAP 7 and common maker practice and is
  labelled "typical" in the app. The Schneider GV2 "≈ 13 × Ir" figure was seen only in a
  search snippet.

### Transformer (tool 3)
- Source and transformer per-unit impedances are added arithmetically (both treated as
  reactance), as in simple hand methods; IEC 60909's voltage factor c and KT correction are
  not applied (stated in the notes). The EIG worked example uses the no-load voltage U₂₀.
- IEC 60076-5 minimum impedance help text (4 % ≤ 630 kVA, 5 % ≤ 1250 kVA, 6 % ≤ 2500 kVA)
  is from memory of the 2006 edition — validator to confirm.

### Earthing (tool 6)
- BS 7430 writes R = ρ/(2πL)·(ln(8L/d) − 1) with d = diameter; IEEE 142 (Dwight) writes
  ln(4L/a) − 1 with a = radius — identical. IEEE 80/142 primary texts could not be fetched;
  their forms are from secondary sources.
- **BS 7430 hollow-square λ differs between editions:** 2011 Table 2 prints 5.46, 7.30, 8.22,
  8.95 (4, 8, 12, 16 per side) where 1998 Table 3 has 5.48, 7.36, 8.32, 8.96. The 2011 values
  break the smooth trend and are less conservative; **the 1998 values are used — validator to
  confirm against a purchased copy.** Neither edition has a filled-square table.
- **λ method vs Heppe for rods in line disagree by ~14 %** on BS 7430's own Annex B case
  (6 rods, s = 3.6 m: 35.38 Ω by λ, 30.96 Ω by Heppe). Both are offered; the app notes that
  the larger is safer.
- BS 7430:1998 says the λ method holds for spacing **not less than** the rod length; one
  secondary source (Pangonilo) misquotes it as "less than". The app warns if s < L or
  α > 0.2 (BS 7430:2011 §9.5.8.5 note).
- IEEE 142 factor F table: 2→1.16, 3→1.29, 4→1.36, 6→1.52, 8→1.68, 12→1.80, 16→1.92,
  20→2.00, 24→2.16 (from csemag and AEMC reproductions); intermediate counts interpolated.

### Solar (tool 7)
- City sun hours: Global Solar Atlas v2.2 (Solargis) GTI at optimum tilt, annual mean and
  lowest month. **PVGIS-ERA5 is 7–11 % higher than GSA in Punjab/KP and up to 25 % higher in
  winter** (reanalysis misses fog/smog); NREL NSRDB lies between. In Karachi/Hyderabad the
  worst tilted-plane month is the monsoon (Jul–Aug), not winter. GSA is used as the default.
- Battery presets (LiFePO4 80 % DoD / 95 %, lead-acid 50 % / 80 %) are common practice; no
  primary source was found — labelled typical.
- PV derate default 0.77 = PVWatts 14 % default losses × ≈ 0.90 hot-cell temperature loss.

## Template limitations (no edits made to plant_core)
- No charge unit (Ah): battery capacity is a dimensionless output labelled "Battery capacity, Ah".
- No per-length impedance quantity: cable reactance uses Ω with a "/km" suffix; switching the
  unit to mΩ shows "mΩ/km" (still consistent).
- No integer input type: rod, circuit and cable counts are numbers checked for whole values
  in `compute`.
- No "K·m/W" or "h/day" units: soil resistivity and sun hours use dimensionless inputs with
  a unit suffix.

## Open items for the FFL validator
1. Provide 3 real plant cases per tool (tag, inputs, expected result) — add them as `ToolCase`s.
2. Confirm the three cable-table resolutions above (B.52.4 D1 120 mm² = 192 A; B.52.10 E
   70/120 mm² = 196/276 A) against FFL's purchased IEC 60364-5-52, and whether AMD1:2024
   changed Annex B.
3. Confirm FFL practice for voltage-drop limits (Annex G type B: 6 %/8 %, or plant 5 %
   running / 15 % starting) and whether to use max or actual conductor temperature for R.
4. Confirm the BS 7430 hollow-square λ edition question and whether FFL prefers λ or Heppe
   for rods in line; give typical measured soil resistivity at FFL sites.
5. Confirm IEC 60076-5 minimum impedances and typical 11 kV / 6.6 kV source fault levels at FFL.
6. Confirm the starter guidance wording (overload, MPCB magnetic multiple, aM fuse) against
   FFL's preferred maker coordination tables.
7. Confirm solar defaults (PV derate 0.77, inverter 95 %, battery presets) and the design-month
   choice used by FFL for off-grid/hybrid systems.
