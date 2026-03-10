import 'dart:convert';
import 'dart:html';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:quiver/iterables.dart' as quiver;
import 'package:react/react.dart';
import 'package:built_collection/built_collection.dart';

import 'package:redux/redux.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/domain.dart';
import 'package:scadnano/src/state/extension.dart';
import 'package:scadnano/src/state/geometry.dart';
import 'package:scadnano/src/state/grid.dart';
import 'package:scadnano/src/state/loopout.dart';
import 'package:scadnano/src/state/position3d.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:tuple/tuple.dart';
import '../state/app_state.dart';
import '../state/photoproduct_junction.dart';
import '../state/t_base_location.dart';
import '../actions/actions.dart' as actions;
import '../state/helix.dart';
import '../util.dart' as util;
import 'export_cadnano_file.dart' as export_cadnano;
import '../constants.dart' as constants;

oxdna_export_middleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  if (action is actions.OxdnaExport || action is actions.OxviewExport) {
    AppState state = store.state;

    List<Strand> strands_to_export;
    if (action.selected_strands_only) {
      strands_to_export = store.state.ui_state.selectables_store.selected_strands.toList();
      if (strands_to_export.isEmpty) {
        window.alert('''\
No strands are selected, so nothing to export.
First select some strands, or choose Export🡒oxDNA to export all strands in the design.''');
        return;
      }
    } else {
      strands_to_export = state.design.strands.toList();
    }

    double fwd_x_offset = state.ui_state.loopout_fwd_x_offset;
    double rev_x_offset = state.ui_state.loopout_rev_x_offset;
    double fwd_z_offset = state.ui_state.loopout_fwd_z_offset;
    double rev_z_offset = state.ui_state.loopout_rev_z_offset;
    double fwd_theta = state.ui_state.loopout_fwd_theta;
    double rev_theta = state.ui_state.loopout_rev_theta;

    var cpd_junctions = state.design.photoproduct_junctions.toList();
    var cpd_t_base_locations = state.ui_state.t_base_locations;

    if (action is actions.OxdnaExport) {
      Tuple2<String, String> dat_top = to_oxdna_format(state.design, strands_to_export,
          fwd_x_offset, rev_x_offset, fwd_z_offset, rev_z_offset, fwd_theta, rev_theta,
          cpd_junctions, cpd_t_base_locations);
      String dat = dat_top.item1;
      String top = dat_top.item2;

      String default_filename = state.ui_state.loaded_filename;
      String default_filename_dat = path.setExtension(default_filename, '.dat');
      String default_filename_top = path.setExtension(default_filename, '.top');

      util.save_file(default_filename_dat, dat);
      util.save_file(default_filename_top, top);
    } else if (action is actions.OxviewExport) {
      // var start = DateTime.now();
      String content = to_oxview_format(state.design, strands_to_export,
          fwd_x_offset: fwd_x_offset,
          rev_x_offset: rev_x_offset,
          fwd_z_offset: fwd_z_offset,
          rev_z_offset: rev_z_offset,
          fwd_theta: fwd_theta,
          rev_theta: rev_theta,
          cpd_junctions: cpd_junctions,
          cpd_t_base_locations: cpd_t_base_locations);
      // print('to_oxview_format: ${DateTime.now().inMilliseconds} ms');
      String default_filename = state.ui_state.loaded_filename;
      String default_filename_ext = path.setExtension(default_filename, '.oxview');
      util.save_file(default_filename_ext, content);
    }
  }
  next(action);
}

