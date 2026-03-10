/// A confirmed CPD photoproduct junction between two thymine bases.
///
/// Created when the user right-clicks a detected CPD site and selects
/// "Mark as photoproduct junction".  Persisted in the `.sc` file under the
/// top-level `photoproduct_junctions` key.
///
/// All photoproducts are assumed to be canonical TT-CPDs (cyclobutane
/// pyrimidine dimers).  The `photoproduct_id` field is kept for forward
/// compatibility when other photoproduct types are eventually supported.

class PhotoproductJunction {
  /// Stable ID of the first thymine base (lower helix offset or earlier in strand).
  final String t1_stable_id;

  /// Stable ID of the second thymine base.
  final String t2_stable_id;

  /// Photoproduct type identifier, e.g. 'TT-CPD'.
  final String photoproduct_id;

  const PhotoproductJunction({
    required this.t1_stable_id,
    required this.t2_stable_id,
    this.photoproduct_id = 'TT-CPD',
  });

  // ── Equality & hash (required for BuiltList) ─────────────────────────────

  @override
  bool operator ==(Object other) =>
      other is PhotoproductJunction &&
      t1_stable_id == other.t1_stable_id &&
      t2_stable_id == other.t2_stable_id &&
      photoproduct_id == other.photoproduct_id;

  @override
  int get hashCode => Object.hash(t1_stable_id, t2_stable_id, photoproduct_id);

  @override
  String toString() =>
      'PhotoproductJunction(t1=$t1_stable_id, t2=$t2_stable_id, id=$photoproduct_id)';

  // ── JSON ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        't1_stable_id': t1_stable_id,
        't2_stable_id': t2_stable_id,
        'photoproduct_id': photoproduct_id,
      };

  static PhotoproductJunction fromJson(Map<String, dynamic> json) =>
      PhotoproductJunction(
        t1_stable_id: json['t1_stable_id'] as String,
        t2_stable_id: json['t2_stable_id'] as String,
        photoproduct_id: (json['photoproduct_id'] as String?) ?? 'TT-CPD',
      );
}
