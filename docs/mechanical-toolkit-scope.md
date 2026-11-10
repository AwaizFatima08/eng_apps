# TorqueMate – Mechanical Toolkit · V1 scope

**Status:** DRAFT scope lock — built 10 Nov 2026; awaiting FFL mechanical engineer validation
against plant numbers (plan §4 step 3) before release.

Seven tools (V1 hard cap). Every tool ships with its formula sheet, cited standard,
and ≥ 3 worked cases that run in `flutter test` (a failing case fails the build).

| # | Tool | Method / standard | Worked-case sources |
|---|---|---|---|
| 1 | Bolt torque & preload (M6–M36 coarse; 8.8 / 10.9 / 12.9, A2-70/A4-70, A4-80) | VDI 2230 Part 1:2015 (F_M Tab at ν = 0.9, M_A with µG/µK), ISO 16047, ISO 898-1, ISO 3506-1; nut factor T = K·F·d (Shigley Table 8-15) | VDI 2230 Table A1 values (5 cases, F_M ≤ 0.3 %, M_A ≤ 1 %); hand calcs with ISO 898-1 / 3506-1 data (2 cases) |
| 2 | Belt, pulley & gear ratio (ratio, driven speed, exact open-belt length ⇄ centre distance, wrap, belt speed, torques) | Shigley §17-2 Eq. (17-1); ISO 4184 datum lengths | Shigley Example 17-1 (θ, V) + independent hand-calc script (4 cases) |
| 3 | Bearing L10 life (L10, L10h, Lnm with a1 and user a_ISO, C needed) | ISO 281:2007 §6, Table 12 | Shigley Example 11-1; hand calcs with ISO 281 a1 (4 cases) |
| 4 | Shaft Ø & parallel key (ASME code with K_m/K_t; ASME B106.1M; DIN 6885-1 key; shear and crushing) | ASME shafting code (ASA B17c), ANSI/ASME B106.1M-1985, DIN 6885-1, DIN 6892 (simplified) | Hand calcs; DIN 6885-1 table rows (5 cases) |
| 5 | ISO fits & tolerances (IT5–IT11; holes D–H, JS; shafts c–s, js; ≤ 500 mm; 10 preset fits + custom) | ISO 286-1:2010 Tables 1–3; ISO 286-2:2010 | ISO 286-2 limit values as reproduced by RoyMech (9 cases) |
| 6 | Vibration severity (zones A–D; RMS / peak / pk-pk / in/s) | ISO 20816-3:2022 Annex A = ISO 10816-3:2009 Table A.1 | Standard's boundary table + hand conversions (5 cases) |
| 7 | Regreasing interval (t_f from n·d_m·b_f and C/P, temperature, vertical shaft, outer-ring rotation, cap; G_p) | SKF Bearing maintenance handbook / Rolling bearings catalogue: Diagram 1, Tables 7–8, G_p = 0.005·D·B | SKF Diagram 1 digitised from the PDF vector paths (5 cases, ≤ 2 %) |

## Research notes

- **VDI 2230 table reproduction.** The tool's table preload uses VDI 2230 R5,
  F_M = A_s·ν·R_p0.2/√(1 + 3[1.5·d2/d_s·(P/(π·d2) + 1.155·µG)]²) with A_s from d_s = (d2 + d3)/2.
  It reproduces the VDI 2230 Part 1 Table A1 preloads (Würth DINO technical chapter 6, Tab. 5)
  within 0.4 % for all of M6–M36. Tightening torques match within ≈ 1 % **only** if the
  head bearing Ø d_w = **d_w min of ISO 4014/4017** (not the width across flats s; using s
  over-predicts torque by 2–3 %) and d_h = **medium** hole ISO 273. The d_w values were
  checked by back-solving d_w from the table torques (scratch script `vdi_fit.py`).
- **ν = 0.9 utilisation.** The equivalent stress σ_red shown by the VDI method is the
  same R5 expression, so a VDI-table preload always shows ν = 90 %.
- **Older VDI 2230 (1986) tables give lower values** than the 2003/2015 edition (Bossard notes
  the 2015 values use more of the strength reserve). Plant torque sheets copied from 1986-era
  tables will read about 5–10 % lower — **validator to confirm which edition FFL uses.**
- **Stainless bolts:** ISO 3506-1:2009 gives class 70/80 properties only up to M24
  (larger: by agreement); the 2020 edition may extend this. The app warns above M24.
  ISO 3506-1 has no proof-load stress; the 0.2 % load A_s·R_p0.2 is used for "% of proof".
- **Nut factor K** is very scattered (±25 % or more). Shigley Table 8-15 values are used for
  presets; they are US-practice figures for plated/black finishes.
- **ISO 281 a1 factors:** ISO 281:1990 used 0.62 / 0.53 / 0.44 / 0.33 / 0.21 for 95–99 %;
  ISO 281:2007 uses 0.64 / 0.55 / 0.47 / 0.37 / 0.25 (formula 0.95·[ln(100/S)/ln(1/0.9)]^(2/3) + 0.05).
  Some maker charts and older textbooks still show the 1990 values. The app uses 2007.
  One secondary source (Accendo) rounds 99.9 % to 0.09; the 2007 table value is 0.093.
