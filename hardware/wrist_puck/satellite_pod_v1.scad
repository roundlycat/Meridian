// ============================================================
//  Meridian Wrist Array — Satellite Pod v1
//  July 2026 | Sean (Whitehorse, YT)
//
//  One pod = one DRV2605L board + one LRA. Five of these plus
//  the puck get sewn onto a flexible elastic/velcro band rather
//  than living in a rigid cross or star base. Print one now,
//  dry-fit it against a real Adafruit DRV + LRA before the new
//  boards arrive -- this is the one piece of the whole build
//  that doesn't need the new parts to test.
//
//  LAYOUT (top view, +X to the right):
//    [ DRV chamber ][ divider ][ LRA pocket ]
//  DRV chamber holds the driver board flat. LRA pocket has a
//  through-hole in the floor so the LRA sits directly against
//  skin (same principle as the puck's rev 4.5 bare-window LRA
//  opening: hole = LRA_D + 1.0mm). A small pass-hole through the
//  divider lets the two LRA leads reach the DRV board's OUT+/OUT-
//  pads without routing them externally.
//
//  CABLE ROUTING -- left open on purpose:
//  Two small holes exit through the DRV chamber's outer end wall
//  (the end away from the LRA pocket), toward whichever direction
//  the band runs. Use one for a single home-run cable to the puck
//  (star), or both for a daisy-chain bus in/out along the band.
//  Topology isn't decided yet -- this just doesn't block either
//  choice. Cap the unused hole with a dab of glue if you go star.
//
//  MOUNTING: flat stitch tabs on both long sides, two 1.5mm holes
//  each, meant for hand-sewing to a strip of non-stretch webbing
//  or twill tape -- NOT sewn straight through stretchy elastic.
//  The elastic/velcro sections should live between pods, not at
//  the attachment points, so stitching never takes stretch load.
//
//  LID: one piece over the whole pod, two M2 self-tapping screw
//  bosses at diagonal corners. Screws over snap-fit here on
//  purpose -- these need to come apart repeatedly for servicing,
//  and small snap tabs wear out faster than a couple of screws.
//
//  Units: mm throughout. Print in PETG on the A1 Mini, same as
//  the puck revisions. First print is a fit test, not final --
//  check DRV board and LRA seat correctly before committing to
//  five more.
// ============================================================

// ---- Component dimensions (measure your actual boards if in doubt) ----
DRV_L   = 26;    // Adafruit DRV2605L STEMMA QT board length
DRV_W   = 18;    // board width
DRV_CLR = 2;     // clearance added around the board, each side

LRA_D   = 10;    // LRA diameter (coin-type)
LRA_T   = 4;     // LRA thickness
LRA_SKIN_GAP = 1.0; // skin-contact opening = LRA_D + this, per rev 4.5 convention

// ---- Wall/floor/lid thicknesses ----
WALL   = 1.6;
FLOOR  = 1.2;
LID_T  = 1.6;

// ---- Derived chamber sizes ----
CHAMBER_L = DRV_L + DRV_CLR*2;      // ~30mm interior length
CHAMBER_W = DRV_W + DRV_CLR*2;      // ~22mm interior width
CHAMBER_H = 10;                     // clears board + header/connector height

POCKET_W  = CHAMBER_W;              // keep the pod a clean rectangular capsule
POCKET_L  = LRA_D + 6;              // ~16mm, LRA + retention lip + wire slack
POCKET_H  = CHAMBER_H;              // same interior height as the chamber, simpler lid

DIVIDER_T = WALL;

POD_L = WALL + CHAMBER_L + DIVIDER_T + POCKET_L + WALL;
POD_W = CHAMBER_W + WALL*2;
POD_H = FLOOR + CHAMBER_H + LID_T;

// ---- Cable pass-through ----
CABLE_HOLE_D = 3.0;
CABLE_HOLE_SPACING = 6;

// ---- Screw bosses (M2 self-tapping) ----
BOSS_OD = 4.5;
BOSS_PILOT_D = 1.7;
BOSS_MARGIN = 3.5; // inset from each corner

// ---- Stitch tabs ----
TAB_L = 8;
TAB_W = 4;
TAB_T = 2;
TAB_HOLE_D = 1.5;

$fn = 40;

// ============================================================
//  Modules
// ============================================================

module drv_chamber_cavity() {
    translate([WALL, WALL, FLOOR])
        cube([CHAMBER_L, CHAMBER_W, CHAMBER_H + 1]); // +1 so it opens through the top
}

module pocket_cavity() {
    translate([WALL + CHAMBER_L + DIVIDER_T, WALL, FLOOR])
        cube([POCKET_L, POCKET_W, POCKET_H + 1]);
}

