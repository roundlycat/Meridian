// ============================================================
//  Meridian Wrist Array — Satellite Pod v2
//  July 2026 | Sean (Whitehorse, YT)
//
//  v2 change: LRA pocket placement is now a parameter.
//    LRA_SIDE = "end"   -> original v1 layout, pocket beyond the
//                          chamber's far end:  [ DRV ][ div ][ LRA ]
//    LRA_SIDE = "side"  -> pocket alongside the chamber's long
//                          side (pod gets wider, shorter):
//                              [ DRV chamber ]
//                              [   divider   ]
//                              [ LRA pocket  ]
//                          Motivation: coin LRA leads are very
//                          short; side placement puts the LRA
//                          adjacent to the board instead of a
//                          full board-length away.
//    LRA_X_FRAC slides the LRA (and its divider wire pass) along
//    the chamber length in side mode, 0.0 = cable-hole end,
//    1.0 = far end. Park it next to the OUT+/OUT- pads of
//    whichever DRV board you're using. NOTE: keep it <= ~0.75
//    or the LRA counterbore starts crowding the far screw boss.
//
//  "end" mode is geometry-identical to v1 -- regression-check by
//  rendering both and diffing bounding boxes.
//
//  One pod = one DRV2605L board + one LRA. Five of these plus
//  the puck get sewn onto a flexible elastic/velcro band rather
//  than living in a rigid cross or star base.
//
//  LRA pocket has a through-hole in the floor so the LRA sits
//  directly against skin (same principle as the puck's rev 4.5
//  bare-window LRA opening: hole = LRA_D + 1.0mm). A small
//  pass-hole through the divider lets the two LRA leads reach
//  the DRV board's OUT+/OUT- pads without routing externally.
//
//  CABLE ROUTING -- left open on purpose:
//  Two small holes exit through the DRV chamber's outer end wall
//  (x = 0 face in both modes), toward whichever direction the
//  band runs. Use one for a single home-run cable to the puck
//  (star), or both for a daisy-chain bus in/out along the band.
//  Cap the unused hole with a dab of glue if you go star.
//
//  MOUNTING: flat stitch tabs on both Y faces, two 1.5mm holes
//  each, meant for hand-sewing to a strip of non-stretch webbing
//  or twill tape -- NOT sewn straight through stretchy elastic.
//  In side mode one tab lands on the pocket's outer wall; the
//  band still runs along X, same as the cable exit direction.
//
//  LID: one piece over the whole pod, two M2 self-tapping screw
//  bosses at diagonal corners. In side mode the far boss moves
//  to the pocket's far corner so the two bosses span the whole
//  (wider) lid diagonally.
//
//  Units: mm throughout. Print in PETG on the A1 Mini. First
//  print of the side variant is a fit test -- check the LRA
//  leads actually reach before committing to more.
// ============================================================

// ---- LRA placement (v2) ----
LRA_SIDE   = "side";   // "end" (v1 layout) | "side" (long-side pocket)
LRA_X_FRAC = 0.5;      // side mode only: LRA position along chamber, 0..~0.75

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

// POCKET_SPAN is the pocket's dimension perpendicular to the
// divider in both modes: X-extent in end mode, Y-extent in side
// mode. Same value as v1's POCKET_L.
POCKET_SPAN = LRA_D + 6;            // ~16mm, LRA + retention lip + wire slack
POCKET_H    = CHAMBER_H;            // same interior height, simpler lid

DIVIDER_T = WALL;

// ---- Pod outer dimensions (mode-dependent) ----
POD_L = (LRA_SIDE == "side")
        ? WALL + CHAMBER_L + WALL
        : WALL + CHAMBER_L + DIVIDER_T + POCKET_SPAN + WALL;
POD_W = (LRA_SIDE == "side")
        ? WALL + CHAMBER_W + DIVIDER_T + POCKET_SPAN + WALL
        : CHAMBER_W + WALL*2;
