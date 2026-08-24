// ============================================================
//  Wrist-Puck Keyhole Enclosure — First Draft
//  Rev 1.0  |  July 2026  |  Sean (Whitehorse, YT)
//
//  Replaces the circular puck (wrist_puck_enclosure_5_0.scad) with
//  a keyhole silhouette: a round chamber (servo + arm + LRA) joined
//  to an elongated rectangular body (battery/DRV/PowerBoost stack +
//  XIAO/IMU stack), sized against Sean's actual wrist (53mm wide x
//  35mm thick where the watch sits) rather than a fixed diameter
//  that didn't fit.
//
//  Component numbers below are Sean's own measurements from this
//  session, not the earlier file's assumed values -- several
//  changed (battery is 9mm thick now, not 6mm; servo+arm sweep is
//  28x30mm, not just the 21.5x25.1mm body; PowerBoost/XIAO/IMU all
//  slightly different from the rev5 assumptions). Reused without
//  change: WALL, FLOOR_T, LID_T, CLEARANCE, CAP_T, SNAP_* from
//  wrist_puck_enclosure_5_0.scad -- no reason to re-derive numbers
//  that were already validated there.
//
//  FIRST-PASS FLAGS -- explicit, not buried in comments:
//    - RECT_W (51mm) against Sean's 53mm wrist width leaves only
//      ~1mm clearance per side. That's tight. A real dry-fit is not
//      optional here the way it was borderline-optional elsewhere.
//    - Servo pocket fits chamber inner radius with ~1mm margin --
//      also tight. If the actual arm sweep needs clearance beyond
//      the bounding rectangle, this will need revisiting.
//    - LRA position is a placement guess, not derived from a known
//      arm-sweep direction -- flagged in-line below.
//    - No snap tabs, USB-C cutout, or standoff posts yet -- this
//      draft establishes the outer silhouette and the two internal
//      cavities are load-bearing; those details are next-pass.
//    - No lid/cap yet -- bottom shell only, to get the harder shape
//      right first.
// ============================================================

// ── SHARED CONSTANTS (unchanged from wrist_puck_enclosure_5_0) ──
WALL      = 2.2;
FLOOR_T   = 2.0;
LID_T     = 1.8;
CLEARANCE = 0.3;
CAP_T     = 2.0;

$fn = 80;

// ── OUTER SILHOUETTE ─────────────────────────────────────────
// X = along the forearm (0 = chamber center, increasing toward
//     the rectangular body / strap end)
// Y = across the wrist (must stay under ~53mm total)
// Z = vertical, floor at Z=0, same convention as the circular puck

CHAMBER_D = 48;   // round chamber outer diameter
CHAMBER_R = CHAMBER_D / 2;

RECT_L = 48;    // rectangular body outer length (along arm)
RECT_W = 51;    // rectangular body outer width (across arm) --
                 // SEE FIRST-PASS FLAG ABOVE: tight against 53mm wrist
RECT_X0 = 10;   // where the rectangle starts, overlapping into the
                 // chamber circle for a continuous keyhole silhouette

module outer_silhouette(h) {
    union() {
        cylinder(h = h, d = CHAMBER_D);
        translate([RECT_X0, -RECT_W/2, 0])
            cube([RECT_L, RECT_W, h]);
    }
}

// ── SERVO + ARM (chamber) ────────────────────────────────────
// Sean's measured footprint: 28 x 30mm to the end of the arm swing
// (bounding box, not the bare servo body) x 12mm height.
SERVO_W = 28.0 + CLEARANCE;
SERVO_D = 30.0 + CLEARANCE;
SERVO_H = 12.0 + CLEARANCE;
SERVO_CX = -2;   // roughly centered in the chamber; not yet
SERVO_CY = 4;    // finalized against actual arm swing direction

// ── LRA ───────────────────────────────────────────────────────
// FIRST-PASS PLACEMENT GUESS: tucked into the chamber's leftover
// crescent space, away from the servo footprint above. Needs
// verification once the servo's actual mounting orientation (which
// way the arm swings) is fixed -- it's placed clear of the servo's
// bounding box as currently assumed, not clear of the real swept
// arc if that's smaller than the bounding box suggests.
LRA_DIAM = 10.0 + CLEARANCE;
LRA_H    = 3.5;
LRA_CX   = 2;
LRA_CY   = -16;

// ── POWER STACK (battery / DRV / PowerBoost) ─────────────────
// Stacks in Z exactly like the circular puck did -- same X/Y
// center for all three, different heights. Footprint is the
// battery's own (the largest of the three).
BATT_W = 22.0 + CLEARANCE;   // Sean's measured 22mm (incl. shim/tape)
BATT_D = 41.0 + CLEARANCE;
BATT_H = 9.0;                 // measured, incl. shim/foam/kapton tape

