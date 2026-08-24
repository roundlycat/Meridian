// ============================================================
//  Wrist-Puck Dual-Channel Haptic Node — Enclosure
//  Rev 5.0  |  July 2026  |  Sean (Whitehorse, YT)
//
//  76mm diameter. All component positions geometry-validated
//  by Python solver before this file was written.
//
//  Rev 5.0 changes (from Rev 1.5) -- driven by the wrist-mount
//  piece work: the two independent, foam-backed, compound-curve
//  mount pieces now handle wrist conformance AND strap attachment
//  (captured M2 rod through each piece). The puck no longer needs
//  to do either job, so:
//    - Strap lug pads and through-wall strap slots REMOVED
//      entirely (were STRAP_W/STRAP_H/STRAP_Z + the ±X lug
//      geometry). Puck outer silhouette is a clean cylinder again.
//    - Interior dividing walls mostly REMOVED. Servo, XIAO, DRV,
//      and PowerBoost cavities now share one open bay instead of
//      separate pockets under a POCKET_H ceiling. The ONE thing
//      that keeps a real pocket is the battery: it's a soft pouch
//      cell that needs XY containment, so a thin wall survives
//      around its footprint up to BATT_RETAIN_H (top of the
//      battery, where DRV sits) -- open bay above that, same as
//      everywhere else. See BATT_WALL_MARGIN / BATT_RETAIN_H.
//    - PUCK_D left at 76mm. Nothing about this pass changes what
//      drove that number (component fit, solver-validated) --
//      shrinking it would be a separate exercise, re-run through
//      the solver, not a side effect of this cleanup.
//    - LRA bare-skin window (bottom_cap, LRA_DIAM+1.0 opening) is
//      untouched -- it already matched the same "direct contact,
//      no material in the way" principle the mount pieces use.
//
//  Rev 1.5 changes (from Rev 1.4):
//    - PowerBoost 500C retention: floor-rising M2 standoff posts
//      at PB's own mounting-hole pattern are not buildable — PB
//      shares its XY center with BATT/DRV (Z-stacked), and all 4
//      of PB's corner holes land inside the battery's own pocket
//      footprint, so a post there would pass straight through the
//      battery. Replaced with 4 capture nubs on the lid's underside
//      that close the air gap above PB and clamp it to DRV via the
//      snap-fit's own closing force when the shell closes — no
//      screws needed. See PB_NUB_* params. Pair with a thin foam
//      pad on each nub tip in practice, not a perfectly dialed
//      rigid dimension.
//
//  Rev 1.4 changes (from Rev 1.3):
//    - Snap channels: previous design cut slots recessed below
//      the shell top with 1.4mm of solid wall above them. Lid
//      tabs hit the shell rim and could not enter. Slots replaced
//      with full-height guide channels opening from above the
//      shell top (PUCK_H - LID_T + 0.3mm) down to below the
//      tab seating zone. Tabs now drop straight in.
//      Retention: inner locating rim press-fit (0.3mm clearance).
//      If grip is too loose, a thin foam tape strip on the rim
//      adds friction without a reprint.
//
//  RENDER control:
//    RENDER = "bottom"   -> bottom shell only (print this)
//    RENDER = "lid"      -> lid only (print this)
//    RENDER = "cap"      -> bottom cap only (print this)
//    RENDER = "preview"  -> assembled view with coloured components
//    RENDER = "section"  -> Y cross-section for inspection
//
//  Print settings (Bambu A1 Mini):
//    PETG, 0.2mm layer height, 25% infill, no supports, outer brim only
//
//  CLEARANCE note:
//    Default 0.3mm suits the Bambu A1 Mini.
//    Increase to 0.4mm if cavities are too tight on first print.
// ============================================================

RENDER    = "preview";   // "bottom" | "lid" | "preview" | "section"

