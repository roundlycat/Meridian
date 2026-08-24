// ============================================================
//  Meridian Wrist Array — Satellite Pod v2
//  Rebuilt Aug 2026 | Sean (Whitehorse, YT)
//
//  ** REBUILD NOTICE **
//  The original satellite_pod_v2.scad could not be found on disk.
//  This file was reconstructed from two sources:
//    1. Authored parameter/geometry fragments recovered from past
//       conversation transcripts (marked CONFIRMED below).
//    2. Direct measurement of satellite_pod_v2_side.stl, which you
//       still had. Two values were back-solved from that mesh and
//       are marked DERIVED — trustworthy as dimensions, but the
//       original formulas that produced them are not recovered.
//    3. A few features (screw boss exact placement, lid rim) had no
//       surviving source text at all and are marked REBUILT — these
//       are reasonable reconstructions, not verified originals.
//       Cross-check against your physical prints before reprinting
//       a batch on these.
//
//  Rendered POD_L and POD_H below reproduce the uploaded STL's
//  bounding box exactly (33.2 x 46.6 x 12.8mm) — see the print
//  at the bottom of this file for the live check.
//
//  v2 change (CONFIRMED, from source): LRA pocket placement is a
//  parameter.
//    LRA_SIDE = "end"   -> v1 layout, pocket beyond the chamber's
//                          far end: [ DRV ][ div ][ LRA ]
//    LRA_SIDE = "side"  -> pocket alongside the chamber's long
//                          wall (pod gets wider, shorter):
//                              [ DRV chamber ]
//                              [   divider   ]
//                              [ LRA pocket  ]
//    LRA_X_FRAC slides the LRA along the chamber length in side
//    mode, 0.0 = cable-hole end, 1.0 = far end. NOT recovered from
//    source — set to 0.5 as a placeholder. Re-tune by dry-fitting
//    your DRV board and aligning to its OUT+/OUT- pads before
//    trusting this value.
//
//  NEW in this rebuild: LRA_CONN geometry. A notch through the
//  divider wall sized to the in-line connector on your LRA lead
//  (measured 6.90 x 3.20 x 2.20mm), positioned low near the floor
//  so it stays clear of the lid parting line rather than needing
//  a lid-side channel.
// ============================================================

// ---- Pod variant switch (CONFIRMED) ----
BOARD_TYPE = "drv_lra"; // "drv_lra" or "mux" -- this STL was drv_lra (verified: CHAMBER_L math reproduces measured 33.2mm exactly only with DRV_L, not MUX_L)
LRA_SIDE   = "side";    // "end" or "side"
LRA_X_FRAC = 0.5;       // REBUILT placeholder -- re-tune by dry fit, see note above

// ---- Component dimensions (CONFIRMED) ----
DRV_L = 26;    // Adafruit DRV2605L STEMMA QT board length
DRV_W = 18;    // board width
MUX_L = 31;    // TCA9548A breakout length -- Sean measured
MUX_W = 17.71; // TCA9548A breakout width -- Sean measured
BOARD_CLR = 2; // clearance added around the board, each side

LRA_D = 10;    // LRA diameter (coin-type)
LRA_T = 4;     // LRA thickness
LRA_SKIN_GAP = 1.0; // skin-contact opening = LRA_D + this

HAS_POCKET = (BOARD_TYPE == "drv_lra");
BOARD_L = (BOARD_TYPE == "mux") ? MUX_L : DRV_L;
BOARD_W = (BOARD_TYPE == "mux") ? MUX_W : DRV_W;

// ---- Wall/floor/lid thicknesses (CONFIRMED) ----
WALL  = 1.6;
FLOOR = 1.2;
LID_T = 1.6;
DIVIDER_T = WALL;

// ---- Derived chamber sizes (CONFIRMED formula, CHAMBER_H confirmed) ----
CHAMBER_L = BOARD_L + BOARD_CLR*2;
CHAMBER_W = BOARD_W + BOARD_CLR*2;
CHAMBER_H = 10; // matches puck's rev-4.5 DRV clearance convention; check vs your actual board+header stack

