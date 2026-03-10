# CPD Feature — Development Plan

Phased implementation roadmap for the probabilistic CPD detection and visualization system.
See [README.md](README.md) for architecture background, [QUICKSTART.md](QUICKSTART.md) for dev server commands.

---

## Phase 0 — Photoproduct Parameter Schema ✅ COMPLETE
*Completed: 2026-03-08*

Establish the JSON schema for photoproduct formation parameters and the Dart model that reads it.

| Deliverable | File | Notes |
|---|---|---|
| Parameter JSON file | `web/cpd_parameters.json` | TT-CPD active; TT-6-4PP and TC-6-4PP as disabled placeholders |
| Dart model | `lib/src/state/cpd_parameters.dart` | Plain immutable class; `from_json()` / `to_json()` |
| Path constant | `lib/src/constants.dart` | `CPD_PARAMETERS_PATH = "cpd_parameters.json"` |
| Schema tests | `test/cpd_parameters_test.dart` | 42 cases: parsing, constraints, round-trip |
| Human checklist | `cpd/VALIDATION_GUIDE_PHASE0.md` | PI/lab review guide |

**Run tests:**
```bash
dart run build_runner test -- test/cpd_parameters_test.dart --platform vm
```

**Pending lab sign-off before Phase 1 weights are changed:**
- PI review of equal-weight decision (all structural_context_weights = 1.0)
- Confirm relative_formation_rate placeholders for TT-6-4PP (0.25) and TC-6-4PP (0.15)

---

## Phase 1 — Probabilistic Rule Engine ✅ COMPLETE
*Completed: 2026-03-08*

Wire the parameter file into the rule engine so that each `CPDSite` carries a `formation_score`
computed from `relative_formation_rate × structural_context_weight`.

| Deliverable | File | Notes |
|---|---|---|
| `RuleDefinition` + `photoproduct_id` + `structural_context_key` | `lib/src/middleware/cpd_rule_helpers.dart` | |
| `CpdCandidate` data class | same | Replaces `Tuple3` in rule processor pipeline |
| `build_rule_definitions(CpdParameters)` factory | same | Computes score from params |
| `_evaluate_rule_for_pair()` → `double?` | same | Returns score on match, `null` on miss |
| `CPDSite.photoproduct_id` (nullable `String?`) | `lib/src/state/cpd_site.dart` + `.g.dart` | |
| `CPDSite.formation_score` (`double`, default 1.0) | same | |
| Async parameter loading | `lib/src/middleware/detect_cpd_sites.dart` | Cached module-level; loads `cpd_parameters.json` via `HttpRequest` on first detection |
| Score proportionality tests | `test/cpd_rules/score_proportionality_test.dart` | 9 cases (Chrome) |

**Architecture note:** `CpdParameters` is stored as a module-level cache in
`detect_cpd_sites.dart`, not in Redux state, to avoid regenerating `app_ui_state.g.dart`.
The fallback (`allRuleDefinitions`, hardcoded score = 1.0) is used if the file hasn't loaded yet.

---

## Phase 2 — Parameter Management UI ✅ COMPLETE
*Completed: 2026-03-08*

Let the user inspect loaded parameters and reload the file without restarting the app.

| Deliverable | File | Notes |
|---|---|---|
| `ReloadCpdParameters` plain action | `lib/src/actions/actions.dart` | No built_value; triggers re-fetch |
| `CpdParametersLoaded` plain action | same | Carries freshly-parsed `CpdParameters` |
| `cpd_parameters_reload_middleware` | `lib/src/middleware/cpd_parameters_reload_middleware.dart` | Fetches JSON, dispatches loaded action, re-triggers detection |
| `CpdParametersLoaded` handler in detect middleware | `lib/src/middleware/detect_cpd_sites.dart` | Syncs module-level cache; exposes `get_loaded_cpd_params()` |
| `lib/src/view/cpd_parameters_panel.dart` | `lib/src/view/cpd_parameters_panel.dart` | Read-only render function: version, per-photoproduct swatch + weights |
| "Reload parameters" button | `lib/src/view/menu.dart` | View → CPD Sites submenu |
| Parameter inspector panel | same | Renders inline below reload button once params loaded |