String to_oxview_format(Design design, List<Strand> strands_to_export,
    {double fwd_x_offset = 0.5,
    double rev_x_offset = 0.5,
    double fwd_z_offset = 0.0,
    double rev_z_offset = 0.0,
    double fwd_theta = 0.0,
    double rev_theta = 0.0,
    List<PhotoproductJunction>? cpd_junctions,
    TBaseLocations? cpd_t_base_locations}) {
  // var start = DateTime.now();
  OxdnaSystem system = convert_design_to_oxdna_system(design, strands_to_export,
      fwd_x_offset, rev_x_offset, fwd_z_offset, rev_z_offset, fwd_theta, rev_theta,
      cpd_junctions, cpd_t_base_locations);
  // print('convert_design_to_oxdna_system: ${DateTime.now().difference(start).inMilliseconds} ms');

  // start = DateTime.now();
  List<Map<String, dynamic>> oxview_strands = [];
  int nuc_count = 0;
  int strand_count = 0;
  List<int> strand_nuc_start = [-1];
  assert(strands_to_export.length == system.strands.length);

  Map<String, dynamic> oxview_strand_map = {};
  Map<String, int> strand_id_to_index = {};
  List<String> strand_names_without_dna = [];
  for (int i = 0; i < strands_to_export.length; i++) {
    Strand sc_strand = strands_to_export[i];

    if (sc_strand.dna_sequence == null || sc_strand.dna_sequence!.contains(constants.DNA_BASE_WILDCARD)) {
      if (sc_strand.name != null) {
        strand_names_without_dna.add(sc_strand.name!);
      } else {
        strand_names_without_dna.add(sc_strand.id);
      }
    }

    strand_id_to_index[sc_strand.id] = i;
    OxdnaStrand oxdna_strand = system.strands[i];

    strand_count += 1;
    List<Map<String, dynamic>> oxvnucs = [];
    strand_nuc_start.add(nuc_count);
    Map<String, dynamic> oxv_strand = {
      'id': strand_count,
      'class': 'NucleicAcidStrand',
      'end5': nuc_count,
      'end3': nuc_count + system.strands[i].nucleotides.length,
      'monomers': oxvnucs,
    };
    oxview_strand_map[sc_strand.id] = oxv_strand;

    int scolor = export_cadnano.to_cadnano_v2_int_hex(sc_strand.color);

    for (int index_in_strand = 0; index_in_strand < oxdna_strand.nucleotides.length; index_in_strand++) {
      OxdnaNucleotide nuc = oxdna_strand.nucleotides[index_in_strand];
      Map<String, dynamic> oxvnuc = {
        'id': nuc_count,
        'p': [nuc.r.x, nuc.r.y, nuc.r.z],
        'a1': [nuc.b.x, nuc.b.y, nuc.b.z],
        'a3': [nuc.n.x, nuc.n.y, nuc.n.z],
        'class': 'DNA',
        'type': nuc.base,
        'cluster': 1,
      };
      if (index_in_strand != 0) {
        oxvnuc['n5'] = nuc_count - 1;
      }
      if (index_in_strand != oxdna_strand.nucleotides.length - 1) {
        oxvnuc['n3'] = nuc_count + 1;
      }
      // if (scolor != null) {
      oxvnuc['color'] = scolor;
      // }
      nuc_count += 1;
      oxvnucs.add(oxvnuc);
    }
    oxview_strands.add(oxv_strand);
  }

  if (strand_names_without_dna.isNotEmpty) {
    var msg =
        'The following strands do not have complete DNA sequences assigned: '
        '${strand_names_without_dna.join(", ")}. '
        'These strands will be exported with a default sequence of "T" '
        'for each nucleotide whose base is not specified. '
        'This can lead to unexpected behavior in oxView. For best results, '
        'assign a DNA sequence to each strand before exporting.';
    window.alert(msg);
  }

  //TODO: this hasn't been tested well
  var base_pairs_map = design.base_pairs_with_domain_strand(
    false,
    true,
    strands_to_export.toSet().build(),
    true,
  );
  for (int helix in base_pairs_map.keys) {
    for (var offset_dom_strands in base_pairs_map[helix]!) {
      int offset = offset_dom_strands.item1;
      Domain domain1 = offset_dom_strands.item2;
      Domain domain2 = offset_dom_strands.item3;
      Strand sc_strand1 = offset_dom_strands.item4;
      Strand sc_strand2 = offset_dom_strands.item5;
      Map<String, dynamic> oxv_strand1 = oxview_strand_map[sc_strand1.id];
      Map<String, dynamic> oxv_strand2 = oxview_strand_map[sc_strand2.id];
      int d1 = sc_strand1.domain_offset_to_strand_dna_idx(domain1, offset, false);
      int d2 = sc_strand2.domain_offset_to_strand_dna_idx(domain2, offset, false);
      int s1_nuc_idx = strand_nuc_start[strand_id_to_index[sc_strand1.id]! + 1];
      int s2_nuc_idx = strand_nuc_start[strand_id_to_index[sc_strand2.id]! + 1];
      oxv_strand1['monomers'][d1]['bp'] = s2_nuc_idx + d2;
      if (oxv_strand2['monomers'][d2].containsKey('bp')) {
        if (oxv_strand2['monomers'][d2]['bp'] != s1_nuc_idx + d1) {
          print(
            '${s2_nuc_idx + d2} ${s1_nuc_idx + d1} '
            '${oxv_strand2['monomers'][d2]['bp']} ${domain1} ${domain2}',
          );
          window.alert("You have found a bug in scadnano, please file a bug report.");
        }
      }
    }
  }

  // print('second loop: ${DateTime.now().difference(start).inMilliseconds} ms');
  var b = system.compute_bounding_box();
  Map<String, dynamic> oxvsystem = {
    'box': [b.x, b.y, b.z],
    'date': DateTime.now().toIso8601String(),
    'systems': [
      {'id': 0, 'strands': oxview_strands},
    ],
    'forces': [],
    'selections': [],
  };

  // start = DateTime.now();
  String content = jsonEncode(oxvsystem);
  // print('jsonEncode: ${DateTime.now().difference(start).inMilliseconds} ms');

  return content;
}

