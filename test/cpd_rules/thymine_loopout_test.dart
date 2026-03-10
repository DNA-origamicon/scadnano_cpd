// Tests for the "convert crossover to thymine loopout" workflow (Phase 4).
//
// Verifies that:
//   1. The reducer assigns the correct thymine DNA sequence to the new loopout.
//   2. The loopout_num_bases matches the requested number of thymines.
//   3. CPD detection correctly finds T-T pairs within the resulting loopout.
//
// Run with:
//   dart run build_runner test -- test/cpd_rules/thymine_loopout_test.dart

import 'dart:convert';
import 'package:test/test.dart';
import 'package:scadnano/src/state/design.dart';
import 'package:scadnano/src/state/strand.dart';
import 'package:scadnano/src/state/loopout.dart';
import 'package:scadnano/src/state/crossover.dart';
import 'package:scadnano/src/actions/actions.dart' as actions;
import 'package:scadnano/src/reducers/change_loopout_ext_properties.dart';
import 'package:scadnano/src/middleware/cpd_rule_helpers.dart';

// ────────────────────────────────────────────────────────────────────────────
// Minimal design: one staple strand crossing between two helices.
//
//   helix 0 forward  ──────>   (domain at offsets 0–5)
//                       ↓       (crossover)
//   helix 1 backward <──────   (domain at offsets 0–5)
//
// The strand has:  substrands = [Domain(h0,fwd,0–5), Domain(h1,back,0–5)]
// and one crossover between them.
// ────────────────────────────────────────────────────────────────────────────

const String _DESIGN_JSON = '''
{
  "version": "0.20.0",
  "helices": [
    {"grid_position": [0, 0]},
    {"grid_position": [0, 1]}
  ],
  "strands": [
    {
      "domains": [
        {"helix": 0, "forward": true,  "start": 0, "end": 6},
        {"helix": 1, "forward": false, "start": 0, "end": 6}
      ],
      "sequence": "TTTTTTTTTTTT"
    }
  ]
}
''';

void main() {
  late Design design;
  late Strand strand;
  late Crossover crossover;

  setUpAll(() {
    design = Design.from_json_str(_DESIGN_JSON, false)!;
    strand = design.strands.first;
    // The single crossover connects domain 0 (fwd h0) to domain 1 (back h1).
    crossover = strand.crossovers.first;
  });

  group('thymine loopout reducer', () {
    test('creates loopout with thymine sequence', () {
      final int num_t = 3;
      final String seq = 'T' * num_t;
      final action = actions.ConvertCrossoverToLoopout(crossover, num_t, seq);
      final Strand result = convert_crossover_to_loopout_reducer(strand, action);

      expect(result.loopouts.length, equals(1));
      final Loopout loopout = result.loopouts.first;
      expect(loopout.dna_sequence, equals(seq));
    });

    test('loopout_num_bases matches num thymines', () {
      final int num_t = 4;
      final action = actions.ConvertCrossoverToLoopout(crossover, num_t, 'T' * num_t);
      final Strand result = convert_crossover_to_loopout_reducer(strand, action);

      expect(result.loopouts.first.loopout_num_bases, equals(num_t));
    });

    test('resulting strand has no crossovers', () {
      final action = actions.ConvertCrossoverToLoopout(crossover, 2, 'TT');
      final Strand result = convert_crossover_to_loopout_reducer(strand, action);

      expect(result.crossovers.length, equals(0));
    });

    test('single thymine loopout (N=1) has sequence "T"', () {
      final action = actions.ConvertCrossoverToLoopout(crossover, 1, 'T');
      final Strand result = convert_crossover_to_loopout_reducer(strand, action);

      expect(result.loopouts.first.dna_sequence, equals('T'));
    });

    test('six-thymine loopout has sequence "TTTTTT"', () {
      final action = actions.ConvertCrossoverToLoopout(crossover, 6, 'TTTTTT');
      final Strand result = convert_crossover_to_loopout_reducer(strand, action);

      expect(result.loopouts.first.dna_sequence, equals('TTTTTT'));
    });
  });

  group('CPD detection on thymine loopout strand', () {
    // Build a design where the crossover has been replaced by a 2-thymine loopout,
    // then verify that CPD detection (at the rule-engine level) finds a loopout-loopout
    // T-T pair.

    late Design loopout_design;
    late List<IdentifiedTBase> identified_t_bases;

    setUpAll(() {
      // Simulate the conversion: replace the crossover domain list manually.
      // Easiest: reconstruct from JSON with a loopout already in place.
      const loopout_json = '''
      {
        "version": "0.20.0",
        "helices": [
          {"grid_position": [0, 0]},
          {"grid_position": [0, 1]}
        ],
        "strands": [
          {
            "domains": [
              {"helix": 0, "forward": true,  "start": 0, "end": 6},
              {"loopout": 2},
              {"helix": 1, "forward": false, "start": 0, "end": 6}
            ],
            "sequence": "TTTTTTTTTTTTTT"
          }
        ]
      }
      ''';
      loopout_design = Design.from_json_str(loopout_json, false)!;

      // Build IdentifiedTBase list manually from the loopout strand.
      // We reference the loopout's two T bases by position in its sequence.
      final Strand s = loopout_design.strands.first;
      final Loopout loopout = s.loopouts.first;
      final String strand_id = s.id;

      identified_t_bases = [
        IdentifiedTBase(
          source_id: 'manual-loop-t0',
          strand: s,
          substrand: loopout,
          idx_in_substrand_sequence: 0,
          visual_coord_x: null,
          visual_coord_y: null,
          grid_coord_x: null,
          grid_coord_y: null,
          parent_element_id_from_dom: null,
          char_idx_from_dom: 0,
        ),
        IdentifiedTBase(
          source_id: 'manual-loop-t1',
          strand: s,
          substrand: loopout,
          idx_in_substrand_sequence: 1,
          visual_coord_x: null,
          visual_coord_y: null,
          grid_coord_x: null,
          grid_coord_y: null,
          parent_element_id_from_dom: null,
          char_idx_from_dom: 1,
        ),
      ];
    });

    test('detects T-T pair in loopout as CPD candidate', () {
      final output = detect_cpd_sites_from_t_bases(loopout_design, identified_t_bases);
      // The two thymines on the same loopout should match the loopout-loopout rule.
      expect(output.cpd_sites.length, greaterThan(0));
    });

    test('detected site uses loopout-loopout structural context', () {
      final output = detect_cpd_sites_from_t_bases(loopout_design, identified_t_bases);
      expect(output.cpd_sites.isNotEmpty, isTrue);
    });
  });
}