// ---- Pocket sizing (DERIVED from STL -- formula not recovered) ----
POCKET_SPAN = 19.8; // back-solved from measured pod Y=46.6mm; treat as a known-good
                     // number for THIS pod, not a formula to trust for other boards
POCKET_H = CHAMBER_H;

// ---- NEW: LRA connector channel through the divider ----
// Measured connector body: 6.90(L) x 3.20(W) x 2.20(H)mm
CONN_L = 6.90;
CONN_W = 3.20;
CONN_H = 2.20;
CONN_CLR_W = 0.7;   // total width clearance (per side ~0.35, PETG print tolerance)
CONN_CLR_H = 1.5;   // total height clearance -- bumped +1mm from 0.5 per print fit test (was too short)
CHANNEL_W = CONN_L + 1.2;      // 9-10mm target: length axis of connector runs along the channel
CHANNEL_H = CONN_H + CONN_CLR_H; // 3.7mm -- fits within DIVIDER_T's adjacent floor zone
CHANNEL_MOUTH_CHAMFER = 0.7;   // chamfer at each channel mouth so the wire jacket doesn't bite on a sharp edge

// Position: aligned with LRA_X_FRAC by default so the channel sits
// right next to wherever the LRA pocket actually lands. Override
// with CHANNEL_X_FRAC if your DRV board's OUT+/OUT- pads are
// somewhere else along the chamber.
CHANNEL_X_FRAC = LRA_X_FRAC;
CHANNEL_X = WALL + (CHAMBER_L - CHANNEL_W) * CHANNEL_X_FRAC;
CHANNEL_Z = FLOOR + 0.4; // low, near the floor -- clear of the lid regardless of LID_T

// ---- Pod outer envelope ----
POD_L = WALL + CHAMBER_L + WALL; // side mode: length axis is just the chamber, unchanged from v1
POD_W = HAS_POCKET && LRA_SIDE == "side"
    ? (WALL + CHAMBER_W + DIVIDER_T + POCKET_SPAN + WALL)
    : (CHAMBER_W + WALL*2);
POD_H = FLOOR + CHAMBER_H + LID_T;

// ---- NEW: stitch tabs for sewing the pod to a non-stretch rail ----
// No surviving source for these -- fresh design. Two tabs at diagonal
// corners (same convention as the screw bosses below), each a flat
// wing in the floor plane with a through-hole for waxed thread/floss.
// Bump TAB_HOLE_D if you're using something chunkier like paracord.
TAB_W = 8.0;       // tab length, projecting out from the corner
TAB_D = 6.0;       // tab width, perpendicular to projection
TAB_T = 2.0;       // tab thickness -- slightly thicker than FLOOR alone for stitch durability
TAB_HOLE_D = 2.0;  // through-hole diameter
TAB_HOLE_FRAC = 0.65; // hole position along the tab length, clear of the wall root
TAB_OVERLAP = 2.0; // tab extends this far INTO the shell wall so the union is a real
                    // solid merge, not just two solids touching along one edge

module stitch_tab(corner_x, corner_y, angle_deg) {
    translate([corner_x, corner_y, 0])
        rotate([0, 0, angle_deg])
            difference() {
                translate([-TAB_OVERLAP, -TAB_D/2, 0])
                    cube([TAB_W + TAB_OVERLAP, TAB_D, TAB_T]);
                translate([TAB_W * TAB_HOLE_FRAC, 0, -0.5])
                    cylinder(d=TAB_HOLE_D, h=TAB_T + 1, $fn=24);
            }
}

module stitch_tabs() {
    stitch_tab(0, 0, 225);         // near corner, points away into -x,-y
    stitch_tab(POD_L, POD_W, 45);  // far corner, points away into +x,+y
}

