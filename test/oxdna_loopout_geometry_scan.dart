/// Loopout geometry scan for 2hb_loopout_test.sc.
///
/// Sweeps the new (x_offset, z_offset, theta) parameter set and prints the
/// backbone-center position and base-normal vector for loopout bases at strand
/// indices 11 and 12 of the green strand (T 0:0:11 and T 0:0:12 in the
/// 2hb_loopout_test.sc design).
///
/// Also computes the flanking nucleotide backbone bead positions (r = center + normal*0.6)
/// and finds optimal x_offset, z_offset for even backbone bead spacing.
///
/// Design 2hb_loopout_test.sc (group g1, grid=honeycomb):
///   Helix 0: grid[0,-1], roll=184.285714°  → y = -1.5 * 3.0 / 0.8518 = -5.2835 ox
///   Helix 1: grid[0, 0], roll=154.285714°  → y = 0
///   Green strand:  h0 backward start=7..18, loopout(2), h1 forward start=7..18
///     prev_nuc = h0 backward offset 7,  next_nuc = h1 forward offset 7
///   Red strand:    h1 forward start=0..7,  loopout(2), h0 backward start=0..7
///     prev_nuc = h1 forward offset 6,   next_nuc = h0 backward offset 6
///
/// Run with:
///   dart test/oxdna_loopout_geometry_scan.dart

import 'dart:math';

// ── Minimal vector ─────────────────────────────────────────────────────────────

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double length() => sqrt(x * x + y * y + z * z);
  V3 normalize() {
    final len = length();
    return V3(x / len, y / len, z / len);
  }

  // Rodrigues rotation: rotate this by angle° CCW around axis (matches oxdna_export.dart)
  V3 rotate(double angleDeg, V3 axis) {
    final u = axis.normalize();
    final c = cos(angleDeg * pi / 180.0);
    final s = sin(angleDeg * pi / 180.0);
    final uCrossThis = u.cross(this);
    // return u*dot(u) + (uCrossThis*c).cross(u) - uCrossThis*s
    return u * dot(u) + (uCrossThis * c).cross(u) - uCrossThis * s;
  }

  String fmt() =>
      '(${x.toStringAsFixed(4).padLeft(8)}, ${y.toStringAsFixed(4).padLeft(8)}, ${z.toStringAsFixed(4).padLeft(8)})';
}

// ── Geometry constants (matching scadnano defaults) ────────────────────────────

const nm2ox = 1.0 / 0.8518;
const rise_nm = 0.332;
const dist_nm = 3.0; // 2*helix_radius + inter_helix_gap
const bases_per_turn = 10.5;
const minor_groove_angle = 150.0;
const groove_gamma = 20.0;
const base_dist = 0.6; // backbone bead offset from center

// Honeycomb helix origins for 2hb_loopout_test.sc (group g1, grid=honeycomb):
//   helix 0: grid [0,-1]  →  honeycomb: y = 1.5*(-1)*dist_nm = -4.5 nm = -5.2836 ox
//   helix 1: grid [0, 0]  →  y = 0
final h0 = V3(0, -1.5 * dist_nm * nm2ox, 0);
final h1 = V3(0, 0.0, 0);

final h0_roll = 184.285714; // degrees
final h1_roll = 154.285714; // degrees

V3 helix_center(V3 helix_origin, int offset) =>
    helix_origin + V3(0, 0, 1) * (offset * rise_nm * nm2ox);

// ── Normal computation (mirrors oxdna_export.dart: oxdna_get_helix_vectors + domain processing) ──

