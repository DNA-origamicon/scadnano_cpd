import 'dart:math';

import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';
import './oxdna_data.dart';
import './oxdna_file_parser.dart';
import '../constants.dart' as constants;

// #################################################################### //
// Port of tacoxdna's oxDNA-to-PDB converter
// Source: https://github.com/LSU-CompBio/tacoxdna/
// Files ported: src/oxDNA_PDB.py, src/libs/pdb.py, src/libs/utils.py
// #################################################################### //

const FROM_OXDNA_TO_ANGSTROM = 8.518;
const BASE_NAME_TO_CHAR = {"ADE": "A", "CYT": "C", "GUA": "G", "THY": "T", "URA": "U"};
const BASE_SHIFT = 1.13;

extension on OxdnaVector {
  OxdnaVector copy() => OxdnaVector(this.x, this.y, this.z);
}

// Port of tacoxdna's src/libs/pdb.py Atom class
class PdbAtom {
  String name;
  String residue;
  String chain_id;
  int residue_idx;
  OxdnaVector pos;
  double occupancy;
  double bfactor;
  static int serial_atom_idx = 1;

  PdbAtom(
    this.name,
    this.residue,
    this.chain_id,
    this.residue_idx,
    this.pos, {
    this.occupancy = 1.0,
    this.bfactor = 0.0,
  });

  factory PdbAtom.from_pdb_line(String pdb_line) {
    // http://cupnet.net/pdb-format/
    var name = pdb_line.substring(12, 16).trim();
    if (name.contains("*")) {
      name = name.replaceAll("*", "'");
    }
    var residue = pdb_line.substring(17, 20).trim();
    var chain_id = pdb_line.substring(21, 22).trim();
    var residue_idx = int.parse(pdb_line.substring(22, 26).trim());
    var pos = OxdnaVector(
      double.parse(pdb_line.substring(30, 38)),
      double.parse(pdb_line.substring(38, 46)),
      double.parse(pdb_line.substring(46, 54)),
    );
    var occupancy = double.parse(pdb_line.substring(54, 60));
    var bfactor = double.parse(pdb_line.substring(60, 66));
    return PdbAtom(name, residue, chain_id, residue_idx, pos, occupancy: occupancy, bfactor: bfactor);
  }

  PdbAtom.copy(PdbAtom other)
    : this(
        other.name,
        other.residue,
        other.chain_id,
        other.residue_idx,
        other.pos.copy(),
        occupancy: other.occupancy,
        bfactor: other.bfactor,
      );

  void shift(OxdnaVector diff) {
    this.pos += diff;
  }

  String to_pdb_line(
    String chain_identifier,
    int residue_serial,
    String residue_suffix, {
    double bfactor = 0.0,
  }) {
    var residue_full_name = this.residue + residue_suffix;
    var atom_name = this.name;
    var atom_name_padded;
    if (atom_name.length >= 4) {
      atom_name_padded = atom_name;
    } else {
      var pad_total = 4 - atom_name.length;
      var pad_left = (pad_total / 2).ceil();
      var pad_right = (pad_total / 2).floor();
      atom_name_padded = (' ' * pad_left) + atom_name + (' ' * pad_right);
    }

    // Extract element symbol (handles cases like "1H7", "2H5'" where H is the element)
    var element = '';
    if (atom_name.contains('H')) {
      element = 'H';
    } else if (atom_name.contains('C')) {
      element = 'C';
    } else if (atom_name.contains('N')) {
      element = 'N';
    } else if (atom_name.contains('O')) {
      element = 'O';
    } else if (atom_name.contains('P')) {
      element = 'P';
    } else {
      // Fallback to first character if no known element found
      element = this.name[0];
    }

    var line =
        "ATOM  "
        "${PdbAtom.serial_atom_idx.toString().padLeft(5)} "
        "$atom_name_padded"
        " "
        "${residue_full_name.padRight(3)} "
        "$chain_identifier"
        "${residue_serial.toString().padLeft(4)} "
        "   "
        "${pos.x.toStringAsFixed(3).padLeft(8)}"
        "${pos.y.toStringAsFixed(3).padLeft(8)}"
        "${pos.z.toStringAsFixed(3).padLeft(8)}"
        "${this.occupancy.toStringAsFixed(2).padLeft(6)}"
        "${bfactor.toStringAsFixed(2).padLeft(6)}"
        "          "
        "${element.padLeft(2)}"
        "  ";
    PdbAtom.serial_atom_idx++;
    if (PdbAtom.serial_atom_idx > 99999) {
      PdbAtom.serial_atom_idx = 1;
    }
    return line;
  }
}

