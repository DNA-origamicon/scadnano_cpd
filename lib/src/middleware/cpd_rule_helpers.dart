import 'dart:math'; // For Point and max()

import 'package:tuple/tuple.dart'; // For Tuple3 used in RuleProcessor return type hint
import 'package:built_collection/built_collection.dart';

import '../state/strand.dart';
import '../state/substrand.dart';
import '../state/domain.dart';
import '../state/extension.dart';
import '../state/loopout.dart';
import '../state/cpd_site.dart';
import '../state/t_base_location.dart';
import '../state/design.dart';

enum SubstrandTypeEnum { DOMAIN, EXTENSION, LOOPOUT }

//##############################################################################
// CPD Rule Processing Data Structures & Conditions
//##############################################################################

/// Holds comprehensive data about a T-base, including precomputed characteristics.
class TBaseData {
  // Original/Source Info
  final String stable_id;
  final String parent_element_id; // ID of the <text> or <textPath> element
  final Point<double>? visual_coord; // Calculated visual coordinate
  final Point<double>? grid_coord; // Calculated grid anchor coordinate (optional)

  // Structural Info (parsed from ID or calculated)
  final String strand_id;
  final SubstrandTypeEnum substrand_type;
  final String sequence_element_id; // ID of the sequence element (<tspan>)
  final bool forward; // Directionality on helix
  final int logical_index; // Index within the strand's full sequence
  final double precise_offset; // Offset on the helix
  final int sequence_position; // Index within the <tspan>'s characters

  // Direct references to model objects and core indices/lengths
  final Strand strand_object;
  final Substrand substrand_object;
  final int idx_in_substrand;
  final int substrand_length;

  // Helix info (useful for rules)
  final int
      helixIdx; // Helix associated with base's position (parent for Domain/Ext, anchor1 for Loopout)

  // --- Extension Specific Precomputed Info ---
  // Populated if substrand_type == SubstrandTypeEnum.EXTENSION
  final int? extension_anchor_helix_idx;
  final int? extension_anchor_offset; // Helix offset of the anchor point
  final bool?
      extension_anchor_parent_domain_forward; // Direction of the parent domain at the anchor point
  final bool? is_5p_extension; // True if this is a 5' extension
  final int? extension_eff_dist_from_anchor; // Calculated as idx_in_substrand for extensions

  // --- Loopout Specific Precomputed Info ---
  // Populated if substrand_type == SubstrandTypeEnum.LOOPOUT
  final int? loopout_anchor1_helix_idx;
  final int? loopout_anchor1_offset;
  final bool? loopout_anchor1_parent_domain_forward;
  final bool?
      loopout_anchor1_is_5p_end_of_loop_seq; // True if this anchor corresponds to the 5'-end of the loopout's own sequence
  final int? loopout_eff_dist_from_anchor1;

  final int? loopout_anchor2_helix_idx;
  final int? loopout_anchor2_offset;
  final bool? loopout_anchor2_parent_domain_forward;
  final bool?
      loopout_anchor2_is_5p_end_of_loop_seq; // True if this anchor corresponds to the 5'-end of the loopout's own sequence
  final int? loopout_eff_dist_from_anchor2;

  TBaseData({
    required this.stable_id,
    required this.parent_element_id,
    this.visual_coord,
    this.grid_coord,
    required this.strand_id,
    required this.substrand_type,
    required this.sequence_element_id,
    required this.forward,
    required this.logical_index,
    required this.precise_offset,
    required this.sequence_position,
    required this.strand_object,
    required this.substrand_object,
    required this.idx_in_substrand,
    required this.substrand_length,
    required this.helixIdx,

    // Extension fields (nullable as they only apply to extensions)
    this.extension_anchor_helix_idx,
    this.extension_anchor_offset,
    this.extension_anchor_parent_domain_forward,
    this.is_5p_extension,
    this.extension_eff_dist_from_anchor,

    // Loopout fields (nullable as they only apply to loopouts)
    this.loopout_anchor1_helix_idx,
    this.loopout_anchor1_offset,
    this.loopout_anchor1_parent_domain_forward,
    this.loopout_anchor1_is_5p_end_of_loop_seq,
    this.loopout_eff_dist_from_anchor1,
    this.loopout_anchor2_helix_idx,
    this.loopout_anchor2_offset,
    this.loopout_anchor2_parent_domain_forward,
    this.loopout_anchor2_is_5p_end_of_loop_seq,
    this.loopout_eff_dist_from_anchor2,
  });