// ── MAIN PARAMETERS ─────────────────────────────────────────
PUCK_D    = 76;
PUCK_H    = 30;
WALL      = 2.2;
FLOOR_T   = 2.0;
LID_T     = 1.8;
POCKET_H  = 8.0;   // height of component pocket zone from floor
                    // interior void starts at FLOOR_T+POCKET_H=10mm
                    // leaving physical walls between component wells
CLEARANCE = 0.3;
$fn       = 128;

// ── DERIVED ─────────────────────────────────────────────────
INNER_R   = PUCK_D/2 - WALL;       // 35.8 mm
INNER_H   = PUCK_H - FLOOR_T - LID_T;  // 26.2 mm

// ── SG51R SERVO ─────────────────────────────────────────────
// Actual dims: 21.5mm(L) × 11.7mm(W) × 25.1mm(H)
// Mounted on side, horn on +X toward rail
// Solver-validated position: max corner 35.7mm < 35.8mm inner_r
SERVO_CX  = -22;
SERVO_CY  =   0;
SERVO_W   = 21.5 + CLEARANCE;   // was 22.4 — corrected for SG51R body length
SERVO_D   = 25.1 + CLEARANCE;   // matches 25.1mm height ✓ (Rev 1.2 had 25.0 — 0.1mm short)
SERVO_H   = 12.0 + CLEARANCE;   // pocket depth, 11.7mm body width + clearance ✓

// ── LINEAR RAIL SLOT ────────────────────────────────────────
// Runs along X axis (lateral = left/right on wrist)
RAIL_L    = 44;
RAIL_W    =  6.2;
RAIL_Z    = FLOOR_T + 8;    // near servo top, linkage arm connects here
RAIL_SLOT_H = 12;            // slot height (open to interior)

// ── LIPO BATTERY ────────────────────────────────────────────
// HXJNLDC 602040: 20mm wide, 40mm long, 6mm thick
// Updated from 35x25mm design — solver re-checked, corners clear
BATT_CX   =  2;
BATT_CY   = 12;
BATT_W    = 25.0 + CLEARANCE;   // pocket wider than cell (20mm) for wire room
BATT_D    = 41.0 + CLEARANCE;   // was 35.0 — 602040 is 40mm long
BATT_H    =  6.0;               // actual measured 5.59mm + clearance
BATT_LIP  =  1.0;

// ── XIAO ESP32-C3 ────────────────────────────────────────────
// Back arc. Solver-validated: max corner 35.4mm < 35.8mm
XIAO_CX   = -2;
XIAO_CY   = -24;
XIAO_W    = 21.0 + CLEARANCE;
XIAO_D    = 17.8 + CLEARANCE;
XIAO_H    =  4.5;

// USB-C port faces -Y (back of wrist). Cutout through back shell wall.
USBC_W    =  9.5;
USBC_H    =  4.5;

// ── DRV2605L BREAKOUT ────────────────────────────────────────
// Mounted ON TOP of battery (Z-stacked). No floor space conflict.
// Z: FLOOR_T + BATT_H = 7.5mm from shell base
DRV_CX    = BATT_CX;
DRV_CY    = BATT_CY;
DRV_W     = 20.0 + CLEARANCE;
DRV_D     = 25.0 + CLEARANCE;
DRV_H     =  4.0;
DRV_Z     = FLOOR_T + BATT_H;

// ── POWERBOOST 500C ──────────────────────────────────────────
// Adafruit ID 1944 | PCB: 22mm × 37mm, height w/ components: 7mm
// Rev A power arch — replaces PAM2401 + perfboard junction
// Orientation: long axis (37mm) along Y
// Note: Micro-USB charge port faces +Y wall; v1 charges lid-off
PB_CX  = BATT_CX;
PB_CY  = BATT_CY;
PB_W   = 22.0 + CLEARANCE;          // 22.3mm (X)
PB_D   = 37.0 + CLEARANCE;          // 37.3mm (Y)
PB_H   =  7.5;                       // 7mm board + 0.5mm clearance
PB_Z   = FLOOR_T + BATT_H + DRV_H;  // 11.5mm — sits above DRV