Tuple2<String, String> to_oxdna_format(Design design,
    [List<Strand>? strands_to_export = null,
    double fwd_x_offset = 0.5,
    double rev_x_offset = 0.5,
    double fwd_z_offset = 0.0,
    double rev_z_offset = 0.0,
    double fwd_theta = 0.0,
    double rev_theta = 0.0,
    List<PhotoproductJunction>? cpd_junctions = null,
    TBaseLocations? cpd_t_base_locations = null]) {
  OxdnaSystem system = convert_design_to_oxdna_system(design, strands_to_export,
      fwd_x_offset, rev_x_offset, fwd_z_offset, rev_z_offset, fwd_theta, rev_theta,
      cpd_junctions, cpd_t_base_locations);
  Tuple2<String, String> dat_top = system.oxdna_output();
  return dat_top;
}

class OxdnaVector {
  double x;
  double y;
  double z;

  OxdnaVector(this.x, this.y, this.z);

  double dot(OxdnaVector other) => x * other.x + y * other.y + z * other.z;

  OxdnaVector cross(OxdnaVector other) {
    double xc = y * other.z - z * other.y;
    double yc = z * other.x - x * other.z;
    double zc = x * other.y - y * other.x;
    return OxdnaVector(xc, yc, zc);
  }

  double length() => sqrt(x * x + y * y + z * z);

  OxdnaVector normalize() {
    double len = length();
    return OxdnaVector(x / len, y / len, z / len);
  }

  OxdnaVector coord_min(OxdnaVector other) => OxdnaVector(min(x, other.x), min(y, other.y), min(z, other.z));

  OxdnaVector coord_max(OxdnaVector other) => OxdnaVector(max(x, other.x), max(y, other.y), max(z, other.z));

  OxdnaVector operator +(OxdnaVector other) => OxdnaVector(x + other.x, y + other.y, z + other.z);

  OxdnaVector operator -(OxdnaVector other) => OxdnaVector(x - other.x, y - other.y, z - other.z);

  OxdnaVector operator *(num scalar) => OxdnaVector(x * scalar, y * scalar, z * scalar);

  OxdnaVector operator -() => OxdnaVector(-x, -y, -z);

  String toString() => '(${x}, ${y}, ${z})';

  OxdnaVector rotate(num angle, OxdnaVector axis) {
    OxdnaVector u = axis.normalize();
    double c = cos(angle * pi / 180);
    double s = sin(angle * pi / 180);

    OxdnaVector u_cross_this = u.cross(this);
    return u * dot(u) + (u_cross_this * c).cross(u) - (u_cross_this * s);
  }
}

// Constants related to oxdna export
const _GROOVE_GAMMA = 20.0;
const _BASE_DIST = 0.6;
final _OXDNA_ORIGIN = OxdnaVector(0, 0, 0);

/// r, b, and n represent the oxDNA conf file vectors that describe a nucleotide
/// r is the position of the base
/// b is the backbone-base vector (in documentation as versor: more info on versors here https://eater.net/quaternions)
/// n is the forward direction of the helix
class OxdnaNucleotide {
  OxdnaVector center;
  OxdnaVector normal;
  OxdnaVector forward;
  String base;

  OxdnaVector v = _OXDNA_ORIGIN; // velocity for oxDNA conf file
  OxdnaVector L = _OXDNA_ORIGIN; // angular velocity for oxDNA conf file

  OxdnaNucleotide(this.center, this.normal, this.forward, this.base);

  OxdnaVector get r => center - b * _BASE_DIST;

  OxdnaVector get b => -normal;

  OxdnaVector get n => forward;
}

class OxdnaStrand {
  List<OxdnaNucleotide> nucleotides = [];

  OxdnaStrand();

  OxdnaStrand join(OxdnaStrand other) => OxdnaStrand()..nucleotides = nucleotides + other.nucleotides;
}