  Map<String, dynamic> toMap() {
    return {
      'stable_id': stable_id,
      'parent_element_id': parent_element_id,
      'strand_id': strand_id,
      'substrand_type': substrand_type.toString(),
      'sequence_element_id': sequence_element_id,
      'forward': forward,
      'logical_index': logical_index,
      'precise_offset': precise_offset,
      'sequence_position': sequence_position,
      'idx_in_substrand': idx_in_substrand,
      'substrand_length': substrand_length,
      'helixIdx': helixIdx,
      'extension_anchor_helix_idx': extension_anchor_helix_idx,
      'extension_anchor_offset': extension_anchor_offset,
      'extension_anchor_parent_domain_forward': extension_anchor_parent_domain_forward,
      'is_5p_extension': is_5p_extension,
      'extension_eff_dist_from_anchor': extension_eff_dist_from_anchor,
      'loopout_anchor1_helix_idx': loopout_anchor1_helix_idx,
      'loopout_anchor1_offset': loopout_anchor1_offset,
      'loopout_anchor1_parent_domain_forward': loopout_anchor1_parent_domain_forward,
      'loopout_anchor1_is_5p_end_of_loop_seq': loopout_anchor1_is_5p_end_of_loop_seq,
      'loopout_eff_dist_from_anchor1': loopout_eff_dist_from_anchor1,
      'loopout_anchor2_helix_idx': loopout_anchor2_helix_idx,
      'loopout_anchor2_offset': loopout_anchor2_offset,
      'loopout_anchor2_parent_domain_forward': loopout_anchor2_parent_domain_forward,
      'loopout_anchor2_is_5p_end_of_loop_seq': loopout_anchor2_is_5p_end_of_loop_seq,
      'loopout_eff_dist_from_anchor2': loopout_eff_dist_from_anchor2,
    };
  }

  // Helper getters for conditions.
  bool get isOnExtension => substrand_type == SubstrandTypeEnum.EXTENSION;
  bool get isLoopout => substrand_type == SubstrandTypeEnum.LOOPOUT;

  // For Extensions:
  bool? get parentDomainForward => extension_anchor_parent_domain_forward;

  // For Loopouts

  // Override toString for use as Map keys if needed (use stable_id for uniqueness)
  @override
  String toString() => stable_id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TBaseData && runtimeType == other.runtimeType && stable_id == other.stable_id;

  @override
  int get hashCode => stable_id.hashCode;
}

/// Abstract base class for conditions evaluated on a single T-base.
abstract class TBaseCondition {
  bool evaluate(TBaseData t);
}

/// Abstract base class for conditions evaluated on a pair of T-bases.
abstract class PairCondition {
  bool evaluate(TBaseData t1, TBaseData t2);
}

/// Defines a specific CPD pairing rule using declarative conditions.
class RuleDefinition {
  final String ruleName;
  final List<TBaseCondition> t1_conditions;
  final List<TBaseCondition> t2_conditions;
  final List<PairCondition> pair_conditions;
  final double score;

  RuleDefinition({
    required this.ruleName,
    required this.t1_conditions,
    required this.t2_conditions,
    required this.pair_conditions,
    required this.score,
  });
}

// --- Concrete Conditions Implementations ---

// Conditions for Rule 1: Adjacent Perfectly Aligned Extensions
class IsOnExtensionCondition implements TBaseCondition {
  @override
  bool evaluate(TBaseData t) => t.isOnExtension;
}

// Condition for Adjacent Extensions (combines adjacency and specific T-alignment)
class AdjacentExtensionsAlignedPairCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) {

    // Ensure necessary fields are populated for extensions
    if (t1.extension_anchor_offset == null ||
        t2.extension_anchor_offset == null ||
        t1.extension_eff_dist_from_anchor == null ||
        t2.extension_eff_dist_from_anchor == null) {
      return false;
    }

    // Geometric Adjacency Part: Anchor offsets must be consecutive.
    // (Other parts of geometric adjacency like same helix & same parent domain direction
    // are handled by other conditions in the RuleDefinition like AreOnSameHelixCondition
    // and AreParentDomainsSameDirectionCondition).
    if ((t1.extension_anchor_offset! - t2.extension_anchor_offset!).abs() != 1) {
      return false;
    }

    // T-Alignment Rule: eff_dist_E (T1) == eff_dist_E (T2)
    // Direct equality of effective distances, as per the universal "walking away" principle.
    return t1.extension_eff_dist_from_anchor == t2.extension_eff_dist_from_anchor;
  }
}

class AreParentDomainsSameDirectionCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) {
    // Ensure both are extensions and have direction data
    if (t1.parentDomainForward == null || t2.parentDomainForward == null) {
      return false;
    }
    return t1.parentDomainForward == t2.parentDomainForward;
  }
}

