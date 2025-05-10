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
[{"source_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H1-4-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l3-p3-fwd","strand_id":"strand-H1-4-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_3p_strand_H1_4_forward-hna-ona-l9-p0-fwd","strand_id":"strand-H1-4-forward","substrand_idx_in_strand":2,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_10_reverse-_\$Loopout-loopout_1_strand_H0_10_reverse-hna-ona-l5-p2-fwd","strand_id":"strand-H0-10-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l3-p1-fwd","strand_id":"strand-H1-36-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l5-p3-fwd","strand_id":"strand-H1-36-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_5p_strand_H0_29_forward-hna-ona-l0-p0-fwd","strand_id":"strand-H0-29-forward","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_3p_strand_H0_29_forward-hna-ona-l7-p0-fwd","strand_id":"strand-H0-29-forward","substrand_idx_in_strand":2,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_5p_strand_H1_34_reverse-hna-ona-l1-p1-fwd","strand_id":"strand-H1-34-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_3p_strand_H1_34_reverse-hna-ona-l10-p1-fwd","strand_id":"strand-H1-34-reverse","substrand_idx_in_strand":2,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_5p_strand_H0_20_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_idx_in_strand":0,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_3p_strand_H0_20_reverse-hna-ona-l10-p2-fwd","strand_id":"strand-H0-20-reverse","substrand_idx_in_strand":2,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H0_23_reverse-_\$Loopout-loopout_1_strand_H0_23_reverse-hna-ona-l5-p2-fwd","strand_id":"strand-H0-23-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":2},{"source_id":"tb-strandstrand_H0_46_reverse-_\$Loopout-loopout_1_strand_H0_46_reverse-hna-ona-l5-p1-fwd","strand_id":"strand-H0-46-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H0_46_reverse-_\$Loopout-loopout_1_strand_H0_46_reverse-hna-ona-l7-p3-fwd","strand_id":"strand-H0-46-reverse","substrand_idx_in_strand":1,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H0_40_forward-_\$Extension-extension_3p_strand_H0_40_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H0-40-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_40_forward-_\$Extension-extension_3p_strand_H1_40_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H1-40-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_13_forward-_\$Loopout-loopout_1_strand_H1_13_forward-hna-ona-l3-p0-fwd","strand_id":"strand-H1-13-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0},{"source_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H1-1-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":1},{"source_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l6-p3-fwd","strand_id":"strand-H1-1-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":3},{"source_id":"tb-strandstrand_H0_26_forward-_\$Loopout-loopout_1_strand_H0_26_forward-hna-ona-l3-p0-fwd","strand_id":"strand-H0-26-forward","substrand_idx_in_strand":1,"idx_in_substrand_sequence":0}]
''';

const String cpdSitesJsonLog = '''
[{"t1_stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l1-p1-fwd","t2_stable_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l6-p3-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l3-p3-fwd","t2_stable_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l4-p1-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_3p_strand_H1_4_forward-hna-ona-l9-p0-fwd","t2_stable_id":"tb-strandstrand_H0_10_reverse-_\$Loopout-loopout_1_strand_H0_10_reverse-hna-ona-l5-p2-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_5p_strand_H0_29_forward-hna-ona-l0-p0-fwd","t2_stable_id":"tb-strandstrand_H0_26_forward-_\$Loopout-loopout_1_strand_H0_26_forward-hna-ona-l3-p0-fwd","is_conflicted":true},{"t1_stable_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_3p_strand_H0_29_forward-hna-ona-l7-p0-fwd","t2_stable_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l5-p3-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_5p_strand_H1_34_reverse-hna-ona-l1-p1-fwd","t2_stable_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l3-p1-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_3p_strand_H1_34_reverse-hna-ona-l10-p1-fwd","t2_stable_id":"tb-strandstrand_H0_26_forward-_\$Loopout-loopout_1_strand_H0_26_forward-hna-ona-l3-p0-fwd","is_conflicted":true},{"t1_stable_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_5p_strand_H0_20_reverse-hna-ona-l0-p0-fwd","t2_stable_id":"tb-strandstrand_H0_23_reverse-_\$Loopout-loopout_1_strand_H0_23_reverse-hna-ona-l5-p2-fwd","is_conflicted":false},{"t1_stable_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_3p_strand_H0_20_reverse-hna-ona-l10-p2-fwd","t2_stable_id":"tb-strandstrand_H1_13_forward-_\$Loopout-loopout_1_strand_H1_13_forward-hna-ona-l3-p0-fwd","is_conflicted":false}]
''';

const String tBaseLocationsJsonLog = '''
[{"stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l1-p1-fwd","strand_id":"strand-H1-4-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":1,"precise_offset":1,"forward":true,"sequence_element_id":"extension-5p-strand-H1-4-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H1-4-forward","visual_x":21.003281593322754,"visual_y":79.77849960327148,"grid_anchor_x":44.999280000000006,"grid_anchor_y":95.35992},{"stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_5p_strand_H1_4_forward-hna-ona-l3-p3-fwd","strand_id":"strand-H1-4-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":3,"precise_offset":3,"forward":true,"sequence_element_id":"extension-5p-strand-H1-4-forward","sequence_position":3,"parent_element_id":"seq-extension-strand-H1-4-forward","visual_x":30.838854789733887,"visual_y":86.66543960571289,"grid_anchor_x":44.999280000000006,"grid_anchor_y":95.35992},{"stable_id":"tb-strandstrand_H1_4_forward-_\$Extension-extension_3p_strand_H1_4_forward-hna-ona-l9-p0-fwd","strand_id":"strand-H1-4-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":9,"precise_offset":0,"forward":true,"sequence_element_id":"extension-3p-strand-H1-4-forward","sequence_position":0,"parent_element_id":"seq-extension-strand-H1-4-forward-e3p","visual_x":89.15922546386719,"visual_y":86.66543960571289,"grid_anchor_x":74.9988,"grid_anchor_y":95.35992},{"stable_id":"tb-strandstrand_H0_10_reverse-_\$Loopout-loopout_1_strand_H0_10_reverse-hna-ona-l5-p2-fwd","strand_id":"strand-H0-10-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":2,"forward":false,"sequence_element_id":"loopout-1-strand-H0-10-reverse","sequence_position":2,"parent_element_id":"seq-loopout-strand-H0-10-reverse-0","visual_x":69.78948974609375,"visual_y":62.446773529052734,"grid_anchor_x":84.99864000000001,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l3-p1-fwd","strand_id":"strand-H1-36-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":3,"precise_offset":1,"forward":false,"sequence_element_id":"loopout-1-strand-H1-36-reverse","sequence_position":1,"parent_element_id":"seq-loopout-strand-H1-36-reverse-0","visual_x":341.2758483886719,"visual_y":58.807804107666016,"grid_anchor_x":354.99432,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H1_36_reverse-_\$Loopout-loopout_1_strand_H1_36_reverse-hna-ona-l5-p3-fwd","strand_id":"strand-H1-36-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":3,"forward":false,"sequence_element_id":"loopout-1-strand-H1-36-reverse","sequence_position":3,"parent_element_id":"seq-loopout-strand-H1-36-reverse-0","visual_x":341.3677215576172,"visual_y":44.33814811706543,"grid_anchor_x":354.99432,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_5p_strand_H0_29_forward-hna-ona-l0-p0-fwd","strand_id":"strand-H0-29-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":0,"precise_offset":0,"forward":true,"sequence_element_id":"extension-5p-strand-H0-29-forward","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-29-forward-e5p","visual_x":275.91705322265625,"visual_y":-7.1380321979522705,"grid_anchor_x":294.99528,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H0_29_forward-_\$Extension-extension_3p_strand_H0_29_forward-hna-ona-l7-p0-fwd","strand_id":"strand-H0-29-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":7,"precise_offset":0,"forward":true,"sequence_element_id":"extension-3p-strand-H0-29-forward","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-29-forward-e3p","visual_x":359.1549377441406,"visual_y":-3.6945629715919495,"grid_anchor_x":344.99448,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_5p_strand_H1_34_reverse-hna-ona-l1-p1-fwd","strand_id":"strand-H1-34-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":1,"precise_offset":1,"forward":false,"sequence_element_id":"extension-5p-strand-H1-34-reverse","sequence_position":1,"parent_element_id":"seq-extension-strand-H1-34-reverse-e5p","visual_x":364.0727233886719,"visual_y":117.49771118164062,"grid_anchor_x":344.99448,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H1_34_reverse-_\$Extension-extension_3p_strand_H1_34_reverse-hna-ona-l10-p1-fwd","strand_id":"strand-H1-34-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":10,"precise_offset":1,"forward":false,"sequence_element_id":"extension-3p-strand-H1-34-reverse","sequence_position":1,"parent_element_id":"seq-extension-strand-H1-34-reverse-e3p","visual_x":273.4581604003906,"visual_y":119.21944046020508,"grid_anchor_x":294.99528,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_5p_strand_H0_20_reverse-hna-ona-l0-p0-fwd","strand_id":"strand-H0-20-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":0,"precise_offset":0,"forward":false,"sequence_element_id":"extension-5p-strand-H0-20-reverse","sequence_position":0,"parent_element_id":"seq-extension-strand-H0-20-reverse-e5p","visual_x":215.89891052246094,"visual_y":25.415971755981445,"grid_anchor_x":194.99664,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_20_reverse-_\$Extension-extension_3p_strand_H0_20_reverse-hna-ona-l10-p2-fwd","strand_id":"strand-H0-20-reverse","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":10,"precise_offset":2,"forward":false,"sequence_element_id":"extension-3p-strand-H0-20-reverse","sequence_position":2,"parent_element_id":"seq-extension-strand-H0-20-reverse-e3p","visual_x":128.44664001464844,"visual_y":23.69423484802246,"grid_anchor_x":164.99736000000001,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_23_reverse-_\$Loopout-loopout_1_strand_H0_23_reverse-hna-ona-l5-p2-fwd","strand_id":"strand-H0-23-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":2,"forward":false,"sequence_element_id":"loopout-1-strand-H0-23-reverse","sequence_position":2,"parent_element_id":"seq-loopout-strand-H0-23-reverse-0","visual_x":180.6798858642578,"visual_y":65.89025115966797,"grid_anchor_x":214.99632,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_46_reverse-_\$Loopout-loopout_1_strand_H0_46_reverse-hna-ona-l5-p1-fwd","strand_id":"strand-H0-46-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":5,"precise_offset":1,"forward":false,"sequence_element_id":"loopout-1-strand-H0-46-reverse","sequence_position":1,"parent_element_id":"seq-loopout-strand-H0-46-reverse-0","visual_x":425.9005432128906,"visual_y":58.807804107666016,"grid_anchor_x":434.99328000000003,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_46_reverse-_\$Loopout-loopout_1_strand_H0_46_reverse-hna-ona-l7-p3-fwd","strand_id":"strand-H0-46-reverse","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":7,"precise_offset":3,"forward":false,"sequence_element_id":"loopout-1-strand-H0-46-reverse","sequence_position":3,"parent_element_id":"seq-loopout-strand-H0-46-reverse-0","visual_x":425.992431640625,"visual_y":44.33814811706543,"grid_anchor_x":434.99328000000003,"grid_anchor_y":14.999760000000002},{"stable_id":"tb-strandstrand_H0_40_forward-_\$Extension-extension_3p_strand_H0_40_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H0-40-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":4,"precise_offset":1,"forward":true,"sequence_element_id":"extension-3p-strand-H0-40-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H0-40-forward-e3p","visual_x":401.6131591796875,"visual_y":-5.416293025016785,"grid_anchor_x":394.99368,"grid_anchor_y":4.99992},{"stable_id":"tb-strandstrand_H1_40_forward-_\$Extension-extension_3p_strand_H1_40_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H1-40-forward","substrand_type":"SubstrandTypeEnum.EXTENSION","logical_index":4,"precise_offset":1,"forward":true,"sequence_element_id":"extension-3p-strand-H1-40-forward","sequence_position":1,"parent_element_id":"seq-extension-strand-H1-40-forward-e3p","visual_x":401.6131591796875,"visual_y":84.9437026977539,"grid_anchor_x":394.99368,"grid_anchor_y":95.35992},{"stable_id":"tb-strandstrand_H1_13_forward-_\$Loopout-loopout_1_strand_H1_13_forward-hna-ona-l3-p0-fwd","strand_id":"strand-H1-13-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":3,"precise_offset":0,"forward":true,"sequence_element_id":"loopout-1-strand-H1-13-forward","sequence_position":0,"parent_element_id":"seq-loopout-strand-H1-13-forward-0","visual_x":149.28277587890625,"visual_y":50.28223419189453,"grid_anchor_x":134.99784000000002,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l4-p1-fwd","strand_id":"strand-H1-1-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":4,"precise_offset":1,"forward":true,"sequence_element_id":"loopout-1-strand-H1-1-forward","sequence_position":1,"parent_element_id":"seq-loopout-strand-H1-1-forward-0","visual_x":29.79633331298828,"visual_y":46.06003189086914,"grid_anchor_x":14.999760000000002,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H1_1_forward-_\$Loopout-loopout_1_strand_H1_1_forward-hna-ona-l6-p3-fwd","strand_id":"strand-H1-1-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":6,"precise_offset":3,"forward":true,"sequence_element_id":"loopout-1-strand-H1-1-forward","sequence_position":3,"parent_element_id":"seq-loopout-strand-H1-1-forward-0","visual_x":29.888219833374023,"visual_y":60.529685974121094,"grid_anchor_x":14.999760000000002,"grid_anchor_y":105.35976000000001},{"stable_id":"tb-strandstrand_H0_26_forward-_\$Loopout-loopout_1_strand_H0_26_forward-hna-ona-l3-p0-fwd","strand_id":"strand-H0-26-forward","substrand_type":"SubstrandTypeEnum.LOOPOUT","logical_index":3,"precise_offset":0,"forward":true,"sequence_element_id":"loopout-1-strand-H0-26-forward","sequence_position":0,"parent_element_id":"seq-loopout-strand-H0-26-forward-0","visual_x":275.82521057128906,"visual_y":34.07684326171875,"grid_anchor_x":264.99559999999997,"grid_anchor_y":4.99992}]
''';

// Content of example_designs/loopout-ext_test_cases.sc
const String extLoopoutTestCasesScContent = '''
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
      "sequence": "CTCTCAAAATAA",
      "domains": [
        {"extension_num_bases": 5},
        {"helix": 1, "forward": true, "start": 4, "end": 8},
        {"extension_num_bases": 3}
      ]
    },
    {
      "color": "#006400",
      "sequence": "AAAAATGGG",
      "domains": [
        {"helix": 0, "forward": false, "start": 8, "end": 11},
        {"loopout": 3},
        {"helix": 1, "forward": true, "start": 8, "end": 11}
      ]
    },
    {
      "color": "#417505",
      "sequence": "AACTCTGGG",
      "domains": [
        {"helix": 1, "forward": false, "start": 35, "end": 37},
        {"loopout": 4},
        {"helix": 0, "forward": true, "start": 35, "end": 38}
      ]
    },
    {
      "color": "#7ed321",
      "sequence": "TAAAAAATAA",
      "domains": [
        {"extension_num_bases": 1},
        {"helix": 0, "forward": true, "start": 29, "end": 35},
        {"extension_num_bases": 3}
      ]
    },
    {
      "color": "#7ed321",
      "sequence": "ATAGGGGGGAT",
      "domains": [
        {"extension_num_bases": 3},
        {"helix": 1, "forward": false, "start": 29, "end": 35},
        {"extension_num_bases": 2}
      ]
    },
    {
      "color": "#7ed321",
      "sequence": "TAAAAAAAAAT",
      "domains": [
        {"extension_num_bases": 3, "display_length": 1.9358340166503643, "display_angle": 56.28009683293238},
        {"helix": 0, "forward": false, "start": 16, "end": 21},
        {"extension_num_bases": 3, "display_length": 1.6890186253824646, "display_angle": 56.37446494364922}
      ]
    },
    {
      "color": "#417505",
      "sequence": "GGGCCTCAAA",
      "domains": [
        {"helix": 0, "forward": false, "start": 21, "end": 24},
        {"loopout": 4},
        {"helix": 1, "forward": true, "start": 21, "end": 24}
      ]
    },
    {
      "color": "#9013fe",
      "sequence": "GGGGCTCTAAAA",
      "domains": [
        {"helix": 0, "forward": false, "start": 43, "end": 47},
        {"loopout": 4},
        {"helix": 1, "forward": true, "start": 43, "end": 47}
      ]
    },
    {
      "color": "#ff00ff",
      "sequence": "AAAATA",
      "domains": [
        {"helix": 0, "forward": true, "start": 40, "end": 43},
        {"extension_num_bases": 3}
      ]
    },
    {
      "color": "#ff00ff",
      "sequence": "GGGATA",
      "domains": [
        {"helix": 1, "forward": true, "start": 40, "end": 43},
        {"extension_num_bases": 3}
      ]
    },
    {
      "color": "#417505",
      "sequence": "GGGTAAAAA",
      "domains": [
        {"helix": 1, "forward": true, "start": 13, "end": 16},
        {"loopout": 3},
        {"helix": 0, "forward": false, "start": 13, "end": 16}
      ]
    },
    {
      "color": "#006400",
      "sequence": "GGGGTATAAA",
      "domains": [
        {"helix": 1, "forward": true, "start": 1, "end": 4},
        {"loopout": 4},
        {"helix": 0, "forward": false, "start": 1, "end": 4}
      ]
    },
    {
      "color": "#417505",
      "sequence": "GGGTCAA",
      "domains": [
        {"helix": 0, "forward": true, "start": 26, "end": 29},
        {"loopout": 2},
        {"helix": 1, "forward": false, "start": 27, "end": 29}
      ]
    }
  ]
}
''';

void main() {
  group('CPD Rule Tests - Extension-Loopout', () {
    late Design design;
    late List<IdentifiedTBase> test_identified_t_bases;
    late List<ExpectedCPDSite> expected_sites;
    late Set<String> expected_t_location_ids;

    setUpAll(() {
      // Load Design from embedded .sc file content
      design = Design.from_json_str(extLoopoutTestCasesScContent, false)!;

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

    test('AdjacentExtensionLoopoutPerfectlyAligned rule processes ext-loopout_test_cases.sc correctly', () {
      // Find the specific rule definition for AdjacentExtensionLoopoutPerfectlyAligned
      RuleDefinition? ext_loopout_rule = allRuleDefinitions.firstWhere(
        (rule) => rule.ruleName == "AdjacentExtensionLoopoutPerfectlyAligned",
        orElse: () => throw StateError('AdjacentExtensionLoopoutPerfectlyAligned rule not found'),
      );

      // Call the core logic function with only the extension-loopout rule
      CPDDetectionOutput output =
          detect_cpd_sites_from_t_bases(design, test_identified_t_bases, [ext_loopout_rule]);

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