POD_H = FLOOR + CHAMBER_H + LID_T;

// ---- LRA center point (used by window + divider pass) ----
LRA_CX = (LRA_SIDE == "side")
         ? WALL + CHAMBER_L * LRA_X_FRAC
         : WALL + CHAMBER_L + DIVIDER_T + POCKET_SPAN/2;
LRA_CY = (LRA_SIDE == "side")
         ? WALL + CHAMBER_W + DIVIDER_T + POCKET_SPAN/2
         : WALL + CHAMBER_W/2;

// ---- Cable pass-through ----
CABLE_HOLE_D = 3.0;
CABLE_HOLE_SPACING = 6;

// ---- Screw bosses (M2 self-tapping) ----
BOSS_OD = 4.5;
BOSS_PILOT_D = 1.7;
BOSS_MARGIN = 3.5; // inset from each corner

// Boss XY positions, mode-dependent. End mode: both in the DRV
// chamber corners (v1 behavior). Side mode: near chamber corner
// + far pocket corner, spanning the wider lid diagonally.
BOSS_POSITIONS = (LRA_SIDE == "side")
    ? [ [WALL + BOSS_MARGIN,              WALL + BOSS_MARGIN],
        [WALL + CHAMBER_L - BOSS_MARGIN,  POD_W - WALL - BOSS_MARGIN] ]
    : [ [WALL + BOSS_MARGIN,              WALL + BOSS_MARGIN],
        [WALL + CHAMBER_L - BOSS_MARGIN,  WALL + CHAMBER_W - BOSS_MARGIN] ];

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
    if (LRA_SIDE == "side") {
        // Alongside the chamber: full chamber length in X, so wire
        // slack has somewhere to live wherever LRA_X_FRAC puts the LRA.
        translate([WALL, WALL + CHAMBER_W + DIVIDER_T, FLOOR])
            cube([CHAMBER_L, POCKET_SPAN, POCKET_H + 1]);
    } else {
        translate([WALL + CHAMBER_L + DIVIDER_T, WALL, FLOOR])
            cube([POCKET_SPAN, CHAMBER_W, POCKET_H + 1]);
    }
}

module divider_wire_pass() {
    // Small round pass-through for the two LRA leads, mid-height.
    // End mode: through the X-normal divider, centered in Y.
    // Side mode: through the Y-normal divider, aligned with the
    // LRA's X position so the leads take the shortest path.
    z = FLOOR + CHAMBER_H/2;
    if (LRA_SIDE == "side") {
        translate([LRA_CX, WALL + CHAMBER_W + DIVIDER_T/2, z])
            rotate([90, 0, 0])
                cylinder(d = 3.5, h = DIVIDER_T + 2, center = true);
    } else {
        translate([WALL + CHAMBER_L + DIVIDER_T/2, WALL + CHAMBER_W/2, z])
            rotate([0, 90, 0])
                cylinder(d = 3.5, h = DIVIDER_T + 2, center = true);
    }
}

module lra_window() {
    // Two-stage hole in the pocket floor: a wider counterbore from
    // inside the pocket for the LRA body to sit in, narrowing to
    // the skin-contact opening (LRA_D + LRA_SKIN_GAP) through the
    // outer floor surface. The step this creates is the retention
    // lip -- no separate part needed.

    // Counterbore (from inside, doesn't go all the way through)
    translate([LRA_CX, LRA_CY, FLOOR - 0.01])
        cylinder(d = LRA_D + 1.5, h = LRA_T + 0.5);

    // Through opening to skin
    translate([LRA_CX, LRA_CY, -0.5])
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
    for (p = BOSS_POSITIONS)
        translate([p[0], p[1], FLOOR])
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
        for (p = BOSS_POSITIONS)
            translate([p[0], p[1], -0.5])
                cylinder(d = BOSS_PILOT_D + 0.6, h = LID_T + 1); // clearance holes
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