class PdbNucleotide {
  String name;
  int idx;
  String base;
  List<PdbAtom> base_atoms = [];
  List<PdbAtom> phosphate_atoms = [];
  List<PdbAtom> sugar_atoms = [];
  List<PdbAtom> get atoms => [...base_atoms, ...phosphate_atoms, ...sugar_atoms];
  Map<String, PdbAtom> named_atoms = {};
  String chain_id = '';

  /// Unit vector indicating orientation of backbone with respect to base (points from backbone to base).
  OxdnaVector? a1;

  /// Cross product of a3 and a1.
  OxdnaVector? a2;

  /// Unit vector indicating orientation of the base normal.
  OxdnaVector? a3;

  double? check;

  PdbNucleotide(this.name, this.idx, this.base);

  PdbNucleotide.copy(PdbNucleotide other)
    : this.name = other.name,
      this.idx = other.idx,
      this.base = other.base,
      this.base_atoms = [],
      this.phosphate_atoms = [],
      this.sugar_atoms = [],
      this.named_atoms = {},
      this.chain_id = other.chain_id,
      this.a1 = other.a1?.copy(),
      this.a2 = other.a2?.copy(),
      this.a3 = other.a3?.copy(),
      this.check = other.check {
    // Copy atoms and ensure named_atoms points to the same instances
    for (var atom in other.atoms) {
      this.add_atom(PdbAtom.copy(atom));
    }
  }

  void add_atom(PdbAtom atom) {
    if (atom.name.contains('P') || atom.name == "HO5'") {
      phosphate_atoms.add(atom);
    } else if (atom.name.contains("'")) {
      sugar_atoms.add(atom);
    } else {
      base_atoms.add(atom);
    }
    named_atoms[atom.name] = atom;
    if (chain_id == '') {
      chain_id = atom.chain_id;
    }
  }

  void compute_as() {
    compute_a1();
    compute_a3();
    a2 = a3!.cross(a1!);
    check = a1!.dot(a3!).abs();
  }

  void compute_a1() {
    List<List<String>> pairs;
    if (name.contains("C") || name.contains("T") || name.contains("U")) {
      pairs = [
        ["N3", "C6"],
        ["C2", "N1"],
        ["C4", "C5"],
      ];
    } else {
      pairs = [
        ["N1", "C4"],
        ["C2", "N3"],
        ["C6", "C5"],
      ];
    }
    this.a1 = OxdnaVector(0, 0, 0);
    for (var pair in pairs) {
      var p = named_atoms[pair[0]]!;
      var q = named_atoms[pair[1]]!;
      var diff = p.pos - q.pos;
      this.a1 = this.a1! + diff;
    }
    this.a1 = this.a1!.normalize();
  }

  void compute_a3() {
    // tacoxdna computes base_com using ALL base atoms, not just ring atoms
    var base_com = get_com(base_atoms);
    // Comment from tacoxdna version of the converter:
    // "The O4' oxygen is always (at least for non-pathological configurations, as far as I know)"
    // "oriented 3' -> 5' with respect to the base's centre of mass."
    var parallel_to = named_atoms["O4'"]!.pos - base_com;

    var a3_sum = OxdnaVector(0, 0, 0);

    // But for permutations, we only use the ring atoms
    var all_ring_names = ["C2", "C4", "C5", "C6", "N1", "N3"];
    var available_ring_names = <String>[];
    for (var name in all_ring_names) {
      if (named_atoms.containsKey(name)) {
        available_ring_names.add(name);
      }
    }

    for (var perm in _permutations(available_ring_names, 3)) {
      var p = named_atoms[perm[0]]!;
      var q = named_atoms[perm[1]]!;
      var r = named_atoms[perm[2]]!;
      var v1 = (p.pos - q.pos).normalize();
      var v2 = (p.pos - r.pos).normalize();

      var a3_current = v1.cross(v2);

      if (a3_current.length_sq() > 1e-12) {
        a3_current = a3_current.normalize();
        if (a3_current.dot(parallel_to) < 0) {
          a3_current = -a3_current;
        }
        a3_sum = a3_sum + a3_current;
      }
    }
    this.a3 = a3_sum.normalize();
  }

