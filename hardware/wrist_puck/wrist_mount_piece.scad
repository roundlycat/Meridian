// ============================================================
// Wrist-conforming mount piece (independent of puck body)
// Sits on ONE side of the puck; print two, mirror for the other.
// The LRA window stays bare — this piece never covers it.
//
// Modeling axes (before you rotate for your own print orientation):
//   X = curve "run" from the puck-side edge (x=0) out to the
//       strap-side edge (x=mount_run)
//   Y = height/sag of the curve (this is the direction that
//       drops away from the puck as the piece follows the wrist)
//   Z = width along the wrist / strap direction (mount_length)
//
// Curve is a smooth blend of two circular arcs: tighter radius
// near the puck (r_inner), gentler radius near the strap edge
// (r_outer), blended over [blend_start, blend_end]. This is a
// single difference() between two well-conditioned (smooth,
// non-spiky) extruded solids -- not the multi-union pattern that
// broke CGAL on the cameo project, so no heightmap workaround
// should be needed here. Render-tested below.
// ============================================================

// ---------- PARAMETERS (mm) ----------------------------------
mount_run    = 24;   // curve profile length, puck-edge to strap-edge
mount_length = 46;   // width along the wrist (strap direction) --
                       // widened from 30mm: see strap-ear section below,
                       // this number is no longer arbitrary, it's derived
                       // from needing 30mm webbing to actually fit with
                       // connected ears (see the comment there for why)

r_inner = 32;   // curvature radius near the puck edge (tighter)
r_outer = 55;   // curvature radius near the strap edge (gentler)
blend_start = 6;     // x where blend away from r_inner begins
blend_end   = 18;    // x where blend to r_outer completes

back_thickness = 1.6;   // solid backing thickness above the pocket floor (structural)
rim_width      = 2.5;   // solid rim border around the foam pocket (all sides)

foam_thickness = 2.0;   // target foam pad thickness (adjust once you've picked stock)
foam_proud     = 0.3;   // how far the foam should sit proud of the rim at rest
pocket_depth   = foam_thickness - foam_proud;  // recess cut UP from the rim plane for the foam

seg = 40;   // profile sample resolution
$fn = 60;

// ---------- CURVE MATH ----------------------------------------
function sag(x, r) = r - sqrt(max(r*r - x*x, 0));

function smoothstep(x, a, b) =
    let(t = min(max((x - a) / (b - a), 0), 1))
    t * t * (3 - 2 * t);

function sag_blend(x) =
    let(w = smoothstep(x, blend_start, blend_end))
    sag(x, r_inner) * (1 - w) + sag(x, r_outer) * w;

// skin-facing (bottom / rim) curve -- dips down (negative) as x grows
function z_bottom(x) = -sag_blend(x);
// pocket floor: recessed UP from the rim plane by pocket_depth
function z_floor(x) = z_bottom(x) + pocket_depth;
// outer back surface, above the floor by the structural backing
function shell_top_z(x) = z_floor(x) + back_thickness;

// ---------- 2D PROFILES -----------------------------------------
module shell_profile() {
    bottom_pts = [ for (i = [0:seg]) let(x = mount_run * i / seg) [x, z_bottom(x)] ];
    top_pts    = [ for (i = [seg:-1:0]) let(x = mount_run * i / seg) [x, shell_top_z(x)] ];
    polygon(concat(bottom_pts, top_pts));
}

// Cuts the pocket from the skin-facing (bottom) side up to the
// floor -- inset by rim_width in x so a solid rim survives all
// the way around. The -1 undercut guarantees the cut breaks
// cleanly through the bottom face rather than leaving a skin.
module pocket_profile() {
    x0 = rim_width;
    x1 = mount_run - rim_width;
    bottom_pts = [ for (i = [0:seg]) let(x = x0 + (x1 - x0) * i / seg) [x, z_bottom(x) - 1] ];
    top_pts    = [ for (i = [seg:-1:0]) let(x = x0 + (x1 - x0) * i / seg) [x, z_floor(x)] ];
    polygon(concat(bottom_pts, top_pts));
}

// ---------- 3D PIECE ---------------------------------------------
module mount_piece() {
    difference() {
        union() {
            linear_extrude(height = mount_length)
                shell_profile();
            strap_tab();
        }
        translate([0, 0, rim_width])
            linear_extrude(height = mount_length - 2 * rim_width)
                pocket_profile();
        key_slot_cutter();
        rod_hole_cutter();
    }
}

