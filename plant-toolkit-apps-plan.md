# HomiLabs Plant Tools — 7-App Plan

**Status:** DRAFT — not locked. Items under "Decisions pending" must be confirmed before any code is written.
**Date:** 2026-11-09
**Owner:** Homi (HomiLabs)

---

## 1. Decision summary

- Seven separate Android apps, one per plant discipline.
- Built strictly one at a time; the next app starts only after the previous one is released and backed up.
- A shared code template is built first (Phase 0) and reused by all seven.
- Each tool ships only with a cited formula/standard and passing test cases validated by a discipline engineer at FFL.

## 2. Build order

| Cycle | App | FFL validator | Reason for position |
|---|---|---|---|
| 0 | Shared template | — | Everything else depends on it |
| 1 | Instrument Toolkit | I&C engineer | Thin competition, daily use, simple formulas |
| 2 | Lab Toolkit | QC lab chemist | Thin competition, chemistry well understood |
| 3 | HSE Toolkit | Homi / HSE team | No external dependency for validation |
| 4 | Process Toolkit | Process engineer | Highest value, hardest formulas — template mature by then |
| 5 | Electrical Toolkit | Electrical engineer | Crowded market; solar/battery sizer is the local hook |
| 6 | Mechanical Toolkit | Mechanical engineer | Crowded market |
| 7 | Civil Toolkit | Civil engineer | Most crowded, least plant-specific |

## 3. Phase 0 — Shared template

Repo: `plant-toolkit-template`

Deliverables:
- Home screen: list of tools with search.
- Tool screen: inputs with unit pickers → result(s) → expandable "Formula & reference" sheet.
- Settings: unit system (SI / Imperial), theme.
- Tool definition pattern: one file per tool containing inputs, formula, outputs, reference standard, and ≥3 test cases.
- Unit handling layer (pressure, temperature, flow, length, mass, power, etc.) written once.
- Test harness: all tool test cases run on every build; a failing case blocks release.
- Shared branding: icon style, colour scheme, naming pattern "*Discipline* Toolkit".
- Disclaimer text (estimation only, verify against governing standard) shown on first launch and in About.
- Offline; no login; no analytics beyond Play Console defaults; no ads.

Exit criteria: template builds, runs, has one dummy tool passing its tests, and is committed/pushed/backed up.

## 4. Per-app cycle (repeated 7 times)

1. **Scope lock** — tool list (5–7 tools), formula and cited standard per tool, ≥3 worked test cases per tool supplied or confirmed by the FFL validator. Written document, confirmed by Homi. No code before this.
2. **Build** — clone template, add one tool file, run tests, verify on device, then add the next.
3. **Validate** — FFL validator checks results against real plant numbers; defects fixed before release.
4. **Release** — Play Store listing, screenshots, disclaimer, privacy policy page on homilabs site.
5. **Close** — git commit + push, local snapshot, Google Drive sync. Only then start the next app.

## 5. Candidate tool lists (to be confirmed at each app's scope lock)

### Instrument Toolkit
- 4–20 mA ↔ engineering units
- Orifice DP ↔ flow
- Thermocouple / RTD tables
- Control valve Cv
- Transmitter 5-point calibration (0/25/50/75/100 %)
- Pressure / level unit converter

### Lab Toolkit
- Solution / dilution (C1V1 = C2V2)
- Normality / molarity / ppm conversions
- Titration result
- Density temperature correction
- % moisture / loss on ignition
- Mean, SD, RSD, uncertainty
- Water hardness / TDS / conductivity conversions

### HSE Toolkit
- Noise dose and 8-hr TWA
- WBGT heat stress index
- Confined-space ventilation (air changes)
- Chemical exposure 8-hr TWA vs TLV
- Fall-protection clearance
- Fire extinguisher coverage
- Incident rates (TRIR, LTIFR)

### Process Toolkit
- Pipe flow and pressure drop (Darcy–Weisbach)
- Pump head, NPSH, power
- Heat exchanger LMTD / duty
- Steam properties
- Tank volume (vertical, horizontal, dished ends) with level chart
- Orifice / relief sizing (simplified)
- Plant unit converter

### Electrical Toolkit
- Cable sizing and voltage drop
- Motor FLA / breaker / starter
- Transformer kVA
- Three-phase power
- Power-factor correction capacitor
- Earthing resistance
- Solar array + battery bank sizer

### Mechanical Toolkit
- Bolt torque / preload
- Belt & pulley / gear ratio
- Bearing L10 life
- Shaft and key sizing
- ISO fits and tolerances
- Vibration severity lookup
- Lubrication interval estimator

### Civil Toolkit
- Beam shear / moment / deflection
- Concrete mix and quantity
- Steel section weight
- Footing / pad sizing
- Earthwork volume
- Paint / coating area

## 6. Rough effort

- Template: ~3 weeks.
- Each app: 2–3 weeks once template exists.
- Whole family: ~6 months if worked continuously; longer alongside other projects.

## 7. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Seven listings dilute reviews and ranking | Structure code so the seven apps can be merged into one suite later via a build flag |
| Wrong formula relied on in the field | Cited standard per tool, ≥3 test cases, FFL validation, visible disclaimer |
| Validator unavailable, cycle stalls | Allow cycle order to swap (e.g. HSE before Lab) without changing anything else |
| Scope creep per app | Hard cap of 7 tools per app in V1; extras go to a V2 list |
| Project competes with other HomiLabs work | One app at a time; no parallel cycles |

## 8. Decisions pending (confirm before Phase 0 starts)

1. Stack: Flutter — yes / no
2. Family name "HomiLabs Plant Tools" and pattern "*Discipline* Toolkit" — yes / change
3. Template first, then Instrument Toolkit — yes / no
4. Merge-later-capable structure — yes / no
5. V1 free, offline, no ads — yes / no

## 9. Out of scope for V1 (all apps)

- User accounts, cloud sync, sharing
- Ads or in-app purchases
- iOS builds
- Report / PDF export
- Any tool not on the confirmed scope-lock list for that app