  void correct_for_large_boxes(OxdnaVector box) {
    for (var atom in atoms) {
      // Equivalent of: atom.shift(-np.rint(atom.pos / box) * box)
      var scaled_pos = OxdnaVector(atom.pos.x / box.x, atom.pos.y / box.y, atom.pos.z / box.z);
      var rounded = OxdnaVector(
        scaled_pos.x.roundToDouble(),
        scaled_pos.y.roundToDouble(),
        scaled_pos.z.roundToDouble(),
      );
      var shift = OxdnaVector(rounded.x * box.x, rounded.y * box.y, rounded.z * box.z);
      atom.shift(-shift);
    }
  }

  void set_base(OxdnaVector new_base_com) {
    var ring_atoms = <PdbAtom>[];
    for (var name in ["C2", "C4", "C5", "C6", "N1", "N3"]) {
      if (named_atoms.containsKey(name)) {
        ring_atoms.add(named_atoms[name]!);
      }
    }
    var ring_com = get_com(ring_atoms);
    var diff = new_base_com - ring_com - (this.a1! * BASE_SHIFT);
    for (var a in atoms) {
      a.shift(diff);
    }
    compute_as();
  }

  String to_pdb({
    required String chain_identifier,
    required String residue_type,
    required int residue_serial,
    required String residue_suffix,
    double bfactor = 0.0,
  }) {
    var lines = <String>[];
    // NOTE: Commenting out to match tacoxdna's undefined phosphorus/O3prime variables (bug?)
    // PdbAtom? phosphorus;
    // PdbAtom? o5_prime;
    // PdbAtom? o3_prime;

    var atoms_to_print = atoms;

    for (var a in atoms_to_print) {
      if (residue_type == '5') {
        if (a.name == 'P') {
          // phosphorus = a;
        } else if (a.name == "HO5'") {
          continue; // Don't print the template's terminal HO5'
        } else if (a.name == "O5'") {
          // o5_prime = a;
        }
      } else if (residue_type == '3') {
        if (a.name == "HO3'") {
          continue; // Don't print the template's terminal HO3'
        } else if (a.name == "O3'") {
          // o3_prime = a;
        }
      }

      // Don't append suffix if template already has a terminal residue name
      var effective_suffix = residue_suffix;
      if ((a.residue.endsWith('3') || a.residue.endsWith('5')) && residue_suffix.isNotEmpty) {
        effective_suffix = '';
      }

      lines.add(a.to_pdb_line(chain_identifier, residue_serial, effective_suffix, bfactor: bfactor));
    }

    // Add terminal hydrogens for 3' or 5' ends
    // NOTE: Commenting out to match tacoxdna's behavior where this fails due to undefined phosphorus/O3prime variables (bug?)
    /*
    if (residue_type == '5' && phosphorus != null && o5_prime != null) {
      // Create HO5' hydrogen
      var new_hydrogen = PdbAtom.copy(phosphorus);
      new_hydrogen.name = "HO5'";
      // Set residue to base name without terminal suffix
      new_hydrogen.residue = this.base == 'A'
          ? 'DA'
          : this.base == 'G'
              ? 'DG'
              : this.base == 'C'
                  ? 'DC'
                  : 'DT';

      // Position 1 Angstrom from O5' along P-O5' direction
      var dist_P_O = (phosphorus.pos - o5_prime.pos).normalize();
      new_hydrogen.pos = o5_prime.pos + dist_P_O;

      lines.add(new_hydrogen.to_pdb_line(chain_identifier, residue_serial, '', bfactor: bfactor));
    }
    */

    return lines.join('\n');
  }

  OxdnaVector get_com(List<PdbAtom> atoms) {
    if (atoms.isEmpty) return OxdnaVector(0, 0, 0);
    var com = OxdnaVector(0, 0, 0);
    for (var atom in atoms) {
      com += atom.pos;
    }
    return com * (1.0 / atoms.length);
  }
}

void align(PdbNucleotide full_base, OxdnaNucleotide ox_base) {
  var theta = angle_between(full_base.a3!, ox_base.a3);
  if (sin(theta) > 1e-3) {
    var axis = full_base.a3!.cross(ox_base.a3);
    axis = axis.normalize();
    var R = rotation_matrix(axis, theta);
    full_base.rotate(R);
  }

  theta = angle_between(full_base.a1!, ox_base.a1);
  if (sin(theta) > 1e-3) {
    var axis = full_base.a1!.cross(ox_base.a1);
    axis = axis.normalize();
    var R = rotation_matrix(axis, theta);
    full_base.rotate(R);
  }
}