/// represents an oxDNA system and contains a list of strands
/// from its list of strands it can compute the oxDNA conf and top files
class OxdnaSystem {
  List<OxdnaStrand> strands = [];

  OxdnaVector compute_bounding_box([bool cubic = true]) {
    OxdnaVector? min_vec = null;
    OxdnaVector? max_vec = null;

    for (var strand in strands) {
      for (var nuc in strand.nucleotides) {
        if (min_vec == null) {
          min_vec = nuc.center;
          max_vec = nuc.center;
        } else {
          min_vec = min_vec.coord_min(nuc.center);
          // we know max_vec got assigned with mix_vec if we are here
          max_vec = max_vec!.coord_max(nuc.center);
        }
      }
    }

    if (min_vec != null && max_vec != null) {
      // 5 is arbitrarily chosen so that the box has a bit of wiggle room
      // 1.5 multiplier is to make all crossovers appear (advice from Oxdna authors)
      var box = (max_vec - min_vec + OxdnaVector(5, 5, 5)) * 1.5;
      if (cubic) {
        // oxDNA requires cubic bounding box with default simulation options
        var max_side = max(box.x, max(box.y, box.z));
        box = OxdnaVector(max_side, max_side, max_side);
      }
      return box;
    } else {
      return OxdnaVector(1, 1, 1);
    }
  }

  Tuple2<String, String> oxdna_output() {
    OxdnaVector bbox = compute_bounding_box();

    List<String> dat_list = ['t = 0', 'b = ${bbox.x} ${bbox.y} ${bbox.z}', 'E = 0 0 0'];
    List<String> top_list = [];

    int nuc_count = 0;
    int strand_count = 0;

    for (var strand in strands) {
      strand_count += 1;

      int nuc_index = 0;
      for (var nuc in strand.nucleotides) {
        int n5 = nuc_count - 1;
        int n3 = nuc_count + 1;
        nuc_count += 1;

        if (nuc_index == 0) n5 = -1;
        if (nuc_index == strand.nucleotides.length - 1) n3 = -1;
        nuc_index += 1;

        top_list.add('${strand_count} ${nuc.base} ${n3} ${n5}');
        dat_list.add(
          '${nuc.r.x} ${nuc.r.y} ${nuc.r.z} ' +
              '${nuc.b.x} ${nuc.b.y} ${nuc.b.z} ' +
              '${nuc.n.x} ${nuc.n.y} ${nuc.n.z} ' +
              '${nuc.v.x} ${nuc.v.y} ${nuc.v.z} ' +
              '${nuc.L.x} ${nuc.L.y} ${nuc.L.z}',
        );
      }
    }

    String top = top_list.join('\n') + '\n';
    String dat = dat_list.join('\n') + '\n';

    top = '${nuc_count} ${strand_count}\n' + top;

    return Tuple2<String, String>(dat, top);
  }
}

const NM_TO_OX_UNITS = 1.0 / 0.8518;

// returns the origin, forward, and normal vectors of a helix
Tuple3<OxdnaVector, OxdnaVector, OxdnaVector> oxdna_get_helix_vectors(Design design, Helix helix) {
  /*
  TODO: document functions/methods with docstrings
  :param helix:
  :return: return tuple (origin, forward, normal)
      origin  -- the starting point of the center of a helix, assumed to be at offset 0
      forward -- the direction in which the helix propagates
      normal  -- a direction perpendicular to forward which represents the angle to the backbone at offset 0
          for the forward Domain on the Helix.
  */
  var group = design.groups[helix.group]!;
  var grid = group.grid;
  var geometry = group.geometry ?? design.geometry;

  // principal axes for computing rotation
  // see https://en.wikipedia.org/wiki/Aircraft_principal_axes
  var yaw_axis = OxdnaVector(0, 1, 0);
  var pitch_axis = OxdnaVector(1, 0, 0);
  var roll_axis = OxdnaVector(0, 0, 1);

  // we apply rotations in the order yaw, pitch, and then roll
  // the _OxdnaVector.rotate function applies ccw rotation so angle needs to be negated

  // first the yaw rotation
  pitch_axis = pitch_axis.rotate(-design.yaw_of_helix(helix), yaw_axis);
  roll_axis = roll_axis.rotate(-design.yaw_of_helix(helix), yaw_axis);

  // then the pitch rotation
  yaw_axis = yaw_axis.rotate(design.pitch_of_helix(helix), pitch_axis);
  roll_axis = roll_axis.rotate(design.pitch_of_helix(helix), pitch_axis);

  // then the roll rotation
  yaw_axis = yaw_axis.rotate(-group.roll, roll_axis);
  pitch_axis = pitch_axis.rotate(-group.roll, roll_axis);

  // by chosen convention, forward is the same as the roll axis
  // and normal is the negated yaw axis
  var forward = roll_axis;
  var normal = -yaw_axis;

  // account for helix roll separately or this would mess up the rotations of the axes above
  normal = normal.rotate(-helix.roll, roll_axis);

  var position_in_helix_group = Position3D();
  if (grid == Grid.none) {
    // unnecessary since this check is done in the position getter, but this way the code exactly mirrors
    // the Python package equivalent
    position_in_helix_group = helix.position(geometry);
  } else {
    position_in_helix_group = util.grid_position_to_position3d(helix.grid_position!, grid, geometry);
  }

  var position_in_helix_group_rotated =
      ((pitch_axis * position_in_helix_group.x) +
          (yaw_axis * position_in_helix_group.y) +
          (roll_axis * position_in_helix_group.z));

  var helix_group_offset = OxdnaVector(group.position.x, group.position.y, group.position.z);

  var origin = (position_in_helix_group_rotated + helix_group_offset) * NM_TO_OX_UNITS;

  return Tuple3<OxdnaVector, OxdnaVector, OxdnaVector>(origin, forward, normal);
}