module divider_wire_pass() {
    // Small round pass-through for the two LRA leads, centered
    // in the divider wall, positioned mid-height of the chamber.
    x = WALL + CHAMBER_L + DIVIDER_T/2;
    y = WALL + CHAMBER_W/2;
    z = FLOOR + CHAMBER_H/2;
    translate([x, y, z])
        rotate([0, 90, 0])
            cylinder(d = 3.5, h = DIVIDER_T + 2, center = true);
}

module lra_window() {
    // Two-stage hole in the pocket floor: a wider counterbore from
    // inside the pocket for the LRA body to sit in, narrowing to
    // the skin-contact opening (LRA_D + LRA_SKIN_GAP) through the
    // outer floor surface. The step this creates is the retention
    // lip -- no separate part needed.
    cx = WALL + CHAMBER_L + DIVIDER_T + POCKET_L/2;
    cy = WALL + POCKET_W/2;

    // Counterbore (from inside, doesn't go all the way through)
    translate([cx, cy, FLOOR - 0.01])
        cylinder(d = LRA_D + 1.5, h = LRA_T + 0.5);

    // Through opening to skin
    translate([cx, cy, -0.5])
        cylinder(d = LRA_D + LRA_SKIN_GAP, h = FLOOR + 1);
}

module cable_holes() {
    // Through the outer end wall of the DRV chamber (x = 0 face).
    y1 = WALL + CHAMBER_W/2 - CABLE_HOLE_SPACING/2;
    y2 = WALL + CHAMBER_W/2 + CABLE_HOLE_SPACING/2;
    z  = FLOOR + CHAMBER_H/2;

    translate([-0.5, y1, z])
        rotate([0, 90, 0])
            cylinder(d = CABLE_HOLE_D, h = WALL + 1);
    translate([-0.5, y2, z])
        rotate([0, 90, 0])
            cylinder(d = CABLE_HOLE_D, h = WALL + 1);
}

module screw_boss(solid = true) {
    if (solid) {
        // Starts 0.2mm below the floor's top surface so it truly
        // overlaps solid material (guarantees a fused union rather
        // than two volumes merely touching at a coincident face).
        translate([0, 0, -0.2])
            cylinder(d = BOSS_OD, h = CHAMBER_H + 0.2);
    } else {
        translate([0, 0, -0.5])
            cylinder(d = BOSS_PILOT_D, h = CHAMBER_H + 1);
    }
}

module screw_bosses(solid = true) {
    // Two diagonal corners, inset into the DRV chamber where the
    // board footprint leaves the corners clear.
    translate([WALL + BOSS_MARGIN, WALL + BOSS_MARGIN, FLOOR])
        screw_boss(solid);
    translate([WALL + CHAMBER_L - BOSS_MARGIN, WALL + CHAMBER_W - BOSS_MARGIN, FLOOR])
        screw_boss(solid);
}

module stitch_tab(mirror_y = false) {
    translate([POD_L/2 - TAB_L/2, mirror_y ? POD_W - 0.1 : -TAB_T + 0.1, FLOOR])
        cube([TAB_L, TAB_T, POD_H - FLOOR - LID_T]);
}

module stitch_tab_holes(mirror_y = false) {
    y = mirror_y ? POD_W + TAB_T/2 : -TAB_T/2;
    z = FLOOR + (POD_H - FLOOR - LID_T)/2;
    for (dx = [-TAB_L/4, TAB_L/4])
        translate([POD_L/2 + dx, y, z])
            rotate([90, 0, 0])
                cylinder(d = TAB_HOLE_D, h = TAB_T + 1, center = true);
}

module pod_body() {
    difference() {
        union() {
            cube([POD_L, POD_W, POD_H]);
            stitch_tab(false);
            stitch_tab(true);
        }
        drv_chamber_cavity();
        pocket_cavity();
        divider_wire_pass();
        lra_window();
        cable_holes();
        stitch_tab_holes(false);
        stitch_tab_holes(true);
        screw_bosses(false); // pilot holes cut from the solid boss below
    }
    // Bosses added back as solid posts standing in the chamber cavity
    difference() {
        screw_bosses(true);
        screw_bosses(false);
    }
}

module pod_lid() {
    difference() {
        cube([POD_L, POD_W, LID_T]);
        translate([WALL + BOSS_MARGIN, WALL + BOSS_MARGIN, -0.5])
            cylinder(d = BOSS_PILOT_D + 0.6, h = LID_T + 1); // clearance hole
        translate([WALL + CHAMBER_L - BOSS_MARGIN, WALL + CHAMBER_W - BOSS_MARGIN, -0.5])
            cylinder(d = BOSS_PILOT_D + 0.6, h = LID_T + 1);
        // Corner clipped off as an orientation cue -- the lid only
        // sits flush one way round, so you can't put it on backwards
        // without noticing.
        translate([POD_L - 4, POD_W - 4, -0.5])
            cube([4, 4, LID_T + 1]);
    }
}

// ============================================================
//  Layout for printing -- body and lid side by side
// ============================================================
pod_body();
translate([0, POD_W + 10, 0])
    pod_lid();