extension on PdbNucleotide {
  void rotate(List<List<double>> R) {
    var com = get_com(this.atoms);
    for (var atom in atoms) {
      // Translate to origin
      var pos_centered = atom.pos - com;
      // Apply rotation
      var rotated = OxdnaVector(
        R[0][0] * pos_centered.x + R[0][1] * pos_centered.y + R[0][2] * pos_centered.z,
        R[1][0] * pos_centered.x + R[1][1] * pos_centered.y + R[1][2] * pos_centered.z,
        R[2][0] * pos_centered.x + R[2][1] * pos_centered.y + R[2][2] * pos_centered.z,
      );
      // Translate back
      atom.pos = rotated + com;
    }
    compute_as();
  }
}

Iterable<List<T>> _permutations<T>(List<T> list, int length) {
  if (length <= 0 || length > list.length) {
    return const [];
  }

  // generates permutations in lexicographic order to match tacoxdna's behavior
  var result = <List<T>>[];

  void permute(List<T> current, List<bool> used) {
    if (current.length == length) {
      result.add(List<T>.from(current));
      return;
    }

    for (int i = 0; i < list.length; i++) {
      if (!used[i]) {
        used[i] = true;
        current.add(list[i]);
        permute(current, used);
        current.removeLast();
        used[i] = false;
      }
    }
  }

  permute([], List<bool>.filled(list.length, false));
  return result;
}

Tuple3<OxdnaVector, OxdnaVector, OxdnaVector> get_orthonormalized_base(
  OxdnaVector v1,
  OxdnaVector v2,
  OxdnaVector v3,
) {
  double v1_norm2 = v1.dot(v1);
  double v2_v1 = v2.dot(v1);
  v2 = v2 - (v1 * (v2_v1 / v1_norm2));
  double v3_v1 = v3.dot(v1);
  double v3_v2 = v3.dot(v2);
  double v2_norm2 = v2.dot(v2);
  v3 = v3 - (v1 * (v3_v1 / v1_norm2)) - (v2 * (v3_v2 / v2_norm2));
  v1 = v1 * (1.0 / sqrt(v1_norm2));
  v2 = v2 * (1.0 / sqrt(v2_norm2));
  v3 = v3 * (1.0 / sqrt(v3.length_sq()));
  return Tuple3(v1, v2, v3);
}

double angle_between(OxdnaVector a, OxdnaVector b) {
  var ab = a.dot(b);
  if (ab > (1.0 - 1e-6)) {
    return 0.0;
  } else if (ab < (-1.0 + 1e-6)) {
    return pi;
  } else {
    return acos(ab);
  }
}

List<List<double>> rotation_matrix(OxdnaVector axis, double angle) {
  var ct = cos(angle);
  var st = sin(angle);
  var olc = 1.0 - ct;
  var axis_norm = axis.normalize();
  var x = axis_norm.x;
  var y = axis_norm.y;
  var z = axis_norm.z;
  return [
    [olc * x * x + ct, olc * x * y - st * z, olc * x * z + st * y],
    [olc * x * y + st * z, olc * y * y + ct, olc * y * z - st * x],
    [olc * x * z - st * y, olc * y * z + st * x, olc * z * z + ct],
  ];
}

Map<String, PdbNucleotide> parse_pdb_template_from_string(String pdb_file_content) {
  var lines = pdb_file_content.split('\n');
  var nucleotides = <PdbNucleotide>[];
  int? old_residue_idx;
  const BASES = ["A", "T", "G", "C", "U"];

  for (var line in lines) {
    if (line.startsWith('ATOM')) {
      var atom = PdbAtom.from_pdb_line(line);
      if (atom.residue_idx != old_residue_idx) {
        var residue_name = atom.residue.trim();

        var base_char;
        if (BASE_NAME_TO_CHAR.containsKey(residue_name)) {
          base_char = BASE_NAME_TO_CHAR[residue_name]!;
        } else if (BASES.contains(residue_name)) {
          base_char = residue_name;
        } else {
          // Handle DNA nucleotides like DA, DC, DG, DT, DC5, DG3
          if (residue_name.startsWith('D') && residue_name.length >= 2) {
            var second_char = residue_name[1];
            if (BASES.contains(second_char)) {
              base_char = second_char;
            } else {
              // Fallback for unexpected cases
              base_char = residue_name.substring(1);
            }
          } else {
            // Fallback for other cases
            base_char = residue_name.substring(1);
          }
        }
        var nuc = PdbNucleotide(residue_name, atom.residue_idx, base_char);
        nucleotides.add(nuc);
        old_residue_idx = atom.residue_idx;
      }
      nucleotides.last.add_atom(atom);
    }
  }

  Map<String, PdbNucleotide> templates = {};
  for (var n in nucleotides) {
    n.compute_as();
    // Prefer non-terminal templates over terminal ones
    bool isTerminalTemplate = n.name.endsWith('3') || n.name.endsWith('5');

    if (!templates.containsKey(n.base)) {
      templates[n.base] = PdbNucleotide.copy(n);
    } else {
      // If we already have a template for this base
      var existingTemplate = templates[n.base]!;
      bool existingIsTerminal = existingTemplate.name.endsWith('3') || existingTemplate.name.endsWith('5');

      // Replace if:
      // 1. Current is non-terminal and existing is terminal, OR
      // 2. Both are same type (terminal/non-terminal) and current has better check value
      if ((!isTerminalTemplate && existingIsTerminal) ||
          (isTerminalTemplate == existingIsTerminal && n.check! < existingTemplate.check!)) {
        templates[n.base] = PdbNucleotide.copy(n);
      }
    }
  }

  for (var n in templates.values) {
    var orthonormalized = get_orthonormalized_base(n.a1!, n.a2!, n.a3!);
    n.a1 = orthonormalized.item1;
    n.a2 = orthonormalized.item2;
    n.a3 = orthonormalized.item3;
  }
  return templates;
}