// PB CAPTURE NUBS — why no floor-rising M2 posts here:
// PB shares its XY center with BATT/DRV (Z-stacked), and PB's own
// corner mounting holes (per Adafruit forum: 0.05" hole radius,
// centers inset 0.1"/2.54mm from each board edge — VERIFY WITH
// CALIPERS against the actual board before trusting this) sit at
// dx=8.46mm, dy=15.96mm from board center. That's INSIDE the
// battery pocket's own footprint (BATT half-extents 12.65 x 20.65),
// so any post rising from the floor at those XY coords would have
// to pass straight through the battery. Not buildable as a
// standoff. Above POCKET_H (z=10) the area is already open
// interior void anyway — no nearby wall to hang a bracket from.
// Fix: small nubs on the LID's underside that close the air gap
// above PB and press it down against DRV when the shell snaps
// shut — clamped by the snap-fit's own closing force, no screws.
// Nudge target points ~2mm inward from the actual hole centers so
// the nub presses on solid board/copper, not through the open hole.
PB_BOARD_W   = 22.0;   // bare board (no clearance) — for hole math
PB_BOARD_D   = 37.0;
PB_HOLE_DX   = PB_BOARD_W/2 - 2.54 - 2;   // ≈6.46mm — nudged off hole center
PB_HOLE_DY   = PB_BOARD_D/2 - 2.54 - 2;   // ≈13.96mm
PB_NUB_D     = 3.0;
PB_NUB_PRELOAD = 0.3;  // light squeeze; pair with a thin foam pad on
                        // each nub tip rather than trusting this number
                        // to be perfect — forgives tolerance stack-up
PB_NUB_DROP  = (PUCK_H - LID_T) - (PB_Z + PB_H) - PB_NUB_PRELOAD;

// ── LRA (10mm COIN LRA) ──────────────────────────────────────
// Floor pocket, skin-facing. Shares XY with battery but different Z.
// (Battery sits on floor surface; LRA is recessed INTO floor below)
LRA_CX    = -4;
LRA_CY    =  8;
LRA_DIAM  = 10.0 + CLEARANCE;
LRA_H     =  3.5;

// ── SNAP FIT ────────────────────────────────────────────────
SNAP_W    = 10;
SNAP_H    =  2.0;
SNAP_N    =  4;

// ── WRIST STRAP SLOTS ────────────────────────────────────────
// REMOVED in Rev 5.0 -- the puck no longer carries strap tension.
// The two independent wrist-mount pieces (compound-curve, foam-
// backed, hull-decorated) now handle both wrist conformance AND
// strap attachment via a captured M2 rod. The puck goes back to
// being purely an electronics enclosure -- see the Rev 5.0 note
// at the top of this file.

// ── BATTERY POCKET WALL (new in Rev 5.0) ────────────────────
// With strap lugs gone, most of the interior can open into one
// bay (servo/XIAO/DRV/PowerBoost all share the void now -- see
// Rev 5.0 note). The battery is the one thing that still wants
// a real pocket: it's a soft pouch cell, not a rigid board, and
// needs XY containment so it can't migrate sideways under wrist
// motion even though DRV+PowerBoost constrain it in Z from above.
BATT_WALL_MARGIN = 1.5;   // wall thickness around the battery footprint
BATT_RETAIN_H    = BATT_H; // wall height -- up to where DRV sits on top;
                            // open bay above that, same as everywhere else

// ── LID FEATURES ────────────────────────────────────────────
LRA_WIN   = 12;    // LRA window diameter
LED_WIN   =  3.5;  // LED window diameter

// ── M2 STANDOFF POSTS ───────────────────────────────────────
POST_RADIUS = INNER_R - 5;
POST_OD     =  5.0;
POST_ID     =  1.8;   // was 2.2 — 1.8mm suits M2 self-tapping in PETG
POST_H      =  3.0;