- **ASME shaft code K_m/K_t:** secondary sources disagree on K_t for "suddenly applied, minor
  shock" (1.0–1.5) vs heavy shock (1.5–3.0); one source lists only 1.0–1.5 for all shock. The
  app takes K_m, K_t as inputs with the common table in the help text.
- **ASME B106.1M** was withdrawn; it survives as Shigley's DE-elliptic equation with M_m = T_a = 0.
- **ISO 286 data** were typed from memory then machine-compared (`check_iso286.py`) against
  RoyMech's ISO 286-1 fundamental-deviation tables (letters c–s, all 25 steps) and ISO 286-2
  h-rows (IT5–IT11 to 400 mm; IT6–IT11 to 500 mm): 0 mismatches. IT5 for 400–500 mm (27 µm)
  was not covered by that source. RoyMech's ISO 286-2 page shows k6 400–500 as "+45/+4",
  which contradicts its own fundamental-deviation table (ei = +5, IT6 = 40 → +45/+5): treated as
  a RoyMech typo. **js/JS:** the app uses exactly ±IT/2 (e.g. js7 18–30 = ±10.5 µm, as in the
  2010 tables); the 1988 edition rounded odd IT7–IT11 values down to even µm.
- **Vibration:** secondary sources agree ISO 20816-3:2022 kept the ISO 10816-3:2009 velocity
  boundaries (G1 rigid 2.3/4.5/7.1, flexible 3.5/7.1/11; G2 rigid 1.4/2.8/4.5, flexible
  2.3/4.5/7.1 mm/s RMS) and widened the speed scope to 120–30 000 rpm. One web glossary
  (Vibromera) lists different numbers (e.g. 0.71/1.8/4.5) — those are ISO 10816-1 style values,
  not part 3. Displacement criteria (needed below 600 rpm) are not implemented.
- **SKF regreasing chart:** SKF publishes Diagram 1 only as a graph. The handbook PDF
  (PUB 10000/2 EN, p. 193) is a vector drawing; the three lines were extracted from the path
  coordinates (`skf_digitize.py`). They are exactly straight on the semi-log grid:
  t_f ≈ 32 000 / 16 000 / 6 400 h × 10^(−A·b_f/400 000) for C/P ≥ 15 / ≈ 8 / ≈ 4
  (fit within 2 % of the drawn lines over 0–800 000 mm/min). The often-quoted older SKF formula
  t_f = K·(14·10⁶/(n·√d) − 4d) and some blog tables (e.g. "nd_m 500 000 → 1 500 h") do **not**
  match the current diagram (it gives ≈ 1 800 h) — not used. SKF gives no numeric factors for
  contamination or vibration ("reduce the interval"); the app takes a user factor.
  Base interval > 30 000 h is capped at 30 000 h (SKF: grease ageing governs).

## Template limitations (plant_core not edited)

- No **angle** unit: wrap angle is shown as a plain number labelled "(°)".
- No **mm/s or in/s velocity** units: vibration input is a dimensionless number with a
  "Reading is" chooser (mm/s RMS, peak, pk-pk, in/s peak, in/s RMS).
- `ToolOutput` has no unit suffix for dimensionless values (speed factor A shown with
  "(mm/min)" in its label).

## Open items for the FFL validator

1. Provide 3 real plant cases per tool (tag, inputs, expected result) — add them as `ToolCase`s
   (e.g. FFL torque sheets for flange/coupling bolts, a pump bearing life, a recorded vibration survey).
2. Confirm the VDI 2230 edition and friction class FFL uses (µ = 0.12 vs 0.14, lubricant),
   and whether site torque sheets are for hex heads with medium holes.
3. Confirm stainless bolt sizes > M24 and the ISO 3506-1 edition used by FFL suppliers.
4. Confirm the K_m / K_t values FFL uses for rotating equipment shafts, and allowable key
   shear / crushing stresses (hub materials, cast-iron hubs).
5. Confirm ISO 286 values against FFL's licensed ISO 286-2 (especially js rounding,
   IT5 400–500 mm) and whether any hole letters K/M/N/P (shaft-basis fits) are needed in V2.
6. Confirm FFL's vibration acceptance practice (ISO 20816-3 zones vs OEM/API 610/API 541
   limits) and whether displacement criteria for slow machines are needed.
7. Compare the regreasing tool with SKF's online calculator (SKF Bearing Select / LubeSelect)
   for 3–5 plant bearings; agree on contamination/vibration factors for FFL areas
   (urea prilling dust, humidity).
8. Archive the independent reference scripts (`ref_cases.py`, `vdi_fit.py`, `vdi_check.py`,
   `skf_digitize.py`, `check_iso286.py`) with the project if FFL wants them audited; they were
   kept outside the repo during the build.
