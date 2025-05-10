import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/substrand.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';
import 'package:test/test.dart';
import 'dart:convert';
import 'package:collection/collection.dart';


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

// Prepare Test Data from Captured Logs
const String identifiedTBasesJsonLog = '''
[{"source_id":"tb-strandstrand_H1_12_forward-_\$Loopout-loopout_1_strand_H1_12_forward-hna-ona-l7-p2-fwd","strand_id":"strand-H1-12-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H0_20_reverse-_\$Loopout-loopout_1_strand_H0_20_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_20_reverse-_\$Domain-substrand_H1_17_22_forward-h1-o17-l7-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_idx_in_strand":2,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_3_forward-_\$Loopout-loopout_1_strand_H0_3_forward-hna-ona-l5-p2-fwd","strand_id":"strand-H0-3-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H1_9_reverse-_\$Domain-substrand_H1_6_10_reverse-h1-o9-l0-p0-rev","strand_id":"strand-H1-9-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_9_reverse-_\$Loopout-loopout_1_strand_H1_9_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H1-9-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_33_reverse-_\$Domain-substrand_H1_29_34_reverse-h1-o33-l0-p0-rev","strand_id":"strand-H1-33-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_33_reverse-_\$Loopout-loopout_1_strand_H1_33_reverse-hna-ona-l5-p0-fwd","strand_id":"strand-H1-33-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_25_forward-_\$Loopout-loopout_1_strand_H1_25_forward-hna-ona-l4-p0-fwd","strand_id":"strand-H1-25-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_36_forward-_\$Loopout-loopout_1_strand_H1_36_forward-hna-ona-l4-p0-fwd","strand_id":"strand-H1-36-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_43_reverse-_\$Loopout-loopout_1_strand_H0_43_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H0-43-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_43_reverse-_\$Domain-substrand_H1_40_45_forward-h1-o40-l7-p0-fwd","strand_id":"strand-H0-43-reverse","substrand_idx_in_strand":2,"idx_in_substrand_sequence":0}]''';

const String cpdSitesJsonLog = '''
[{"t1_stable_id":"tb-strandstrand_H1_12_forward-_\$Loopout-loopout_1_strand_H1_12_forward-hna-ona-l7-p2-fwd","t2_stable_id":"tb-strandstrand_H0_20_reverse-_\$Loopout-loopout_1_strand_H0_20_reverse-hna-ona-l4-p0-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H0_3_forward-_\$Loopout-loopout_1_strand_H0_3_forward-hna-ona-l5-p2-fwd","t2_stable_id":"tb-strandstrand_H1_9_reverse-_\$Loopout-loopout_1_strand_H1_9_reverse-hna-ona-l4-p0-fwd","is_conflicted":false}]''';

