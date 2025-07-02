import './oxdna_data.dart';

// ################################################## //
// Port of tacoxdna's LorenzoReader
// Source: https://github.com/LSU-CompBio/tacoxdna/
// Files ported: src/libs/readers.py
// ################################################## //

const BASE_TO_NUMBER = {'A': 0, 'G': 1, 'C': 2, 'T': 3, 'U': 3};
const NUMBER_TO_BASE = {0: 'A', 1: 'G', 2: 'C', 3: 'T'};


class LorenzoReader {
  String _top_content;
  String _dat_content;

  LorenzoReader(this._top_content, this._dat_content);

  OxdnaSystem getSystem() {
    List<String> top_lines = _top_content.split('\n').where((line) => line.isNotEmpty).toList();
    List<String> dat_lines = _dat_content.split('\n').where((line) => line.trim().isNotEmpty).toList();

    if (top_lines.isEmpty) {
      throw ArgumentError("Topology file is empty");
    }
    if (dat_lines.length < 4) {
      throw ArgumentError(
        "Configuration file should have at least 4 lines (t, b, E, and at least one nucleotide)",
      );
    }

    var header_parts = top_lines[0].split(' ');
    int total_nucleotides = int.parse(header_parts[0]);

    // Parse box dimensions from the second line of the .dat file
    var box_parts = dat_lines[1].split(' ');
    var box = OxdnaVector(double.parse(box_parts[2]), double.parse(box_parts[3]), double.parse(box_parts[4]));

    var data_lines = dat_lines.sublist(3);

    if (data_lines.length != total_nucleotides) {
      throw ArgumentError("Number of nucleotides in topology and configuration files do not match.");
    }

    var all_nucleotides = <OxdnaNucleotide>[];
    for (int i = 0; i < data_lines.length; i++) {
      var top_line_parts = top_lines[i + 1].split(' ');
      var dat_line_parts = data_lines[i].split(' ');

      // The topology file can store base as a character or an integer.
      var base_str = top_line_parts[1];
      var base_char;
      if (BASE_TO_NUMBER.containsKey(base_str)) {
        base_char = base_str;
      } else {
        var base_int = int.parse(base_str);
        base_char = NUMBER_TO_BASE[base_int % 4]!;
      }

      int n3 = int.parse(top_line_parts[2]);
      int n5 = int.parse(top_line_parts[3]);

      var cm_pos = OxdnaVector(
        double.parse(dat_line_parts[0]),
        double.parse(dat_line_parts[1]),
        double.parse(dat_line_parts[2]),
      );
      var a1 = OxdnaVector(
        double.parse(dat_line_parts[3]),
        double.parse(dat_line_parts[4]),
        double.parse(dat_line_parts[5]),
      );
      var a3 = OxdnaVector(
        double.parse(dat_line_parts[6]),
        double.parse(dat_line_parts[7]),
        double.parse(dat_line_parts[8]),
      );

      all_nucleotides.add(OxdnaNucleotide(i, cm_pos, a1, a3, base_char, n3, n5));
    }

    var strands = <OxdnaStrand>[];
    if (all_nucleotides.isNotEmpty) {
      int? current_strand_id;
      var current_strand_nucleotides = <OxdnaNucleotide>[];

      for (int i = 0; i < top_lines.length - 1; i++) {
        var parts = top_lines[i + 1].split(' ');
        int strand_id = int.parse(parts[0]);

        if (current_strand_id == null) {
          current_strand_id = strand_id;
        }

        if (strand_id != current_strand_id) {
          var strand = OxdnaStrand(current_strand_nucleotides);
          // Check for circularity
          if (strand.nucleotides.first.n3 == strand.nucleotides.last.id) {
            strand.is_circular = true;
          }
          strands.add(strand);

          current_strand_nucleotides = [];
          current_strand_id = strand_id;
        }
        current_strand_nucleotides.add(all_nucleotides[i]);
      }

      if (current_strand_nucleotides.isNotEmpty) {
        var strand = OxdnaStrand(current_strand_nucleotides);
        if (strand.nucleotides.first.n3 != -1 && strand.nucleotides.first.n3 == all_nucleotides.last.id) {
          strand.is_circular = true;
        }
        strands.add(strand);
      }
    }

    return OxdnaSystem(strands, box);
  }
}
