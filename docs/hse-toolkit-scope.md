# SafeShift – HSE Toolkit · V1 scope

**Status:** DRAFT scope lock — built 10 Nov 2026; awaiting validation by the FFL HSE team
against site numbers (plan §4 step 3) before release.

Seven tools (V1 hard cap). Every tool ships with its formula sheet, cited standard,
and ≥ 3 worked cases that run in `flutter test` (a failing case fails the build).
Expected values come from published examples where one exists, otherwise from an
independent hand-calculation script written from the standards' equations (kept
outside the repo; not derived from the Dart code).

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | Noise dose & 8-h TWA (OSHA 5 dB or ISO 9612 / EU 3 dB) | OSHA 29 CFR 1910.95 Table G-16a, App. A; OSHA Technical Manual III-5 (80/90 dBA thresholds); ISO 9612:2009; Directive 2003/10/EC | OSHA App. A Table A-1 (50 % ⇒ 85.0, 200 % ⇒ 95.0) + hand calculations (5 cases) |
| 2 | WBGT heat stress (solar / no solar, CAV, TLV / action limit) | ISO 7243:2017 cl. 5 eq. (1)(2), cl. 7, Annex A equations; ACGIH TLV 2021; NIOSH 2016-106 | ASSP *Professional Safety* Aug 2022 "Math Toolbox" worked examples (TLV 28.74 / 25.86, AL 25.62 / 30.84, CAV examples); LSI-Lastem ISO 7243 note (27 / 23 °C at 400 W) (5 cases) |
| 3 | Confined-space purge time (ACH, purge time, fan flow) | Dilution/purge equation with mixing factor K (ACGIH Industrial Ventilation); OSHA 1910.146(c)(5)(ii); NIOSH 80-106; HSE L101 | Hand calculations (4 cases) |
| 4 | Chemical exposure (8-h TWA vs OEL, Brief & Scala, mixture index, ppm ⇄ mg/m³) | OSHA 1910.1000(d)(1)–(2), Table Z-1; ACGIH App. E; Brief & Scala 1975; HSE EH40 | OSHA (d)(1) example 81.25 ppm and (d)(2) example Em = 0.925; ammonia conversions by hand vs Z-1 / ACGIH / EH40 listed values (6 cases) |
| 5 | Fall clearance (EA lanyard / SRL, overhead or foot-level anchor) | ANSI/ASSP Z359.13-2013, Z359.14-2021; OSHA 1910.140(d)(1)–(2), (c)(21) | FallTech worked examples (17 ft EAL, 10 ft SRL, foot-level SRL), WC Safety 18.5 ft example, hand calc (5 cases) |
| 6 | Fire extinguisher coverage (Class A area/number, Class B travel distance) | NFPA 10 (2022) Tables 6.2.1.1, 6.3.1.1 | Table values as reproduced in California CCR Title 19 §568 / §569 + hand calculations (7 cases) |
| 7 | Incident rates (TRIR, DART, LTIR, LTIFR, TRIFR, severity, ILO incidence) | BLS / OSHA 1904 (200 000 h); ILO 16th ICLS 1998 / ILOSTAT (1 000 000 h) | BLS ABC Company example (3.5 / 1.5); ILOSTAT formula example; hand calculations (4 cases) |

## Research notes

- **Noise thresholds (OSHA).** 1910.95(d)(2)(i) integrates 80–130 dB for the hearing
  conservation programme (action level 85 dBA = 50 % dose); PEL compliance (Table G-16)
  counts only ≥ 90 dBA. The tool shows both doses. Table A-1's "16.61·lg(D/100) + 90"
  gives 84.9999 dB at 50 % (16.61 is a rounded 5/lg 2 = 16.6096) — matches the table to 0.1 dB.
- **ISO 9612 vs EU.** LEX,8h is computed with every level (no threshold), normalised to 8 h
  even for 12-h shifts. The EU limit value 87 dB(A) is at the ear *with* hearing protection;
  the action values 80/85 are without. The tool warns rather than applying an attenuation.
- **WBGT reference values — sources disagree.** The ISO 7243:2017 Annex A equations
  (= ACGIH TLV/AL = NIOSH REL/RAL: 56.7 − 11.5 lg M and 59.9 − 14.1 lg M, M in W) do not
  reproduce the rounded values quoted from ISO Table A.1 for unacclimatised workers
  (e.g. class 0 resting: equation 30.8 °C vs table 32 °C; class 1: 28.1 °C vs 29 °C). Secondary
  sources also quote different class-2…4 table values. **The app uses the equations** (more
  conservative where they differ). FFL validator to confirm against the purchased ISO 7243:2017.