DRV_W = 19.0 + CLEARANCE;
DRV_D = 25.0 + CLEARANCE;
DRV_H = 4.0;

PB_W = 22.0 + CLEARANCE;
PB_D = 36.0 + CLEARANCE;      // Sean's remeasure, was 37 in rev5
PB_H = 7.5;

PWR_CX = RECT_X0 + RECT_L/2;      // roughly centered along the rectangle
PWR_CY = -(RECT_W/2 - BATT_W/2 - 1.5);  // offset to one side, 1.5mm margin off the wall

// ── COMPUTE STACK (XIAO / IMU) ────────────────────────────────
// Also stacks in Z -- XIAO on the floor, IMU on top of it.
// IMU is the header-less 601N1 module: 20.6 x 17.8 x 3mm.
XIAO_W = 22.5 + CLEARANCE;
XIAO_D = 18.0 + CLEARANCE;
XIAO_H = 4.5;

IMU_W = 20.6 + CLEARANCE;
IMU_D = 17.8 + CLEARANCE;
IMU_H = 3.0;   // header-less, per Sean's measurement

CPU_CX = PWR_CX;                              // same X-center as power stack
// Y-offset must use XIAO_D (18.3mm, the across-wrist cube dimension
// below), not XIAO_W -- XIAO_W is the along-arm dimension here since
// its cube is [XIAO_W, XIAO_D, ...], long-side-on-X, same convention
// as the (now-fixed) power stack.
CPU_CY = (RECT_W/2 - XIAO_D/2 - 1.5);

// ── SHARED CAVITY MODULES ────────────────────────────────────
// Each takes cut_top_z (absolute Z height to cut up to) so both
// bottom_shell() (full height) and floorplan.scad's shallow test
// tray (via use<>, calling these same modules at a small cut_top_z)
// share the exact same XY footprint logic. No duplicated numbers,
// no variable-scoping fights -- learned the hard way that neither
// plain nor $-prefixed variable overrides survive OpenSCAD's
// duplicate-assignment resolution across an include<>, even with
// an is_undef() guard. Modules ARE importable via use<>, so this
// sidesteps the whole problem structurally instead.
module servo_cavity(cut_top_z) {
    translate([SERVO_CX, SERVO_CY, (FLOOR_T - 0.2 + cut_top_z)/2])
        cube([SERVO_W, SERVO_D, cut_top_z - (FLOOR_T - 0.2)], center = true);
}

module lra_cavity() {
    // opens through the BOTTOM, not the top -- correct as a short
    // cavity regardless of caller, no cut_top_z parameter needed
    translate([LRA_CX, LRA_CY, -0.2])
        cylinder(h = LRA_H + 0.2, d = LRA_DIAM);
}

module power_cavity(cut_top_z) {
    translate([PWR_CX, PWR_CY, (FLOOR_T - 0.2 + cut_top_z)/2])
        cube([BATT_D, BATT_W, cut_top_z - (FLOOR_T - 0.2)], center = true);
}

module compute_cavity(cut_top_z) {
    translate([CPU_CX, CPU_CY, (FLOOR_T - 0.2 + cut_top_z)/2])
        cube([XIAO_W, XIAO_D, cut_top_z - (FLOOR_T - 0.2)], center = true);
}

// ── BOTTOM SHELL ───────────────────────────────────────────────
module bottom_shell() {
    // Shell height must clear the TALLEST cavity, not just the
    // servo -- the power stack (battery+DRV+PowerBoost, 20.5mm) is
    // taller than the servo pocket (12.3mm). Missed this on the
    // first pass through this file; caught before rendering, not
    // after.
    power_stack_h = BATT_H + DRV_H + PB_H;
    tallest = max(SERVO_H, power_stack_h, XIAO_H + IMU_H);
    shell_h = FLOOR_T + tallest + 4;   // 4mm margin for lid/wall clearance

    difference() {
        outer_silhouette(shell_h);

        // All three cavities must reach the TOP of the shell (open,
        // not a sealed void) -- components need to go in from above,
        // and a lid (not yet built) will close over the top later.
        // The real bug on earlier passes: each cavity only extended to
        // its OWN component height + a small overshoot, which fell
        // well short of shell_h. Every cavity was therefore a fully
        // enclosed void, sealed on all sides -- no way to insert a
        // battery into a bubble with no opening. Fixed by overshooting
        // every cavity's top past shell_h, via cut_top_z = shell_h+1.
        servo_cavity(shell_h + 1);
        lra_cavity();
        power_cavity(shell_h + 1);
        compute_cavity(shell_h + 1);
    }
}

bottom_shell();
