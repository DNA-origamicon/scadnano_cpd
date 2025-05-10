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
[{"source_id":"tb-strandstrand_H0_12_forward-_\$Extension-extension_3p_strand_H0_12_forward-hna-ona-l5-p0-fwd","strand_id":"strand-H0-12-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_17_forward-_\$Extension-extension_5p_strand_H0_17_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H0-17-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_27_reverse-_\$Extension-extension_5p_strand_H0_27_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-27-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_32_reverse-_\$Extension-extension_3p_strand_H0_32_reverse-hna-ona-l6-p1-fwd","strand_id":"strand-H0-32-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_1_forward-_\$Extension-extension_3p_strand_H0_1_forward-hna-ona-l6-p1-fwd","strand_id":"strand-H0-1-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_6_forward-_\$Extension-extension_5p_strand_H0_6_forward-hna-ona-l2-p2-fwd","strand_id":"strand-H0-6-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H0_40_forward-_\$Extension-extension_5p_strand_H0_40_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H0-40-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_34_forward-_\$Extension-extension_3p_strand_H0_34_forward-hna-ona-l5-p0-fwd","strand_id":"strand-H0-34-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_44_reverse-_\$Extension-extension_3p_strand_H0_44_reverse-hna-ona-l5-p0-fwd","strand_id":"strand-H0-44-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_39_reverse-_\$Extension-extension_5p_strand_H0_39_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-39-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0}]''';

const String cpdSitesJsonLog = '''
[{"t1_stable_id":"tb-strandstrand_H0_12_forward-_\$Extension-extension_3p_strand_H0_12_forward-hna-ona-l5-p0-fwd","t2_stable_id":"tb-strandstrand_H0_17_forward-_\$Extension-extension_5p_strand_H0_17_forward-hna-ona-l1-p1-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H0_27_reverse-_\$Extension-extension_5p_strand_H0_27_reverse-hna-ona-l0-p0-fwd","t2_stable_id":"tb-strandstrand_H0_32_reverse-_\$Extension-extension_3p_strand_H0_32_reverse-hna-ona-l6-p1-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H0_1_forward-_\$Extension-extension_3p_strand_H0_1_forward-hna-ona-l6-p1-fwd","t2_stable_id":"tb-strandstrand_H0_6_forward-_\$Extension-extension_5p_strand_H0_6_forward-hna-ona-l2-p2-fwd","is_conflicted":false}]''';

const String tBaseLocationsJsonLog = '''
[{"stable_id":"tb-strandstrand_H0_12_forward-_\$Extension-extension_3p_strand_H0_12_forward-hna-ona-l5-p0-fwd","strand_id":"strand-H0-12-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":5,"precise_offset":0,"forward":true,"sequence_element_id":"extension-3p-strand-H0-12-forward","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-12-forward-e3p","visual_x":181.61668395996094,"visual_y":-5.416291832923889,"grid_anchor_x":164.99736000000001,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_17_forward-_\$Extension-extension_5p_strand_H0_17_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H0-17-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"extension-5p-strand-H0-17-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H0-17-forward-e5p","visual_x":158.37787628173828,"visual_y":-5.416291832923889,"grid_anchor_x":174.99720000000002,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_27_reverse-_\$Extension-extension_5p_strand_H0_27_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-27-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"extension-5p-strand-H0-27-reverse","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-27-reverse-e5p","visual_x":296.53273010253906,"visual_y":28.85945701599121,"grid_anchor_x":274.99559999999997,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_32_reverse-_\$Extension-extension_3p_strand_H0_32_reverse-hna-ona-l6-p1-fwd","strand_id":"strand-H0-32-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":6,"precise_offset":1,"forward":false,"sequence_element_id":"extension-3p-strand-H0-32-reverse","sequence_position":1,"parent_element_id":"seq-extension-strand-H0-32-reverse-e3p","visual_x":263.4583282470703,"visual_y":28.859455108642578,"grid_anchor_x":284.99544,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_1_forward-_\$Extension-extension_3p_strand_H0_1_forward-hna-ona-l6-p1-fwd","strand_id":"strand-H0-1-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":6,"precise_offset":1,"forward":true,"sequence_element_id":"extension-3p-strand-H0-1-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H0-1-forward-e3p","visual_x":74.07733154296875,"visual_y":-7.138033866882324,"grid_anchor_x":54.999120000000005,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_6_forward-_\$Extension-extension_5p_strand_H0_6_forward-hna-ona-l2-p2-fwd","strand_id":"strand-H0-6-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":2,"precise_offset":2,"forward":true,"sequence_element_id":"extension-5p-strand-H0-6-forward","sequence_position":2,"parent_element_id":"seq-extension-strand-H0-6-forward-e5p","visual_x":48.3796501159668,"visual_y":-5.416294097900391,"grid_anchor_x":64.99896000000001,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_40_forward-_\$Extension-extension_5p_strand_H0_40_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H0-40-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"extension-5p-strand-H0-40-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H0-40-forward-e5p","visual_x":388.3742218017578,"visual_y":-5.416293025016785,"grid_anchor_x":404.99352,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_34_forward-_\$Extension-extension_3p_strand_H0_34_forward-hna-ona-l5-p0-fwd","strand_id":"strand-H0-34-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":5,"precise_offset":0,"forward":true,"sequence_element_id":"extension-3p-strand-H0-34-forward","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-34-forward-e3p","visual_x":401.6131591796875,"visual_y":-5.416293025016785,"grid_anchor_x":384.99384,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_44_reverse-_\$Extension-extension_3p_strand_H0_44_reverse-hna-ona-l5-p0-fwd","strand_id":"strand-H0-44-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":5,"precise_offset":0,"forward":false,"sequence_element_id":"extension-3p-strand-H0-44-reverse","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-44-reverse-e3p","visual_x":388.3742218017578,"visual_y":25.415971755981445,"grid_anchor_x":404.99352,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_39_reverse-_\$Extension-extension_5p_strand_H0_39_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-39-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"extension-5p-strand-H0-39-reverse","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-39-reverse-e5p","visual_x":416.5308074951172,"visual_y":28.85945701599121,"grid_anchor_x":394.99368,"grid_anchor_y":14.999760000000002}]''';

// Content of example_designs/ext-ext_test_cases.sc
const String extExtTestCasesScContent = '''
{
  "version": "0.19.5",
  "grid": "square",
  "helices": [
    {"grid_position": [0, 0], "max_offset": 48}
  ],
  "strands": [
    {
      "color": "#f8e71c",
      "sequence": "AAAAATA",
      "domains": [
        {"helix": 0, "forward": true, "start": 12, "end": 17},
        {"extension_num_bases": 2}
      ]
    },
    {
      "color": "#f5a623",
      "sequence": "ATGGGGG",
      "domains": [
        {"extension_num_bases": 2},
        {"helix": 0, "forward": true, "start": 17, "end": 22}
      ]
    },
    {
      "color": "#f8e71c",
      "sequence": "TAAAAAA",
      "domains": [
        {"extension_num_bases": 2},
        {"helix": 0, "forward": false, "start": 23, "end": 28}
      ]
    },
    {
      "color": "#f5a623",
      "sequence": "GGGGGAT",
      "domains": [
        {"helix": 0, "forward": false, "start": 28, "end": 33},
        {"extension_num_bases": 2}
      ]
    },
    {
      "color": "#f8e71c",
      "sequence": "AAAAAATC",
      "domains": [
        {"helix": 0, "forward": true, "start": 1, "end": 6},
        {"extension_num_bases": 3}
      ]
    },
    {
      "color": "#f5a623",
      "sequence": "AATGGGGGG",
      "domains": [
        {"extension_num_bases": 4},
        {"helix": 0, "forward": true, "start": 6, "end": 11}
      ]
    },
    {
      "color": "#bd10e0",
      "sequence": "ATGGGGG",
      "domains": [
        {"extension_num_bases": 2},
        {"helix": 0, "forward": true, "start": 40, "end": 45}
      ]
    },
    {
      "color": "#ff00ff",
      "sequence": "AAAAATA",
      "domains": [
        {"helix": 0, "forward": true, "start": 34, "end": 39},
        {"extension_num_bases": 2}
      ]
    },
    {
      "color": "#bd10e0",
      "sequence": "GGGGGTA",
      "domains": [
        {"helix": 0, "forward": false, "start": 40, "end": 45},
        {"extension_num_bases": 2}
      ]
    },
    {
      "color": "#ff00ff",
      "sequence": "TAAAAAA",
      "domains": [
        {"extension_num_bases": 2},
        {"helix": 0, "forward": false, "start": 35, "end": 40}
      ]
    }
  ]
}
''';

void main() {
  group('CPD Rule Tests - Extension-Extension', () {
    late Design design;
    late List<IdentifiedTBase> test_identified_t_bases;
    late List<ExpectedCPDSite> expected_sites;
    late Set<String> expected_t_location_ids;

    setUpAll(() {
      // Load Design from embedded .sc file content
      design = Design.from_json_str(extExtTestCasesScContent, false)!;

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

    test('AdjacentPerfectlyAlignedExtensions rule processes ext-ext_test_cases.sc correctly', () {
      // Find the specific rule definition for AdjacentPerfectlyAlignedExtensions
      RuleDefinition? ext_ext_rule = allRuleDefinitions.firstWhere(
        (rule) => rule.ruleName == "AdjacentPerfectlyAlignedExtensions",
        orElse: () => throw StateError('AdjacentPerfectlyAlignedExtensions rule not found'),
      );

      // Call the core logic function with only the extension-extension rule
      CPDDetectionOutput output =
          detect_cpd_sites_from_t_bases(design, test_identified_t_bases, [ext_ext_rule]);

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
