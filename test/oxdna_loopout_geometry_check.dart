/// Standalone geometry check for improved loopout 3D positioning.
///
/// Computes the oxDNA positions and orientations for a pair of opposing thymine
/// loopouts (same crossover, different strands) using the exact same math as
/// the production code in oxdna_export.dart, but without any dart:html or
/// over_react dependencies.
///
/// Run with:
///   dart test/oxdna_loopout_geometry_check.dart
///
/// Expected result: loopout 1 arcs in the −x direction, loopout 2 arcs in the
/// +x direction — they are mirror images about the zy plane (x → −x).
///
/// Design:
///   Helix 0, grid [0,0], forward strand, offsets 0–5
///       ──────────────────●   (prev_nuc of loopout 1 / next_nuc of loopout 2)
///   ↕ loopout 1 (strand 1)    ↕ loopout 2 (strand 2)
///   Helix 1, grid [0,1], backward strand, offsets 0–5
///       <─────────────────●   (next_nuc of loopout 1 / prev_nuc of loopout 2)
///
/// Default geometry constants (matching scadnano defaults):
///   rise_per_base_pair = 0.332 nm
///   helix_radius       = 1.0 nm
///   inter_helix_gap    = 1.0 nm  →  distance_between_helices = 3.0 nm
///   bases_per_turn     = 10.5
///   NM_TO_OX_UNITS     = 1.0 / 0.8518
///
/// In oxDNA coordinates (no yaw/pitch/roll):
///   forward  = (0, 0, 1)   — helix propagation direction
///   normal   = (0, −1, 0)  — backbone→base at offset 0 for forward domains
///   nuc.forward for a forward domain = −forward = (0, 0, −1)

import 'dart:math';

// ── Minimal vector class (same operations as OxdnaVector) ─────────────────────

class V3 {
  final double x, y, z;
  const V3(this.x, this.y, this.z);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);

  double dot(V3 o) => x * o.x + y * o.y + z * o.z;

  V3 cross(V3 o) => V3(
    y * o.z - z * o.y,
    z * o.x - x * o.z,
    x * o.y - y * o.x,
  );

  double length() => sqrt(x * x + y * y + z * z);

  V3 normalize() {
    final len = length();
    return V3(x / len, y / len, z / len);
  }

  @override
  String toString() => '(${_f(x)}, ${_f(y)}, ${_f(z)})';

  static String _f(double v) => v.toStringAsFixed(5);
}

// ── Geometry constants ────────────────────────────────────────────────────────

const nm2ox = 1.0 / 0.8518; // NM_TO_OX_UNITS
const rise_nm = 0.332; // rise_per_base_pair
const helix_radius_nm = 1.0;
const inter_helix_gap_nm = 1.0;
const dist_between_helices_nm = 2 * helix_radius_nm + inter_helix_gap_nm; // = 3.0 nm
const bases_per_turn = 10.5;

// In oxDNA frame (no yaw/pitch/roll, square lattice):
//   roll_axis (helix propagation) = z
//   yaw_axis  = y
//   forward = roll_axis = (0,0,1)
//   normal  = -yaw_axis = (0,-1,0)
const oxForward = V3(0, 0, 1); // helix axis direction
const oxNormal = V3(0, -1, 0); // backbone→base normal at offset 0 for fwd

// Helix origins in oxDNA units (square lattice, grid [0,0] and [0,1]):
final h0_origin = V3(0, 0 * dist_between_helices_nm * nm2ox, 0); // (0,0,0)
final h1_origin = V3(0, 1 * dist_between_helices_nm * nm2ox, 0); // (0,~3.52,0)

// ── Helper: backbone-center position at a given offset on a helix ─────────────

V3 backbone_center(V3 helix_origin, int offset) {
  return helix_origin + oxForward * (offset * rise_nm * nm2ox);
}

// ── Helper: nuc.forward for a domain ─────────────────────────────────────────
//   Production code: `var forw = domain.forward ? -forward : forward;`

V3 nuc_forward(bool domain_is_forward) =>
    domain_is_forward ? -oxForward : oxForward;

// ── Helper: reproduce the loopout arc positions ───────────────────────────────

class NucPos {
  final V3 center;
  final V3 normal; // backbone→base (out_of_plane in arc code)
  final V3 forward; // 5'→3' propagation
  NucPos(this.center, this.normal, this.forward);
}

