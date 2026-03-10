import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';
import 'package:tuple/tuple.dart';

import 'package:scadnano/src/state/helix.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/util/pdb_exporter.dart';
import 'package:scadnano/src/util/oxdna_file_parser.dart';
import 'package:scadnano/src/util/oxdna_data.dart';
import 'package:scadnano/src/middleware/oxdna_export.dart';
import 'package:scadnano/src/constants.dart' as constants;
import 'package:scadnano/src/util.dart' as util;

main() {
  group('PDB Export', () {
    test('pdb_export_basic_design', () async {
      /*
      Design copied from oxDNA export test: 
      2 double strands of length 7 connected across helices.
                  0      7
        helix 0   [------\
                  +------]\
                  |       |
        helix 1   +------>/
                  <------/
      */
      var helices = [for (int i = 0; i < 2; i++) Helix(idx: i, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).cross(1).move(-7).commit();
      design = design.draw_strand(0, 7).move(-7).cross(1).move(7).commit();

      // Convert to oxDNA format first (same as oxDNA export test)
      var oxdna_dat_top = to_oxdna_format(design);
      String dat_content = oxdna_dat_top.item1;
      String top_content = oxdna_dat_top.item2;

      // Load tacoxdna converter template file
      String pdb_template_content = await util.get_text_file_content('tests_inputs/pdb_export/dd12_na.pdb');

      String pdb_content = await export_pdb_from_oxdna_strings(
        top_content: top_content,
        dat_content: dat_content,
        pdb_template_content: pdb_template_content,
        oxDNA_direction: true,
        uniform_residue_names: false,
      );

      // Basic validation - should contain PDB structure
      expect(pdb_content.contains('ATOM'), isTrue, reason: 'PDB should contain ATOM records');
      expect(pdb_content.contains('TER'), isTrue, reason: 'PDB should contain TER records');

      // Verify the PDB ends properly with TER
      expect(pdb_content.trim().endsWith('TER'), isTrue, reason: 'PDB should end with TER record');

      // Count ATOM lines to verify reasonable output
      List<String> lines = pdb_content.trim().split('\n');
      List<String> atom_lines = lines.where((line) => line.startsWith('ATOM')).toList();

      // We expect multiple atoms per nucleotide (P, O5', C5', etc.)
      // With 4 strands * 7 nucleotides = 28 total nucleotides, expect many atoms
      expect(atom_lines.length, greaterThan(50), reason: 'Should have many ATOM records');
    });

    test('pdb_export_link_records_for_photoproduct_junction', () async {
      // Minimal single helix design with one double-stranded region.
      var helices = [Helix(idx: 0, max_offset: 7, grid: Grid.square)];
      var design = Design(helices: helices, grid: Grid.square);
      design = design.draw_strand(0, 0).to(7).commit();
      design = design.draw_strand(0, 7).move(-7).commit();

      var oxdna_dat_top = to_oxdna_format(design);
      String dat_content = oxdna_dat_top.item1;
      String top_content = oxdna_dat_top.item2;

      String pdb_template_content =
          await util.get_text_file_content('tests_inputs/pdb_export/dd12_na.pdb');

      // Manually construct a stable_id → (chain, residue_serial) mapping.
      // Strand 0 (chain A): 7 nucleotides; residue serials 1..7.
      // We designate position 2 (serial 3) as t1 and position 4 (serial 5) as t2.
      var stable_id_to_pdb_loc = <String, Tuple2<String, int>>{
        'fake-t1': Tuple2('A', 3),
        'fake-t2': Tuple2('A', 5),
      };
      var junction_pairs = [Tuple2('fake-t1', 'fake-t2')];

      String pdb_content = await export_pdb_from_oxdna_strings(
        top_content: top_content,
        dat_content: dat_content,
        pdb_template_content: pdb_template_content,
        oxDNA_direction: true,
        uniform_residue_names: false,
        junction_stable_id_pairs: junction_pairs,
        stable_id_to_pdb_loc: stable_id_to_pdb_loc,
      );

      List<String> lines = pdb_content.trim().split('\n');
      List<String> link_lines = lines.where((line) => line.startsWith('LINK')).toList();

      // Expect exactly 2 LINK records: C5–C5 and C6–C6.
      expect(link_lines.length, equals(2), reason: 'Should have 2 LINK records for one junction');

      // C5–C5 bond record.
      expect(link_lines.any((l) => l.contains(' C5 ') && l.indexOf(' C5 ', 12) < 40), isTrue,
          reason: 'Should have C5–C5 LINK record');

      // C6–C6 bond record.
      expect(link_lines.any((l) => l.contains(' C6 ')), isTrue,
          reason: 'Should have C6–C6 LINK record');

      // LINK records should appear before the first ATOM record.
      int first_link_idx = lines.indexWhere((l) => l.startsWith('LINK'));
      int first_atom_idx = lines.indexWhere((l) => l.startsWith('ATOM'));
      expect(first_link_idx, lessThan(first_atom_idx),
          reason: 'LINK records should precede ATOM records');

      // Distance field (last 5 chars) should be "1.57".
      for (var link in link_lines) {
        expect(link.trim().endsWith('1.57'), isTrue, reason: 'LINK distance should be 1.57 Å');
      }
    });
  });
}
