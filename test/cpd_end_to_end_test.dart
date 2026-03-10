// End-to-end test for the CPD pipeline:
//   Design → CPD detection → PhotoproductJunction → .sc round-trip → PDB LINK records
//
// Run with:
//   dart run build_runner test -- test/cpd_end_to_end_test.dart --platform chrome

import 'dart:convert';
import 'package:built_collection/built_collection.dart';
import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/helix.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/substrand.dart';
import 'package:scadnano/src/state/t_base_location.dart';
import 'package:scadnano/src/state/photoproduct_junction.dart';
import 'package:scadnano/src/state/cpd_parameters.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';
import 'package:scadnano/src/middleware/oxdna_export.dart';
import 'package:scadnano/src/util/pdb_exporter.dart';
import 'package:scadnano/src/util.dart' as util;

// ── Shared design fixture ─────────────────────────────────────────────────
//
//   Minimal two-helix design with a staple strand that has two adjacent T's
//   on the same domain:
//
//     helix 0: scaffold  TTATTTTTAAT  (offsets 0–10 forward)
//     helix 1: scaffold  (reverse)
//
//   We assign sequence "TTACGTTTAAT" to the staple so positions 0 and 1 are
//   both T, which the adjacent_domain_ds rule should detect.

/// Build a 1-helix design with a single strand whose first two bases are TT.
Design _build_tt_design() {
  var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
  var design = Design(helices: helices, grid: Grid.square);
  // Two strands: scaffold (fwd) and staple (rev) on the same helix.
  design = design.draw_strand(0, 0).to(7).commit();
  design = design.draw_strand(0, 7).move(-7).commit();
  // Assign TT at the start of the forward strand (logical index 0 and 1).
  design = design.strands[0].dna_sequence != null ? design :
      design.assign_dna_complement_from_sequence(design.strands[0], 'TTACGTA');
  return design;
}

