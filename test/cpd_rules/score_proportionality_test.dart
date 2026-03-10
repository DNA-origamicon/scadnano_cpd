// Tests that CPDSite.formation_score reflects the weights in CpdParameters.
//
// Uses the adjacent-domain design (same as adjacent_domain_rule_test.dart) to
// verify that formation_score scales with structural_context_weight.
//
// Run with:
//   dart run build_runner test -- test/cpd_rules/score_proportionality_test.dart

import 'dart:convert';

import 'package:test/test.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/substrand.dart';
import 'package:scadnano/src/state/cpd_parameters.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';
import 'package:scadnano/src/util.dart' as util;

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Creates CpdParameters with TT_CPD enabled and a specific adjacent_domain_ds
/// weight; all other structural context weights are set to 1.0.
CpdParameters _make_params(double adj_domain_weight) {
  return CpdParameters.from_json({
    'schema_version': '0.1.0',
    'last_updated': '2026-03-08',
    'global': {
      'display_threshold': 0.0,
      'conflict_resolution': 'highest_score_wins',
      'watch_bases': ['T'],
    },
    'photoproducts': [
      {
        'id': 'TT_CPD',
        'display_name': 'T-T Cyclobutane Pyrimidine Dimer',
        'abbreviation': 'CPD',
        'color': '#e87d2b',
        'enabled': true,
        'sequence_contexts': [
          {
            'upstream_base': 'T',
            'downstream_base': 'T',
            'relative_formation_rate': 1.0,
          }
        ],
        'structural_context_weights': {
          'adjacent_domain_ds': {'weight': adj_domain_weight},
          'extension_extension': {'weight': 1.0},
          'loopout_loopout': {'weight': 1.0},
          'extension_loopout': {'weight': 1.0},
        },
        'geometry': {'max_interbase_distance_angstrom': 4.0},
        'references': [],
      }
    ],
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. build_rule_definitions() unit tests ───────────────────────────────

  group('build_rule_definitions() — score computation', () {
    test('rule score = relative_formation_rate × structural_weight', () {
      final params_half = _make_params(0.5);
      final params_full = _make_params(1.0);

      final rules_half = build_rule_definitions(params_half);
      final rules_full = build_rule_definitions(params_full);

      final adj_half =
          rules_half.firstWhere((r) => r.structural_context_key == 'adjacent_domain_ds');
      final adj_full =
          rules_full.firstWhere((r) => r.structural_context_key == 'adjacent_domain_ds');

      // score = relative_formation_rate(1.0) × structural_weight
      expect(adj_half.score, closeTo(0.5, 1e-9));
      expect(adj_full.score, closeTo(1.0, 1e-9));

      // Other contexts stay at their own weight (1.0)
      final ext_half =
          rules_half.firstWhere((r) => r.structural_context_key == 'extension_extension');
      expect(ext_half.score, closeTo(1.0, 1e-9));
    });

    test('all four structural context keys present per enabled photoproduct', () {
      final rules = build_rule_definitions(_make_params(1.0));
      final context_keys = rules.map((r) => r.structural_context_key).toSet();
      expect(context_keys, containsAll([
        'adjacent_domain_ds',
        'extension_extension',
        'loopout_loopout',
        'extension_loopout',
      ]));
    });

    test('photoproduct_id propagated to each rule', () {
      final rules = build_rule_definitions(_make_params(1.0));
      for (final rule in rules) {
        expect(rule.photoproduct_id, equals('TT_CPD'));
      }
    });

    test('disabled photoproduct produces no rules', () {
      final params = CpdParameters.from_json({
        'schema_version': '0.1.0',
        'last_updated': '2026-03-08',
        'global': {
          'display_threshold': 0.0,
          'conflict_resolution': 'highest_score_wins',
          'watch_bases': ['T'],
        },
        'photoproducts': [
          {
            'id': 'TT_CPD',
            'display_name': 'disabled',
            'abbreviation': 'CPD',
            'color': '#e87d2b',
            'enabled': false,
            'sequence_contexts': [
              {'upstream_base': 'T', 'downstream_base': 'T', 'relative_formation_rate': 1.0}
            ],
            'structural_context_weights': {
              'adjacent_domain_ds': {'weight': 1.0},
              'extension_extension': {'weight': 1.0},
              'loopout_loopout': {'weight': 1.0},
              'extension_loopout': {'weight': 1.0},
            },
            'geometry': {'max_interbase_distance_angstrom': 4.0},
            'references': [],
          }
        ],
      });
      expect(build_rule_definitions(params), isEmpty);
    });
  });

  // ── 2. CPDSite.formation_score integration ────────────────────────────────

  group('CPDSite.formation_score — adjacent domain design', () {
    late Design design;
    late List<IdentifiedTBase> t_bases;

    setUpAll(() async {
      final sc_content = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/adjacent_domain_design.sc',
      );
      final t_bases_json_str = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/adjacent_domain_identified_t_bases.json',
      );

      design = Design.from_json_str(sc_content, false)!;

      final List<dynamic> decoded = jsonDecode(t_bases_json_str);
      t_bases = decoded.map((entry) {
        final Strand strand = design.strands_by_id[entry['strand_id'] as String]!;
        final Substrand substrand = strand.substrands[entry['substrand_idx_in_strand'] as int];
        return IdentifiedTBase(
          source_id: entry['source_id'] as String,
          strand: strand,
          substrand: substrand,
          idx_in_substrand_sequence: entry['idx_in_substrand_sequence'] as int,
        );
      }).toList();
    });

    test('formation_score equals structural_weight (seq_rate == 1.0)', () {
      for (final weight in [0.25, 0.5, 0.75, 1.0]) {
        final params = _make_params(weight);
        final output = detect_cpd_sites_from_t_bases(design, t_bases, null, params);

        expect(output.cpd_sites, isNotEmpty,
            reason: 'Expected CPD sites from adjacent-domain design');

        for (final site in output.cpd_sites) {
          expect(site.photoproduct_id, equals('TT_CPD'),
              reason: 'Site must carry photoproduct_id from matched rule');
          expect(site.formation_score, closeTo(weight, 1e-9),
              reason: 'formation_score = structural_weight when seq_rate = 1.0; weight=$weight');
        }
      }
    });

    test('detection count is invariant to structural weight', () {
      // Weights change scores only, not which pairs are geometrically detected
      final output_low = detect_cpd_sites_from_t_bases(design, t_bases, null, _make_params(0.1));
      final output_high = detect_cpd_sites_from_t_bases(design, t_bases, null, _make_params(1.0));

      expect(output_low.cpd_sites.length, equals(output_high.cpd_sites.length));
    });

    test('fallback (no params) gives formation_score == 1.0 from allRuleDefinitions', () {
      final output = detect_cpd_sites_from_t_bases(design, t_bases);
      expect(output.cpd_sites, isNotEmpty);
      for (final site in output.cpd_sites) {
        expect(site.formation_score, closeTo(1.0, 1e-9),
            reason: 'allRuleDefinitions hardcodes score = 1.0');
      }
    });
  });
}
