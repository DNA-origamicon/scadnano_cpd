import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 't_base_location.g.dart';

/// Represents a collection of T-base locations found in the design
abstract class TBaseLocations implements Built<TBaseLocations, TBaseLocationsBuilder> {
  /// List of all T-base locations found in the design
  BuiltList<TBaseLocation> get t_bases;

  /************************ begin BuiltValue boilerplate ************************/
  factory TBaseLocations([void Function(TBaseLocationsBuilder) updates]) = _$TBaseLocations;

  TBaseLocations._();

  static Serializer<TBaseLocations> get serializer => _$tBaseLocationsSerializer;

  @memoized
  int get hashCode;
}

/// Represents the location of a single T-base in the design
abstract class TBaseLocation implements Built<TBaseLocation, TBaseLocationBuilder> {
  /// Unique ID of the strand containing this T-base
  String get strand_id;

  /// Stable unique ID generated for this T-base during rendering
  String get stable_id;

  /// Indicates if the T-base is on the forward strand
  bool get forward;

  /// Logical index of the T-base within the strand's full sequence
  int get logical_index;

  /// Precise offset of the T-base within its specific substrand (domain, loopout, etc.)
  /// For domains, this accounts for insertions/deletions relative to the domain start.
  int get precise_offset;

  /// Type of substrand (domain, loopout, extension)
  String get substrand_type;

  /// ID of the sequence element (substrand) containing this T-base
  String get sequence_element_id;

  /// Position of the T within the rendered sequence text of its element (might be redundant later)
  int get sequence_position;

  /// x-coordinate of the grid position representing the T-base's structural location (e.g., helix center)
  double? get grid_anchor_x;

  /// y-coordinate of the grid position representing the T-base's structural location (e.g., helix center)
  double? get grid_anchor_y;

  /// Visual x-coordinate of this T-base in the design view
  /// This is the rendered position derived from text metrics
  double? get visual_x;

  /// Visual y-coordinate of this T-base in the design view
  /// This is the rendered position derived from text metrics
  double? get visual_y;

  /// ID of the parent DOM element containing this T-base
  String? get parent_element_id;

  // toMap() method used for console logging
  Map<String, dynamic> toMap() {
    return {
      'stable_id': stable_id,
      'strand_id': strand_id,
      'substrand_type': substrand_type,
      'logical_index': logical_index,
      'precise_offset': precise_offset,
      'forward': forward,
      'sequence_element_id': sequence_element_id,
      'sequence_position': sequence_position,
      'parent_element_id': parent_element_id,
      // Optional visual/grid coords
      if (visual_x != null) 'visual_x': visual_x,
      if (visual_y != null) 'visual_y': visual_y,
      if (grid_anchor_x != null) 'grid_anchor_x': grid_anchor_x,
      if (grid_anchor_y != null) 'grid_anchor_y': grid_anchor_y,
    };
  }

  /************************ begin BuiltValue boilerplate ************************/
  factory TBaseLocation([void Function(TBaseLocationBuilder) updates]) = _$TBaseLocation;

  TBaseLocation._();

  static Serializer<TBaseLocation> get serializer => _$tBaseLocationSerializer;

  @memoized
  int get hashCode;
}