// Conditions for Rule 2: Adjacent Perfectly Aligned Loopouts
class IsOnLoopoutCondition implements TBaseCondition {
  @override
  bool evaluate(TBaseData t) => t.isLoopout;
}

// Condition for Adjacent Loopouts (combines adjacency and T-alignment)
class AdjacentLoopoutsAlignedPairCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) {

    // Helper to check a specific pair of anchors (one from t1, one from t2)
    bool check_anchor_pair(
        int? t1_anchor_helix_idx,
        bool? t1_anchor_parent_domain_forward,
        int? t1_anchor_offset,
        int? t1_eff_dist,
        int? t2_anchor_helix_idx,
        bool? t2_anchor_parent_domain_forward,
        int? t2_anchor_offset,
        int? t2_eff_dist) {
      // Check for nulls (essential data missing for these anchors)
      if (t1_anchor_helix_idx == null ||
          t1_anchor_parent_domain_forward == null ||
          t1_anchor_offset == null ||
          t1_eff_dist == null ||
          t2_anchor_helix_idx == null ||
          t2_anchor_parent_domain_forward == null ||
          t2_anchor_offset == null ||
          t2_eff_dist == null) {
        return false;
      }

      // Geometric Adjacency Part 1: Common Helix
      if (t1_anchor_helix_idx != t2_anchor_helix_idx) {
        return false;
      }

      // Geometric Adjacency Part 2: Same parent domain direction (for these specific anchors on the common helix)
      if (t1_anchor_parent_domain_forward != t2_anchor_parent_domain_forward) {
        return false;
      }

      // Geometric Adjacency Part 3: Numerically consecutive anchor offsets on the common helix
      if ((t1_anchor_offset - t2_anchor_offset).abs() != 1) {
        return false;
      }

      // T-Alignment Rule: eff_dist(T1, from_anchor=A1_adj) == eff_dist(T2, from_anchor=A2_adj)
      return t1_eff_dist == t2_eff_dist;
    }

    // Check all four combinations of anchors:
    // Combo 1: t1.anchor1 with t2.anchor1
    if (check_anchor_pair(
        t1.loopout_anchor1_helix_idx,
        t1.loopout_anchor1_parent_domain_forward,
        t1.loopout_anchor1_offset,
        t1.loopout_eff_dist_from_anchor1,
        t2.loopout_anchor1_helix_idx,
        t2.loopout_anchor1_parent_domain_forward,
        t2.loopout_anchor1_offset,
        t2.loopout_eff_dist_from_anchor1)) {
      return true;
    }
    // Combo 2: t1.anchor1 with t2.anchor2
    if (check_anchor_pair(
        t1.loopout_anchor1_helix_idx,
        t1.loopout_anchor1_parent_domain_forward,
        t1.loopout_anchor1_offset,
        t1.loopout_eff_dist_from_anchor1,
        t2.loopout_anchor2_helix_idx,
        t2.loopout_anchor2_parent_domain_forward,
        t2.loopout_anchor2_offset,
        t2.loopout_eff_dist_from_anchor2)) {
      return true;
    }
    // Combo 3: t1.anchor2 with t2.anchor1
    if (check_anchor_pair(
        t1.loopout_anchor2_helix_idx,
        t1.loopout_anchor2_parent_domain_forward,
        t1.loopout_anchor2_offset,
        t1.loopout_eff_dist_from_anchor2,
        t2.loopout_anchor1_helix_idx,
        t2.loopout_anchor1_parent_domain_forward,
        t2.loopout_anchor1_offset,
        t2.loopout_eff_dist_from_anchor1)) {
      return true;
    }
    // Combo 4: t1.anchor2 with t2.anchor2
    if (check_anchor_pair(
        t1.loopout_anchor2_helix_idx,
        t1.loopout_anchor2_parent_domain_forward,
        t1.loopout_anchor2_offset,
        t1.loopout_eff_dist_from_anchor2,
        t2.loopout_anchor2_helix_idx,
        t2.loopout_anchor2_parent_domain_forward,
        t2.loopout_anchor2_offset,
        t2.loopout_eff_dist_from_anchor2)) {
      return true;
    }

    return false; // No adjacent and aligned anchor pair found
  }
}

// Condition for Adjacent Extension-Loopout (combines adjacency and T-alignment)
class AdjacentExtensionLoopoutAlignedPairCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) {
    TBaseData t_ext, t_loop;

    if (t1.isOnExtension && t2.isLoopout) {
      t_ext = t1;
      t_loop = t2;
    } else if (t1.isLoopout && t2.isOnExtension) {
      t_ext = t2;
      t_loop = t1;
    } else {
      return false; // Not an extension-loopout pair
    }

