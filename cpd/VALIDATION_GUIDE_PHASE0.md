# Phase 0 Validation Guide — Photoproduct Parameter Schema

This document is the sign-off checklist for Phase 0. Complete every section before
beginning Phase 1 (probabilistic rule engine). Record your initials and date next
to each item when it is confirmed.

---

## Contents

1. [What Phase 0 Delivers](#1-what-phase-0-delivers)
2. [Running the Automated Tests](#2-running-the-automated-tests)
3. [Schema Content Review (PI / Lab Sign-off)](#3-schema-content-review)
4. [Manual JSON Smoke Test](#4-manual-json-smoke-test)
5. [Pre-Phase-1 Decisions](#5-pre-phase-1-decisions)
6. [Parameter Update Protocol](#6-parameter-update-protocol)
7. [Sign-off Record](#7-sign-off-record)

---

## 1. What Phase 0 Delivers

| File | Purpose |
|------|---------|
| `web/cpd_parameters.json` | The photoproduct formation parameter file. Served statically at runtime. Updated by researchers as data accumulate. |
| `lib/src/state/cpd_parameters.dart` | Dart model. Parses/serializes the JSON. Not a Built Value — loaded fresh at startup, not Redux-managed yet. |
| `lib/src/constants.dart` → `CPD_PARAMETERS_PATH` | String constant `"cpd_parameters.json"`. Used by the Phase 1 loader. |
| `test/cpd_parameters_test.dart` | 30 automated tests: parsing, value constraints, round-trip, real-file load. |
| This document | Human validation checklist. |

**What Phase 0 does NOT do:**
The parameter file is not yet loaded or used by the application. It is defined and
tested in isolation. Wiring it into the Redux store and rule engine is Phase 1.

---

## 2. Running the Automated Tests

### 2a. Prerequisites

```bash
# From the repo root
dart pub get
dart run build_runner build --delete-conflicting-outputs
```

### 2b. Run just the Phase 0 tests

```bash
dart run build_runner test -- test/cpd_parameters_test.dart --platform vm
```

The `--platform vm` flag is required because the test uses `dart:io` for file
reading (Group 4) and is annotated `@TestOn('vm')`. This bypasses the Chrome
requirement in `dart_test.yaml` without modifying the global test configuration.

Expected output:
```
00:01 +42: All tests passed!
```

### 2c. Run all tests (regression check)

```bash
dart run build_runner test
```

All pre-existing tests must still pass. Phase 0 adds only new tests; it does not
modify any rule-engine logic.

### 2d. Test groups and what they cover

| Group | # Tests | What it checks |
|-------|---------|----------------|
| `CpdParameters parsing` | 12 | Every field parses; `enabled_photoproducts` filters; `photoproduct()` lookup |
| `CpdParameters value constraints` | 14 | Weights in [0,1]; rates non-negative; TT-CPD rate = 1.0; unique IDs; valid hex colors; distinct colors; valid nucleotide bases; required structural keys present; semver format; missing-key defaults |
| `CpdParameters round-trip serialization` | 5 | `parse → to_json → re-parse` produces equal object; no data loss |
| `Real cpd_parameters.json file` | 7 | Loads actual file from `web/`; TT_CPD enabled; TT rate = 1.0; all structural keys present; real-file round-trip |

### 2e. Interpreting failures

| Failure | Likely cause | Fix |
|---------|-------------|-----|
| `Real cpd_parameters.json file` group fails to load | Path resolution issue in test runner | Verify `web/cpd_parameters.json` exists; check test runner base directory |
| `TT_CPD TT rate is 1.0` fails | Someone changed the rate in the JSON | The TT-CPD TT rate must remain 1.0 — it is the normalization anchor for all other values |
| Color uniqueness test fails | Two photoproducts share a color | Assign a visually distinct hex color to each photoproduct |
| Round-trip test fails | A new field was added to the JSON but not to `to_json()` | Update `CpdParameters.to_json()` or the relevant subclass |
| Structural key test fails | A new photoproduct was added without all four context keys | Add missing keys to `structural_context_weights` in the JSON |

---

## 3. Schema Content Review

This section requires review by the PI or a lab member with domain expertise.
Automated tests verify structure; this section verifies scientific correctness.

### 3a. Photoproduct inventory

Confirm the set of photoproducts in `web/cpd_parameters.json` is appropriate for
the current stage of research:

- [ ] **TT_CPD** — T-T Cyclobutane Pyrimidine Dimer — **enabled: true**
  - [ ] TT relative_formation_rate = 1.0 (normalization reference — do not change)
  - [ ] structural_context_weights reflect current understanding of geometry effects
  - [ ] References are correct and accessible

- [ ] **TT_64PP** — T-T 6-4 Photoproduct — **enabled: false**
  - [ ] Placeholder weights (0.25 relative rate) are plausible given published literature
  - [ ] Decision recorded in [Section 5](#5-pre-phase-1-decisions): enable at Phase 1 or keep disabled?

- [ ] **TC_64PP** — T-C 6-4 Photoproduct — **enabled: false**
  - [ ] Placeholder weights (0.15 relative rate) are plausible
  - [ ] Note: enabling this requires extending `watch_bases` to include `"C"` (Phase 1 task)
  - [ ] Decision recorded in [Section 5](#5-pre-phase-1-decisions)

### 3b. Structural context weight sanity check

The four structural contexts map to the four existing CPD detection rules:

| JSON key | Rule | Physical meaning |
|----------|------|----------------|
| `adjacent_domain_ds` | adjacentDomainDoubleStrandRule | Adjacent T's within a continuous ds domain |
| `extension_extension` | adjacentExtensionRule | T's on paired extensions at a crossover |
| `loopout_loopout` | adjacentLoopoutRule | T's on paired loopouts at a crossover |
| `extension_loopout` | extensionLoopoutRule | Mixed extension + loopout pair |

For each enabled photoproduct, verify these questions:

- [ ] Does `extension_extension = 1.0` make sense as the reference context for TT-CPD?
  *(Extensions at crossovers are the most geometrically controlled context in DNA origami.)*

- [ ] Is `adjacent_domain_ds = 0.85` plausible?
  *(B-form helical stacking constrains the interbase angle; this may reduce reactivity slightly vs. extensions.)*

- [ ] Are the loopout weights lower than extension weights? If not, justify.

- [ ] For any future photoproduct added, are all four context keys provided?
  *(Automated test enforces this, but also verify the weights are not just copied from TT-CPD without review.)*

### 3c. Geometry thresholds

- [ ] `max_interbase_distance_angstrom = 4.0` — is this threshold appropriate?
  - B-form DNA stacks at ~3.4 Å; 4.0 Å allows for thermal fluctuation
  - This field is not yet used by the rule engine (Phase 1 will integrate it)
  - Confirm the value is sensible relative to the oxDNA geometry that will be used

### 3d. References

- [ ] At least one reference is provided for each enabled photoproduct
- [ ] The cited papers are the best available sources for the rates used
- [ ] The reference strings follow a consistent citation format (Author, Year, Journal, DOI/page)

---

## 4. Manual JSON Smoke Test

Perform this quick sanity check after any edit to `cpd_parameters.json`:

```bash
# 1. Validate JSON syntax
python3 -c "import json, sys; json.load(open('web/cpd_parameters.json')); print('JSON syntax OK')"

# 2. Check required top-level keys
python3 -c "
import json
data = json.load(open('web/cpd_parameters.json'))
required = ['schema_version', 'last_updated', 'global', 'photoproducts']
missing = [k for k in required if k not in data]
print('Missing keys:', missing if missing else 'none')
"

# 3. Print summary of photoproducts and their enabled status
python3 -c "
import json
data = json.load(open('web/cpd_parameters.json'))
print(f'Schema version: {data[\"schema_version\"]}')
print(f'Photoproducts:')
for p in data['photoproducts']:
    status = 'ENABLED' if p['enabled'] else 'disabled'
    print(f'  {p[\"id\"]:20s} {status}')
"
```

Expected output for the current file:
```
Schema version: 0.1.0
Photoproducts:
  TT_CPD               ENABLED
  TT_64PP              disabled
  TC_64PP              disabled
```

---

## 5. Pre-Phase-1 Decisions

The following decisions must be made before Phase 1 begins. Record the decision
and rationale here.

### Decision 1: Which photoproducts to enable at Phase 1?

**Options:**
- A. Enable only TT_CPD (current setting). Keeps Phase 1 scope minimal; TT-CPD is the
  best-characterized photoproduct for DNA origami. Recommended for initial release.
- B. Enable TT_CPD + TT_64PP. Requires updating structural weights with more data.
  TT-6-4PP is significant (~25% relative yield) so ignoring it understates total
  photoproduct load.
- C. Enable all three. Requires extending watch_bases to ["T","C"] and additional
  sequence-context detection work in the rule engine.

**Decision:** _______________
**Rationale:** _______________
**Recorded by:** _______________ **Date:** _______________

---

### Decision 2: Are the TT-CPD structural context weights final for Phase 1?

Current values: **all equal at 1.0** (updated 2026-03-08).

Rationale: Insufficient in vitro or in silico data to differentiate formation rates
between structural contexts (adjacent-domain ds, extension-extension, loopout-loopout,
extension-loopout). All T-T pairs — whether adjacent on the same strand or unpaired
and adjacent on opposite strands at a junction — are treated as equally likely CPD
candidates until experimental data justify differentiation.

This decision will be revisited when the lab has in-house quantum yield data or MD
simulation results comparing structural contexts.

**Decision:** Equal weights (1.0) for all contexts.
**Recorded by:** (fill in) **Date:** 2026-03-08

---

### Decision 3: Should `schema_version` be incremented before Phase 1?

If any weights or structures are changed during Phase 0 review, increment the minor
version: `0.1.0 → 0.2.0`. If the schema structure itself changes (new keys), increment
the major version: `0.1.0 → 1.0.0`.

**Decision:** _______________
**Recorded by:** _______________ **Date:** _______________

---

## 6. Parameter Update Protocol

This protocol applies from Phase 1 onward, whenever new experimental or simulation
data justify changing parameter values.

### When to update

- New in vitro quantum yield data for a photoproduct type
- New MD simulation results comparing structural contexts
- New literature values superseding the current references
- Enabling a previously-disabled photoproduct

### Steps

1. **Create a git branch** named `cpd-params-vX.Y.Z` (where X.Y.Z is the new version).

2. **Edit `web/cpd_parameters.json`**:
   - Update `schema_version` following semver:
     - Weight changes only → increment **minor** (`0.1.0 → 0.2.0`)
     - New photoproduct type or structural change → increment **major** (`0.1.0 → 1.0.0`)
   - Update `last_updated` to today's date.
   - Update the relevant `notes` field with a one-sentence explanation of what changed.
   - Add or update the `references` list for the changed entry.

3. **Update test baselines** if the change affects expected detection scores.
   - Run `dart run build_runner test -- test/cpd_parameters_test.dart` — all tests must pass.
   - Run `dart run build_runner test` — all pre-existing tests must still pass.
   - If Phase 6 is complete: run `dart run build_runner test -- test/cpd_parameter_regression_test.dart`
     and update pinned baseline values if score changes are intentional.

4. **Open a pull request** with:
   - The updated `cpd_parameters.json`
   - A PR description stating: what changed, why, and the source data/citation.
   - At least one reviewer familiar with the photochemistry.

5. **After merge**, note the `schema_version` that is now live so that previously
   exported designs can be cross-referenced with the parameter version used.

### What NOT to change without major version bump

- Adding a new key to the JSON structure
- Removing an existing key
- Changing the meaning of an existing key (e.g. redefining what `weight` represents)
- Changing the normalization anchor (TT-CPD TT rate must always remain 1.0)

---

## 7. Sign-off Record

| Item | Verified by | Date | Notes |
|------|------------|------|-------|
| Automated tests pass (`cpd_parameters_test.dart`) | | | |
| All pre-existing tests still pass | | | |
| Schema content review complete (Section 3) | | | |
| Manual JSON smoke test passes (Section 4) | | | |
| Pre-Phase-1 Decision 1 recorded | | | |
| Pre-Phase-1 Decision 2 recorded | | | |
| Pre-Phase-1 Decision 3 recorded | | | |
| Phase 0 complete — Phase 1 approved to begin | | | |