void main() {
  // ── 1. Design JSON round-trip with photoproduct_junctions ─────────────────
  group('Design.photoproduct_junctions — JSON round-trip', () {
    test('serialized junctions survive to_json / from_json', () {
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      design = design.draw_strand(0, 7).move(-7).commit();

      final j = PhotoproductJunction(
        t1_stable_id: 'fake-t1',
        t2_stable_id: 'fake-t2',
        photoproduct_id: 'TT-CPD',
      );
      design = design.rebuild((b) => b.photoproduct_junctions.add(j));

      // Serialize.
      final json_map = design.to_json_serializable();
      expect(json_map.containsKey('photoproduct_junctions'), isTrue,
          reason: 'photoproduct_junctions key must appear in .sc JSON');

      // Deserialize.
      final json_str = jsonEncode(json_map);
      final Design? reloaded = Design.from_json_str(json_str, false);
      expect(reloaded, isNotNull);
      expect(reloaded!.photoproduct_junctions.length, equals(1));

      final reloaded_j = reloaded.photoproduct_junctions.first;
      expect(reloaded_j.t1_stable_id, equals('fake-t1'));
      expect(reloaded_j.t2_stable_id, equals('fake-t2'));
      expect(reloaded_j.photoproduct_id, equals('TT-CPD'));
    });

    test('empty photoproduct_junctions — key omitted from JSON', () {
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      final json_map = design.to_json_serializable();
      expect(json_map.containsKey('photoproduct_junctions'), isFalse,
          reason: 'empty list must not emit the key (keeps files clean)');
    });

    test('multiple junctions survive round-trip', () {
      var helices = [Helix(idx: 0, max_offset: 14, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(14).commit();

      final junctions = [
        PhotoproductJunction(t1_stable_id: 'ta', t2_stable_id: 'tb'),
        PhotoproductJunction(t1_stable_id: 'tc', t2_stable_id: 'td'),
        PhotoproductJunction(t1_stable_id: 'te', t2_stable_id: 'tf'),
      ];
      design = design.rebuild((b) => b.photoproduct_junctions.addAll(junctions));

      final json_str = jsonEncode(design.to_json_serializable());
      final Design? reloaded = Design.from_json_str(json_str, false);
      expect(reloaded!.photoproduct_junctions.length, equals(3));
      expect(reloaded.photoproduct_junctions.map((j) => j.t1_stable_id).toList(),
          containsAll(['ta', 'tc', 'te']));
    });
  });

  // ── 2. CPD detection → junction → PDB LINK records ───────────────────────
  group('CPD detection → PDB LINK records (end-to-end)', () {
    // Build params with equal weights so every detected site gets score 1.0.
    CpdParameters _make_all_weight_1_params() {
      return CpdParameters.from_json({
        'schema_version': '0.1.0',
        'last_updated': '2026-03-09',
        'global': {
          'display_threshold': 0.0,
          'conflict_resolution': 'highest_score_wins',
          'watch_bases': ['T'],
        },
        'photoproducts': [
          {
            'id': 'TT_CPD',
            'display_name': 'T-T CPD',
            'abbreviation': 'CPD',
            'color': '#e87d2b',
            'enabled': true,
            'sequence_contexts': [
              {'upstream_base': 'T', 'downstream_base': 'T', 'relative_formation_rate': 1.0}
            ],
            'structural_context_weights': {
              'adjacent_domain_ds': {'weight': 1.0},
              'extension_extension': {'weight': 1.0},
              'loopout_loopout': {'weight': 1.0},
              'within_loopout': {'weight': 1.0},
              'extension_loopout': {'weight': 1.0},
            },
            'geometry': {'max_interbase_distance_angstrom': 4.0},
            'references': [],
          }
        ],
      });
    }

    test('detected CPD sites have formation_score from params', () {
      // Build a design with TT adjacent on the same strand.
      final sc_content = '''
{
  "version": "0.19.0",
  "helices": [{"idx": 0, "max_offset": 7, "grid_position": [0, 0]}],
  "strands": [
    {"domains": [{"helix": 0, "forward": true, "start": 0, "end": 7}],
     "sequence": "TTACGTA"},
    {"domains": [{"helix": 0, "forward": false, "start": 0, "end": 7}]}
  ]
}
''';
      final design = Design.from_json_str(sc_content, false)!;
      final params = _make_all_weight_1_params();

      // Extract IdentifiedTBase list from the forward strand's TT bases
      // by inspecting all substrands for the 'T' bases.
      final Strand fwd_strand = design.strands[0];
      final Substrand domain = fwd_strand.substrands[0];

      // Build minimal IdentifiedTBase list for positions 0 and 1 in the strand.
      final t_bases = <IdentifiedTBase>[
        IdentifiedTBase(
          source_id: 'test-t0',
          strand: fwd_strand,
          substrand: domain,
          idx_in_substrand_sequence: 0,
        ),
        IdentifiedTBase(
          source_id: 'test-t1',
          strand: fwd_strand,
          substrand: domain,
          idx_in_substrand_sequence: 1,
        ),
      ];

      final output = detect_cpd_sites_from_t_bases(design, t_bases, null, params);
      // The two T's at offsets 0 and 1 should form an adjacent_domain_ds site.
      expect(output.cpd_sites, isNotEmpty,
          reason: 'TT pair at adjacent offsets should be detected');
      for (final site in output.cpd_sites) {
        expect(site.photoproduct_id, equals('TT_CPD'));
        expect(site.formation_score, closeTo(1.0, 1e-9));
      }
    });

    test('PDB export emits LINK records for confirmed junction', () async {
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      design = design.draw_strand(0, 7).move(-7).commit();

      // Add a confirmed junction using synthetic stable IDs.
      design = design.rebuild((b) => b.photoproduct_junctions.add(
        PhotoproductJunction(t1_stable_id: 'syn-t1', t2_stable_id: 'syn-t2')
      ));

      final oxdna_dat_top = to_oxdna_format(design);
      final dat_content = oxdna_dat_top.item1;
      final top_content = oxdna_dat_top.item2;

      final pdb_template_content =
          await util.get_text_file_content('tests_inputs/pdb_export/dd12_na.pdb');

      // Build a minimal stable_id → PDB location mapping.
      // Strand 0 (chain A): serial 1 = first nucleotide, serial 2 = second.
      final stable_id_to_pdb_loc = <String, Tuple2<String, int>>{
        'syn-t1': Tuple2('A', 1),
        'syn-t2': Tuple2('A', 2),
      };
      final junction_pairs = [Tuple2('syn-t1', 'syn-t2')];

      final pdb_content = await export_pdb_from_oxdna_strings(
        top_content: top_content,
        dat_content: dat_content,
        pdb_template_content: pdb_template_content,
        oxDNA_direction: true,
        uniform_residue_names: false,
        junction_stable_id_pairs: junction_pairs,
        stable_id_to_pdb_loc: stable_id_to_pdb_loc,
      );

      final lines = pdb_content.trim().split('\n');
      final link_lines = lines.where((l) => l.startsWith('LINK')).toList();
      expect(link_lines.length, equals(2),
          reason: 'One junction → 2 LINK records (C5–C5 and C6–C6)');
      expect(link_lines.every((l) => l.trim().endsWith('1.57')), isTrue,
          reason: 'Cyclobutane C-C bond length should be 1.57 Å');
    });
  });

  // ── 3. oxDNA export with CPD distortion ───────────────────────────────────
  group('oxDNA export — CPD geometry distortion', () {
    test('without junctions — output is unmodified (no distortion)', () {
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      design = design.draw_strand(0, 7).move(-7).commit();

      final no_junctions = to_oxdna_format(design);
      final with_empty_junctions = to_oxdna_format(design,
          null, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, [], null);

      // Both should produce identical output when no junctions exist.
      expect(no_junctions.item1, equals(with_empty_junctions.item1),
          reason: '.dat should be identical when junctions list is empty');
      expect(no_junctions.item2, equals(with_empty_junctions.item2),
          reason: '.top should be identical when junctions list is empty');
    });

    test('with junction and TBaseLocations — two T nucleotides share center', () {
      // Single helix, two strands.
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      design = design.draw_strand(0, 7).move(-7).commit();

      final strands = design.strands.toList();
      final strand0_id = strands[0].id;

      // Nucleotides 0 and 1 of strand 0 are T1 and T2.
      final t_loc_1 = TBaseLocation((b) => b
        ..stable_id = 'cpd-t1'
        ..strand_id = strand0_id
        ..forward = true
        ..logical_index = 0
        ..precise_offset = 0
        ..substrand_type = 'domain'
        ..sequence_element_id = 'domain-0'
        ..sequence_position = 0);
      final t_loc_2 = TBaseLocation((b) => b
        ..stable_id = 'cpd-t2'
        ..strand_id = strand0_id
        ..forward = true
        ..logical_index = 1
        ..precise_offset = 1
        ..substrand_type = 'domain'
        ..sequence_element_id = 'domain-0'
        ..sequence_position = 1);
      final t_base_locations = TBaseLocations((b) => b
        ..t_bases = ListBuilder([t_loc_1, t_loc_2]));

      final junctions = [
        PhotoproductJunction(t1_stable_id: 'cpd-t1', t2_stable_id: 'cpd-t2'),
      ];

      // Export WITHOUT distortion (baseline).
      final baseline = to_oxdna_format(design);
      // Export WITH distortion.
      final distorted = to_oxdna_format(
          design, null, 0.5, 0.5, 0.0, 0.0, 0.0, 0.0, junctions, t_base_locations);

      // The .dat files must differ when distortion is applied.
      expect(baseline.item1, isNot(equals(distorted.item1)),
          reason: 'Distortion should change nucleotide positions in the .dat file');

      // The .top file should be identical (distortion does not change topology).
      expect(baseline.item2, equals(distorted.item2),
          reason: '.top file (topology) must not change with distortion');

      // Parse the distorted .dat to verify that nucleotides 0 and 1 of strand 0
      // have the same center position (midpoint collocation).
      final dat_lines = distorted.item1.trim().split('\n');
      // First two lines are header lines; nucleotide data starts at line 3.
      // Order in .dat matches nucleotide order in .top: strand 0 first, then strand 1.
      // Each nucleotide line: "cx cy cz ax ay az bx by bz vx vy vz Lx Ly Lz"
      final nuc0_parts = dat_lines[2].trim().split(RegExp(r'\s+'));
      final nuc1_parts = dat_lines[3].trim().split(RegExp(r'\s+'));

      final cx0 = double.parse(nuc0_parts[0]);
      final cy0 = double.parse(nuc0_parts[1]);
      final cz0 = double.parse(nuc0_parts[2]);
      final cx1 = double.parse(nuc1_parts[0]);
      final cy1 = double.parse(nuc1_parts[1]);
      final cz1 = double.parse(nuc1_parts[2]);

      expect(cx0, closeTo(cx1, 1e-6),
          reason: 'Distorted T centers must share x-coordinate (midpoint)');
      expect(cy0, closeTo(cy1, 1e-6),
          reason: 'Distorted T centers must share y-coordinate (midpoint)');
      expect(cz0, closeTo(cz1, 1e-6),
          reason: 'Distorted T centers must share z-coordinate (midpoint)');
    });
  });
}