- **WBGT naming.** ISO 7243:2017 speaks of "with/without solar load", not indoor/outdoor;
  the choice labels say both.
- **Clothing adjustment values** are the ACGIH 2021 Table 1 / OSHA Technical Manual values
  (0, 0, 0.5, 1, 3, 11 °C). ISO 7243:2017 Annex F has its own list (not checked — standard not
  available); validator to confirm.
- **Purge-equation mixing factor — conventions conflict.** ACGIH uses Q′ = Q/K with K ≥ 1
  (K = 1 perfect); some building texts use Q′ = k·Q with k ≤ 1; one confined-space guide
  multiplies the volume. All are equivalent if applied consistently; the app uses K ≥ 1
  dividing the flow and says so in the input label.
- **ppm ⇄ mg/m³ molar volume.** 24.45 L/mol (ACGIH/OSHA/NIOSH convention, 25 °C) vs the
  ideal-gas value 24.465 L/mol; UK EH40 uses 24.05 (20 °C). The molar volume is an input
  (default 24.45). Ammonia 25 ppm = 17.4 mg/m³ (ACGIH lists 17), 18 mg/m³ in EH40 (20 °C),
  OSHA Z-1 pairs 50 ppm with 35 mg/m³ (exact 34.8).
- **Extended shifts.** OSHA divides by 8 regardless of shift length; ACGIH suggests a
  Brief & Scala reduction for unusual schedules. The tool reports the OSHA TWA and, for
  > 8 h sampled, the B&S factor and adjusted OEL (12 h ⇒ RF 0.5).
- **Fall clearance.** OSHA limits deceleration to 3.5 ft (1.07 m), while Z359.13-2013 allows
  48 in (1.2 m) for 6-ft free-fall absorbers and 60 in (1.5 m) for 12-ft absorbers — the tool
  warns above 3.5 ft. FallTech's foot-level SRL example lists terms 8½ + 1 + 1½ + 5 + 4 but
  prints 19 ft; the terms sum to 20 ft (the case uses 20 ft). Z359.14-2021 caps overhead
  arrest distance at 42 in; foot-level arrest distance is maker-declared.
- **NFPA 10 SI values disagree slightly.** 75 ft is given as 22.7 m (CCR Title 19) and
  22.9 m (NFPA fact sheet 2022); exact is 22.86 m. 30 ft is 9.15 m in CCR vs 9.14 m exact.
  The app converts exactly from the ft / ft² values.
- **Incident rates.** ISO 45001 does not prescribe any rate formula (cl. 9.1 only requires
  monitoring); the "ISO 45001-style" base used by many companies is the ILO 10⁶-hour base.
  ILOSTAT counts scheduled workdays lost; OSHA counts calendar days (capped at 180).

## Template limitations (worked around, `plant_core` not edited)

- No ppm unit: ppm, %LEL and the OEL are dimensionless inputs with the unit in the
  label / suffix; the TWA and mixture modes do not convert units.
- `ListInput` has no unit suffix, so the concentration lists carry the unit in the label.
- No "optional" number input: the incident-rate headcount uses 0 = skip; the purge tool
  always shows the flow needed for the "time available".
- Hours worked are a dimensionless "h" input (the time quantity would offer days/seconds).

## Open items for the FFL validator

1. Provide 3 real site cases per tool (area, inputs, expected result) — add them as `ToolCase`s.
2. Confirm ISO 7243:2017 Table A.1 values vs the Annex A equations, and the Annex F CAV list.
3. Confirm FFL's noise criterion (OSHA 85/90 dBA with 5 dB, or 3 dB / LEX,8h per ISO 9612)
   and the Pakistani / FFL corporate limits to show as pass/fail.
4. Confirm which OEL set FFL uses for ammonia (ACGIH 25 ppm, OSHA 50 ppm, other) and
   whether the ½ OEL action level and Brief & Scala adjustment match FFL practice.
5. Confirm FFL's fall-protection safety margin and default D-ring height / harness stretch,
   and the SRL / lanyard models used on site (label values).
6. Confirm the NFPA 10 edition adopted, the clause numbers quoted in notes (6.2.1 hose
   stations, 6.3.1 lower-rated units, 6.3.2 deep-layer liquids) and whether Class B ratings
   between the two table values may be interpolated (the app uses 30 ft).
7. Confirm FFL's KPI definitions (LTI incl. fatalities? restricted work? contractor hours)
   and the base used in FFL reports.
8. Confirm the purge mixing factor K FFL permits use for vessel entry (default 3).
