# HomiLabs Plant Tools

Offline engineering calculators for plant engineers, one Android app per discipline
(plan: `plant-toolkit-apps-plan.md`, names: `docs/app-names.md`).

```
packages/plant_core/       shared template: units, tool model, screens, test harness
apps/instrument_toolkit/   LoopCal – Instrument Toolkit (com.homilabs.loopcal)
apps/lab_toolkit/          TitraLab – Lab Toolkit (com.homilabs.titralab)
apps/hse_toolkit/          SafeShift – HSE Toolkit (com.homilabs.safeshift)
apps/process_toolkit/      FlowSheet – Process Toolkit (com.homilabs.flowsheet)
apps/electrical_toolkit/   VoltWise – Electrical Toolkit (com.homilabs.voltwise)
apps/mechanical_toolkit/   TorqueMate – Mechanical Toolkit (com.homilabs.torquemate)
apps/civil_toolkit/        BeamBook – Civil Toolkit (com.homilabs.beambook)
docs/                      scope locks and research notes per app
tool/                      release_check.sh, coefficient and icon generators
```

## Adding a tool
One file per tool in `apps/<app>/lib/tools/`: a `ToolDef` with inputs (base SI units),
`compute`, formula text, references, and ≥ 3 `ToolCase`s with their source. Add it to the
app's `tools.dart`. `test/tool_cases_test.dart` runs every case.

## Commands
```bash
tool/release_check.sh apps/instrument_toolkit          # gate: analyze + all cases
cd apps/instrument_toolkit && jobq run --name loopcal-apk -- flutter build apk --release
```

All tools are estimates — see the in-app disclaimer.
