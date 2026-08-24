use <wrist_mount_piece.scad>

// ============================================================
// Decorated variant v2 -- continuous engraved line via hull()
// between consecutive spheres (reads as a swept groove instead
// of a strand of beads). Leaf accents dropped for now -- at this
// scale they read as blobs rather than leaves; simple line work
// first, ornament later (maybe toward the reticulated porcelain
// positive/negative space idea once we've got room to do it
// properly -- that's a real project on its own, not a bolt-on).
//
// Safety note: hull() of two spheres is always convex. Many
// convex solids subtracted from one shell (difference(shell,
// seg1, seg2, ...)) is ordinary CSG -- not the multi-concave-
// union pattern that broke CGAL on the cameo.
// ============================================================

mount_run_d      = 24;
r_inner_d        = 32;
r_outer_d        = 55;
blend_start_d    = 6;
blend_end_d      = 18;
back_thickness_d = 1.6;
foam_thickness_d = 2.0;
foam_proud_d     = 0.3;
pocket_depth_d   = foam_thickness_d - foam_proud_d;
mount_length_d   = 30;

function sag_d(x, r) = r - sqrt(max(r*r - x*x, 0));
function smoothstep_d(x, a, b) =
    let(t = min(max((x - a) / (b - a), 0), 1))
    t * t * (3 - 2 * t);
function sag_blend_d(x) =
    let(w = smoothstep_d(x, blend_start_d, blend_end_d))
    sag_d(x, r_inner_d) * (1 - w) + sag_d(x, r_outer_d) * w;
function z_bottom_d(x) = -sag_blend_d(x);
function z_floor_d(x)  = z_bottom_d(x) + pocket_depth_d;
function back_z(x)     = z_floor_d(x) + back_thickness_d;
function lerp(a, b, t) = a + (b - a) * t;

// ---------- VINE PATH -----------------------------------------
vine_steps    = 22;
vine_x0       = 3;
vine_x1       = mount_run_d - 3;
vine_z_mid    = mount_length_d / 2;
vine_amp      = 5;
vine_freq     = 1.0;
vine_r_start  = 1.3;
vine_r_end    = 0.7;     // tapers thinner toward the strap edge
engrave_depth = 0.6;

function vine_x(t) = vine_x0 + (vine_x1 - vine_x0) * t;
function vine_z(t) = vine_z_mid + vine_amp * sin(t * 360 * vine_freq / 2);
function vine_r(t) = lerp(vine_r_start, vine_r_end, t);

module vine_point(t) {
    x = vine_x(t);
    z = vine_z(t);
    r = vine_r(t);
    y = back_z(x) + (r - engrave_depth);
    translate([x, y, z]) sphere(r = r);
}

module vine_cutter() {
    for (i = [0 : vine_steps - 1]) {
        hull() {
            vine_point(i / vine_steps);
            vine_point((i + 1) / vine_steps);
        }
    }
}

module decorated_mount_piece_v3() {
    difference() {
        mount_piece();
        vine_cutter();
    }
}

decorated_mount_piece_v3();