// ---------- STRAP EARS + CAPTURED ROD -----------------------------
// REBUILT after a real print failure: the first version centered
// the ears around a 32mm gap while the piece itself was only 30mm
// wide -- there is no way to fit a gap wider than the piece and
// still have the ears touch it. Each ear ended up floating ~1mm
// short of the shell, connected to nothing. What printed was two
// disconnected islands held together only by the slicer's own
// support lattice -- which is exactly the "spring-like" structure
// Sean found between the two end blocks. Caught from a real print,
// not caught by "Simple: yes" or the rod-hole probe, because neither
// of those checks verifies that separate solid islands are actually
// connected to each other. Fixed properly this time with an actual
// connected-component check (see check_connectivity.py), not just a
// manifold check.
//
// This time: ear_w is chosen first (comfortable wall around the rod
// hole), then rod_span and mount_length are DERIVED from it and from
// the webbing width -- not picked independently and hoped to fit.
webbing_w  = 30.0;
webbing_t  = 2.2;
ear_w      = 6.0;   // each ear's width (z-extent) -- wall around the
                     // 2.3mm hole is (ear_w - rod_hole_d)/2 ~= 1.85mm
rod_span   = mount_length - 2 * ear_w;   // derived, not independent --
                                          // guaranteed to fit inside
                                          // mount_length by construction
ear_len    = 6.0;    // how far each ear extends past mount_run
ear_t      = 4.0;    // ear thickness (y), independent of the thin edge
rod_hole_d      = 2.3;   // M2 rod clearance, free-spinning
rod_hole_inset  = 3.0;   // distance from each ear's outer tip

function tab_y_center() = (z_bottom(mount_run) + shell_top_z(mount_run)) / 2;
// Ears now sit WITHIN [0, mount_length], flush against each end --
// this is what actually keeps them connected to the shell, since the
// shell has continuous solid cross-section across its whole
// mount_length span. The 0.5mm x-overlap (below) only helps if the
// ear's z-range is a subset of the shell's z-range in the first
// place -- that was the part the first version got wrong.
function ear1_z() = ear_w / 2;
function ear2_z() = mount_length - ear_w / 2;

module strap_tab() {
    for (ez = [ear1_z(), ear2_z()])
        translate([mount_run - 0.5, tab_y_center(), ez])
            cube([ear_len + 0.5, ear_t, ear_w], center = true);
}

module rod_hole_cutter() {
    hole_x = mount_run + ear_len - rod_hole_inset;
    // spans both ears and the open gap between them -- harmless
    // where there's no material (the gap), only cuts where it
    // overlaps the two ear blocks
    translate([hole_x, tab_y_center(), ear1_z() - ear_w/2 - 1])
        cylinder(h = (ear2_z() + ear_w/2 + 1) - (ear1_z() - ear_w/2 - 1),
                  d = rod_hole_d, $fn = 24);
}

// ---------- REGISTRATION KEY SLOT ---------------------------------
// Matches the tongue on the puck's ±X wall (wrist_puck_enclosure
// KEY_* params). Cut from the puck-facing (x=0) edge, within the
// solid rim_width=2.5mm band -- i.e. before the foam pocket starts
// -- so it doesn't intrude on the pocket. See the puck file's KEY_*
// comment block for the shared-plane convention and the "first-pass,
// true up by hand" caveat; same applies here.
key_clearance = 0.3;   // loose dry-fit, not a press fit
key_depth = 1.8 + key_clearance;  // must match puck KEY_H + clearance
key_w     = 8.0 + key_clearance;  // must match puck KEY_W + clearance
key_t     = 2.0 + key_clearance;  // must match puck KEY_T + clearance
key_z     = 1.8;                  // must match puck KEY_Z

module key_slot_cutter() {
    // x = depth into the piece (undercut past x=0 so the cut
    //     breaks cleanly through the face rather than sitting
    //     tangent to it)
    // y = key_t  (mount piece's height/sag axis == puck's Z)
    // z = key_w  (mount piece's width axis == puck's Y)
    translate([(key_depth - 1) / 2, key_z, mount_length / 2])
        cube([key_depth + 1, key_t, key_w], center = true);
}

mount_piece();

// For the mirrored (opposite-side) piece:
// mirror([1, 0, 0]) mount_piece();
