# CPD Parameter Update Protocol

Guidelines for updating `web/cpd_parameters.json` and maintaining reproducibility.

---

## When to Update Parameters

| Change type | `schema_version` bump | Regression test update required |
|---|---|---|
| Adjust existing weight values | Minor (0.x.0 → 0.y.0) | Yes |
| Add a new photoproduct entry | Minor | Yes |
| Enable a disabled photoproduct | Minor | Yes |
| Rename a field or change JSON structure | Major (x.0.0 → y.0.0) | Yes — update `cpd_parameters.dart` parser too |
| Fix a typo in a `description` string | Patch (0.0.x → 0.0.y) | No |

**Semantic versioning rules for `schema_version`:**
- `MAJOR`: Breaking schema change — any code that parses the old file must be updated.
- `MINOR`: New photoproduct, new structural context key, or weight update (backward-compatible new data).
- `PATCH`: Documentation-only edits (descriptions, comments).

---

## Step-by-Step Update Procedure

1. **Edit `web/cpd_parameters.json`**
   - Increment `schema_version` per the rules above.
   - Record the change and rationale in `cpd/PARAMETER_CHANGELOG.md` (create if absent).

2. **Run unit tests locally**
   ```bash
   # VM tests (schema parsing + round-trip)
   dart run build_runner test -- test/cpd_parameters_test.dart --platform vm

   # Chrome tests (rule scoring)
   dart run build_runner test -- test/cpd_rules/score_proportionality_test.dart --platform chrome
   dart run build_runner test -- test/cpd_parameter_regression_test.dart --platform chrome
   ```

3. **Update pinned expected scores in `test/cpd_parameter_regression_test.dart`**
   - Change the `expected_*` constants to reflect the new weights.
   - The test explicitly loads `web/cpd_parameters.json` via `HttpRequest`, so it always tests
     the live file.

4. **Commit with the schema_version in the commit message**, e.g.:
   ```
   cpd: bump cpd_parameters.json to 0.2.0 — TT-CPD adj_domain_ds weight 0.5→0.7
   ```

5. **Notify collaborators** if the change affects interpretation of previously exported `.sc` files.
   Existing designs do NOT embed the parameter version; users must re-run CPD detection after
   an update to get new scores.

---

## Enabling a Disabled Photoproduct

Currently `TT-6-4PP` and `TC-6-4PP` are disabled (`"enabled": false`).  To enable one:

1. Set `"enabled": true` in the JSON entry.
2. Set a non-zero `relative_formation_rate` (discuss with PI).
3. Set `structural_context_weights` values (start equal at 1.0 until experimental data).
4. Add test cases in `score_proportionality_test.dart` for the new photoproduct.
5. Add filter checkbox in the CPD submenu (deferred; see Phase 3 deferred items in DEVELOPMENT_PLAN.md).

---

## Reproducibility Note

The current architecture does **not** embed the parameter version in exported `.sc` files or PDB files.
This is a Phase 6 deferred item (`cpd_parameters_version` field on exported designs).  In the meantime,
record which `schema_version` was active when performing a CPD analysis session in your lab notebook.