const String tBaseLocationsJsonLog = '''
[{"stable_id":"tb-strandstrand_H1_12_forward-_\$Loopout-loopout_1_strand_H1_12_forward-hna-ona-l7-p2-fwd","strand_id":"strand-H1-12-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":7,"precise_offset":2,"forward":true,"sequence_element_id":"loopout-1-strand-H1-12-forward","sequence_position":2,"parent_element_id":"tb-strandstrand_H1_12_forward-_\$Loopout-loopout_1_strand_H1_12_forward-hna-ona-l7-p2-fwd"},{"stable_id":"tb-strandstrand_H0_20_reverse-_\$Loopout-loopout_1_strand_H0_20_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":0,"forward":false,"sequence_element_id":"loopout-1-strand-H0-20-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H0_20_reverse-_\$Loopout-loopout_1_strand_H0_20_reverse-hna-ona-l4-p0-fwd"},{"stable_id":"tb-strandstrand_H0_20_reverse-_\$Domain-substrand_H1_17_22_forward-h1-o17-l7-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":7,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H1-17-22-forward","sequence_position":0,"parent_element_id":"tb-strandstrand_H0_20_reverse-_\$Domain-substrand_H1_17_22_forward-h1-o17-l7-p0-fwd"},{"stable_id":"tb-strandstrand_H0_3_forward-_\$Loopout-loopout_1_strand_H0_3_forward-hna-ona-l5-p2-fwd","strand_id":"strand-H0-3-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":2,"forward":true,"sequence_element_id":"loopout-1-strand-H0-3-forward","sequence_position":2,"parent_element_id":"tb-strandstrand_H0_3_forward-_\$Loopout-loopout_1_strand_H0_3_forward-hna-ona-l5-p2-fwd"},{"stable_id":"tb-strandstrand_H1_9_reverse-_\$Domain-substrand_H1_6_10_reverse-h1-o9-l0-p0-rev","strand_id":"strand-H1-9-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"substrand-H1-6-10-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_9_reverse-_\$Domain-substrand_H1_6_10_reverse-h1-o9-l0-p0-rev"},{"stable_id":"tb-strandstrand_H1_9_reverse-_\$Loopout-loopout_1_strand_H1_9_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H1-9-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":0,"forward":false,"sequence_element_id":"loopout-1-strand-H1-9-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_9_reverse-_\$Loopout-loopout_1_strand_H1_9_reverse-hna-ona-l4-p0-fwd"},{"stable_id":"tb-strandstrand_H1_33_reverse-_\$Domain-substrand_H1_29_34_reverse-h1-o33-l0-p0-rev","strand_id":"strand-H1-33-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"substrand-H1-29-34-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_33_reverse-_\$Domain-substrand_H1_29_34_reverse-h1-o33-l0-p0-rev"},{"stable_id":"tb-strandstrand_H1_33_reverse-_\$Loopout-loopout_1_strand_H1_33_reverse-hna-ona-l5-p0-fwd","strand_id":"strand-H1-33-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":0,"forward":false,"sequence_element_id":"loopout-1-strand-H1-33-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_33_reverse-_\$Loopout-loopout_1_strand_H1_33_reverse-hna-ona-l5-p0-fwd"},{"stable_id":"tb-strandstrand_H1_25_forward-_\$Loopout-loopout_1_strand_H1_25_forward-hna-ona-l4-p0-fwd","strand_id":"strand-H1-25-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":0,"forward":true,"sequence_element_id":"loopout-1-strand-H1-25-forward","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_25_forward-_\$Loopout-loopout_1_strand_H1_25_forward-hna-ona-l4-p0-fwd"},{"stable_id":"tb-strandstrand_H1_36_forward-_\$Loopout-loopout_1_strand_H1_36_forward-hna-ona-l4-p0-fwd","strand_id":"strand-H1-36-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":0,"forward":true,"sequence_element_id":"loopout-1-strand-H1-36-forward","sequence_position":0,"parent_element_id":"tb-strandstrand_H1_36_forward-_\$Loopout-loopout_1_strand_H1_36_forward-hna-ona-l4-p0-fwd"},{"stable_id":"tb-strandstrand_H0_43_reverse-_\$Loopout-loopout_1_strand_H0_43_reverse-hna-ona-l4-p0-fwd","strand_id":"strand-H0-43-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":0,"forward":false,"sequence_element_id":"loopout-1-strand-H0-43-reverse","sequence_position":0,"parent_element_id":"tb-strandstrand_H0_43_reverse-_\$Loopout-loopout_1_strand_H0_43_reverse-hna-ona-l4-p0-fwd"},{"stable_id":"tb-strandstrand_H0_43_reverse-_\$Domain-substrand_H1_40_45_forward-h1-o40-l7-p0-fwd","strand_id":"strand-H0-43-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":7,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H1-40-45-forward","sequence_position":0,"parent_element_id":"tb-strandstrand_H0_43_reverse-_\$Domain-substrand_H1_40_45_forward-h1-o40-l7-p0-fwd"}]''';