/// Compute the backbone→base normal (a1) for a nucleotide at [offset] in [domain_forward] domain,
/// for a helix with the given [roll].  All angles in degrees.
/// Returns the unit vector pointing from backbone toward base.
V3 nucleotide_normal(double helix_roll, bool domain_forward, int offset) {
  final step_rot = -360.0 / bases_per_turn;
  final helix_axis = V3(0, 0, 1); // roll_axis for default orientation

  // 1. Start from default normal (after yaw/pitch = 0, group.roll = 0):
  //    normal = -yaw_axis = -(0,1,0) = (0,-1,0)
  var normal = V3(0, -1, 0);

  // 2. Apply helix.roll (separate from axis rotations):
  normal = normal.rotate(-helix_roll, helix_axis);

  // 3. For backward domain: apply -minor_groove_angle
  if (!domain_forward) {
    normal = normal.rotate(-minor_groove_angle, helix_axis);
  }

  // 4. Apply groove_gamma_correction:
  final groove_correction = domain_forward ? groove_gamma : -groove_gamma;
  normal = normal.rotate(groove_correction, helix_axis);

  // 5. Apply per-offset step rotation:
  normal = normal.rotate(step_rot * offset, helix_axis);

  return normal;
}

/// Backbone bead position: r = center + normal * base_dist
V3 backbone_bead(V3 helix_origin, double helix_roll, bool domain_forward, int offset) {
  final center = helix_center(helix_origin, offset);
  final normal = nucleotide_normal(helix_roll, domain_forward, offset);
  return center + normal * base_dist;
}

/// nuc.forward in oxDNA: for forward domain = -helix_axis, for backward = +helix_axis
V3 nuc_forward(bool domain_forward) {
  return domain_forward ? V3(0, 0, -1) : V3(0, 0, 1);
}

// ── Loopout arc function ───────────────────────────────────────────────────────

class NucPos {
  final V3 center;
  final V3 normal; // backbone→base (a1 vector)
  final V3 forward; // 5'→3' direction (a3)
  final V3 r; // backbone bead position = center + normal * base_dist
  NucPos(this.center, this.normal, this.forward)
      : r = center + normal * base_dist;
}