**Architecture note:** `CpdParameters` is kept in the module-level cache in `detect_cpd_sites.dart`
(not added to `AppUIState`/`.g.dart`) to avoid regenerating the 1087-line generated file.
The panel reads from `get_loaded_cpd_params()` at render time.

---

## Phase 3 — Visualization Upgrade ✅ COMPLETE
*Completed: 2026-03-08*

Encode photoproduct type (color) and formation probability (opacity) in the highlights.

| Deliverable | File | Notes |
|---|---|---|
| Color by `photoproduct_id` | `lib/src/view/design_main_cpd_highlights.dart` | Reads hex from loaded params; falls back to `'pink'` |
| Opacity scaled by `formation_score` | same | Clamped to [0.3, 1.0] so low-score sites remain visible |
| Conflict: red stroke overlay | same | `stroke='red'` + `strokeWidth=1.5`; fill retains photoproduct color |
| `cpd_score_threshold` storable | `app_ui_state_storables.dart` + `.g.dart` | Default 0.0 (show all); persisted to localStorage |
| `CpdScoreThresholdSet` plain action | `lib/src/actions/actions.dart` | |
| `cpd_score_threshold_reducer` | `lib/src/reducers/app_ui_state_reducer.dart` | |
| Min. score threshold input | `lib/src/view/menu.dart` | `MenuNumber` in CPD Sites submenu (step 0.05) |
| Auto-generated legend | `lib/src/view/cpd_parameters_panel.dart` | Color swatches + weights in Phase 2 panel double as legend |

**Deferred:**
- Per-photoproduct filter checkboxes — only 1 enabled product currently; add when TT-6-4PP enabled
- SVG snapshot regression test — requires headless Chrome setup

---

## Phase 4 — Crossover → Thymine Loopout Conversion ✅ COMPLETE
*Completed: 2026-03-08*

Add a workflow to convert a selected crossover into a thymine loopout (to engineer a CPD site).

| Deliverable | File | Notes |
|---|---|---|
| Confirm crossover multi-select works | (pre-existing) | `selectables_store.selected_crossovers` already works |
| Thymine loopout context menu item | `lib/src/view/design_main_strand_crossover.dart` | "convert to thymine loopout" in crossover right-click menu |
| `convert_crossover_to_thymine_loopout()` handler | same | Asks for N thymines; dispatches `ConvertCrossoverToLoopout(xover, N, 'T'×N)`; multi-select dispatches `BatchAction` |
| Reuse existing reducer | `lib/src/reducers/change_loopout_ext_properties.dart` | `convert_crossover_to_loopout_reducer` already accepts `dna_sequence` |
| CPD re-detection | `lib/src/middleware/cpd_auto_trigger_middleware.dart` | Already triggers on `ConvertCrossoverToLoopout` |
| Unit tests | `test/cpd_rules/thymine_loopout_test.dart` | 7 cases: sequence assignment, num_bases, crossover removal, CPD detection |

**Architecture note:** The existing `ConvertCrossoverToLoopout` action already carries an optional `dna_sequence`
field, so no new action class was needed. Multi-select batches individual conversions via `BatchAction` so
each loopout independently receives the thymine sequence.

---

## Phase 5 — PhotoproductJunction Object ✅ COMPLETE (5a–5e done)
*Completed 5a/5b/5c: 2026-03-09*
*Completed 5d/5e: 2026-03-09*
*Assumption: all photoproducts are canonical TT-CPDs (cyclobutane pyrimidine dimer).*