List<NucPos> loopout_arc(
  V3 prev_center,
  V3 prev_nuc_forward,
  bool prev_domain_is_forward,
  V3 next_center,
  int strand_length, {
  double arc_amplitude = 0.1,
  double z_tilt_ratio = 0.5,
}) {
  final connection = next_center - prev_center;
  // Recover helix axis (constant regardless of domain direction):
  //   nuc.forward = domain.forward ? -helix_axis : +helix_axis
  final helix_axis = prev_domain_is_forward ? -prev_nuc_forward : prev_nuc_forward;
  var out_of_plane_raw = connection.cross(helix_axis);
  if (out_of_plane_raw.length() < 1e-6) {
    // fallback: arbitrary perpendicular (same as get_normal_vector_to)
    var unit = V3(1, 0, 0);
    if (1 - connection.normalize().dot(unit).abs() < 0.001) unit = V3(0, 1, 0);
    out_of_plane_raw = unit.cross(connection);
  }
  final out_of_plane = out_of_plane_raw.normalize();
  // Tilt along the 5'→3' strand exit direction (-prev_nuc_forward) to also
  // separate opposing loopouts along the helix axis (z).
  final strand_exit_dir = -prev_nuc_forward;
  final arc_dir = (out_of_plane + strand_exit_dir * z_tilt_ratio).normalize();
  final conn_norm = connection.normalize();

  final positions = <NucPos>[];
  for (int i = 0; i < strand_length; i++) {
    final t = (i + 1) / (strand_length + 1);
    final bulge = arc_amplitude * sin(pi * t);
    final pos = prev_center + connection * t + arc_dir * bulge;
    positions.add(NucPos(pos, arc_dir, conn_norm));
  }
  return positions;
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
  // Crossover offset: both domains end at offset 5 (end=6, so last offset is 5).
  const int crossover_offset = 5;
  const int loopout_length = 2; // "TT" thymine loopout

  // ── Strand 1: h0_forward → loopout → h1_backward ──────────────────────────
  //   prev_nuc = last nuc of h0_forward at offset 5
  //   next_nuc = first nuc of h1_backward (stored reversed) = its 3' end = offset 5

  final prev1 = backbone_center(h0_origin, crossover_offset);
  final next1 = backbone_center(h1_origin, crossover_offset);
  final prev1_fwd = nuc_forward(true); // prev domain is forward

  // ── Strand 2: h1_forward → loopout → h0_backward ──────────────────────────
  //   prev_nuc = last nuc of h1_forward at offset 5
  //   next_nuc = first nuc of h0_backward (stored reversed) = offset 5

  final prev2 = backbone_center(h1_origin, crossover_offset);
  final next2 = backbone_center(h0_origin, crossover_offset);
  final prev2_fwd = nuc_forward(true); // prev domain is forward

  final arc1 = loopout_arc(prev1, prev1_fwd, true, next1, loopout_length);
  final arc2 = loopout_arc(prev2, prev2_fwd, true, next2, loopout_length);

  // ── Print header ───────────────────────────────────────────────────────────
  print('=' * 70);
  print('oxDNA loopout 3D geometry check');
  print('Square lattice, default geometry, crossover at offset $crossover_offset');
  print('Loopout length: $loopout_length bases ("TT")');
  print('arc_amplitude: 0.5 oxDNA units (≈ ${(0.5 * 0.8518).toStringAsFixed(3)} nm)');
  print('=' * 70);
  print('');

  print('ANCHOR POSITIONS (backbone centers):');
  print('  prev_nuc(strand1) = $prev1   [h0 offset $crossover_offset, fwd domain]');
  print('  next_nuc(strand1) = $next1   [h1 offset $crossover_offset, bwd domain]');
  print('  prev_nuc(strand2) = $prev2   [h1 offset $crossover_offset, fwd domain]');
  print('  next_nuc(strand2) = $next2   [h0 offset $crossover_offset, bwd domain]');
  print('');

  print('CONNECTION VECTORS (next_nuc.center − prev_nuc.center):');
  final conn1 = next1 - prev1;
  final conn2 = next2 - prev2;
  print('  strand1: $conn1');
  print('  strand2: $conn2  [should be −strand1]');
  print('');

  print('ARC DIRECTIONS (connection × helix_axis, tilted by strand_exit_dir):');
  final ha1 = -prev1_fwd; // helix_axis: forward domain → -nuc.forward
  final ha2 = -prev2_fwd;
  final oop1 = conn1.cross(ha1).normalize();
  final oop2 = conn2.cross(ha2).normalize();
  final exit1 = -prev1_fwd; // strand 5'→3' exit direction
  final exit2 = -prev2_fwd;
  final arc1_dir = (oop1 + exit1 * 0.5).normalize();
  final arc2_dir = (oop2 + exit2 * 0.5).normalize();
  print('  strand1: $arc1_dir');
  print('  strand2: $arc2_dir  [should be −strand1 in both x and z]');
  print('');

  print('LOOPOUT BASE POSITIONS (backbone centers):');
  print('');
  print('  Strand 1 (arc_dir=${arc1_dir}):');
  for (int i = 0; i < arc1.length; i++) {
    final n = arc1[i];
    print('    base[$i]:  center=${n.center}  normal=${n.normal}  fwd=${n.forward}');
  }
  print('');
  print('  Strand 2 (arc_dir=${arc2_dir}):');
  for (int i = 0; i < arc2.length; i++) {
    final n = arc2[i];
    print('    base[$i]:  center=${n.center}  normal=${n.normal}  fwd=${n.forward}');
  }
  print('');

  // ── Symmetry verification ──────────────────────────────────────────────────
  // The two strands are antiparallel: strand 1 traverses h0→h1 (y increasing)
  // while strand 2 traverses h1→h0 (y decreasing).  The correct spatial pairing
  // is strand1[i] ↔ strand2[N−1−i] (reverse-indexed).  At each paired position
  // the x-coordinates should be equal and opposite (zy-plane mirror) while y and
  // z should be identical.
  // Both prev domains are forward here, so strand_exit_dir = (0,0,+1) for both.
  // x-displacement is opposite; z-displacement is the SAME (both tilt +z).
  // This is expected for the all-forward case — z-tilt is only opposite when
  // prev domains are mixed (one fwd, one bwd), as in 2hb_loopout_test.sc.
  print('MIRROR CHECK (strand1[i] ↔ strand2[N−1−i]):');
  bool all_ok = true;
  for (int i = 0; i < loopout_length; i++) {
    final c1 = arc1[i].center;
    final c2 = arc2[loopout_length - 1 - i].center; // reverse-paired
    final x_mirror_ok = (c1.x + c2.x).abs() < 1e-9;
    final y_same_ok = (c1.y - c2.y).abs() < 1e-6;
    final z_same_ok = (c1.z - c2.z).abs() < 1e-6;
    // For all-forward: x is mirrored, z is same (both prev domains forward → same tilt).
    final status = x_mirror_ok ? 'PASS (x mirrored)' : 'FAIL';
    if (!x_mirror_ok) all_ok = false;
    print(
      '  s1[$i] ↔ s2[${loopout_length - 1 - i}]:'
      '  x: ${c1.x.toStringAsFixed(5)} ↔ ${c2.x.toStringAsFixed(5)} ${x_mirror_ok ? "✓" : "✗"}'
      '  z: ${c1.z.toStringAsFixed(5)} ↔ ${c2.z.toStringAsFixed(5)} (same=expected for all-fwd)'
      '  → $status',
    );
  }
  print('');
  print('Overall: ${all_ok ? "ALL PASS" : "FAILURES DETECTED"}');
  print('');

  // ── 2hb_loopout_test.sc case: mixed fwd/bwd prev domains ──────────────────
  // Green strand (#32b86c): h0_backward(offsets 7-17) → loopout → h1_forward(7-17)
  // Red   strand (#cc0000): h1_forward(offsets 0-6)   → loopout → h0_backward(0-6)
  //
  // Honeycomb grid, group "g1":
  //   helix 0 at grid [0,-1]: honeycomb pos (0, -1.0) → nm (0, -3.0, 0)
  //   helix 1 at grid [0,0]:  honeycomb pos (0,  0.0) → nm (0,  0.0, 0)
  // (h=0 in both, so x=0; v=-1 gives y=1.5*(-1)=-1.5, +0.5 adjust (h%2==0,v%2==1) = -1.0)
  print('─' * 70);
  print('TEST 2: 2hb_loopout_test.sc (honeycomb, mixed fwd/bwd prev domains)');
  print('Green: h0_backward(7-17) → loopout → h1_forward(7-17)');
  print('Red:   h1_forward(0-6)   → loopout → h0_backward(0-6)');
  print('');

  // Honeycomb distance_between_helices = 3.0 nm (same default geometry)
  // Helix origins in oxDNA units:
  final h0_hc = V3(0, -1.0 * dist_between_helices_nm * nm2ox, 0); // (0, -3.522, 0)
  final h1_hc = V3(0,  0.0 * dist_between_helices_nm * nm2ox, 0); // (0,  0.000, 0)

  // Green: prev_nuc = last nuc of h0_backward domain (offsets 7-17, stored reversed)
  //   After reversal nucleotides are [17,16,...,7]; .last = offset 7
  final prev_green = backbone_center(h0_hc, 7);
  final prev_green_fwd = nuc_forward(false); // backward domain: nuc.forward = +helix_axis
  // next_nuc = first nuc of h1_forward domain: offset 7
  final next_green = backbone_center(h1_hc, 7);

  // Red: prev_nuc = last nuc of h1_forward domain (offsets 0-6): offset 6
  final prev_red = backbone_center(h1_hc, 6);
  final prev_red_fwd = nuc_forward(true); // forward domain: nuc.forward = -helix_axis
  // next_nuc = first nuc of h0_backward domain (stored reversed): offset 6
  final next_red = backbone_center(h0_hc, 6);

  final arc_green = loopout_arc(prev_green, prev_green_fwd, false, next_green, 2);
  final arc_red   = loopout_arc(prev_red,   prev_red_fwd,   true,  next_red,   2);

  final conn_g = next_green - prev_green;
  final conn_r = next_red   - prev_red;
  final ha_g = prev_green_fwd;   // backward: helix_axis = +nuc.forward
  final ha_r = -prev_red_fwd;    // forward:  helix_axis = -nuc.forward
  final oop_g = conn_g.cross(ha_g).normalize();
  final oop_r = conn_r.cross(ha_r).normalize();
  final exit_g = -prev_green_fwd; // 5'→3': backward → −(+z) = −z
  final exit_r = -prev_red_fwd;   // 5'→3': forward  → −(−z) = +z
  final adir_g = (oop_g + exit_g * 0.5).normalize();
  final adir_r = (oop_r + exit_r * 0.5).normalize();

  print('  connection green: $conn_g');
  print('  connection red:   $conn_r');
  print('  arc_dir green: $adir_g');
  print('  arc_dir red:   $adir_r  [x AND z should both be opposite]');
  print('');
  print('  Green loopout base positions:');
  for (int i = 0; i < arc_green.length; i++) {
    print('    base[$i]: center=${arc_green[i].center}');
  }
  print('  Red loopout base positions:');
  for (int i = 0; i < arc_red.length; i++) {
    print('    base[$i]: center=${arc_red[i].center}');
  }
  print('');

  // X and Z mirror check (antiparallel: pair green[i] with red[N-1-i]).
  // x must be opposite (zy-plane mirror).
  // z displacement must also be opposite (opposite z-tilt from strand_exit_dir).
  // Note: absolute z positions differ due to different helix offsets (7 vs 6);
  // we check that the z DISPLACEMENT (relative to the straight-line midpoint) is opposite.
  print('X- AND Z-DISPLACEMENT MIRROR CHECK (green[i] ↔ red[N−1−i]):');
  bool ok2 = true;
  for (int i = 0; i < 2; i++) {
    final cg = arc_green[i].center;
    final cr = arc_red[1 - i].center;
    // Straight-line midpoint z for each arc (no displacement):
    final t = (i + 1) / 3.0; // t for base i in 2-base loopout
    final midz_g = prev_green.z + conn_g.z * t; // conn_g.z == 0 here, so same as prev_green.z
    final midz_r = prev_red.z   + conn_r.z * (1 - t);
    final dz_g = cg.z - midz_g; // z displacement for green
    final dz_r = cr.z - midz_r; // z displacement for red
    final x_ok = (cg.x + cr.x).abs() < 1e-9;
    final z_ok = (dz_g + dz_r).abs() < 1e-9; // displacements should be opposite
    final status = (x_ok && z_ok) ? 'PASS' : 'FAIL';
    if (!x_ok || !z_ok) ok2 = false;
    print('  g[$i] ↔ r[${1-i}]:'
        '  x: ${cg.x.toStringAsFixed(5)} ↔ ${cr.x.toStringAsFixed(5)} ${x_ok ? "✓" : "✗"}'
        '  Δz: ${dz_g.toStringAsFixed(5)} ↔ ${dz_r.toStringAsFixed(5)} ${z_ok ? "✓" : "✗"}'
        '  → $status');
  }
  print('');
  print('Overall: ${ok2 ? "ALL PASS — x and z displacements are opposite" : "FAILURES DETECTED"}');
}
