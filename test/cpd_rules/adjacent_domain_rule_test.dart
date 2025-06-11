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

// Logs will be populated in the next step.
const String identifiedTBasesJsonLog = '''
[{"source_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o5-l0-p0-fwd","strand_id":"strand-H0-5-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o6-l1-p1-fwd","strand_id":"strand-H0-5-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o3-l0-p0-rev","strand_id":"strand-H1-3-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o2-l1-p1-rev","strand_id":"strand-H1-3-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o4-l2-p2-fwd","strand_id":"strand-H2-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o5-l3-p3-fwd","strand_id":"strand-H2-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H3_0_forward-SubstrandTypeEnum.DOMAIN-substrand_H3_0_2_forward-h3-o1-l1-p1-fwd","strand_id":"strand-H3-0-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H3_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H3_2_4_forward-h3-o2-l0-p0-fwd","strand_id":"strand-H3-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H4_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H4_2_4_forward-h4-o2-l0-p0-fwd","strand_id":"strand-H4-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H4_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H4_2_4_forward-h4-o3-l1-p1-fwd","strand_id":"strand-H4-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H5_5_reverse-SubstrandTypeEnum.DOMAIN-substrand_H5_4_6_reverse-h5-o5-l0-p0-rev","strand_id":"strand-H5-5-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H5_5_reverse-SubstrandTypeEnum.DOMAIN-substrand_H5_4_6_reverse-h5-o4-l1-p1-rev","strand_id":"strand-H5-5-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H6_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H6_2_7_forward-h6-o3-l1-p1-fwd","strand_id":"strand-H6-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H6_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H6_2_7_forward-h6-o5-l3-p3-fwd","strand_id":"strand-H6-2-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o10-l0-p0-fwd","strand_id":"strand-H7-10-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o11-l1-p1-fwd","strand_id":"strand-H7-10-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o12-l2-p2-fwd","strand_id":"strand-H7-10-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":2}]
''';

const String cpdSitesJsonLog = '''
[{"t1_stable_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o5-l0-p0-fwd","t2_stable_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o6-l1-p1-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o3-l0-p0-rev","t2_stable_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o2-l1-p1-rev","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o4-l2-p2-fwd","t2_stable_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o5-l3-p3-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o10-l0-p0-fwd","t2_stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o11-l1-p1-fwd","is_conflicted":true},{"t1_stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o11-l1-p1-fwd","t2_stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o12-l2-p2-fwd","is_conflicted":true}]
''';