/// Pull both thymine nucleotide centers to their midpoint for each confirmed
/// PhotoproductJunction.  This gives a clear "bonded" visual in oxView/oxDNA
/// without requiring any atomic-resolution geometry.  The base normals are
/// averaged so orientations remain plausible.  Silently skips junctions whose
/// stable IDs are not found in [t_base_locations] (e.g. if CPD detection has
/// not been run yet, or the junction involves strands not being exported).
void _apply_cpd_distortion(
  OxdnaSystem system,
  List<Strand> strands_to_export,
  TBaseLocations t_base_locations,
  List<PhotoproductJunction> junctions,
) {
  if (junctions.isEmpty) return;

  // Map strand_id → index in strands_to_export (= index in system.strands).
  var strand_id_to_idx = <String, int>{};
  for (int i = 0; i < strands_to_export.length; i++) {
    strand_id_to_idx[strands_to_export[i].id] = i;
  }

  // Map stable_id → (system-strand-index, logical_index_within_strand).
  var stable_to_loc = <String, Tuple2<int, int>>{};
  for (var t in t_base_locations.t_bases) {
    var idx = strand_id_to_idx[t.strand_id];
    if (idx == null) continue;
    stable_to_loc[t.stable_id] = Tuple2(idx, t.logical_index);
  }

  for (var junction in junctions) {
    var loc1 = stable_to_loc[junction.t1_stable_id];
    var loc2 = stable_to_loc[junction.t2_stable_id];
    if (loc1 == null || loc2 == null) continue;

    int si1 = loc1.item1, li1 = loc1.item2;
    int si2 = loc2.item1, li2 = loc2.item2;
    if (si1 >= system.strands.length || si2 >= system.strands.length) continue;

    var nucs1 = system.strands[si1].nucleotides;
    var nucs2 = system.strands[si2].nucleotides;
    if (li1 >= nucs1.length || li2 >= nucs2.length) continue;

    var nuc1 = nucs1[li1];
    var nuc2 = nucs2[li2];

    // Move both centers to midpoint so they appear co-located in oxView.
    var mid = (nuc1.center + nuc2.center) * 0.5;
    nuc1.center = mid;
    nuc2.center = mid;

    // Average backbone-base normals.  Guard against antiparallel cancellation
    // (which would produce a near-zero vector) by keeping nuc1's normal as a
    // fallback.
    var avg_normal_raw = nuc1.normal + nuc2.normal;
    nuc1.normal = avg_normal_raw.length() > 1e-6 ? avg_normal_raw.normalize() : nuc1.normal;
    nuc2.normal = nuc1.normal;
  }
}