// ── BOTTOM CAP ───────────────────────────────────────────────
// Thin disc screwed to M2 standoffs — seals component openings
// LRA opening for direct skin contact
// Use M2×8mm screws (2mm cap + 2mm floor + 3mm into post)
CAP_T       =  2.0;


// ============================================================
//  MODULE: bottom_shell
// ============================================================
module bottom_shell() {
    difference() {
        // Main cylinder -- strap lug pads removed in Rev 5.0,
        // straps now attach to the independent mount pieces
        cylinder(h = PUCK_H - LID_T, d = PUCK_D);

        // Interior void — Rev 5.0: opens from FLOOR_T (not
        // FLOOR_T+POCKET_H) so servo/XIAO/DRV/PowerBoost share one
        // open bay. The battery wall ring is protected from this
        // cut (subtracted out of the cutter itself, below), so it
        // survives as real material up to BATT_RETAIN_H even though
        // everything else opens all the way to the floor.
        difference() {
            translate([0, 0, FLOOR_T])
                cylinder(h = PUCK_H, d = INNER_R*2);

            // Protect the battery wall ring (footprint + margin) —
            // subtracting this FROM the void cutter means that
            // region is NOT cut here, i.e. it stays solid. The
            // actual battery cavity is still carved out separately
            // below (BATT_W x BATT_D, no margin), leaving just the
            // margin band as a real retaining wall.
            translate([BATT_CX, BATT_CY, FLOOR_T + BATT_RETAIN_H/2])
                cube([BATT_W + 2*BATT_WALL_MARGIN,
                      BATT_D + 2*BATT_WALL_MARGIN,
                      BATT_RETAIN_H], center=true);
        }

        // Snap guide channels: open from above shell top to below tab seating zone.
        // Previous design had slots recessed below the top with solid wall above —
        // tabs hit the shell rim and couldn't enter. Channels now run from
        // (PUCK_H - LID_T + 0.3mm) down to (snap seating bottom), so tabs
        // drop straight in. Inner locating rim provides retention.
        for (i = [0:SNAP_N-1])
            rotate([0, 0, i*(360/SNAP_N) + 45])
                translate([PUCK_D/2 - WALL - 0.25, -SNAP_W/2,
                           PUCK_H - LID_T - SNAP_H - 0.7])
                    cube([WALL + 0.5, SNAP_W, SNAP_H + LID_T + 1.2]);

        // LRA floor pocket (recessed from below — vibration to skin)
        translate([LRA_CX, LRA_CY, 0])
            cylinder(h = LRA_H, d = LRA_DIAM);

        // LRA wire channel toward battery/DRV zone
        hull() {
            translate([LRA_CX, LRA_CY, 0])
                cylinder(h=1.5, d=3.5);
            translate([BATT_CX - BATT_W/2, BATT_CY - BATT_D/2 + 4, 0])
                cylinder(h=1.5, d=3.5);
        }

        // Battery pocket — the actual cell cavity, carved out of the
        // wall ring protected above. Full height (past BATT_RETAIN_H)
        // so wires/DRV/PowerBoost stack through it same as before.
        translate([BATT_CX, BATT_CY, FLOOR_T + (POCKET_H + 1)/2])
            cube([BATT_W, BATT_D, POCKET_H + 1], center=true);

        // Servo cavity — starts at interior floor, rises up
        translate([SERVO_CX, SERVO_CY, FLOOR_T + SERVO_H/2])
            cube([SERVO_W, SERVO_D, SERVO_H], center=true);

        // Servo horn clearance slot (+X of servo, connects to rail)
        translate([SERVO_CX + SERVO_W/2 + 2.5, SERVO_CY,
                   FLOOR_T + SERVO_H/2 + 2])
            cube([7, SERVO_D, 5], center=true);

        // Rail slot (lateral, near servo top height)
        translate([0, 0, RAIL_Z + RAIL_SLOT_H/2])
            cube([RAIL_L, RAIL_W, RAIL_SLOT_H], center=true);

        // XIAO pocket — extends past POCKET_H ceiling, visible from interior
        translate([XIAO_CX, XIAO_CY, FLOOR_T + (POCKET_H + 1)/2])
            cube([XIAO_W, XIAO_D, POCKET_H + 1], center=true);

        // USB-C cutout through back wall (-Y direction)
        translate([XIAO_CX, -(PUCK_D/2 - 0.1), FLOOR_T + 2.5])
            cube([USBC_W, WALL+0.5, USBC_H], center=true);

        // DRV pocket (above battery)
        translate([DRV_CX, DRV_CY, DRV_Z])
            cube([DRV_W, DRV_D, DRV_H + 0.5], center=true);

        // PowerBoost 500C pocket (above DRV — Rev A power arch)
        // 22 × 37 × 7mm board; pocket starts at PB_Z, opens upward
        translate([PB_CX, PB_CY, PB_Z + PB_H/2])
            cube([PB_W, PB_D, PB_H], center=true);

        // I2C wire channel: DRV/battery zone to XIAO
        hull() {
            translate([BATT_CX, BATT_CY - BATT_D/2, FLOOR_T + 2])
                cube([3, 1, 3], center=true);
            translate([XIAO_CX, XIAO_CY + XIAO_D/2, FLOOR_T + 2])
                cube([3, 1, 3], center=true);
        }

        // Servo PWM wire channel: servo to XIAO
        hull() {
            translate([SERVO_CX + SERVO_W/2, SERVO_CY - 4, FLOOR_T + 2])
                cube([1, 3, 3], center=true);
            translate([XIAO_CX, XIAO_CY + XIAO_D/2 + 2, FLOOR_T + 2])
                cube([1, 3, 3], center=true);
        }

        // M2 standoff holes
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, 0])
                    cylinder(h = FLOOR_T + POST_H + 1, d = POST_ID);
    }

    // M2 standoff posts (added back after difference)
    // FIX: posts start 0.1mm into floor to ensure solid union (no coplanar face)
    difference() {
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, FLOOR_T - 0.1])
                    cylinder(h = POST_H + 0.1, d = POST_OD);
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, 0])
                    cylinder(h = FLOOR_T + POST_H + 1, d = POST_ID);
    }
}