const String tBaseLocationsJsonLog = '''
[{"stable_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o5-l0-p0-fwd","strand_id":"strand-H0-5-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H0-5-7-forward","sequence_position":0,"parent_element_id":"seq-domain-strand-H0-5-forward-h0-o5","visual_x":55.40038871765137,"visual_y":2.499959945678711,"grid_anchor_x":54.999120000000005,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_5_forward-SubstrandTypeEnum.DOMAIN-substrand_H0_5_7_forward-h0-o6-l1-p1-fwd","strand_id":"strand-H0-5-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"substrand-H0-5-7-forward","sequence_position":1,"parent_element_id":"seq-domain-strand-H0-5-forward-h0-o5","visual_x":64.77768898010254,"visual_y":2.499959945678711,"grid_anchor_x":64.99896000000001,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o3-l0-p0-rev","strand_id":"strand-H1-3-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"substrand-H1-2-4-reverse","sequence_position":0,"parent_element_id":"seq-domain-strand-H1-3-reverse-h1-o3","visual_x":34.59817180145265,"visual_y":107.8597253833008,"grid_anchor_x":34.99944000000001,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H1_3_reverse-SubstrandTypeEnum.DOMAIN-substrand_H1_2_4_reverse-h1-o2-l1-p1-rev","strand_id":"strand-H1-3-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":false,"sequence_element_id":"substrand-H1-2-4-reverse","sequence_position":1,"parent_element_id":"seq-domain-strand-H1-3-reverse-h1-o3","visual_x":25.220874400024428,"visual_y":107.8597253833008,"grid_anchor_x":24.9996,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o4-l2-p2-fwd","strand_id":"strand-H2-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":2,"precise_offset":2,"forward":true,"sequence_element_id":"substrand-H2-2-7-forward","sequence_position":2,"parent_element_id":"seq-domain-strand-H2-2-forward-h2-o2","visual_x":45.08928108215332,"visual_y":183.219970703125,"grid_anchor_x":44.999280000000006,"grid_anchor_y":185.71992},{"stable_id":"tb-strandstrand_H2_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H2_2_7_forward-h2-o5-l3-p3-fwd","strand_id":"strand-H2-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":3,"precise_offset":3,"forward":true,"sequence_element_id":"substrand-H2-2-7-forward","sequence_position":3,"parent_element_id":"seq-domain-strand-H2-2-forward-h2-o2","visual_x":54.93348503112793,"visual_y":183.219970703125,"grid_anchor_x":54.999120000000005,"grid_anchor_y":185.71992},{"stable_id":"tb-strandstrand_H3_0_forward-SubstrandTypeEnum.DOMAIN-substrand_H3_0_2_forward-h3-o1-l1-p1-fwd","strand_id":"strand-H3-0-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"substrand-H3-0-2-forward","sequence_position":1,"parent_element_id":"seq-domain-strand-H3-0-forward-h3-o0","visual_x":14.778488159179688,"visual_y":273.5799560546875,"grid_anchor_x":14.999760000000002,"grid_anchor_y":276.07991999999996},{"stable_id":"tb-strandstrand_H3_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H3_2_4_forward-h3-o2-l0-p0-fwd","strand_id":"strand-H3-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H3-2-4-forward","sequence_position":0,"parent_element_id":"seq-domain-strand-H3-2-forward-h3-o2","visual_x":25.400869369506836,"visual_y":273.5799560546875,"grid_anchor_x":24.9996,"grid_anchor_y":276.07991999999996},{"stable_id":"tb-strandstrand_H4_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H4_2_4_forward-h4-o2-l0-p0-fwd","strand_id":"strand-H4-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H4-2-4-forward","sequence_position":0,"parent_element_id":"seq-domain-strand-H4-2-forward-h4-o2","visual_x":25.400869369506836,"visual_y":363.93994140625,"grid_anchor_x":24.9996,"grid_anchor_y":366.43992},{"stable_id":"tb-strandstrand_H4_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H4_2_4_forward-h4-o3-l1-p1-fwd","strand_id":"strand-H4-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"substrand-H4-2-4-forward","sequence_position":1,"parent_element_id":"seq-domain-strand-H4-2-forward-h4-o2","visual_x":34.77816963195801,"visual_y":363.93994140625,"grid_anchor_x":34.99944000000001,"grid_anchor_y":366.43992},{"stable_id":"tb-strandstrand_H5_5_reverse-SubstrandTypeEnum.DOMAIN-substrand_H5_4_6_reverse-h5-o5-l0-p0-rev","strand_id":"strand-H5-5-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"substrand-H5-4-6-reverse","sequence_position":0,"parent_element_id":"seq-domain-strand-H5-5-reverse-h5-o5","visual_x":54.59785128234864,"visual_y":469.2997153125,"grid_anchor_x":54.999120000000005,"grid_anchor_y":466.79976},{"stable_id":"tb-strandstrand_H5_5_reverse-SubstrandTypeEnum.DOMAIN-substrand_H5_4_6_reverse-h5-o4-l1-p1-rev","strand_id":"strand-H5-5-reverse","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":false,"sequence_element_id":"substrand-H5-4-6-reverse","sequence_position":1,"parent_element_id":"seq-domain-strand-H5-5-reverse-h5-o5","visual_x":45.22055101989747,"visual_y":469.2997153125,"grid_anchor_x":44.999280000000006,"grid_anchor_y":466.79976},{"stable_id":"tb-strandstrand_H6_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H6_2_7_forward-h6-o3-l1-p1-fwd","strand_id":"strand-H6-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"substrand-H6-2-7-forward","sequence_position":1,"parent_element_id":"seq-domain-strand-H6-2-forward-h6-o2","visual_x":35.245076179504395,"visual_y":544.659912109375,"grid_anchor_x":34.99944000000001,"grid_anchor_y":547.1599199999999},{"stable_id":"tb-strandstrand_H6_2_forward-SubstrandTypeEnum.DOMAIN-substrand_H6_2_7_forward-h6-o5-l3-p3-fwd","strand_id":"strand-H6-2-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":3,"precise_offset":3,"forward":true,"sequence_element_id":"substrand-H6-2-7-forward","sequence_position":3,"parent_element_id":"seq-domain-strand-H6-2-forward-h6-o2","visual_x":54.93348503112793,"visual_y":544.659912109375,"grid_anchor_x":54.999120000000005,"grid_anchor_y":547.1599199999999},{"stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o10-l0-p0-fwd","strand_id":"strand-H7-10-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":0,"precise_offset":0,"forward":true,"sequence_element_id":"substrand-H7-10-13-forward","sequence_position":0,"parent_element_id":"seq-domain-strand-H7-10-forward-h7-o10","visual_x":105.39958572387695,"visual_y":635.0198974609375,"grid_anchor_x":104.99832,"grid_anchor_y":637.51992},{"stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o11-l1-p1-fwd","strand_id":"strand-H7-10-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"substrand-H7-10-13-forward","sequence_position":1,"parent_element_id":"seq-domain-strand-H7-10-forward-h7-o10","visual_x":115.08815383911133,"visual_y":635.0198974609375,"grid_anchor_x":114.99816000000001,"grid_anchor_y":637.51992},{"stable_id":"tb-strandstrand_H7_10_forward-SubstrandTypeEnum.DOMAIN-substrand_H7_10_13_forward-h7-o12-l2-p2-fwd","strand_id":"strand-H7-10-forward","substrand_type":"SubstrandTypeEnum.DOMAIN","logical_index":2,"precise_offset":2,"forward":true,"sequence_element_id":"substrand-H7-10-13-forward","sequence_position":2,"parent_element_id":"seq-domain-strand-H7-10-forward-h7-o10","visual_x":124.77672958374023,"visual_y":635.0198974609375,"grid_anchor_x":124.99800000000002,"grid_anchor_y":637.51992}]
''';