    // Ensure necessary extension fields are populated
    if (t_ext.extension_anchor_helix_idx == null ||
        t_ext.extension_anchor_parent_domain_forward == null ||
        t_ext.extension_anchor_offset == null ||
        t_ext.extension_eff_dist_from_anchor == null) {
      return false;
    }

    // Helper to check adjacency and alignment with one of the loopout's anchors
    bool check_ext_loop_anchor_pair(int? loop_anchor_helix_idx, bool? loop_anchor_parent_domain_forward,
        int? loop_anchor_offset, int? loop_eff_dist) {
      if (loop_anchor_helix_idx == null ||
          loop_anchor_parent_domain_forward == null ||
          loop_anchor_offset == null ||
          loop_eff_dist == null) {
        return false;
      }

      // Geometric Adjacency Part 1: Common Helix (Extension anchor with this specific Loopout anchor)
      if (t_ext.extension_anchor_helix_idx != loop_anchor_helix_idx) {
        return false;
      }

      // Geometric Adjacency Part 2: Same parent domain direction
      if (t_ext.extension_anchor_parent_domain_forward != loop_anchor_parent_domain_forward) {
        return false;
      }

      // Geometric Adjacency Part 3: Numerically consecutive anchor offsets
      if ((t_ext.extension_anchor_offset! - loop_anchor_offset).abs() != 1) {
        return false;
      }

      // T-Alignment Rule: eff_dist_E == eff_dist_L
      return t_ext.extension_eff_dist_from_anchor == loop_eff_dist;
    }

    // Check against loopout's anchor1
    if (check_ext_loop_anchor_pair(
        t_loop.loopout_anchor1_helix_idx,
        t_loop.loopout_anchor1_parent_domain_forward,
        t_loop.loopout_anchor1_offset,
        t_loop.loopout_eff_dist_from_anchor1)) {
      return true;
    }

    // Check against loopout's anchor2
    if (check_ext_loop_anchor_pair(
        t_loop.loopout_anchor2_helix_idx,
        t_loop.loopout_anchor2_parent_domain_forward,
        t_loop.loopout_anchor2_offset,
        t_loop.loopout_eff_dist_from_anchor2)) {
      return true;
    }

    return false; // No suitable adjacent and aligned anchor found
  }
}

// Common Conditions
class AreNotOnSameStrandCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) => t1.strand_id != t2.strand_id;
}

class AreOnSameHelixCondition implements PairCondition {
  @override
  bool evaluate(TBaseData t1, TBaseData t2) => t1.helixIdx == t2.helixIdx;
}

// Add other common conditions here if needed

//##############################################################################
// Rule Definition Instances
//##############################################################################

final adjacentExtensionRule = RuleDefinition(
  ruleName: "AdjacentPerfectlyAlignedExtensions",
  t1_conditions: [IsOnExtensionCondition()],
  t2_conditions: [IsOnExtensionCondition()],
  pair_conditions: [
    AreNotOnSameStrandCondition(),
    AreOnSameHelixCondition(),
    AreParentDomainsSameDirectionCondition(),
    AdjacentExtensionsAlignedPairCondition(),
  ],
  score: 1.0, // Initial score
);

final adjacentLoopoutRule = RuleDefinition(
  ruleName: "AdjacentPerfectlyAlignedLoopouts",
  t1_conditions: [IsOnLoopoutCondition()],
  t2_conditions: [IsOnLoopoutCondition()],
  pair_conditions: [
    AreNotOnSameStrandCondition(),
    AdjacentLoopoutsAlignedPairCondition(),
  ],
  score: 1.0, // Initial score
);

final extensionLoopoutRule = RuleDefinition(
  ruleName: "AdjacentExtensionLoopoutPerfectlyAligned",
  t1_conditions: [], // Will be handled by the PairCondition determining Ext vs Loopout
  t2_conditions: [], // Will be handled by the PairCondition
  pair_conditions: [
    AreNotOnSameStrandCondition(),
    AdjacentExtensionLoopoutAlignedPairCondition(),
  ],
  score: 1.0, // Initial score
);

// List of all active rules - EXPORTED
final allRuleDefinitions = [
  adjacentExtensionRule,
  adjacentLoopoutRule,
  extensionLoopoutRule,
];

class IdentifiedTBase {
  final String source_id; // For app: DOM stable_id. For test: user-defined test ID
  final Strand strand; // Direct reference
  final Substrand substrand; // Direct reference
  final int idx_in_substrand_sequence; // 0-indexed position of 'T' within substrand.dna_sequence()

  // Optional fields for coordinates and DOM-related data
  final double? visual_coord_x;
  final double? visual_coord_y;
  final double? grid_coord_x;
  final double? grid_coord_y;
  final String? parent_element_id_from_dom;
  final int? char_idx_from_dom;