// ============================================================
//  MODULE: lid
// ============================================================
module lid() {
    difference() {
        union() {
            cylinder(h = LID_T, d = PUCK_D);

            // Inner locating rim (drops into shell opening)
            translate([0, 0, -2.0])
                difference() {
                    cylinder(h=2.0, d=INNER_R*2 - CLEARANCE*2);
                    cylinder(h=2.1, d=INNER_R*2 - CLEARANCE*2 - WALL*2);
                }

            // Snap tabs (project downward, mate with shell slots)
            // FIX: raised so tabs overlap 0.2mm into lid body — eliminates floating region
            for (i = [0:SNAP_N-1])
                rotate([0,0, i*(360/SNAP_N) + 45])
                    translate([PUCK_D/2 - WALL/2, 0, -SNAP_H/2 + 0.1])
                        cube([WALL - CLEARANCE*2, SNAP_W - CLEARANCE,
                              SNAP_H + 0.2], center=true);

            // PowerBoost capture nubs — close the air gap above PB and
            // clamp it to DRV via the snap-fit's closing force. See
            // PB_NUB_* comments near the PowerBoost parameters for why
            // this replaces a floor-rising standoff post here.
            for (sx = [-1, 1])
                for (sy = [-1, 1])
                    translate([PB_CX + sx*PB_HOLE_DX, PB_CY + sy*PB_HOLE_DY,
                               -PB_NUB_DROP])
                        cylinder(h = PB_NUB_DROP, d = PB_NUB_D);
        }

        // LRA window (open hole — max tactile transmission)
        translate([LRA_CX, LRA_CY, -0.1])
            cylinder(h = LID_T+0.2, d = LRA_WIN);

        // LED window (XIAO status LED)
        translate([XIAO_CX, XIAO_CY + 6, -0.1])
            cylinder(h = LID_T+0.2, d = LED_WIN);
    }
}