// Content of example_designs/loopout-loopout_test_cases.sc
const String loopoutTestCasesScContent = '''
{
  "version": "0.19.5",
  "grid": "square",
  "helices": [
    {"grid_position": [0, 0], "max_offset": 48},
    {"grid_position": [0, 1], "max_offset": 48}
  ],
  "strands": [
    {
      "color": "#7ed321",
      "sequence": "AAAAAAATGGGGG",
      "domains": [
        {"helix": 1, "forward": true, "start": 12, "end": 17},
        {"loopout": 3},
        {"helix": 0, "forward": false, "start": 12, "end": 17}
      ]
    },
    {
      "color": "#7ed321",
      "sequence": "AAAATCCTGGGG",
      "domains": [
        {"helix": 0, "forward": false, "start": 17, "end": 21},
        {"loopout": 3},
        {"helix": 1, "forward": true, "start": 17, "end": 22}
      ]
    },
    {
      "color": "#4a90e2",
      "sequence": "GGGAATAAAAA",
      "domains": [
        {"helix": 0, "forward": true, "start": 3, "end": 6},
        {"loopout": 3},
        {"helix": 1, "forward": false, "start": 1, "end": 6}
      ]
    },
    {
      "color": "#4a90e2",
      "sequence": "TGGGTCCAAAAA",
      "domains": [
        {"helix": 1, "forward": false, "start": 6, "end": 10},
        {"loopout": 3},
        {"helix": 0, "forward": true, "start": 6, "end": 11}
      ]
    },
    {
      "color": "#bd10e0",
      "sequence": "TGGGGTCCAAAAA",
      "domains": [
        {"helix": 1, "forward": false, "start": 29, "end": 34},
        {"loopout": 3},
        {"helix": 0, "forward": true, "start": 29, "end": 34}
      ]
    },
    {
      "color": "#bd10e0",
      "sequence": "AAAATAAGGGGG",
      "domains": [
        {"helix": 1, "forward": true, "start": 25, "end": 29},
        {"loopout": 3},
        {"helix": 0, "forward": false, "start": 24, "end": 29}
      ]
    },
    {
      "color": "#9013fe",
      "sequence": "AAAATAAGGGGG",
      "domains": [
        {"helix": 1, "forward": true, "start": 36, "end": 40},
        {"loopout": 3},
        {"helix": 0, "forward": false, "start": 35, "end": 40}
      ]
    },
    {
      "color": "#9013fe",
      "sequence": "AAAATCCTGGGG",
      "domains": [
        {"helix": 0, "forward": false, "start": 40, "end": 44},
        {"loopout": 3},
        {"helix": 1, "forward": true, "start": 40, "end": 45}
      ]
    }
  ]
}
''';

void main() {
  group('CPD Rule Tests - Loopout-Loopout', () {
    late Design design;
    late List<IdentifiedTBase> test_identified_t_bases;
    late List<ExpectedCPDSite> expected_sites;
    late Set<String> expected_t_location_ids;

    setUpAll(() {
      // Load Design from embedded .sc file content
      design = Design.from_json_str(loopoutTestCasesScContent, false)!;

      // Parse IdentifiedTBase log
      final List<dynamic> identified_t_bases_decoded_log = jsonDecode(identifiedTBasesJsonLog);
      test_identified_t_bases = identified_t_bases_decoded_log.map((log_entry) {
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
      expected_sites = cpd_sites_decoded_log.map((log_entry) {
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
      CPDDetectionOutput output =
          detect_cpd_sites_from_t_bases(design, test_identified_t_bases, [loopout_rule]);

      List<String> failureDetails = [];

      // 1. Compare CPD site lengths
      if (output.cpd_sites.length != expected_sites.length) {
        failureDetails.add(
            'Number of CPD sites mismatch. Expected: ${expected_sites.length}, Actual: ${output.cpd_sites.length}');
      }

      // 2. Compare CPD site content
      var actual_sites_set = output.cpd_sites.map((s) {
        return ExpectedCPDSite(t1_id: s.t1.stable_id, t2_id: s.t2.stable_id, is_conflicted: s.is_conflicted);
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