Future<String> export_pdb_from_oxdna_strings({
  required String top_content,
  required String dat_content,
  required String pdb_template_content,
  bool oxDNA_direction = true,
  bool uniform_residue_names = false,
}) async {
  Map<String, PdbNucleotide> templates = parse_pdb_template_from_string(pdb_template_content);
  var lorenzoReader = LorenzoReader(top_content, dat_content);
  OxdnaSystem system = lorenzoReader.getSystem();
  var com = OxdnaVector(0, 0, 0);
  for (var strand in system.strands) {
    com += strand.get_cm_pos();
  }
  if (system.strands.isNotEmpty) {
    com *= (1.0 / system.strands.length);
  }

  var box_angstrom = system.box * FROM_OXDNA_TO_ANGSTROM;
  var correct_for_large_boxes = false;
  if (box_angstrom.x > 999 || box_angstrom.y > 999 || box_angstrom.z > 999) {
    print(
      'Warning: At least one of the box sizes is larger than 999. Atoms outside the box will be brought back through periodic boundary conditions.',
    );
    correct_for_large_boxes = true;
  }

  PdbAtom.serial_atom_idx = 1;
  var pdb_lines = <String>[];
  List<String> strand_chain_letters = [];
  for (int i = 0; i < system.strands.length; i++) {
    int letter_idx = i % 26;
    strand_chain_letters.add(String.fromCharCode('A'.codeUnitAt(0) + letter_idx));
  }
  for (var strand_idx = 0; strand_idx < system.strands.length; strand_idx++) {
    var ox_strand = system.strands[strand_idx];
    var nucleotides_in_strand = ox_strand.nucleotides;
    if (!oxDNA_direction) {
      nucleotides_in_strand = nucleotides_in_strand.reversed.toList();
    }

    for (var n_idx = 0; n_idx < nucleotides_in_strand.length; n_idx++) {
      var ox_nuc = nucleotides_in_strand[n_idx];
      var template = templates[ox_nuc.base]!;
      var pdb_nuc = PdbNucleotide.copy(template);
      pdb_nuc.chain_id = strand_chain_letters[system.strand_id_of(ox_nuc)];

      align(pdb_nuc, ox_nuc);

      pdb_nuc.set_base((ox_nuc.pos_base - com) * FROM_OXDNA_TO_ANGSTROM);

      if (correct_for_large_boxes) {
        pdb_nuc.correct_for_large_boxes(box_angstrom);
      }

      var residue_type = '';
      if (!ox_strand.is_circular) {
        if (identical(ox_nuc, ox_strand.nucleotides[0])) {
          residue_type = '3';
        } else if (identical(ox_nuc, ox_strand.nucleotides[ox_strand.nucleotides.length - 1])) {
          residue_type = '5';
        }
      }

      var residue_suffix = uniform_residue_names ? '' : residue_type;
      int residue_serial = (n_idx + 1) % 9999;
      if (residue_serial == 0) {
        residue_serial = 9999;
      }
      pdb_lines.add(
        pdb_nuc.to_pdb(
          chain_identifier: strand_chain_letters[strand_idx],
          residue_type: residue_type,
          residue_serial: residue_serial,
          residue_suffix: residue_suffix,
        ),
      );
    }
    pdb_lines.add('TER');
  }
  return pdb_lines.join('\n') + '\n';
}
