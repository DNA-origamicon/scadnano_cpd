import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/substrand.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';
import 'package:test/test.dart';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:scadnano/src/util.dart' as util;

class ExpectedCPDSite {
  final String t1_id;
  final String t2_id;
  final bool is_conflicted;

  ExpectedCPDSite({required this.t1_id, required this.t2_id, required this.is_conflicted});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpectedCPDSite &&
          runtimeType == other.runtimeType &&
          ((t1_id == other.t1_id && t2_id == other.t2_id) ||
              (t1_id == other.t2_id && t2_id == other.t1_id)) &&
          is_conflicted == other.is_conflicted;

  @override
  int get hashCode => t1_id.hashCode ^ t2_id.hashCode ^ is_conflicted.hashCode;

  @override
  String toString() => 'ExpectedCPDSite(t1: $t1_id, t2: $t2_id, conflicted: $is_conflicted)';
}

void main() {
  group('CPD Rule Tests - Loopout-Loopout', () {
    late Design design;
    late List<IdentifiedTBase> test_identified_t_bases;
    late List<ExpectedCPDSite> expected_sites;
    late Set<String> expected_t_location_ids;

    setUpAll(() async {
      String loopoutTestCasesScContent = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/loopout_loopout_design.sc',
      );
      String identifiedTBasesJsonLog = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/loopout_loopout_identified_t_bases.json',
      );
      String cpdSitesJsonLog = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/loopout_loopout_expected_cpd_sites.json',
      );
      String tBaseLocationsJsonLog = await util.get_text_file_content(
        '../tests_inputs/cpd_detection/loopout_loopout_expected_t_base_locations.json',
      );

      // Load Design from file content
      design = Design.from_json_str(loopoutTestCasesScContent, false)!;

      // Parse IdentifiedTBase log
      final List<dynamic> identified_t_bases_decoded_log = jsonDecode(identifiedTBasesJsonLog);
      test_identified_t_bases =
          identified_t_bases_decoded_log.map((log_entry) {
            String strand_id = log_entry['strand_id'];
            Strand strand = design.strands_by_id[strand_id]!;
            int substrand_idx = log_entry['substrand_idx_in_strand'];
            Substrand substrand = strand.substrands[substrand_idx];
            return IdentifiedTBase(
              source_id: log_entry['source_id'],
              strand: strand,
              substrand: substrand,
              idx_in_substrand_sequence: log_entry['idx_in_substrand_sequence'],
            );
          }).toList();

      // Parse expected CPD sites log
      final List<dynamic> cpd_sites_decoded_log = jsonDecode(cpdSitesJsonLog);
      expected_sites =
          cpd_sites_decoded_log.map((log_entry) {
            return ExpectedCPDSite(
              t1_id: log_entry['t1_stable_id'],
              t2_id: log_entry['t2_stable_id'],
              is_conflicted: log_entry['is_conflicted'],
            );
          }).toList();

      // Parse expected TBaseLocation IDs log
      final List<dynamic> t_base_locations_decoded_log = jsonDecode(tBaseLocationsJsonLog);
      expected_t_location_ids =
          t_base_locations_decoded_log.map<String>((log_entry) => log_entry['stable_id'] as String).toSet();
    });

    test('AdjacentPerfectlyAlignedLoopouts rule processes loopout-loopout_test_cases.sc correctly', () {
      // Find the specific rule definition for AdjacentPerfectlyAlignedLoopouts
      RuleDefinition? loopout_rule = allRuleDefinitions.firstWhere(
        (rule) => rule.ruleName == "AdjacentPerfectlyAlignedLoopouts",
        orElse: () => throw StateError('AdjacentPerfectlyAlignedLoopouts rule not found'),
      );

      // Call the core logic function with only the loopout rule
      CPDDetectionOutput output = detect_cpd_sites_from_t_bases(design, test_identified_t_bases, [
        loopout_rule,
      ]);

      List<String> failureDetails = [];

      // 1. Compare CPD site lengths
      if (output.cpd_sites.length != expected_sites.length) {
        failureDetails.add(
          'Number of CPD sites mismatch. Expected: ${expected_sites.length}, Actual: ${output.cpd_sites.length}',
        );
      }

      // 2. Compare CPD site content
      var actual_sites_set =
          output.cpd_sites.map((s) {
            return ExpectedCPDSite(
              t1_id: s.t1.stable_id,
              t2_id: s.t2.stable_id,
              is_conflicted: s.is_conflicted,
            );
          }).toSet();
      // Convert expected_sites (List) to a Set for comparison
      var expected_sites_set = expected_sites.toSet();

      if (!SetEquality().equals(actual_sites_set, expected_sites_set)) {
        String contentMismatchDetail = 'CPD site content mismatch:';
        var missing = expected_sites_set.difference(actual_sites_set);
        var extra = actual_sites_set.difference(expected_sites_set);

        if (missing.isNotEmpty) {
          contentMismatchDetail +=
              '\n  Expected CPD sites but not found: ${missing.map((e) => e.toString()).toList()}';
        }
        if (extra.isNotEmpty) {
          contentMismatchDetail +=
              '\n  Found CPD sites but not expected: ${extra.map((e) => e.toString()).toList()}';
        }

        failureDetails.add(contentMismatchDetail);
      }

      // 3. Check TBaseLocation IDs
      var actual_t_location_ids = output.t_base_locations.t_bases.map((t) => t.stable_id).toSet();
      // expected_t_location_ids is already a Set<String> from setUpAll

      if (!SetEquality().equals(actual_t_location_ids, expected_t_location_ids)) {
        String tBaseLocationMismatchDetail = 'TBaseLocation ID set mismatch:';
        var missing_ids = expected_t_location_ids.difference(actual_t_location_ids);
        var extra_ids = actual_t_location_ids.difference(expected_t_location_ids);

        if (missing_ids.isNotEmpty) {
          tBaseLocationMismatchDetail +=
              '\n  Expected TBaseLocation IDs but not found: ${missing_ids.toList()}';
        }
        if (extra_ids.isNotEmpty) {
          tBaseLocationMismatchDetail +=
              '\n  Found TBaseLocation IDs but not expected: ${extra_ids.toList()}';
        }

        failureDetails.add(tBaseLocationMismatchDetail);
      }

      if (failureDetails.isNotEmpty) {
        fail('Test failed with the following issues:\n- ${failureDetails.join('\n\n- ')}');
      }
    });
  });
}