The goal is to let the user "confirm" a detected CPD site into a persistent `PhotoproductJunction`
that: (1) appears as a distinctive icon in the 2D canvas, (2) adds a covalent LINK record to PDB
export, and (3) informs the oxView 3D visualization.

---

### Phase 5a — Data Model & Persistence ✅ COMPLETE

Define the state object, `.sc` schema extension, and Redux wiring.

| Deliverable | File | Notes |
|---|---|---|
| `PhotoproductJunction` state class | `lib/src/state/photoproduct_junction.dart` | Plain immutable Dart class (not Built Value); t1_stable_id/t2_stable_id/photoproduct_id |
| `.sc` JSON key `photoproduct_junctions` | design JSON schema | Top-level array on `Design`; each entry has `t1_stable_id`, `t2_stable_id`, `photoproduct_id` |
| `Design.photoproduct_junctions` field | `lib/src/state/design.dart` | `BuiltList<PhotoproductJunction>`; default empty |
| `MarkAsPhotoproductJunction` action | `lib/src/actions/actions.dart` | Carries `PhotoproductJunction`; dispatched from context menu |
| `UnmarkPhotoproductJunction` action | same | Removes by matching `t1_stable_id`/`t2_stable_id` |
| `ShowPhotoproductJunctionsSet` action | same | Visibility toggle |
| Reducer | `lib/src/reducers/design_reducer.dart` | `photoproduct_junctions_reducer` in composed local reducer |
| De/serialization | `lib/src/state/design.dart` | `from_json` / `to_json` round-trip |
| Schema round-trip test | `test/photoproduct_junction_test.dart` | **Pending** — not yet written |

---

### Phase 5b — 2D Canvas Icon ✅ COMPLETE

Render a small visual marker at each `PhotoproductJunction` in the main scadnano 2D view.

| Deliverable | File | Notes |
|---|---|---|
| `design_main_photoproduct_junctions.dart` | `lib/src/view/` | Connected React component; diamond polygon per junction |
| Icon: diamond (rotated square) at t1/t2 midpoint | same | Distinct from CPD probability circles |
| Icon color from `cpd_parameters.json` photoproduct color | same | Falls back to `'goldenrod'` if params not loaded |
| Click tooltip | same | `title` prop shows photoproduct_id + stable IDs |
| Mount in `DesignMain` | `lib/src/view/design_main.dart` | Added below CPD highlights layer |
| Visibility toggle in menu | `lib/src/view/menu.dart` | "Show photoproduct junctions" boolean under View → CPD Sites |

---

### Phase 5c — Mark / Unmark Workflow ✅ COMPLETE

UI interactions to create and remove `PhotoproductJunction` entries.

| Deliverable | File | Notes |
|---|---|---|
| "Mark as photoproduct junction" context menu item | `lib/src/view/design_main_cpd_highlights.dart` | Right-click on either CPD site circle dispatches `MarkAsPhotoproductJunction` |
| Remove by clicking junction icon | `lib/src/view/design_main_photoproduct_junctions.dart` | Left-click on diamond dispatches `UnmarkPhotoproductJunction` |

---

### Phase 5d — PDB LINK Records ✅ COMPLETE

Emit `LINK` records in the PDB export that describe the covalent C5-C5 / C6-C6 bond of the
cyclobutane ring (canonical CPD: atoms C5 and C6 of each thymine form the four-membered ring).

| Deliverable | File | Notes |
|---|---|---|
| `_format_link_record()` helper | `lib/src/util/pdb_exporter.dart` | Writes two LINK records (C5↔C5 and C6↔C6) for each junction; 78-char PDB spec |
| `junction_stable_id_pairs` + `stable_id_to_pdb_loc` params | `lib/src/util/pdb_exporter.dart` | Optional params with empty defaults; PDB pipeline unaffected |
| Build stable_id → (chain, residue_serial) mapping | `lib/src/middleware/pdb_export.dart` | Uses `t_base_locations.logical_index` + strand index; passes to exporter |
| LINK record format test | `test/pdb_export_test.dart` | Verifies 2 LINK lines, C5/C6 atom names, precede ATOM records, distance 1.57 |

