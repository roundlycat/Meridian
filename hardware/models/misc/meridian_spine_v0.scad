// ============================================================
//  Meridian Wrist Array — Flexible Spine Faceplate (draft v0)
//  First pass, for review only — Aug 2026
//
//  Purpose: replace per-pod sewing with one thin PETG strip that
//  fixes the relative spacing of all 5 LRA windows precisely
//  (repeatable across sessions -- matters for the 2AFC work),
//  while staying thin enough to flex around the wrist along its
//  length the way the fabric band does. Not a rigid plate -- the
//  field thickness is deliberately thin; only the ring around each
//  hole is built up, so the strip still folds around the wrist but
//  doesn't distort at the actuator positions.
//
//  HOLE_D pulled directly from your satellite_pod_v2_3.scad:
//    LRA_D (10) + LRA_SKIN_GAP (1.0) = 11mm
//  Same skin-window convention as your existing pods, not a new
//  number invented for this file.
//
//  PLACEHOLDER, same as your own file's convention -- I don't have
//  your actual pod-to-pod spacing (that's set by hand on the fabric
//  band right now, not parametrized anywhere in the repo I could
//  find). PITCH below is a guess. Measure your current band's
//  spacing and correct it before this means anything dimensionally.
// ============================================================

// ---- Real values, from satellite_pod_v2_3.scad ----
LRA_D        = 10;
LRA_SKIN_GAP = 1.0;
HOLE_D       = LRA_D + LRA_SKIN_GAP;   // 11mm — same skin window as your pods
LACE_HOLE_D  = 2.0;                    // matches your TAB_HOLE_D convention

// ---- New for this part — PLACEHOLDER, verify against your band ----
N_PODS    = 5;
PITCH     = 25;    // center-to-center spacing -- GUESS, measure your real layout
END_MARGIN = 10;   // extra length at each end for lacing to the band's closure

// ---- Thickness: thin field so it flexes, thicker ring only where
//      the hole would otherwise be a stress riser ----
FIELD_T = 1.0;   // flexes along its length at this gauge in PETG
BOSS_D  = 16;     // reinforcement ring OD around each hole
BOSS_T  = 2.0;    // local thickness at each pod position

STRIP_W = 18;     // width -- clears BOSS_D with margin for lacing holes

$fn = 64;

module rounded_strip(l, w, t, r=3) {
    hull() {
        for (x = [r, l - r])
            for (y = [r, w - r])
                translate([x, y, 0])
                    cylinder(r = r, h = t);
    }
}

module pod_boss(cx, cy) {
    translate([cx, cy, 0])
        cylinder(d = BOSS_D, h = BOSS_T);
}

module pod_hole(cx, cy) {
    translate([cx, cy, -1])
        cylinder(d = HOLE_D, h = BOSS_T + 2);
}

// ---- Lead exit notch -- side-exit lead needs clearance past the
//      hole edge or it pinches right at the thinnest cross-section
//      on the part. NOTCH_W borrowed from your divider CONN_W (3.20)
//      + CONN_CLR_W (0.7) = 3.9, rounded to 4 -- that was measured
//      for the DRV-to-LRA connector inside the pocket, NOT verified
//      against what's actually at this specific lead exit. Treat as
//      a placeholder same as PITCH; dry-fit before trusting it.
//      Reaches 1mm past the boss OD so the lead clears the printed
//      edge entirely rather than just clearing the hole itself.
NOTCH_W    = 4.0;
NOTCH_ANGLE_DEG = 90;   // 90 = toward the near edge (lace_y_top side); rotate per pod if lead direction varies

module pod_notch(cx, cy, angle_deg = NOTCH_ANGLE_DEG) {
    notch_reach = BOSS_D/2 + 1;
    translate([cx, cy, -1])
        rotate([0, 0, angle_deg])
            translate([0, -NOTCH_W/2, 0])
                cube([notch_reach, NOTCH_W, BOSS_T + 2]);
}

module lace_hole(cx, cy) {
    translate([cx, cy, -1])
        cylinder(d = LACE_HOLE_D, h = FIELD_T + 2);
}

STRIP_L = 2*END_MARGIN + BOSS_D + (N_PODS - 1) * PITCH;

module spine() {
    difference() {
        union() {
            rounded_strip(STRIP_L, STRIP_W, FIELD_T);
            for (i = [0 : N_PODS - 1])
                pod_boss(END_MARGIN + BOSS_D/2 + i*PITCH, STRIP_W/2);
        }
        // skin windows + lead exit notches (all assumed same rotation --
        // correct per-pod if lead direction actually varies pod to pod)
        for (i = [0 : N_PODS - 1]) {
            cx = END_MARGIN + BOSS_D/2 + i*PITCH;
            pod_hole(cx, STRIP_W/2);
            pod_notch(cx, STRIP_W/2);
        }

        // lacing holes: both ends, and between each pod along both edges
        lace_y_top = 3;
        lace_y_bot = STRIP_W - 3;
        lace_hole(END_MARGIN/2, lace_y_top);
        lace_hole(END_MARGIN/2, lace_y_bot);
        lace_hole(STRIP_L - END_MARGIN/2, lace_y_top);
        lace_hole(STRIP_L - END_MARGIN/2, lace_y_bot);
        for (i = [0 : N_PODS - 2]) {
            mx = END_MARGIN + BOSS_D/2 + i*PITCH + PITCH/2;
            lace_hole(mx, lace_y_top);
            lace_hole(mx, lace_y_bot);
        }
    }
}

spine();

echo("STRIP_L =", STRIP_L, " STRIP_W =", STRIP_W, " HOLE_D =", HOLE_D);
