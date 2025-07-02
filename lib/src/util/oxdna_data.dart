import 'dart:math';

// ###################################################### //
// Port of tacoxdna's data structures for oxDNA systems.
// Source: https://github.com/LSU-CompBio/tacoxdna/
// Files ported: src/libs/base.py
// ###################################################### //

// Constants from oxDNA needed for PDB export
const POS_BASE = 0.4;
const POS_STACK = 0.34;
const POS_BACK = -0.4;

// Represents a 3D vector for oxDNA calculations.
class OxdnaVector {
  double x, y, z;

  OxdnaVector(this.x, this.y, this.z);

  // Vector operations
  OxdnaVector operator +(OxdnaVector other) => OxdnaVector(x + other.x, y + other.y, z + other.z);
  OxdnaVector operator -(OxdnaVector other) => OxdnaVector(x - other.x, y - other.y, z - other.z);
  OxdnaVector operator *(double scalar) => OxdnaVector(x * scalar, y * scalar, z * scalar);
  OxdnaVector operator -() => OxdnaVector(-x, -y, -z);
  double dot(OxdnaVector other) => x * other.x + y * other.y + z * other.z;
  OxdnaVector cross(OxdnaVector other) =>
      OxdnaVector(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x);
  OxdnaVector normalize() {
    var length = this.length();
    if (length == 0) return OxdnaVector(0, 0, 0);
    return OxdnaVector(x / length, y / length, z / length);
  }

  double length_sq() => x * x + y * y + z * z;
  double length() => sqrt(length_sq());

  @override
  String toString() => '($x, $y, $z)';
}

// Represents a single nucleotide in the oxDNA format.
class OxdnaNucleotide {
  final int id;
  final OxdnaVector cm_pos;
  final OxdnaVector a1;
  final OxdnaVector a3;
  final String base;
  int n3;
  int n5;

  OxdnaNucleotide(this.id, this.cm_pos, this.a1, this.a3, this.base, this.n3, this.n5);

  // Calculated properties matching tacoxdna's base.py
  OxdnaVector get a2 => a3.cross(a1);
  OxdnaVector get pos_base => cm_pos + a1 * POS_BASE;
  OxdnaVector get pos_stack => cm_pos + a1 * POS_STACK;
  OxdnaVector get pos_back => cm_pos + a1 * POS_BACK;
}

// Represents a strand of nucleotides in the oxDNA format.
class OxdnaStrand {
  final List<OxdnaNucleotide> nucleotides;
  bool is_circular = false;

  OxdnaStrand(this.nucleotides);

  OxdnaVector get_cm_pos() {
    var com = OxdnaVector(0, 0, 0);
    for (var nuc in nucleotides) {
      com += nuc.cm_pos;
    }
    return com * (1.0 / nucleotides.length);
  }
}

// Represents the entire DNA system in the oxDNA format.
class OxdnaSystem {
  final List<OxdnaStrand> strands;
  final OxdnaVector box;
  final List<int> _nucleotide_to_strand_map;

  OxdnaSystem(this.strands, this.box) : _nucleotide_to_strand_map = _map_nucleotides_to_strands(strands);

  static List<int> _map_nucleotides_to_strands(List<OxdnaStrand> strands) {
    var map = <int>[];
    for (var i = 0; i < strands.length; i++) {
      for (var _ in strands[i].nucleotides) {
        map.add(i);
      }
    }
    return map;
  }

  int strand_id_of(OxdnaNucleotide nuc) => _nucleotide_to_strand_map[nuc.id];
}