**CPD LINK atom names (canonical TT-CPD):**
```
LINK         C5  DT  A      3              C5  DT  A      5     1.57
LINK         C6  DT  A      3              C6  DT  A      5     1.57
```
Bond length ~1.57 Å for the cyclobutane C-C bond. Thymine residue name read from PDB template.

---

### Phase 5e — oxView / oxDNA CPD Geometry Distortion ✅ COMPLETE

Pull confirmed CPD thymine nucleotide centers together in the oxDNA/oxView export so the
junction is visually apparent in 3D (option B chosen).

| Deliverable | File | Notes |
|---|---|---|
| `_apply_cpd_distortion()` post-processor | `lib/src/middleware/oxdna_export.dart` | Moves both T centers to midpoint; averages normals; silently skips unknown stable_ids |
| `cpd_junctions` + `cpd_t_base_locations` params | `convert_design_to_oxdna_system()`, `to_oxdna_format()`, `to_oxview_format()` | Optional with null defaults; PDB pipeline is unaffected |
| Thread junction data from middleware | `oxdna_export_middleware` (same file) | Passes `design.photoproduct_junctions` + `ui_state.t_base_locations` to both export paths |

**Behavior:** The distortion only applies when junctions are confirmed AND CPD Sites detection
has been run (so `t_base_locations` is populated).  Re-export after marking new junctions.

**Note:** True CPD geometry (ring puckering, backbone distortion) requires all-atom MD
refinement.  The PDB LINK records flag the bond; visualization of distorted geometry is best
done in an external tool (e.g., UCSF Chimera, VMD).

**Deferred:**
- ~~oxView live re-export trigger on `MarkAsPhotoproductJunction` / `UnmarkPhotoproductJunction`~~
  **DONE**: `oxview_update_view_middleware` now triggers on both junction actions; passes
  `cpd_junctions` and `cpd_t_base_locations` to `to_oxdna_format` via `update_oxview_view`.

---

## Phase 6 — Integration & Parameter Update Workflow ✅ COMPLETE
*Completed: 2026-03-09*

Lock down the full pipeline with regression tests and a lab protocol for updating parameters.

| Deliverable | File | Notes |
|---|---|---|
| Lab protocol document | `cpd/PARAMETER_UPDATE_PROTOCOL.md` | When/how to increment schema_version, enabling new photoproducts |
| `test/cpd_parameter_regression_test.dart` | `test/cpd_parameter_regression_test.dart` | 10 cases; pins all weights from v0.1.0; Chrome |
| `test/cpd_end_to_end_test.dart` | `test/cpd_end_to_end_test.dart` | Full pipeline: design → CPD detection → junction → PDB LINK + oxDNA distortion; Chrome |
| oxView live junction re-export | `lib/src/middleware/oxview_update_view.dart` | Trigger on `MarkAsPhotoproductJunction` / `UnmarkPhotoproductJunction`; passes junction data |

**Deferred:**
- `cpd_parameters_version` on exported `.sc` files — architecturally complex; lab notebook recording of schema_version is sufficient for now (see PARAMETER_UPDATE_PROTOCOL.md)

---

## Known Issues (cross-cutting)

| Issue | Location | Priority |
|---|---|---|
| Insertions/deletions not handled in `helix_offset` calc | `t_base_util.dart:104–107` | Medium |
| Loopout-loopout adjacency bug: one-anchor match passes when both required | `cpd_rule_helpers.dart` | Medium |
| oxView loopout z-spacing imperfect at non-zero z_offset | `oxdna_export.dart` loopout block | Low — deprioritized; manual slider adjustment is sufficient |
| Direct global state access during rendering | `design_main_dna_sequence.dart` | Low |
| SVG export incompatible with DOM-based T-base markers | `export_svg.dart` | Low |
