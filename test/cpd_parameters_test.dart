// Tests for CpdParameters — the photoproduct formation parameter schema.
//
// These tests use embedded JSON strings so they are self-contained and do not
// depend on browser APIs. The real-file group uses dart:io and runs on the VM.
//
// Run with:
//   dart run build_runner test -- test/cpd_parameters_test.dart --platform vm
//
// Note: dart_test.yaml defaults to Chrome. The @TestOn annotation below
// overrides that for this file so it runs on the Dart VM without requiring
// a browser install. Group 4 loads the actual cpd_parameters.json via dart:io.

@TestOn('vm')

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:scadnano/src/state/cpd_parameters.dart';

// ────────────────────────────────────────────────────────────────────────────
// Shared fixture — a minimal valid CpdParameters JSON string used across groups
// ────────────────────────────────────────────────────────────────────────────

const String _MINIMAL_VALID_JSON = '''
{
  "schema_version": "0.1.0",
  "last_updated": "2026-03-08",
  "global": {
    "display_threshold": 0.1,
    "conflict_resolution": "highest_score_wins",
    "watch_bases": ["T"]
  },
  "photoproducts": [
    {
      "id": "TT_CPD",
      "display_name": "T-T Cyclobutane Pyrimidine Dimer",
      "abbreviation": "CPD",
      "color": "#e87d2b",
      "enabled": true,
      "sequence_contexts": [
        {
          "upstream_base": "T",
          "downstream_base": "T",
          "relative_formation_rate": 1.0
        }
      ],
      "structural_context_weights": {
        "adjacent_domain_ds":  { "weight": 0.85 },
        "extension_extension": { "weight": 1.0  },
        "loopout_loopout":     { "weight": 0.90 },
        "extension_loopout":   { "weight": 0.75 }
      },
      "geometry": {
        "max_interbase_distance_angstrom": 4.0
      },
      "references": ["Test reference"]
    },
    {
      "id": "TT_64PP",
      "display_name": "T-T 6-4 Photoproduct",
      "abbreviation": "6-4PP",
      "color": "#7b52ab",
      "enabled": false,
      "sequence_contexts": [
        {
          "upstream_base": "T",
          "downstream_base": "T",
          "relative_formation_rate": 0.25
        }
      ],
      "structural_context_weights": {
        "adjacent_domain_ds":  { "weight": 0.25 },
        "extension_extension": { "weight": 0.30 },
        "loopout_loopout":     { "weight": 0.28 },
        "extension_loopout":   { "weight": 0.20 }
      },
      "geometry": {
        "max_interbase_distance_angstrom": 4.0
      },
      "references": []
    }
  ]
}
''';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

CpdParameters _parse(String json_str) => CpdParameters.from_json_string(json_str);