  IdentifiedTBase({
    required this.source_id,
    required this.strand,
    required this.substrand,
    required this.idx_in_substrand_sequence,
    this.visual_coord_x,
    this.visual_coord_y,
    this.grid_coord_x,
    this.grid_coord_y,
    this.parent_element_id_from_dom,
    this.char_idx_from_dom,
  });
}

class CPDDetectionOutput {
  final BuiltList<CPDSite> cpd_sites;
  final TBaseLocations t_base_locations;

  CPDDetectionOutput({
    required this.cpd_sites,
    required this.t_base_locations,
  });
}

List<CPDSite> process_cpd_candidates(
    List<Tuple3<TBaseData, TBaseData, double>> candidates, List<TBaseData> all_t_base_data) {
  // Sort candidates by score, descending.
  candidates.sort((a, b) => b.item3.compareTo(a.item3));

  List<CPDSite> final_cpd_sites = [];
  Set<String> t_bases_already_in_a_final_site = {};
  Map<String, List<int>> t_base_to_site_indices_map = {};

  Map<String, TBaseLocation> t_location_cache = {};
  TBaseLocation getLocation(TBaseData t_data) {
    if (t_location_cache.containsKey(t_data.stable_id)) {
      return t_location_cache[t_data.stable_id]!;
    }
    // The TBaseLocation needs fields from TBaseData. Some might be null (visual_coord, grid_coord).
    // SubstrandType needs to be converted to string.
    var loc = TBaseLocation((b) => b
      ..stable_id = t_data.stable_id
      ..strand_id = t_data.strand_id
      ..substrand_type = t_data.substrand_type.toString() // Ensure enum to string
      ..sequence_element_id = t_data.sequence_element_id
      ..forward = t_data.forward
      ..logical_index = t_data.logical_index
      ..precise_offset = t_data.precise_offset.toInt() // Convert from double, TBaseLocation.precise_offset is int.
      ..sequence_position = t_data.sequence_position
      ..parent_element_id = t_data.parent_element_id
      ..visual_x = t_data.visual_coord?.x
      ..visual_y = t_data.visual_coord?.y
      ..grid_anchor_x = t_data.grid_coord?.x
      ..grid_anchor_y = t_data.grid_coord?.y);
    t_location_cache[t_data.stable_id] = loc;
    return loc;
  }

  for (var candidate in candidates) {
    TBaseData t1_data = candidate.item1;
    TBaseData t2_data = candidate.item2;

    String t1_id = t1_data.stable_id;
    String t2_id = t2_data.stable_id;

    bool t1_causes_conflict = t_bases_already_in_a_final_site.contains(t1_id);
    bool t2_causes_conflict = t_bases_already_in_a_final_site.contains(t2_id);
    bool this_new_site_is_conflicted = t1_causes_conflict || t2_causes_conflict;

    int new_site_idx = final_cpd_sites.length; // Index where the new site will be added

    // If t1 caused a conflict, mark all its previous sites as conflicted
    if (t1_causes_conflict) {
      List<int>? sites_for_t1 = t_base_to_site_indices_map[t1_id];
      if (sites_for_t1 != null) {
        for (int site_idx in sites_for_t1) {
          if (site_idx < final_cpd_sites.length && !final_cpd_sites[site_idx].is_conflicted) {
            final_cpd_sites[site_idx] = final_cpd_sites[site_idx].rebuild((b) => b.is_conflicted = true);
          }
        }
      }
    }

    // If t2 caused a conflict, mark all its previous sites as conflicted
    if (t2_causes_conflict) {
      List<int>? sites_for_t2 = t_base_to_site_indices_map[t2_id];
      if (sites_for_t2 != null) {
        for (int site_idx in sites_for_t2) {
          // Check index bounds again, though less likely to be an issue here if map is consistent
          if (site_idx < final_cpd_sites.length && !final_cpd_sites[site_idx].is_conflicted) {
            final_cpd_sites[site_idx] = final_cpd_sites[site_idx].rebuild((b) => b.is_conflicted = true);
          }
        }
      }
    }

    TBaseLocation t1_loc = getLocation(t1_data);
    TBaseLocation t2_loc = getLocation(t2_data);

    CPDSite new_site = CPDSite(t1: t1_loc, t2: t2_loc, is_conflicted: this_new_site_is_conflicted);
    final_cpd_sites.add(new_site);

    // Update tracking information
    t_bases_already_in_a_final_site.add(t1_id);
    t_bases_already_in_a_final_site.add(t2_id);

    (t_base_to_site_indices_map[t1_id] ??= []).add(new_site_idx);
    (t_base_to_site_indices_map[t2_id] ??= []).add(new_site_idx);
  }
  return final_cpd_sites;
}

