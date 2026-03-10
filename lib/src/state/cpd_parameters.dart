// Model for cpd_parameters.json — the photoproduct formation parameter file.
//
// These are plain immutable Dart classes (not Built Values) because CpdParameters
// is loaded from JSON at startup like the PDB template, not managed through Redux
// serialization. It will be stored in AppUIState once Phase 1 wires up the loader.
//
// Schema version history:
//   0.1.0 — initial schema with TT-CPD active, TT-6-4PP and TC-6-4PP as disabled placeholders

import 'dart:convert';

// ────────────────────────────────────────────────────────────────────────────
// Top-level container
// ────────────────────────────────────────────────────────────────────────────

class CpdParameters {
  final String schema_version;
  final String last_updated;
  final String? notes;
  final CpdGlobalConfig global;
  final List<PhotoproductDefinition> photoproducts;

  const CpdParameters({
    required this.schema_version,
    required this.last_updated,
    this.notes,
    required this.global,
    required this.photoproducts,
  });

  /// Returns only enabled photoproduct definitions.
  List<PhotoproductDefinition> get enabled_photoproducts =>
      photoproducts.where((p) => p.enabled).toList();

  /// Look up a photoproduct definition by its id (e.g. "TT_CPD").
  /// Returns null if not found.
  PhotoproductDefinition? photoproduct(String id) {
    for (final p in photoproducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Returns the set of all bases that need to be tagged in the SVG during
  /// rendering, derived from global.watch_bases.
  Set<String> get watch_bases => Set<String>.from(global.watch_bases);

  factory CpdParameters.from_json(Map<String, dynamic> json) {
    return CpdParameters(
      schema_version: json['schema_version'] as String,
      last_updated: json['last_updated'] as String,
      notes: json['notes'] as String?,
      global: CpdGlobalConfig.from_json(json['global'] as Map<String, dynamic>),
      photoproducts: (json['photoproducts'] as List<dynamic>)
          .map((p) => PhotoproductDefinition.from_json(p as Map<String, dynamic>))
          .toList(),
    );
  }

  factory CpdParameters.from_json_string(String json_string) {
    return CpdParameters.from_json(jsonDecode(json_string) as Map<String, dynamic>);
  }

  Map<String, dynamic> to_json() {
    return {
      'schema_version': schema_version,
      'last_updated': last_updated,
      if (notes != null) 'notes': notes,
      'global': global.to_json(),
      'photoproducts': photoproducts.map((p) => p.to_json()).toList(),
    };
  }

  String to_json_string() => const JsonEncoder.withIndent('  ').convert(to_json());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CpdParameters &&
          schema_version == other.schema_version &&
          last_updated == other.last_updated &&
          notes == other.notes &&
          global == other.global &&
          _list_equals(photoproducts, other.photoproducts);

  @override
  int get hashCode =>
      schema_version.hashCode ^ last_updated.hashCode ^ global.hashCode ^ photoproducts.hashCode;

  @override
  String toString() =>
      'CpdParameters(v$schema_version, ${photoproducts.length} photoproducts, '
      '${enabled_photoproducts.length} enabled)';
}

// ────────────────────────────────────────────────────────────────────────────
// Global configuration
// ────────────────────────────────────────────────────────────────────────────

class CpdGlobalConfig {
  /// Sites with computed formation score below this threshold are not displayed.
  final double display_threshold;

  /// Strategy for resolving conflicts when a T-base appears in multiple candidate
  /// pairs. Currently only "highest_score_wins" is implemented.
  final String conflict_resolution;

  /// Bases to tag in the SVG during rendering (e.g. ["T"] or ["T", "C"]).
  final List<String> watch_bases;

  final String? notes;

  const CpdGlobalConfig({
    required this.display_threshold,
    required this.conflict_resolution,
    required this.watch_bases,
    this.notes,
  });

  factory CpdGlobalConfig.from_json(Map<String, dynamic> json) {
    return CpdGlobalConfig(
      display_threshold: (json['display_threshold'] as num).toDouble(),
      conflict_resolution: json['conflict_resolution'] as String,
      watch_bases: (json['watch_bases'] as List<dynamic>).cast<String>(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> to_json() {
    return {
      'display_threshold': display_threshold,
      'conflict_resolution': conflict_resolution,
      'watch_bases': watch_bases,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CpdGlobalConfig &&
          display_threshold == other.display_threshold &&
          conflict_resolution == other.conflict_resolution &&
          _list_equals(watch_bases, other.watch_bases) &&
          notes == other.notes;

  @override
  int get hashCode =>
      display_threshold.hashCode ^ conflict_resolution.hashCode ^ watch_bases.hashCode;
}

// ────────────────────────────────────────────────────────────────────────────
// Photoproduct definition
// ────────────────────────────────────────────────────────────────────────────

class PhotoproductDefinition {
  /// Unique identifier (e.g. "TT_CPD", "TT_64PP").
  final String id;

  final String display_name;
  final String abbreviation;

  /// Hex color for rendering (e.g. "#e87d2b").
  final String color;

  /// Whether this photoproduct participates in detection. Disabled entries are
  /// retained in the file as documented placeholders.
  final bool enabled;

  final String? notes;

  final List<SequenceContext> sequence_contexts;

  /// Weights per structural context key. Keys match the rule engine's context
  /// names: "adjacent_domain_ds", "extension_extension", "loopout_loopout",
  /// "extension_loopout".
  final Map<String, StructuralContextWeight> structural_context_weights;

  final PhotoproductGeometry geometry;

  final List<String> references;

  const PhotoproductDefinition({
    required this.id,
    required this.display_name,
    required this.abbreviation,
    required this.color,
    required this.enabled,
    this.notes,
    required this.sequence_contexts,
    required this.structural_context_weights,
    required this.geometry,
    required this.references,
  });

  /// Returns the relative formation rate for a given (upstream, downstream)
  /// base pair. Returns 0.0 if no matching sequence context exists.
  double sequence_context_rate(String upstream_base, String downstream_base) {
    for (final ctx in sequence_contexts) {
      if (ctx.upstream_base == upstream_base && ctx.downstream_base == downstream_base) {
        return ctx.relative_formation_rate;
      }
    }
    return 0.0;
  }

  /// Returns the weight for a given structural context key. Returns 0.0 if the
  /// key is not present.
  double structural_weight(String context_key) {
    return structural_context_weights[context_key]?.weight ?? 0.0;
  }

  factory PhotoproductDefinition.from_json(Map<String, dynamic> json) {
    final raw_weights = json['structural_context_weights'] as Map<String, dynamic>;
    final weights = raw_weights.map(
      (key, value) => MapEntry(
        key,
        StructuralContextWeight.from_json(value as Map<String, dynamic>),
      ),
    );
    return PhotoproductDefinition(
      id: json['id'] as String,
      display_name: json['display_name'] as String,
      abbreviation: json['abbreviation'] as String,
      color: json['color'] as String,
      enabled: json['enabled'] as bool,
      notes: json['notes'] as String?,
      sequence_contexts: (json['sequence_contexts'] as List<dynamic>)
          .map((c) => SequenceContext.from_json(c as Map<String, dynamic>))
          .toList(),
      structural_context_weights: weights,
      geometry: PhotoproductGeometry.from_json(json['geometry'] as Map<String, dynamic>),
      references: (json['references'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> to_json() {
    return {
      'id': id,
      'display_name': display_name,
      'abbreviation': abbreviation,
      'color': color,
      'enabled': enabled,
      if (notes != null) 'notes': notes,
      'sequence_contexts': sequence_contexts.map((c) => c.to_json()).toList(),
      'structural_context_weights':
          structural_context_weights.map((k, v) => MapEntry(k, v.to_json())),
      'geometry': geometry.to_json(),
      'references': references,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoproductDefinition &&
          id == other.id &&
          enabled == other.enabled &&
          color == other.color &&
          _list_equals(sequence_contexts, other.sequence_contexts) &&
          _map_equals(structural_context_weights, other.structural_context_weights) &&
          geometry == other.geometry;

  @override
  int get hashCode => id.hashCode ^ enabled.hashCode ^ color.hashCode;

  @override
  String toString() => 'PhotoproductDefinition($id, enabled=$enabled)';
}

// ────────────────────────────────────────────────────────────────────────────
// Sequence context
// ────────────────────────────────────────────────────────────────────────────

class SequenceContext {
  /// The 5' base of the dinucleotide step (e.g. "T").
  final String upstream_base;

  /// The 3' base of the dinucleotide step (e.g. "T" or "C").
  final String downstream_base;

  /// Formation rate relative to TT-CPD (the reference, value 1.0). All other
  /// photoproducts and sequence contexts are scaled relative to this.
  final double relative_formation_rate;

  final String? notes;

  const SequenceContext({
    required this.upstream_base,
    required this.downstream_base,
    required this.relative_formation_rate,
    this.notes,
  });

  factory SequenceContext.from_json(Map<String, dynamic> json) {
    return SequenceContext(
      upstream_base: json['upstream_base'] as String,
      downstream_base: json['downstream_base'] as String,
      relative_formation_rate: (json['relative_formation_rate'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> to_json() {
    return {
      'upstream_base': upstream_base,
      'downstream_base': downstream_base,
      'relative_formation_rate': relative_formation_rate,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SequenceContext &&
          upstream_base == other.upstream_base &&
          downstream_base == other.downstream_base &&
          relative_formation_rate == other.relative_formation_rate;

  @override
  int get hashCode =>
      upstream_base.hashCode ^ downstream_base.hashCode ^ relative_formation_rate.hashCode;
}

// ────────────────────────────────────────────────────────────────────────────
// Structural context weight
// ────────────────────────────────────────────────────────────────────────────

class StructuralContextWeight {
  /// Multiplier applied to the sequence_context relative_formation_rate for
  /// this structural context. Range [0.0, 1.0].
  final double weight;

  final String? notes;

  const StructuralContextWeight({required this.weight, this.notes});

  factory StructuralContextWeight.from_json(Map<String, dynamic> json) {
    return StructuralContextWeight(
      weight: (json['weight'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> to_json() {
    return {
      'weight': weight,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is StructuralContextWeight && weight == other.weight;

  @override
  int get hashCode => weight.hashCode;
}

// ────────────────────────────────────────────────────────────────────────────
// Geometry thresholds
// ────────────────────────────────────────────────────────────────────────────

class PhotoproductGeometry {
  /// Maximum interbase (C5-C5) distance in Angstroms below which formation is
  /// considered geometrically possible.
  final double max_interbase_distance_angstrom;

  final String? notes;

  const PhotoproductGeometry({required this.max_interbase_distance_angstrom, this.notes});

  factory PhotoproductGeometry.from_json(Map<String, dynamic> json) {
    return PhotoproductGeometry(
      max_interbase_distance_angstrom:
          (json['max_interbase_distance_angstrom'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> to_json() {
    return {
      'max_interbase_distance_angstrom': max_interbase_distance_angstrom,
      if (notes != null) 'notes': notes,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoproductGeometry &&
          max_interbase_distance_angstrom == other.max_interbase_distance_angstrom;

  @override
  int get hashCode => max_interbase_distance_angstrom.hashCode;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

bool _list_equals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _map_equals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