OxdnaSystem convert_design_to_oxdna_system(Design design,
    [List<Strand>? strands_to_export = null,
    double fwd_x_offset = 0.5,
    double rev_x_offset = 0.5,
    double fwd_z_offset = 0.0,
    double rev_z_offset = 0.0,
    double fwd_theta = 0.0,
    double rev_theta = 0.0,
    List<PhotoproductJunction>? cpd_junctions = null,
    TBaseLocations? cpd_t_base_locations = null]) {
  if (strands_to_export == null) {
    strands_to_export = design.strands.toList();
  }

  var system = OxdnaSystem();

  // each entry is the number of insertions - deletions since the start of a given helix
  Map<int, List<int>> mod_map = {};
  for (int idx in design.helices.keys) {
    var helix = design.helices[idx]!;
    mod_map[idx] = List<int>.filled(helix.max_offset - helix.min_offset, 0);
  }

  // insert each insertion / deletion as a postive / negative number
  // TODO: report error if there is an insertion/deletion on one Domain and not the other
  for (var strand in strands_to_export) {
    for (var domain in strand.domains) {
      var helix = design.helices[domain.helix]!;
      for (var insertion in domain.insertions) {
        mod_map[domain.helix]![insertion.offset - helix.min_offset] = insertion.length;
      }
      for (int deletion in domain.deletions) {
        mod_map[domain.helix]![deletion - helix.min_offset] = -1;
      }
    }
  }

  // propagate the modifier so it stays consistent across domains
  for (int idx in design.helices.keys) {
    var helix = design.helices[idx]!;
    for (int offset = helix.min_offset + 1; offset < helix.max_offset; offset++) {
      mod_map[idx]![offset] += mod_map[idx]![offset - 1];
    }
  }

  // for efficiency just calculate each helix's vector once
  var helix_vectors = {
    for (var idx_helix in design.helices.entries)
      idx_helix.key: oxdna_get_helix_vectors(design, idx_helix.value),
  };

  for (var strand in strands_to_export) {
    List<Tuple2<OxdnaStrand, bool>> strand_domains = [];
    for (int ss_idx = 0; ss_idx < strand.substrands.length; ss_idx++) {
      var domain = strand.substrands[ss_idx];
      var ox_strand = OxdnaStrand();
      String? seq = domain.dna_sequence;
      if (seq == null) {
        seq = 'T' * domain.dna_length();
      }

      // handle normal domains
      if (domain is Domain) {
        var helix = design.helices[domain.helix]!;
        var group = design.groups[helix.group]!;
        var geometry = group.geometry ?? design.geometry;
        var step_rot = -360 / geometry.bases_per_turn;
        var origin_forward_normal = helix_vectors[helix.idx]!;
        var origin = origin_forward_normal.item1;
        var forward = origin_forward_normal.item2;
        var normal = origin_forward_normal.item3;

        if (!domain.forward) {
          normal = normal.rotate(-geometry.minor_groove_angle, forward);
          seq = seq.split('').reversed.join(''); // reverse DNA sequence
        }

        // oxDNA will rotate angles by +/- _GROOVE_GAMMA, so we first unrotate by that amount
        var groove_gamma_correction = domain.forward ? _GROOVE_GAMMA : -_GROOVE_GAMMA;
        normal = normal.rotate(groove_gamma_correction, forward);

        // dict / set for insertions / deletions to make lookup easier and cheaper when there are lots of them
        var deletions = Set<int>.from(domain.deletions);
        Map<int, int> insertions = {};
        for (var insertion in domain.insertions) {
          insertions[insertion.offset] = insertion.length;
        }

        // use Design.geometry or HelixGroup.geometry field to figure out various distances
        // https://github.com/UC-Davis-molecular-computing/scadnano/blob/master/lib/src/state/geometry.dart

        // index is used for finding the base in our sequence
        int index = 0;
        for (int offset = domain.start; offset < domain.end; offset++) {
          if (!deletions.contains(offset)) {
            var mod = mod_map[domain.helix]![offset - helix.min_offset];

            // we have to check insertions first because they affect the index
            if (insertions.containsKey(offset)) {
              int num = insertions[offset]!;
              for (int i = 0; i < num; i++) {
                var cen =
                    origin +
                    forward * (offset + mod - num + i) * geometry.rise_per_base_pair * NM_TO_OX_UNITS;
                var norm = normal.rotate(step_rot * (offset + mod - num + i), forward);
                var forw = domain.forward ? -forward : forward;
                var nuc = OxdnaNucleotide(cen, norm, forw, seq[index]);
                ox_strand.nucleotides.add(nuc);
                index += 1;
              }
            }

            var cen = origin + forward * (offset + mod) * geometry.rise_per_base_pair * NM_TO_OX_UNITS;
            var norm = normal.rotate(step_rot * (offset + mod), forward);
            var forw = domain.forward ? -forward : forward;
            var nuc = OxdnaNucleotide(cen, norm, forw, seq[index]);
            ox_strand.nucleotides.add(nuc);
            index += 1;
          }
        }

        // strands are stored from 5' to 3' end
        if (!domain.forward) {
          ox_strand.nucleotides = List<OxdnaNucleotide>.from(ox_strand.nucleotides.reversed);
        }
        strand_domains.add(Tuple2<OxdnaStrand, bool>(ox_strand, false));
        // because we need to know the positions of nucleotides before and after the loopout
        // we temporarily store domain strands with a boolean that is true if it's a loopout
        // handle loopouts
      } else if (domain is Loopout) {
        for (int i = 0; i < domain.dna_length(); i++) {
          String base = seq[i];
          // we place the loopout nucleotides at temporary nonsense positions and orientations
          // these will be updated later, for now we just need the base
          var center = OxdnaVector(0, 0, 0);
          var normal = OxdnaVector(0, -1, 0);
          var forward = OxdnaVector(0, 0, 1);
          var nuc = OxdnaNucleotide(center, normal, forward, base);
          ox_strand.nucleotides.add(nuc);
        }
        strand_domains.add(Tuple2<OxdnaStrand, bool>(ox_strand, true));
      } else if (domain is Extension) {
        bool is_5p = ss_idx == 0;
        var helix = design.helices[domain.adjacent_domain.helix]!;
        var group = design.groups[helix.group]!;
        var geometry = group.geometry ?? design.geometry;
        var nucleotides = _compute_extension_nucleotides(
          design: design,
          geometry: geometry,
          strand: strand,
          is_5p: is_5p,
          helix_vectors: helix_vectors,
          mod_map: mod_map,
        );
        ox_strand.nucleotides.addAll(nucleotides);
        strand_domains.add(Tuple2<OxdnaStrand, bool>(ox_strand, false));
      } else {
        throw AssertionError('unreachable');
      }
    }

    var sstrand = OxdnaStrand();
    // process loopouts and join strands
    for (int i = 0; i < strand_domains.length; i++) {
      var dstrand_is_loopout = strand_domains[i];
      var dstrand = dstrand_is_loopout.item1;
      var is_loopout = dstrand_is_loopout.item2;
      if (is_loopout) {
        var prev_nuc = strand_domains[i - 1].item1.nucleotides.last;
        var next_nuc = strand_domains[i + 1].item1.nucleotides.first;

        int strand_length = dstrand.nucleotides.length;

        // Direction from the previous nucleotide to the next (the interpolation axis).
        var connection = next_nuc.center - prev_nuc.center;

        // Out-of-plane direction: perpendicular to both the connection vector and
        // the helix axis.  We recover the helix axis from prev_nuc.forward because:
        //   nuc.forward = domain.forward ? -helix_axis : +helix_axis
        // so helix_axis = domain.forward ? -prev_nuc.forward : +prev_nuc.forward.
        //
        // We must NOT use prev_nuc.forward directly: opposing loopouts can have
        // one forward and one backward prev_domain, which would flip prev_nuc.forward
        // and cancel the connection-vector sign change — causing both loopouts to
        // arc in the same direction.  Using the recovered helix_axis keeps the
        // reference vector constant so cross products are always opposite.
        var prev_substrand = strand.substrands[i - 1];
        bool prev_is_forward = (prev_substrand is Domain) ? prev_substrand.forward : true;
        var helix_axis = prev_is_forward ? -prev_nuc.forward : prev_nuc.forward;
        var out_of_plane_raw = connection.cross(helix_axis);
        // Fall back to an arbitrary perpendicular if the vectors happen to be parallel.
        if (out_of_plane_raw.length() < 1e-6) {
          out_of_plane_raw = get_normal_vector_to(connection);
        }
        var out_of_plane = out_of_plane_raw.normalize();

        // Select parameters based on whether the preceding domain is forward or reverse.
        double x_off = prev_is_forward ? fwd_x_offset : rev_x_offset;
        double z_off = prev_is_forward ? fwd_z_offset : rev_z_offset;
        double theta = prev_is_forward ? fwd_theta : rev_theta;

        // Strand exit direction (5'→3' at the loopout junction = −helix_axis direction
        // for forward prev-domain, +helix_axis for reverse).  Naturally opposite for
        // opposing loopouts when their prev domains have mixed forward/backward orientations.
        var strand_exit_dir = -prev_nuc.forward;

        // Normal (backbone→base, a1 vector): rotate by theta in the
        // (out_of_plane, strand_exit_dir) plane.  Both vectors are unit-length and
        // orthogonal, so the result is already unit-length.
        //   theta = 0°   → points radially outward (out_of_plane)
        //   theta = 90°  → points along strand exit direction
        //   theta = 180° → points radially inward
        double theta_rad = theta * pi / 180.0;
        var norm_dir = out_of_plane * cos(theta_rad) + strand_exit_dir * sin(theta_rad);

        var conn_norm = connection.normalize();

        for (int loopout_idx = 0; loopout_idx < strand_length; loopout_idx++) {
          double t = (loopout_idx + 1) / (strand_length + 1);
          // Sine weight: zero at endpoints, maximum of 1 at midpoint.
          double bulge = sin(pi * t);
          // Position: direct radial (x_off) and axial (z_off) displacements, independent.
          OxdnaVector pos = prev_nuc.center +
              connection * t +
              out_of_plane * (x_off * bulge) +
              strand_exit_dir * (z_off * bulge);
          var old_nuc = dstrand.nucleotides[loopout_idx];
          var new_nuc = OxdnaNucleotide(pos, norm_dir, conn_norm, old_nuc.base);
          dstrand.nucleotides[loopout_idx] = new_nuc;
        }
      }
      sstrand = sstrand.join(dstrand);
    }
    system.strands.add(sstrand);
  }

  // Apply CPD geometry distortion: pull confirmed junction T-base centers together.
  if (cpd_junctions != null && cpd_junctions.isNotEmpty && cpd_t_base_locations != null) {
    _apply_cpd_distortion(system, strands_to_export, cpd_t_base_locations, cpd_junctions);
  }

  return system;
}