/// Produce a modified JSON string by overriding one top-level or nested field.
/// Accepts a simple key path as a dotted string (max depth used in tests: 2).
String _with_field(String json_str, String key, dynamic value) {
  final map = jsonDecode(json_str) as Map<String, dynamic>;
  final parts = key.split('.');
  if (parts.length == 1) {
    map[parts[0]] = value;
  } else if (parts.length == 2) {
    (map[parts[0]] as Map<String, dynamic>)[parts[1]] = value;
  }
  return jsonEncode(map);
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

main() {
  // ── 1. Parsing ─────────────────────────────────────────────────────────────
  group('CpdParameters parsing', () {
    late CpdParameters params;

    setUp(() => params = _parse(_MINIMAL_VALID_JSON));

    test('schema_version parses correctly', () {
      expect(params.schema_version, equals('0.1.0'));
    });

    test('last_updated parses correctly', () {
      expect(params.last_updated, equals('2026-03-08'));
    });

    test('global config parses correctly', () {
      expect(params.global.display_threshold, equals(0.1));
      expect(params.global.conflict_resolution, equals('highest_score_wins'));
      expect(params.global.watch_bases, equals(['T']));
    });

    test('photoproducts list has expected length', () {
      expect(params.photoproducts.length, equals(2));
    });

    test('enabled photoproducts filters correctly', () {
      expect(params.enabled_photoproducts.length, equals(1));
      expect(params.enabled_photoproducts.first.id, equals('TT_CPD'));
    });

    test('photoproduct() lookup by id returns correct entry', () {
      final cpd = params.photoproduct('TT_CPD');
      expect(cpd, isNotNull);
      expect(cpd!.display_name, equals('T-T Cyclobutane Pyrimidine Dimer'));
      expect(cpd.abbreviation, equals('CPD'));
      expect(cpd.color, equals('#e87d2b'));
      expect(cpd.enabled, isTrue);
    });

    test('photoproduct() returns null for unknown id', () {
      expect(params.photoproduct('NONEXISTENT'), isNull);
    });

    test('disabled photoproduct parses correctly', () {
      final pp64 = params.photoproduct('TT_64PP');
      expect(pp64, isNotNull);
      expect(pp64!.enabled, isFalse);
    });

    test('sequence_contexts parse correctly', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.sequence_contexts.length, equals(1));
      expect(cpd.sequence_contexts.first.upstream_base, equals('T'));
      expect(cpd.sequence_contexts.first.downstream_base, equals('T'));
      expect(cpd.sequence_contexts.first.relative_formation_rate, equals(1.0));
    });

    test('structural_context_weights parse correctly', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.structural_context_weights.length, equals(4));
      expect(cpd.structural_weight('extension_extension'), equals(1.0));
      expect(cpd.structural_weight('adjacent_domain_ds'), equals(0.85));
      expect(cpd.structural_weight('loopout_loopout'), equals(0.90));
      expect(cpd.structural_weight('extension_loopout'), equals(0.75));
    });

    test('geometry parses correctly', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.geometry.max_interbase_distance_angstrom, equals(4.0));
    });

    test('optional notes field is nullable', () {
      // Minimal JSON has no top-level notes — should not throw
      expect(params.notes, isNull);
    });

    test('watch_bases returns a Set', () {
      expect(params.watch_bases, isA<Set<String>>());
      expect(params.watch_bases.contains('T'), isTrue);
    });
  });

  // ── 2. Value constraints ────────────────────────────────────────────────────
  group('CpdParameters value constraints', () {
    late CpdParameters params;
    setUp(() => params = _parse(_MINIMAL_VALID_JSON));

    test('display_threshold is in [0.0, 1.0]', () {
      final t = params.global.display_threshold;
      expect(t, greaterThanOrEqualTo(0.0));
      expect(t, lessThanOrEqualTo(1.0));
    });

    test('all structural_context_weights are in [0.0, 1.0]', () {
      for (final p in params.photoproducts) {
        for (final entry in p.structural_context_weights.entries) {
          expect(
            entry.value.weight,
            allOf(greaterThanOrEqualTo(0.0), lessThanOrEqualTo(1.0)),
            reason: '${p.id}.${entry.key} weight is out of range',
          );
        }
      }
    });

    test('all relative_formation_rates are non-negative', () {
      for (final p in params.photoproducts) {
        for (final ctx in p.sequence_contexts) {
          expect(
            ctx.relative_formation_rate,
            greaterThanOrEqualTo(0.0),
            reason: '${p.id} sequence context ${ctx.upstream_base}${ctx.downstream_base} has negative rate',
          );
        }
      }
    });

    test('reference photoproduct TT-CPD has rate 1.0', () {
      final cpd = params.photoproduct('TT_CPD')!;
      final tt_rate = cpd.sequence_context_rate('T', 'T');
      expect(tt_rate, equals(1.0),
          reason: 'TT-CPD TT rate must be 1.0 (the normalization reference)');
    });

    test('disabled photoproducts have lower rates than reference', () {
      final cpd_rate = params.photoproduct('TT_CPD')!.sequence_context_rate('T', 'T');
      for (final p in params.photoproducts.where((p) => !p.enabled)) {
        for (final ctx in p.sequence_contexts) {
          expect(
            ctx.relative_formation_rate,
            lessThanOrEqualTo(cpd_rate),
            reason: 'Disabled photoproduct ${p.id} has rate > reference CPD rate',
          );
        }
      }
    });

    test('all photoproduct ids are unique', () {
      final ids = params.photoproducts.map((p) => p.id).toList();
      final unique_ids = ids.toSet();
      expect(ids.length, equals(unique_ids.length),
          reason: 'Duplicate photoproduct ids: ${ids.where((id) => ids.where((i) => i == id).length > 1).toSet()}');
    });

    test('all photoproduct colors are valid hex strings', () {
      final hex_pattern = RegExp(r'^#[0-9a-fA-F]{6}$');
      for (final p in params.photoproducts) {
        expect(hex_pattern.hasMatch(p.color), isTrue,
            reason: '${p.id} color "${p.color}" is not a valid 6-digit hex color');
      }
    });

    test('all photoproduct colors are distinct', () {
      final colors = params.photoproducts.map((p) => p.color.toLowerCase()).toList();
      final unique_colors = colors.toSet();
      expect(colors.length, equals(unique_colors.length),
          reason: 'Two photoproducts share the same color — they will be visually indistinguishable');
    });

    test('watch_bases only contains valid nucleotide characters', () {
      const valid_bases = {'A', 'T', 'G', 'C', 'U'};
      for (final base in params.global.watch_bases) {
        expect(valid_bases.contains(base), isTrue,
            reason: '"$base" in watch_bases is not a valid nucleotide');
      }
    });

    test('all sequence context bases are valid nucleotides', () {
      const valid_bases = {'A', 'T', 'G', 'C', 'U'};
      for (final p in params.photoproducts) {
        for (final ctx in p.sequence_contexts) {
          expect(valid_bases.contains(ctx.upstream_base), isTrue,
              reason: '${p.id} upstream_base "${ctx.upstream_base}" is invalid');
          expect(valid_bases.contains(ctx.downstream_base), isTrue,
              reason: '${p.id} downstream_base "${ctx.downstream_base}" is invalid');
        }
      }
    });

    test('all required structural context keys are present for each photoproduct', () {
      const required_keys = [
        'adjacent_domain_ds',
        'extension_extension',
        'loopout_loopout',
        'extension_loopout',
      ];
      for (final p in params.photoproducts) {
        for (final key in required_keys) {
          expect(p.structural_context_weights.containsKey(key), isTrue,
              reason: '${p.id} is missing structural_context_weights key "$key"');
        }
      }
    });

    test('geometry max_interbase_distance is positive', () {
      for (final p in params.photoproducts) {
        expect(p.geometry.max_interbase_distance_angstrom, greaterThan(0.0),
            reason: '${p.id} max_interbase_distance_angstrom must be positive');
      }
    });

    test('schema_version follows semver pattern', () {
      final semver = RegExp(r'^\d+\.\d+\.\d+$');
      expect(semver.hasMatch(params.schema_version), isTrue,
          reason: 'schema_version "${params.schema_version}" does not match semver (MAJOR.MINOR.PATCH)');
    });

    test('sequence_context_rate returns 0.0 for unknown base pair', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.sequence_context_rate('A', 'G'), equals(0.0));
    });

    test('structural_weight returns 0.0 for unknown context key', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.structural_weight('nonexistent_context'), equals(0.0));
    });
  });

  // ── 3. Round-trip serialization ────────────────────────────────────────────
  group('CpdParameters round-trip serialization', () {
    test('parse → to_json → re-parse produces equal object', () {
      final original = _parse(_MINIMAL_VALID_JSON);
      final json_map = original.to_json();
      final json_str = jsonEncode(json_map);
      final reparsed = _parse(json_str);
      expect(reparsed, equals(original));
    });

    test('round-trip preserves schema_version', () {
      final original = _parse(_MINIMAL_VALID_JSON);
      final reparsed = _parse(jsonEncode(original.to_json()));
      expect(reparsed.schema_version, equals(original.schema_version));
    });

    test('round-trip preserves all photoproduct ids', () {
      final original = _parse(_MINIMAL_VALID_JSON);
      final reparsed = _parse(jsonEncode(original.to_json()));
      final orig_ids = original.photoproducts.map((p) => p.id).toSet();
      final new_ids = reparsed.photoproducts.map((p) => p.id).toSet();
      expect(new_ids, equals(orig_ids));
    });

    test('round-trip preserves structural weights exactly', () {
      final original = _parse(_MINIMAL_VALID_JSON);
      final reparsed = _parse(jsonEncode(original.to_json()));
      final orig_cpd = original.photoproduct('TT_CPD')!;
      final new_cpd = reparsed.photoproduct('TT_CPD')!;
      expect(new_cpd.structural_weight('extension_extension'),
          equals(orig_cpd.structural_weight('extension_extension')));
      expect(new_cpd.structural_weight('adjacent_domain_ds'),
          equals(orig_cpd.structural_weight('adjacent_domain_ds')));
    });

    test('round-trip preserves enabled/disabled status', () {
      final original = _parse(_MINIMAL_VALID_JSON);
      final reparsed = _parse(jsonEncode(original.to_json()));
      for (final orig_p in original.photoproducts) {
        final new_p = reparsed.photoproduct(orig_p.id)!;
        expect(new_p.enabled, equals(orig_p.enabled),
            reason: '${orig_p.id} enabled status changed on round-trip');
      }
    });

    test('to_json_string produces valid JSON', () {
      final params = _parse(_MINIMAL_VALID_JSON);
      final json_str = params.to_json_string();
      expect(() => jsonDecode(json_str), returnsNormally);
    });
  });

  // ── 4. Real file validation (loads actual cpd_parameters.json via dart:io) ─
  group('Real cpd_parameters.json file', () {
    late CpdParameters params;

    setUpAll(() async {
      // Resolve relative to the project root (one level up from test/).
      // Works when the test is run from the project root directory, which is
      // the standard for `dart run build_runner test`.
      final file = File('web/cpd_parameters.json');
      final content = await file.readAsString();
      params = CpdParameters.from_json_string(content);
    });

    test('file loads and parses without error', () {
      expect(params, isNotNull);
    });

    test('file schema_version is non-empty', () {
      expect(params.schema_version, isNotEmpty);
    });

    test('file contains at least one photoproduct', () {
      expect(params.photoproducts, isNotEmpty);
    });

    test('file contains at least one enabled photoproduct', () {
      expect(params.enabled_photoproducts, isNotEmpty,
          reason: 'At least TT_CPD should be enabled in the production file');
    });

    test('file TT_CPD is enabled', () {
      final cpd = params.photoproduct('TT_CPD');
      expect(cpd, isNotNull, reason: 'TT_CPD entry must exist in production file');
      expect(cpd!.enabled, isTrue);
    });

    test('file TT_CPD TT rate is 1.0 (normalization anchor)', () {
      final cpd = params.photoproduct('TT_CPD')!;
      expect(cpd.sequence_context_rate('T', 'T'), equals(1.0));
    });

    test('file passes all structural key constraints', () {
      const required_keys = [
        'adjacent_domain_ds',
        'extension_extension',
        'loopout_loopout',
        'extension_loopout',
      ];
      for (final p in params.photoproducts) {
        for (final key in required_keys) {
          expect(p.structural_context_weights.containsKey(key), isTrue,
              reason: '${p.id} in production file is missing key "$key"');
        }
      }
    });

    test('file round-trips without data loss', () {
      final reparsed = CpdParameters.from_json_string(jsonEncode(params.to_json()));
      expect(reparsed, equals(params));
    });
  });
}