CPDDetectionOutput detect_cpd_sites_from_t_bases(Design design, List<IdentifiedTBase> identified_t_bases,
    [List<RuleDefinition>? rules_to_process]) {
  List<TBaseData> populated_t_base_data_list = [];

  for (var input_t in identified_t_bases) {
    try {
      Strand strand = input_t.strand;
      Substrand ss = input_t.substrand;

      SubstrandTypeEnum substrand_type_enum_val;
      int idx_in_substrand_val = input_t.idx_in_substrand_sequence;
      int substrand_length_val = ss.dna_length();

      int helix_idx_val = -1; // Default, will be overridden
      bool forward_val;
      double precise_offset_val = input_t.idx_in_substrand_sequence.toDouble();
      int logical_index_val =
          CpdStrandUtils.substrand_start_idx(strand, ss) + input_t.idx_in_substrand_sequence;

      int? extension_anchor_helix_idx_val;
      int? extension_anchor_offset_val;
      bool? extension_anchor_parent_domain_forward_val;
      bool? is_5p_extension_val;
      int? extension_eff_dist_from_anchor_val;

      int? loopout_anchor1_helix_idx_val;
      int? loopout_anchor1_offset_val;
      bool? loopout_anchor1_parent_domain_forward_val;
      bool? loopout_anchor1_is_5p_end_of_loop_seq_val;
      int? loopout_eff_dist_from_anchor1_val;

      int? loopout_anchor2_helix_idx_val;
      int? loopout_anchor2_offset_val;
      bool? loopout_anchor2_parent_domain_forward_val;
      bool? loopout_anchor2_is_5p_end_of_loop_seq_val;
      int? loopout_eff_dist_from_anchor2_val;

      if (ss is Extension) {
        substrand_type_enum_val = SubstrandTypeEnum.EXTENSION;
        Extension extension = ss;
        Domain parent_domain = extension.adjacent_domain;

        forward_val = parent_domain.forward;
        helix_idx_val = parent_domain.helix;

        extension_anchor_helix_idx_val = parent_domain.helix;
        if (parent_domain.forward) {
          extension_anchor_offset_val = extension.is_5p ? parent_domain.start : parent_domain.end - 1;
        } else {
          extension_anchor_offset_val = extension.is_5p ? parent_domain.end - 1 : parent_domain.start;
        }
        extension_anchor_parent_domain_forward_val = parent_domain.forward;
        is_5p_extension_val = extension.is_5p;

        if (is_5p_extension_val) {
          extension_eff_dist_from_anchor_val = substrand_length_val - 1 - idx_in_substrand_val;
        } else {
          extension_eff_dist_from_anchor_val = idx_in_substrand_val;
        }
        extension_eff_dist_from_anchor_val = max(0, extension_eff_dist_from_anchor_val!);
      } else if (ss is Loopout) {
        substrand_type_enum_val = SubstrandTypeEnum.LOOPOUT;
        Loopout loopout = ss;

        if (loopout.prev_domain_idx < 0 || loopout.prev_domain_idx >= strand.substrands.length) {
          print(
              "Error precomputing TBaseData for ${input_t.source_id}: Loopout has invalid prev_domain_idx ${loopout.prev_domain_idx}");
          continue; // Skip this T-base
        }
        Substrand prev_ss_in_strand = strand.substrands[loopout.prev_domain_idx];
        if (prev_ss_in_strand is! Domain) {
          print(
              "Error precomputing TBaseData for ${input_t.source_id}: Loopout's prev substrand is not a Domain.");
          continue; // Skip this T-base
        }
        Domain domain_5p_of_loopout = prev_ss_in_strand;
        forward_val = domain_5p_of_loopout.forward;
        helix_idx_val = domain_5p_of_loopout.helix;

        loopout_anchor1_helix_idx_val = domain_5p_of_loopout.helix;
        loopout_anchor1_offset_val =
            domain_5p_of_loopout.forward ? domain_5p_of_loopout.end - 1 : domain_5p_of_loopout.start;
        loopout_anchor1_parent_domain_forward_val = domain_5p_of_loopout.forward;
        loopout_anchor1_is_5p_end_of_loop_seq_val = true;
        loopout_eff_dist_from_anchor1_val = idx_in_substrand_val;

        if (loopout.next_domain_idx < 0 || loopout.next_domain_idx >= strand.substrands.length) {
          print(
              "Error precomputing TBaseData for ${input_t.source_id}: Loopout has invalid next_domain_idx ${loopout.next_domain_idx}");
          continue; // Skip this T-base
        }
        Substrand next_ss_in_strand = strand.substrands[loopout.next_domain_idx];
        if (next_ss_in_strand is! Domain) {
          print(
              "Error precomputing TBaseData for ${input_t.source_id}: Loopout's next substrand is not a Domain.");
          continue; // Skip this T-base
        }
        Domain domain_3p_of_loopout = next_ss_in_strand;

        loopout_anchor2_helix_idx_val = domain_3p_of_loopout.helix;
        loopout_anchor2_offset_val =
            domain_3p_of_loopout.forward ? domain_3p_of_loopout.start : domain_3p_of_loopout.end - 1;
        loopout_anchor2_parent_domain_forward_val = domain_3p_of_loopout.forward;
        loopout_anchor2_is_5p_end_of_loop_seq_val = false;
        loopout_eff_dist_from_anchor2_val = substrand_length_val - 1 - idx_in_substrand_val;

        loopout_eff_dist_from_anchor1_val = max(0, loopout_eff_dist_from_anchor1_val!);
        loopout_eff_dist_from_anchor2_val = max(0, loopout_eff_dist_from_anchor2_val!);
      } else if (ss is Domain) {
        substrand_type_enum_val = SubstrandTypeEnum.DOMAIN;
        Domain domain = ss;
        forward_val = domain.forward;
        helix_idx_val = domain.helix;
      } else {
        print(
            "Error precomputing TBaseData for ${input_t.source_id}: Unknown substrand type ${ss.runtimeType}");
        continue; // Skip this T-base
      }

      var t_data = TBaseData(
        stable_id: input_t.source_id,
        parent_element_id: input_t.parent_element_id_from_dom ??
            input_t.source_id, // Use DOM parent if available, else placeholder
        visual_coord: (input_t.visual_coord_x != null && input_t.visual_coord_y != null)
            ? Point(input_t.visual_coord_x!, input_t.visual_coord_y!)
            : null,
        grid_coord: (input_t.grid_coord_x != null && input_t.grid_coord_y != null)
            ? Point(input_t.grid_coord_x!, input_t.grid_coord_y!)
            : null,
        strand_id: strand.id,
        substrand_type: substrand_type_enum_val,
        sequence_element_id: ss.id, // Use substrand id
        forward: forward_val,
        logical_index: logical_index_val,
        precise_offset: precise_offset_val,
        sequence_position:
            input_t.char_idx_from_dom ?? input_t.idx_in_substrand_sequence, // Use DOM char_idx if available
        strand_object: strand,
        substrand_object: ss,
        idx_in_substrand: idx_in_substrand_val,
        substrand_length: substrand_length_val,
        helixIdx: helix_idx_val,
        extension_anchor_helix_idx: extension_anchor_helix_idx_val,
        extension_anchor_offset: extension_anchor_offset_val,
        extension_anchor_parent_domain_forward: extension_anchor_parent_domain_forward_val,
        is_5p_extension: is_5p_extension_val,
        extension_eff_dist_from_anchor: extension_eff_dist_from_anchor_val,
        loopout_anchor1_helix_idx: loopout_anchor1_helix_idx_val,
        loopout_anchor1_offset: loopout_anchor1_offset_val,
        loopout_anchor1_parent_domain_forward: loopout_anchor1_parent_domain_forward_val,
        loopout_anchor1_is_5p_end_of_loop_seq: loopout_anchor1_is_5p_end_of_loop_seq_val,
        loopout_eff_dist_from_anchor1: loopout_eff_dist_from_anchor1_val,
        loopout_anchor2_helix_idx: loopout_anchor2_helix_idx_val,
        loopout_anchor2_offset: loopout_anchor2_offset_val,
        loopout_anchor2_parent_domain_forward: loopout_anchor2_parent_domain_forward_val,
        loopout_anchor2_is_5p_end_of_loop_seq: loopout_anchor2_is_5p_end_of_loop_seq_val,
        loopout_eff_dist_from_anchor2: loopout_eff_dist_from_anchor2_val,
      );
      populated_t_base_data_list.add(t_data);
    } catch (e, stackTrace) {
      print("Unhandled error during TBaseData precomputation for ${input_t.source_id}: $e\n$stackTrace");
      continue;
    }
  }

  List<RuleDefinition> rules = rules_to_process ?? allRuleDefinitions;
  List<Tuple3<TBaseData, TBaseData, double>> candidate_pairs =
      RuleProcessor().process_rules(populated_t_base_data_list, rules);

  List<CPDSite> final_cpd_sites_list = process_cpd_candidates(candidate_pairs, populated_t_base_data_list);

  List<TBaseLocation> final_t_locations_list = [];
  for (var t_data in populated_t_base_data_list) {
    final_t_locations_list.add(TBaseLocation((b) => b
      ..stable_id = t_data.stable_id
      ..strand_id = t_data.strand_id
      ..substrand_type = t_data.substrand_type.toString()
      ..sequence_element_id = t_data.sequence_element_id
      ..forward = t_data.forward
      ..logical_index = t_data.logical_index
      ..precise_offset = t_data.precise_offset.toInt()
      ..sequence_position = t_data.sequence_position
      ..parent_element_id = t_data.parent_element_id
      ..visual_x = t_data.visual_coord?.x
      ..visual_y = t_data.visual_coord?.y
      ..grid_anchor_x = t_data.grid_coord?.x
      ..grid_anchor_y = t_data.grid_coord?.y));
  }

  return CPDDetectionOutput(
    cpd_sites: BuiltList<CPDSite>(final_cpd_sites_list),
    t_base_locations: TBaseLocations((b) => b..t_bases.replace(final_t_locations_list)),
  );
}