List<OxdnaNucleotide> _compute_extension_nucleotides({
  required Design design,
  required Geometry geometry,
  required Strand strand,
  required bool is_5p,
  required Map<int, Tuple3<OxdnaVector, OxdnaVector, OxdnaVector>> helix_vectors,
  required Map<int, List<int>> mod_map,
}) {
  var step_rot = -360 / geometry.bases_per_turn;

  var adj_dom = is_5p ? strand.domains.first : strand.domains.last;
  var adj_helix = design.helices[adj_dom.helix]!;
  var offset = is_5p ? adj_dom.offset_5p : adj_dom.offset_3p; // offset of attached end of domain

  var origin_forward_normal = helix_vectors[adj_dom.helix]!;
  var origin_ = origin_forward_normal.item1;
  var forward = origin_forward_normal.item2;
  var normal = origin_forward_normal.item3;

  if (!adj_dom.forward) {
    normal = normal.rotate(-geometry.minor_groove_angle, forward);
  }
  // oxDNA will rotate our backbone vector by +- _GROOVE_GAMMA (20 degrees)
  // we apply the opposite rotation so that we get the expected vector from scadnano in oxDNA
  var groove_gamma_correction = adj_dom.forward ? _GROOVE_GAMMA : -_GROOVE_GAMMA;
  normal = normal.rotate(groove_gamma_correction, forward).normalize();

  // rotate normal by angle about the forward vector to get vector pointing at backbone at attached_offset
  var mod = mod_map[adj_dom.helix]![offset - adj_helix.min_offset];
  var cen = origin_ + forward * (offset + mod) * geometry.rise_per_base_pair * NM_TO_OX_UNITS;
  var norm = normal.rotate(step_rot * (offset + mod), forward);
  // note oxDNA n vector points 3' to 5' opposite of scadnano forward vector
  var forw = adj_dom.forward ? -forward : forward;
  var ext = is_5p ? strand.substrands.first : strand.substrands.last;

  var seq = ext.dna_sequence;
  if (seq == null) {
    seq = 'T' * ext.dna_length();
  }
  assert(seq.length == ext.dna_length());
  if (is_5p) {
    seq = seq.split('').reversed.join('');
  }

  var new_forw = norm;
  var new_norm = forw;
  List<OxdnaNucleotide> nucs = [];
  for (int i = 0; i < seq.length; i++) {
    String base = seq[i];
    cen += norm;
    var nuc = OxdnaNucleotide(cen, new_norm, new_forw, base);
    nucs.add(nuc);
  }

  if (is_5p) {
    nucs = List<OxdnaNucleotide>.from(nucs.reversed);
  }

  return nucs;
}

OxdnaVector get_normal_vector_to(OxdnaVector vec) {
  var unit = OxdnaVector(1, 0, 0);
  var normalized_vec = vec.normalize();
  if (1 - normalized_vec.dot(unit).abs() < 0.001) {
    unit = OxdnaVector(0, 1, 0);
  }
  return unit.cross(vec);
}