List<NucPos> loopout_arc(
  V3 prev_center,
  V3 prev_nuc_fwd, // nuc.forward of prev nuc (not helix_axis)
  bool prev_domain_is_forward,
  V3 next_center,
  int strand_length, {
  double x_offset = 0.5,
  double z_offset = 0.0,
  double theta_deg = 0.0,
}) {
  final connection = next_center - prev_center;
  final helix_axis = prev_domain_is_forward ? -prev_nuc_fwd : prev_nuc_fwd;

  var oop_raw = connection.cross(helix_axis);
  if (oop_raw.length() < 1e-6) {
    var unit = V3(1, 0, 0);
    if (1 - connection.normalize().dot(unit).abs() < 0.001) unit = V3(0, 1, 0);
    oop_raw = unit.cross(connection);
  }
  final out_of_plane = oop_raw.normalize();
  final strand_exit_dir = -prev_nuc_fwd;

  final theta_rad = theta_deg * pi / 180.0;
  final norm_dir = out_of_plane * cos(theta_rad) + strand_exit_dir * sin(theta_rad);
  final conn_norm = connection.normalize();

  final positions = <NucPos>[];
  for (int i = 0; i < strand_length; i++) {
    final t = (i + 1) / (strand_length + 1);
    final bulge = sin(pi * t);
    final pos = prev_center +
        connection * t +
        out_of_plane * (x_offset * bulge) +
        strand_exit_dir * (z_offset * bulge);
    positions.add(NucPos(pos, norm_dir, conn_norm));
  }
  return positions;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String pm(double v) => (v >= 0 ? '+' : '') + v.toStringAsFixed(4).padLeft(8);
String pm2(double v) => (v >= 0 ? '+' : '') + v.toStringAsFixed(2).padLeft(6);

// ── Even-spacing solver ───────────────────────────────────────────────────────

/// For a 2-base loopout, find x_offset and z_offset such that
/// d(r_prev, r_loop0) = d(r_loop0, r_loop1) = d(r_loop1, r_next).
///
/// The middle distance d_mid is fixed; we find x,z so that d0 = d2 = d_mid.
///
/// Returns null if no real solution exists.
Map<String, double>? solve_even_spacing({
  required V3 r_prev,
  required V3 r_next,
  required V3 prev_center,
  required V3 next_center,
  required V3 prev_nuc_fwd,
  required bool prev_domain_is_forward,
  required double theta_deg,
  int strand_length = 2,
}) {
  // Compute the fixed middle distance (same for all x,z at given theta and strand_length)
  // Use x=0, z=0 to get the baseline positions; middle dist doesn't depend on x,z
  // when strand_length=2 (both bases have same bulge).
  final arc0 = loopout_arc(prev_center, prev_nuc_fwd, prev_domain_is_forward, next_center,
      strand_length, x_offset: 0, z_offset: 0, theta_deg: theta_deg);
  final r0_tmp = arc0[0].r;
  final r1_tmp = arc0[1].r;
  final d_mid = (r1_tmp - r0_tmp).length();

  // Binary search over x_offset and z_offset to minimize |d0 - d_mid|^2 + |d2 - d_mid|^2
  // But since we derived analytically that for 2-base loopout with equal bulge,
  // r_0 and r_1 differ only in y (the helix-connection direction), we can solve directly.
  //
  // Parameterize: A = x_off * bulge_at_t1/3, dZ = z_off * bulge_at_t1/3
  // r_0 depends linearly on (A, dZ).
  // Equation: |r_0(A,dZ) - r_prev|^2 = d_mid^2
  //           |r_next - r_1(A,dZ)|^2 = d_mid^2
  // Solve via 2-equation linear system for A then dZ.

  final double target = d_mid * d_mid;

  // Numerical solution: sweep x_offset and z_offset
  double best_x = 0.5, best_z = 0.0;
  double best_err = double.infinity;

  for (int xi = -200; xi <= 200; xi++) {
    final x_off = xi * 0.01;
    for (int zi = -200; zi <= 200; zi++) {
      final z_off = zi * 0.01;
      final arc = loopout_arc(prev_center, prev_nuc_fwd, prev_domain_is_forward, next_center,
          strand_length, x_offset: x_off, z_offset: z_off, theta_deg: theta_deg);
      final d0 = (arc[0].r - r_prev).length();
      final d2 = (r_next - arc[1].r).length();
      final err = (d0 - d_mid).abs() + (d2 - d_mid).abs();
      if (err < best_err) {
        best_err = err;
        best_x = x_off;
        best_z = z_off;
      }
    }
  }

  // Refine with fine sweep around best
  for (int xi = -50; xi <= 50; xi++) {
    final x_off = best_x + xi * 0.001;
    for (int zi = -50; zi <= 50; zi++) {
      final z_off = best_z + zi * 0.001;
      final arc = loopout_arc(prev_center, prev_nuc_fwd, prev_domain_is_forward, next_center,
          strand_length, x_offset: x_off, z_offset: z_off, theta_deg: theta_deg);
      final d0 = (arc[0].r - r_prev).length();
      final d2 = (r_next - arc[1].r).length();
      final err = (d0 - d_mid).abs() + (d2 - d_mid).abs();
      if (err < best_err) {
        best_err = err;
        best_x = x_off;
        best_z = z_off;
      }
    }
  }

  return {'x_offset': best_x, 'z_offset': best_z, 'd_mid': d_mid, 'err': best_err};
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  final helix_axis = V3(0, 0, 1);

  // ── GREEN loopout: h0 backward (offset 7) → loopout(2) → h1 forward (offset 7) ──
  const int green_prev_offset = 7;
  const int green_next_offset = 7;
  const bool green_prev_fwd = false; // h0 backward

  final green_prev_center = helix_center(h0, green_prev_offset);
  final green_next_center = helix_center(h1, green_next_offset);
  final green_prev_nuc_fwd = nuc_forward(green_prev_fwd); // (0,0,+1) for backward

  final r_prev_green = backbone_bead(h0, h0_roll, green_prev_fwd, green_prev_offset);
  final r_next_green = backbone_bead(h1, h1_roll, true, green_next_offset); // h1 forward

  // ── RED loopout: h1 forward (offset 6) → loopout(2) → h0 backward (offset 6) ──
  const int red_prev_offset = 6;
  const int red_next_offset = 6;
  const bool red_prev_fwd = true; // h1 forward

  final red_prev_center = helix_center(h1, red_prev_offset);
  final red_next_center = helix_center(h0, red_next_offset);
  final red_prev_nuc_fwd = nuc_forward(red_prev_fwd); // (0,0,-1) for forward

  final r_prev_red = backbone_bead(h1, h1_roll, red_prev_fwd, red_prev_offset);
  final r_next_red = backbone_bead(h0, h0_roll, false, red_next_offset); // h0 backward

  print('=' * 72);
  print('FLANKING BACKBONE BEAD POSITIONS');
  print('-' * 72);
  print('  Green loopout (rev params: prev=h0-bwd-off7, next=h1-fwd-off7)');
  print('    r_prev = ${r_prev_green.fmt()}');
  print('    r_next = ${r_next_green.fmt()}');
  print('    |r_next - r_prev| straight = ${(r_next_green - r_prev_green).length().toStringAsFixed(4)}');
  print('');
  print('  Red loopout (fwd params: prev=h1-fwd-off6, next=h0-bwd-off6)');
  print('    r_prev = ${r_prev_red.fmt()}');
  print('    r_next = ${r_next_red.fmt()}');
  print('    |r_next - r_prev| straight = ${(r_next_red - r_prev_red).length().toStringAsFixed(4)}');
  print('=' * 72);
  print('');

  // ── Section: Optimal even-spacing for theta=261° (rev) and theta=225° (fwd) ──
  const double rev_theta = 261.0;
  const double fwd_theta = 225.0;

  print('OPTIMAL EVEN-SPACING SEARCH');
  print('-' * 72);

  print('  GREEN (rev), theta=$rev_theta°:');
  final result_green = solve_even_spacing(
    r_prev: r_prev_green,
    r_next: r_next_green,
    prev_center: green_prev_center,
    next_center: green_next_center,
    prev_nuc_fwd: green_prev_nuc_fwd,
    prev_domain_is_forward: green_prev_fwd,
    theta_deg: rev_theta,
  );
  if (result_green != null) {
    final x = result_green['x_offset']!;
    final z = result_green['z_offset']!;
    final d = result_green['d_mid']!;
    final err = result_green['err']!;
    final arc = loopout_arc(green_prev_center, green_prev_nuc_fwd, green_prev_fwd,
        green_next_center, 2, x_offset: x, z_offset: z, theta_deg: rev_theta);
    final d0 = (arc[0].r - r_prev_green).length();
    final d1 = (arc[1].r - arc[0].r).length();
    final d2 = (r_next_green - arc[1].r).length();
    print('    rev_x_offset = ${x.toStringAsFixed(3)},  rev_z_offset = ${z.toStringAsFixed(3)}');
    print('    d_mid (fixed)= ${d.toStringAsFixed(4)}  err=$err');
    print('    d0=${d0.toStringAsFixed(4)}  d1=${d1.toStringAsFixed(4)}  d2=${d2.toStringAsFixed(4)}');
  }
  print('');

  print('  RED (fwd), theta=$fwd_theta°:');
  final result_red = solve_even_spacing(
    r_prev: r_prev_red,
    r_next: r_next_red,
    prev_center: red_prev_center,
    next_center: red_next_center,
    prev_nuc_fwd: red_prev_nuc_fwd,
    prev_domain_is_forward: red_prev_fwd,
    theta_deg: fwd_theta,
  );
  if (result_red != null) {
    final x = result_red['x_offset']!;
    final z = result_red['z_offset']!;
    final d = result_red['d_mid']!;
    final err = result_red['err']!;
    final arc = loopout_arc(red_prev_center, red_prev_nuc_fwd, red_prev_fwd, red_next_center, 2,
        x_offset: x, z_offset: z, theta_deg: fwd_theta);
    final d0 = (arc[0].r - r_prev_red).length();
    final d1 = (arc[1].r - arc[0].r).length();
    final d2 = (r_next_red - arc[1].r).length();
    print('    fwd_x_offset = ${x.toStringAsFixed(3)},  fwd_z_offset = ${z.toStringAsFixed(3)}');
    print('    d_mid (fixed)= ${d.toStringAsFixed(4)}  err=$err');
    print('    d0=${d0.toStringAsFixed(4)}  d1=${d1.toStringAsFixed(4)}  d2=${d2.toStringAsFixed(4)}');
  }
  print('');
  print('=' * 72);
}
