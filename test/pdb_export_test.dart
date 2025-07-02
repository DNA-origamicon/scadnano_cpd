import 'dart:async';
import 'dart:html';

import 'package:test/test.dart';

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
  });
}