/// Processes rule definitions against TBaseData to find candidate CPD pairs.
class RuleProcessor {
  /// Takes T-base data and rule definitions, returns scored candidate pairs.
  List<Tuple3<TBaseData, TBaseData, double>> process_rules(
      List<TBaseData> t_bases, List<RuleDefinition> rules) {
    List<Tuple3<TBaseData, TBaseData, double>> all_candidates = [];

    var extensions = <TBaseData>[];
    var loopouts = <TBaseData>[];
    for (var t in t_bases) {
      if (t.isOnExtension) extensions.add(t);
      if (t.isLoopout) loopouts.add(t);
    }

    for (var rule in rules) {
      List<Tuple3<TBaseData, TBaseData, double>> rule_candidates = [];

      if (rule.ruleName == "AdjacentPerfectlyAlignedExtensions") {
        if (extensions.length < 2) continue;
        for (int i = 0; i < extensions.length; ++i) {
          TBaseData t1 = extensions[i];
          for (int j = i + 1; j < extensions.length; ++j) {
            TBaseData t2 = extensions[j];
            if (_evaluate_rule_for_pair(rule, t1, t2)) {
              rule_candidates.add(Tuple3(t1, t2, rule.score));
            }
          }
        }
      } else if (rule.ruleName == "AdjacentPerfectlyAlignedLoopouts") {
        if (loopouts.length < 2) continue;
        for (int i = 0; i < loopouts.length; ++i) {
          TBaseData t1 = loopouts[i];
          for (int j = i + 1; j < loopouts.length; ++j) {
            TBaseData t2 = loopouts[j];
            if (_evaluate_rule_for_pair(rule, t1, t2)) {
              rule_candidates.add(Tuple3(t1, t2, rule.score));
            }
          }
        }
      } else if (rule.ruleName == "AdjacentExtensionLoopoutPerfectlyAligned") {
        if (extensions.isEmpty || loopouts.isEmpty) continue;
        for (TBaseData t_ext in extensions) {
          for (TBaseData t_loop in loopouts) {
            if (_evaluate_rule_for_pair(rule, t_ext, t_loop)) {
              rule_candidates.add(Tuple3(t_ext, t_loop, rule.score));
            }
          }
        }
      } else {
        // Rule not implemented yet
      }
      all_candidates.addAll(rule_candidates);
    }
    
    return all_candidates;
  }

