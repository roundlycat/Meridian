// =====================================================================
// Hedgehog carving reference set -- shared shapes.
// You shouldn't need to edit this file; the stage files (0_..7_) are
// the ones to open if you want to tweak proportions.
// =====================================================================
$fn = 14;

L = 70;   // nose-to-rump length (x axis, nose at x=0, rump at x=L)
W = 36;   // width (y axis, centered at y=0)
H = 34;   // height (z axis, base at z=0)

x1 = 21;  // nose / shoulder boundary
x2 = 48;  // shoulder / rump boundary

function lerp(a,b,t) = a + (b-a)*t;

// Flat-bottomed "loaf" cross-section: dome from (-w/2,0) up over
// (0,h) down to (w/2,0). polygon() auto-closes the flat bottom edge.
// n=2 gives a 3-point triangle (sharp low-poly "sliced" look);
// n=10+ gives a smooth rounded dome.
function loaf_profile(w, h, n=10) =
    [ for (i = [0:n]) let(a = 180 - i*180/n) [ (w/2)*cos(a), h*sin(a) ] ];

function rect_profile(w, h) = [[-w/2,0],[w/2,0],[w/2,h],[-w/2,h]];

module xsection_verts(points, x0, r=0.35) {
    for (p = points)
        translate([x0, p[0], p[1]])
            sphere(r=r);
}

module loft(profA, xA, profB, xB) {
    hull() {
        xsection_verts(profA, xA);
        xsection_verts(profB, xB);
    }
}

// Chain of lofts through a list of [x, w, h] samples, each cross-
// section a loaf_profile. Gives a smooth swept body when samples are
// close together.
module swept_chain(samples, poly_n=10) {
    for (i = [0:len(samples)-2]) {
        s0 = samples[i]; s1 = samples[i+1];
        loft(loaf_profile(s0[1], s0[2], poly_n), s0[0],
             loaf_profile(s1[1], s1[2], poly_n), s1[0]);
    }
}

// Raised reference bead along an arbitrary list of 3D points.
module bead_path(pts, r=1.0) {
    for (i = [0:len(pts)-2])
        hull() {
            translate(pts[i]) sphere(r=r);
            translate(pts[i+1]) sphere(r=r);
        }
}

// Gesture-line silhouette arc, drawn on the -y face. t0/t1 let a
// later stage draw only the part of the arc that's still on
// un-carved material.
function arc_point(t) = [3 + t*(L-6), -W/2, 6 + 24*sin(180*t)];
module gesture_arc(t0=0, t1=1, n=16) {
    bead_path([ for (i=[0:n]) arc_point(lerp(t0,t1,i/n)) ], r=1.0);
}

module zone_divider(xpos) {
    bead_path([[xpos,-W/2,1],[xpos,-W/2,H-1]], r=1.0);
}

// Convert an x-position to the gesture arc's t parameter (for
// trimming the arc to whatever's still raw material at each stage).
function t_at_x(x) = (x-3)/(L-6);

// ---- "First cuts done" body proportions, shared by stages 4-7 ----
nose_tip_w = W*0.58;  nose_tip_h = H*0.62;
body_full_w = W*0.95; body_full_h = H*0.90;
rump_tip_w = W*0.55;  rump_tip_h = H*0.42;

function body_w(x) = x<x1 ? lerp(nose_tip_w, body_full_w, x/x1) :
                     x<x2 ? body_full_w :
                     lerp(body_full_w, rump_tip_w, (x-x2)/(L-x2));
function body_h(x) = x<x1 ? lerp(nose_tip_h, body_full_h, x/x1) :
                     x<x2 ? body_full_h :
                     lerp(body_full_h, rump_tip_h, (x-x2)/(L-x2));

module full_hedgehog_body(n_samples=16, poly_n=10) {
    samples = [ for (i=[0:n_samples]) let(x=lerp(0,L,i/n_samples)) [x, body_w(x), body_h(x)] ];
    swept_chain(samples, poly_n=poly_n);
}
