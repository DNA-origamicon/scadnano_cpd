// Tests for the thymine loopout visual flip (Phase 4 follow-up).
//
// Verifies:
//   1. Loopout.is_thymine_loopout correctly classifies loopouts by sequence.
//   2. The arc control-point direction formula mirrors regular vs thymine
//      loopouts (using the same formula as design_main_strand_loopout.dart).
//
// Note: full path-string tests of loopout_path_description_within_group()
// require importing the view file (which pulls in dart:html, over_react, and
// app.dart) and are better covered as manual integration tests.  The tests
// below cover the meaningful logic without view dependencies.
//
// Run with:
//   dart run build_runner test -- test/loopout_visual_test.dart

import 'package:test/test.dart';
import 'package:scadnano/src/state/loopout.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Group 1: Loopout.is_thymine_loopout getter
  // ──────────────────────────────────────────────────────────────────────────

  group('Loopout.is_thymine_loopout', () {
    test('returns false when dna_sequence is null', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1);
      expect(l.is_thymine_loopout, isFalse);
    });

    test('returns false when dna_sequence is empty string', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: '');
      expect(l.is_thymine_loopout, isFalse);
    });

    test('returns true for single T', () {
      final l = Loopout(loopout_num_bases: 1, prev_domain_idx: 1, dna_sequence: 'T');
      expect(l.is_thymine_loopout, isTrue);
    });

    test('returns true for two Ts', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: 'TT');
      expect(l.is_thymine_loopout, isTrue);
    });

    test('returns true for six Ts', () {
      final l = Loopout(loopout_num_bases: 6, prev_domain_idx: 1, dna_sequence: 'TTTTTT');
      expect(l.is_thymine_loopout, isTrue);
    });

    test('returns false for sequence containing A', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: 'AT');
      expect(l.is_thymine_loopout, isFalse);
    });

    test('returns false for sequence containing lowercase t', () {
      // Sequences are expected to be uppercase; lowercase is not a thymine base.
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: 'Tt');
      expect(l.is_thymine_loopout, isFalse);
    });

    test('returns false for all-question-mark (unassigned) sequence', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: '??');
      expect(l.is_thymine_loopout, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Group 2: Arc control-point direction
  //
  // design_main_strand_loopout.dart applies:
  //   double effective_w = loopout.is_thymine_loopout ? -w : w;
  //   if (top_offset == top_dom.end - 1) {
  //     cx1 = endpoint_x + effective_w;   // "toward-right" case
  //   } else {
  //     cx1 = endpoint_x - effective_w;   // "toward-left" case
  //   }
  //
  // These tests verify that direction of the arc flips for thymine loopouts.
  // ──────────────────────────────────────────────────────────────────────────

  group('arc control-point direction', () {
    const double endpoint_x = 50.0; // arbitrary SVG coordinate
    const double w = 15.0; // arbitrary displacement

    Loopout regular() => Loopout(loopout_num_bases: 2, prev_domain_idx: 1);
    Loopout thymine() =>
        Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: 'TT');
    Loopout mixed() =>
        Loopout(loopout_num_bases: 2, prev_domain_idx: 1, dna_sequence: 'AT');

    double cx1(Loopout l, {required bool toward_right}) {
      final effective_w = l.is_thymine_loopout ? -w : w;
      return toward_right ? endpoint_x + effective_w : endpoint_x - effective_w;
    }

    test('regular loopout arcs RIGHT when endpoint is at domain right end', () {
      expect(cx1(regular(), toward_right: true), greaterThan(endpoint_x));
    });

    test('thymine loopout arcs LEFT when endpoint is at domain right end', () {
      expect(cx1(thymine(), toward_right: true), lessThan(endpoint_x));
    });

    test('regular and thymine are perfect mirrors around the endpoint (right end case)', () {
      final r = cx1(regular(), toward_right: true);
      final t = cx1(thymine(), toward_right: true);
      expect(r + t, closeTo(2 * endpoint_x, 1e-9));
    });

    test('regular loopout arcs LEFT when endpoint is at domain left end', () {
      expect(cx1(regular(), toward_right: false), lessThan(endpoint_x));
    });

    test('thymine loopout arcs RIGHT when endpoint is at domain left end', () {
      expect(cx1(thymine(), toward_right: false), greaterThan(endpoint_x));
    });

    test('regular and thymine are perfect mirrors around the endpoint (left end case)', () {
      final r = cx1(regular(), toward_right: false);
      final t = cx1(thymine(), toward_right: false);
      expect(r + t, closeTo(2 * endpoint_x, 1e-9));
    });

    test('mixed-sequence loopout is treated as regular (not flipped)', () {
      expect(cx1(mixed(), toward_right: true), greaterThan(endpoint_x));
    });

    test('null-sequence loopout is treated as regular (not flipped)', () {
      final l = Loopout(loopout_num_bases: 2, prev_domain_idx: 1);
      expect(cx1(l, toward_right: true), greaterThan(endpoint_x));
    });
  });
}
