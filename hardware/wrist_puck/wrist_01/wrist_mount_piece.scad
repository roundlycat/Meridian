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
mount_length = 30;   // width along the wrist (strap direction)

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
        linear_extrude(height = mount_length)
            shell_profile();
        translate([0, 0, rim_width])
            linear_extrude(height = mount_length - 2 * rim_width)
                pocket_profile();
    }
}

mount_piece();

// For the mirrored (opposite-side) piece:
// mirror([1, 0, 0]) mount_piece();