// Content of all test cases combined into a single design file.
const String adjacentDomainTestCasesScContent = '''
{
  "version": "0.20.0",
  "grid": "square",
  "helices": [
    {"grid_position": [0, 0], "max_offset": 64},
    {"grid_position": [0, 1], "max_offset": 64},
    {"grid_position": [0, 2], "max_offset": 64},
    {"grid_position": [0, 3], "max_offset": 64},
    {"grid_position": [0, 4], "max_offset": 64},
    {"grid_position": [0, 5], "max_offset": 64},
    {"grid_position": [0, 6], "max_offset": 64},
    {"grid_position": [0, 7], "max_offset": 64}
  ],
  "strands": [
    { "color": "#f74308", "sequence": "TT", "domains": [{"helix": 0, "forward": true, "start": 5, "end": 7}] },
    { "color": "#57bb00", "sequence": "AA", "domains": [{"helix": 0, "forward": false, "start": 5, "end": 7}] },

    { "color": "#f74308", "sequence": "TT", "domains": [{"helix": 1, "forward": false, "start": 2, "end": 4}] },
    { "color": "#57bb00", "sequence": "AA", "domains": [{"helix": 1, "forward": true, "start": 2, "end": 4}] },

    { "color": "#57bb00", "sequence": "CCTTG", "domains": [{"helix": 2, "forward": true, "start": 2, "end": 7}] },
    { "color": "#f74308", "sequence": "CAAGG", "domains": [{"helix": 2, "forward": false, "start": 2, "end": 7}] },

    { "color": "#cc0000", "sequence": "GT", "domains": [{"helix": 3, "forward": true, "start": 0, "end": 2}] },
    { "color": "#32b86c", "sequence": "TC", "domains": [{"helix": 3, "forward": true, "start": 2, "end": 4}] },
    { "color": "#007200", "sequence": "CAAG", "domains": [{"helix": 3, "forward": false, "start": 0, "end": 4}] },

    { "color": "#f74308", "sequence": "TT", "domains": [{"helix": 4, "forward": true, "start": 2, "end": 4}] },

    { "color": "#f74308", "sequence": "TT", "domains": [{"helix": 5, "forward": false, "start": 4, "end": 6}] },

    { "color": "#f74308", "sequence": "CAGAG", "domains": [{"helix": 6, "forward": false, "start": 2, "end": 7}] },
    { "color": "#57bb00", "sequence": "CTCTG", "domains": [{"helix": 6, "forward": true, "start": 2, "end": 7}] },

    { "color": "#f74308", "sequence": "TTT", "domains": [{"helix": 7, "forward": true, "start": 10, "end": 13}]},
    { "color": "#57bb00", "sequence": "AAA", "domains": [{"helix": 7, "forward": false, "start": 10, "end": 13}]}
  ]
}
''';