// ============================================================
//  MODULE: bottom_cap
//  Thin disc sealing the underside. Screws to M2 standoffs.
//  Print flat on bed, no supports needed.
// ============================================================
module bottom_cap() {
    difference() {
        // Main disc — flush with shell outer diameter
        cylinder(h = CAP_T, d = PUCK_D);

        // M2 screw holes — 2.2mm clearance, matching standoff positions
        for (a = [0,90,180,270])
            rotate([0,0, a+45])
                translate([POST_RADIUS, 0, -0.1])
                    cylinder(h = CAP_T + 0.2, d = 2.2, $fn = 16);

        // LRA opening — direct skin contact for haptic transmission
        translate([LRA_CX, LRA_CY, -0.1])
            cylinder(h = CAP_T + 0.2, d = LRA_DIAM + 1.0);
    }
}


// ============================================================
//  RENDER DISPATCH
// ============================================================

if (RENDER == "bottom") {
    bottom_shell();
}

else if (RENDER == "lid") {
    translate([0, 0, LID_T + 2.0])
        rotate([180, 0, 0])
            lid();
}

else if (RENDER == "cap") {
    // Print flat — no rotation needed
    bottom_cap();
}

else if (RENDER == "preview") {
    bottom_shell();

    translate([0, 0, PUCK_H - LID_T])
        color("SteelBlue", 0.3)
            lid();

    // Bottom cap
    color("SteelBlue", 0.5)
        translate([0, 0, -CAP_T])
            bottom_cap();

    // Battery
    color("LimeGreen", 0.8)
        translate([BATT_CX, BATT_CY, FLOOR_T + BATT_H/2])
            cube([BATT_W-CLEARANCE, BATT_D-CLEARANCE, BATT_H], center=true);

    // Servo
    color("MediumSeaGreen", 0.8)
        translate([SERVO_CX, SERVO_CY, FLOOR_T + SERVO_H/2])
            cube([SERVO_W-CLEARANCE, SERVO_D-CLEARANCE, SERVO_H], center=true);

    // Rail
    color("CornflowerBlue", 0.5)
        translate([0, 0, RAIL_Z + 5])
            cube([RAIL_L, RAIL_W-CLEARANCE, 10], center=true);

    // Sliding mass
    color("DarkGray", 0.9)
        translate([0, 0, RAIL_Z + 4])
            cube([14, 5.8, 4], center=true);

    // XIAO
    color("MediumPurple", 0.85)
        translate([XIAO_CX, XIAO_CY, FLOOR_T + XIAO_H/2])
            cube([XIAO_W-CLEARANCE, XIAO_D-CLEARANCE, XIAO_H], center=true);

    // DRV (above battery)
    color("Orchid", 0.8)
        translate([DRV_CX, DRV_CY, DRV_Z + DRV_H/2])
            cube([DRV_W-CLEARANCE, DRV_D-CLEARANCE, DRV_H], center=true);

    // PowerBoost 500C (above DRV — Rev A power arch)
    color("DarkOrange", 0.85)
        translate([PB_CX, PB_CY, PB_Z + PB_H/2])
            cube([PB_W-CLEARANCE, PB_D-CLEARANCE, PB_H], center=true);

    // LRA
    color("Coral", 0.9)
        translate([LRA_CX, LRA_CY, LRA_H/2])
            cylinder(h=LRA_H, d=LRA_DIAM-CLEARANCE, center=true);
}

else if (RENDER == "section") {
    // Cross-section showing internal layout
    intersection() {
        union() {
            bottom_shell();
            translate([0, 0, PUCK_H - LID_T])
                lid();
        }
        // Keep +Y half
        translate([0, 50, PUCK_H/2])
            cube([PUCK_D+10, 100, PUCK_H+10], center=true);
    }
}