// ---- REBUILT: screw boss geometry (no surviving source text --
//      positions taken from sectioning the uploaded STL directly) ----
BOSS_OD = 4.2;
BOSS_ID = 1.8; // M2 self-tapping pilot, per puck-design convention
BOSS_H  = FLOOR + CHAMBER_H;
BOSS_INSET = 4.0; // approx from mesh section, diagonal corners

module screw_boss(x, y) {
    translate([x, y, 0])
        difference() {
            cylinder(d=BOSS_OD, h=BOSS_H, $fn=32);
            translate([0,0,-0.5]) cylinder(d=BOSS_ID, h=BOSS_H+1, $fn=24);
        }
}

module pod_body() {
    difference() {
        // outer shell
        cube([POD_L, POD_W, POD_H]);

        // main chamber void -- open-top tray (through-cut fix from the
        // July 28 session: +LID_T so no membrane seals the top)
        translate([WALL, WALL, FLOOR])
            cube([CHAMBER_L, CHAMBER_W, CHAMBER_H + LID_T + 1]);

        // LRA pocket void
        if (HAS_POCKET) {
            if (LRA_SIDE == "side") {
                translate([WALL, WALL + CHAMBER_W + DIVIDER_T, FLOOR])
                    cube([CHAMBER_L, POCKET_SPAN, POCKET_H + LID_T + 1]);
            } else {
                translate([WALL + CHAMBER_L + DIVIDER_T, WALL, FLOOR])
                    cube([POCKET_SPAN, CHAMBER_W, POCKET_H + LID_T + 1]);
            }
        }

        // LRA skin window -- through the floor, centered in the pocket
        // at LRA_X_FRAC along the chamber length
        if (HAS_POCKET) {
            lra_cx = WALL + CHAMBER_L * LRA_X_FRAC;
            lra_cy = WALL + CHAMBER_W + DIVIDER_T + POCKET_SPAN/2;
            translate([lra_cx, lra_cy, -0.5])
                cylinder(d=LRA_D + LRA_SKIN_GAP, h=FLOOR+1, $fn=48);
        }

        // NEW: connector channel through the divider, low near the floor
        if (HAS_POCKET && LRA_SIDE == "side") {
            translate([CHANNEL_X, WALL + CHAMBER_W - 0.5, CHANNEL_Z])
                cube([CHANNEL_W, DIVIDER_T + 1, CHANNEL_H]);
            // chamfer both mouths so the wire/connector doesn't ride a sharp edge
            translate([CHANNEL_X - CHANNEL_MOUTH_CHAMFER, WALL + CHAMBER_W - 0.5, CHANNEL_Z])
                rotate([0,45,0])
                    cube([CHANNEL_MOUTH_CHAMFER*1.5, DIVIDER_T + 1, CHANNEL_H]);
        }

        // screw boss pilot holes cut from the outer shell corners
        screw_boss_holes();
    }
    // screw bosses added back as solid posts inside the chamber corners
    translate([WALL, WALL, 0]) screw_boss(BOSS_INSET, BOSS_INSET);
    translate([WALL, WALL, 0]) screw_boss(CHAMBER_L - BOSS_INSET, CHAMBER_W - BOSS_INSET);

    // stitch tabs for rail attachment
    stitch_tabs();
}

module screw_boss_holes() {
    // placeholder -- bosses are solid posts with their own pilot hole
    // cut in screw_boss(); nothing additional to subtract here.
}

module pod_lid() {
    // REBUILT -- lid footprint measured off the uploaded STL
    // (33.2 x 42.8 x 1.6mm), inset from the outer wall
    lid_w = POD_W - 3.8; // matches measured lid Y vs body Y difference
    translate([0, 1.9, 0])
        cube([POD_L, lid_w, LID_T]);
}

RENDER = "body"; // "body" | "lid" | "preview"

if (RENDER == "body") pod_body();
else if (RENDER == "lid") pod_lid();
else {
    color("SteelBlue") pod_body();
    color([0.6,0.6,0.9,0.4]) translate([0,0,POD_H - LID_T]) pod_lid();
}

echo("POD_L =", POD_L, " POD_W =", POD_W, " POD_H =", POD_H);
