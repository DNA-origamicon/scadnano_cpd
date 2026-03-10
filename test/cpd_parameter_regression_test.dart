// Regression test: pins the known CPD parameter values from web/cpd_parameters.json v0.1.0.
//
// Purpose: catch unintended score changes when cpd_parameters.json is edited.
// When parameters are intentionally updated, increment schema_version and update
// the pinned constants below per cpd/PARAMETER_UPDATE_PROTOCOL.md.
//
// Run with:
//   dart run build_runner test -- test/cpd_parameter_regression_test.dart --platform chrome

import 'dart:async';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:scadnano/src/state/cpd_parameters.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';
import 'package:scadnano/src/util.dart' as util;

// ── Pinned constants for schema_version 0.1.0 ─────────────────────────────
// Update these values AND the assertion below whenever schema_version changes.
const String _pinned_schema_version = '0.1.0';
const String _pinned_photoproduct_id = 'TT_CPD';
const double _pinned_adj_domain_ds = 0.5;
const double _pinned_extension_extension = 1.0;
const double _pinned_loopout_loopout = 1.0;
const double _pinned_within_loopout = 0.75;
const double _pinned_extension_loopout = 1.0;
const double _pinned_relative_formation_rate = 1.0;
const int _pinned_disabled_count = 2; // TT_64PP and TC_64PP

void main() {
  group('CPD parameter regression — schema_version $_pinned_schema_version', () {
    late CpdParameters params;

    setUpAll(() async {
      final json_str = await util.get_text_file_content('../web/cpd_parameters.json');
      params = CpdParameters.from_json(jsonDecode(json_str));
    });

    test('schema_version is pinned value', () {
      expect(params.schema_version, equals(_pinned_schema_version),
          reason: 'If schema_version changed, update pinned constants in this test '
              'per cpd/PARAMETER_UPDATE_PROTOCOL.md');
    });

    test('exactly one enabled photoproduct ($_pinned_photoproduct_id)', () {
      final enabled = params.photoproducts.where((p) => p.enabled).toList();
      expect(enabled.length, equals(1));
      expect(enabled.first.id, equals(_pinned_photoproduct_id));
    });

    test('disabled photoproduct count is $_pinned_disabled_count', () {
      final disabled = params.photoproducts.where((p) => !p.enabled).toList();
      expect(disabled.length, equals(_pinned_disabled_count));
    });

    test('TT_CPD relative_formation_rate is pinned', () {
      final tt_cpd = params.photoproduct(_pinned_photoproduct_id)!;
      expect(tt_cpd.sequence_contexts.first.relative_formation_rate,
          closeTo(_pinned_relative_formation_rate, 1e-9));
    });

    test('TT_CPD structural_context_weights are pinned', () {
      final tt_cpd = params.photoproduct(_pinned_photoproduct_id)!;
      final w = tt_cpd.structural_context_weights;

      expect(w['adjacent_domain_ds']!.weight, closeTo(_pinned_adj_domain_ds, 1e-9),
          reason: 'adj_domain_ds weight changed — update pinned value and schema_version');
      expect(w['extension_extension']!.weight, closeTo(_pinned_extension_extension, 1e-9));
      expect(w['loopout_loopout']!.weight, closeTo(_pinned_loopout_loopout, 1e-9));
      expect(w['within_loopout']!.weight, closeTo(_pinned_within_loopout, 1e-9));
      expect(w['extension_loopout']!.weight, closeTo(_pinned_extension_loopout, 1e-9));
    });

    group('build_rule_definitions() scores match pinned weights', () {
      late List<RuleDefinition> rules;

      setUp(() {
        rules = build_rule_definitions(params);
      });

      test('rule count equals number of enabled structural contexts', () {
        // One rule per structural_context_weight entry in TT_CPD (5 entries).
        expect(rules.length, equals(5));
      });

      test('all rules carry photoproduct_id TT_CPD', () {
        for (final rule in rules) {
          expect(rule.photoproduct_id, equals(_pinned_photoproduct_id));
        }
      });

      test('adjacent_domain_ds score = rate × weight = $_pinned_relative_formation_rate × $_pinned_adj_domain_ds', () {
        final rule = rules.firstWhere((r) => r.structural_context_key == 'adjacent_domain_ds');
        expect(rule.score, closeTo(_pinned_relative_formation_rate * _pinned_adj_domain_ds, 1e-9));
      });

      test('extension_extension score = $_pinned_extension_extension', () {
        final rule = rules.firstWhere((r) => r.structural_context_key == 'extension_extension');
        expect(rule.score, closeTo(_pinned_relative_formation_rate * _pinned_extension_extension, 1e-9));
      });

      test('loopout_loopout score = $_pinned_loopout_loopout', () {
        final rule = rules.firstWhere((r) => r.structural_context_key == 'loopout_loopout');
        expect(rule.score, closeTo(_pinned_relative_formation_rate * _pinned_loopout_loopout, 1e-9));
      });

      test('within_loopout score = $_pinned_within_loopout', () {
        final rule = rules.firstWhere((r) => r.structural_context_key == 'within_loopout');
        expect(rule.score, closeTo(_pinned_relative_formation_rate * _pinned_within_loopout, 1e-9));
      });

      test('extension_loopout score = $_pinned_extension_loopout', () {
        final rule = rules.firstWhere((r) => r.structural_context_key == 'extension_loopout');
        expect(rule.score, closeTo(_pinned_relative_formation_rate * _pinned_extension_loopout, 1e-9));
      });
    });
  });
}