void main() {
  group('CPD Rule Tests - Adjacent Domain Double Strand', () {
    late Design design;
    late List<IdentifiedTBase> test_identified_t_bases;
    late List<ExpectedCPDSite> expected_sites;
    late Set<String> expected_t_location_ids;

    setUpAll(() {
      design = Design.from_json_str(adjacentDomainTestCasesScContent, false)!;

      if (identifiedTBasesJsonLog.trim().isNotEmpty) {
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
      } else {
        test_identified_t_bases = [];
      }

      if (cpdSitesJsonLog.trim().isNotEmpty) {
        final List<dynamic> cpd_sites_decoded_log = jsonDecode(cpdSitesJsonLog);
        expected_sites =
            cpd_sites_decoded_log.map((log_entry) {
              return ExpectedCPDSite(
                t1_id: log_entry['t1_stable_id'],
                t2_id: log_entry['t2_stable_id'],
                is_conflicted: log_entry['is_conflicted'],
              );
            }).toList();
      } else {
        expected_sites = [];
      }

      if (tBaseLocationsJsonLog.trim().isNotEmpty) {
        final List<dynamic> t_base_locations_decoded_log = jsonDecode(tBaseLocationsJsonLog);
        expected_t_location_ids =
            t_base_locations_decoded_log.map<String>((log_entry) => log_entry['stable_id'] as String).toSet();
      } else {
        expected_t_location_ids = {};
      }
    });

    test('adjacentDomainDoubleStrandRule processes test cases correctly', () {
      if (identifiedTBasesJsonLog.trim().isEmpty) {
        print("Skipping test: Log data is not provided yet.");
        return;
      }

      RuleDefinition rule = allRuleDefinitions.firstWhere(
        (r) => r.ruleName == "adjacentDomainDoubleStrandRule",
        orElse: () => throw StateError('adjacentDomainDoubleStrandRule not found'),
      );

      CPDDetectionOutput output = detect_cpd_sites_from_t_bases(design, test_identified_t_bases, [rule]);

      List<String> failureDetails = [];

      if (output.cpd_sites.length != expected_sites.length) {
        failureDetails.add(
          'Number of CPD sites mismatch. Expected: ${expected_sites.length}, Actual: ${output.cpd_sites.length}',
        );
      }

      var actual_sites_set =
          output.cpd_sites.map((s) {
            return ExpectedCPDSite(
              t1_id: s.t1.stable_id,
              t2_id: s.t2.stable_id,
              is_conflicted: s.is_conflicted,
            );
          }).toSet();
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

      var actual_t_location_ids = output.t_base_locations.t_bases.map((t) => t.stable_id).toSet();

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