  bool _evaluate_rule_for_pair(RuleDefinition rule, TBaseData t1, TBaseData t2) {
    bool t1_ok = rule.t1_conditions.every((cond) => cond.evaluate(t1));
    if (!t1_ok) return false;
    bool t2_ok = rule.t2_conditions.every((cond) => cond.evaluate(t2));
    if (!t2_ok) return false;
    bool pair_ok = rule.pair_conditions.every((cond) => cond.evaluate(t1, t2));
    return pair_ok;
  }
}

class CpdStrandUtils {
  static Substrand? substrand_at(Strand strand, int dna_idx) {
    if (dna_idx < 0 || dna_idx >= strand.dna_length) {
      return null;
    }
    int current_idx_start = 0;
    for (var ss in strand.substrands) {
      int current_idx_end = current_idx_start + ss.dna_length();
      if (dna_idx >= current_idx_start && dna_idx < current_idx_end) {
        return ss;
      }
      current_idx_start = current_idx_end;
    }
    return null;
  }

  static int substrand_start_idx(Strand strand, Substrand target_ss) {
    int current_idx_start = 0;
    for (var ss in strand.substrands) {
      if (ss == target_ss) {
        return current_idx_start;
      }
      current_idx_start += ss.dna_length();
    }
    throw ArgumentError('Substrand not found in strand: ${target_ss.id}, strand: ${strand.id}');
  }
}
