// ============================================================
//  Wrist-Puck Dual-Channel Haptic Node — Enclosure
//  Rev 1.1  |  May 2026  |  Sean (Whitehorse, YT)
//
//  76mm diameter. All component positions geometry-validated
//  by Python solver before this file was written.
//
//  RENDER control:
//    RENDER = "bottom"   -> bottom shell only (print this)
//    RENDER = "lid"      -> lid only (print this)
//    RENDER = "preview"  -> assembled view with coloured components
//    RENDER = "section"  -> Y cross-section for inspection
//
//  Print settings (Prusa MK3S):
//    PLA or PETG, 0.2mm layer height, 25% infill, no supports
//    Lid: can also use Form2 resin for better membrane finish
//
//  CLEARANCE note:
//    Default 0.3mm suits a well-calibrated Prusa.
//    Increase to 0.4mm if cavities are too tight on first print.
// ============================================================

RENDER    = "preview";   // "bottom" | "lid" | "preview" | "section"

// ── MAIN PARAMETERS ─────────────────────────────────────────
PUCK_D    = 76;
PUCK_H    = 24;
WALL      = 2.2;
FLOOR_T   = 2.0;
LID_T     = 1.8;
CLEARANCE = 0.3;
$fn       = 128;

// ── DERIVED ─────────────────────────────────────────────────
INNER_R   = PUCK_D/2 - WALL;       // 35.8 mm
INNER_H   = PUCK_H - FLOOR_T - LID_T;  // 20.2 mm

// ── SG51R SERVO ─────────────────────────────────────────────
// Rotated 90 deg: 22.4mm in X, 25mm in Y. Horn on +X side toward rail.
// Solver-validated position: max corner 35.7mm < 35.8mm inner_r
SERVO_CX  = -22;
SERVO_CY  =   0;
SERVO_W   = 22.4 + CLEARANCE;
SERVO_D   = 25.0 + CLEARANCE;
SERVO_H   = 12.0 + CLEARANCE;

// ── LINEAR RAIL SLOT ────────────────────────────────────────
// Runs along X axis (lateral = left/right on wrist)
RAIL_L    = 44;
RAIL_W    =  6.2;
RAIL_Z    = FLOOR_T + 8;    // near servo top, linkage arm connects here
RAIL_SLOT_H = 12;            // slot height (open to interior)

// ── LIPO BATTERY ────────────────────────────────────────────
// 35x25mm portrait (25mm wide, 35mm deep), front arc
// Solver-validated: max corner 33.1mm < 35.8mm
BATT_CX   =  2;
BATT_CY   = 12;
BATT_W    = 25.0 + CLEARANCE;
BATT_D    = 35.0 + CLEARANCE;
BATT_H    =  5.5;
BATT_LIP  =  1.0;   // retaining lip height above battery top

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

// ── PERFBOARD JUNCTION ───────────────────────────────────────
// Also above battery, above DRV layer
PFB_CX    = BATT_CX;
PFB_CY    = BATT_CY;
PFB_W     = 22.0 + CLEARANCE;
PFB_D     = 18.0 + CLEARANCE;
PFB_H     =  6.0;
PFB_Z     = FLOOR_T + BATT_H + DRV_H;

// ── LRA (10mm COIN LRA) ──────────────────────────────────────
// Floor pocket, skin-facing. Shares XY with battery but different Z.
// (Battery sits on floor surface; LRA is recessed INTO floor below)
// Using tighter 0.15mm clearance for press-fit to prevent rattling
LRA_CX    = -4;
LRA_CY    =  8;
LRA_DIAM  = 10.0 + 0.15; 
LRA_H     =  3.5;

// ── SNAP FIT ────────────────────────────────────────────────
SNAP_W    = 10;
SNAP_H    =  2.0;
SNAP_N    =  4;

// ── WRIST STRAP SLOTS ────────────────────────────────────────
// Through shell walls on +X and -X sides (perpendicular to rail)
STRAP_W   = 23;
STRAP_H   =  4.0;
STRAP_Z   = FLOOR_T + 5;

// ── LID FEATURES ────────────────────────────────────────────
LRA_WIN   = 12;    // LRA window diameter
LED_WIN   =  3.5;  // LED window diameter

// ── M2 STANDOFF POSTS ───────────────────────────────────────
POST_RADIUS = INNER_R - 5;
POST_OD     =  5.0;
POST_ID     =  2.2;
POST_H      =  3.0;


// ============================================================
//  MODULE: bottom_shell
// ============================================================
module bottom_shell() {
    difference() {
        union() {
            // Hollowed out main shell
            difference() {
                // Main cylinder
                cylinder(h = PUCK_H - LID_T, d = PUCK_D);
                // Interior void
                translate([0, 0, FLOOR_T])
                    cylinder(h = PUCK_H, d = INNER_R*2);
            }

            // Strap lug pads (+X and -X walls)
            for (s = [-1, 1])
                translate([s*(PUCK_D/2 - WALL/2), 0, STRAP_Z + STRAP_H/2])
                    cube([WALL*2, STRAP_W + WALL*2, STRAP_H + WALL*2], center=true);

            // --- RETAINING WALLS / MOUNTING BOSSES ---
            
            // Battery retaining lip
            translate([BATT_CX, BATT_CY, FLOOR_T + (BATT_H + BATT_LIP)/2])
                cube([BATT_W + WALL*2, BATT_D + WALL*2, BATT_H + BATT_LIP], center=true);
                
            // Servo retaining walls
            translate([SERVO_CX, SERVO_CY, FLOOR_T + SERVO_H/2])
                cube([SERVO_W + WALL*2, SERVO_D + WALL*2, SERVO_H], center=true);
                
            // XIAO retaining walls
            translate([XIAO_CX, XIAO_CY, FLOOR_T + XIAO_H/2])
                cube([XIAO_W + WALL*2, XIAO_D + WALL*2, XIAO_H], center=true);
                
            // Rail supports
            translate([0, 0, FLOOR_T + (RAIL_Z - FLOOR_T + RAIL_SLOT_H)/2])
                cube([RAIL_L + 4, RAIL_W + WALL*2, RAIL_Z - FLOOR_T + RAIL_SLOT_H], center=true);
                
            // LRA boss (since LRA is thicker than floor)
            translate([LRA_CX, LRA_CY, 0])
                cylinder(h = LRA_H + 1.0, d = LRA_DIAM + WALL*2);
        }

        // --- CUTOUTS ---

        // Snap-fit slots in rim (45-deg offset so they land between strap lugs)
        for (i = [0:SNAP_N-1])
            rotate([0, 0, i*(360/SNAP_N) + 45])
                translate([PUCK_D/2 - WALL/2, 0, PUCK_H - LID_T - SNAP_H - 0.5])
                    cube([WALL+0.5, SNAP_W, SNAP_H+0.2], center=true);

        // Strap slots through lug pads
        for (s = [-1, 1])
            translate([s*(PUCK_D/2), 0, STRAP_Z + STRAP_H/2])
                cube([WALL*4+2, STRAP_W, STRAP_H], center=true);

        // LRA floor pocket (recessed from below — vibration to skin)
        translate([LRA_CX, LRA_CY, -0.1])
            cylinder(h = LRA_H + 0.1, d = LRA_DIAM);

        // LRA wire channel toward battery/DRV zone
        hull() {
            translate([LRA_CX, LRA_CY, FLOOR_T])
                cylinder(h=1.5, d=3.5);
            translate([BATT_CX - BATT_W/2, BATT_CY - BATT_D/2 + 4, FLOOR_T])
                cylinder(h=1.5, d=3.5);
        }

        // Battery pocket (floor level + retaining lip)
        translate([BATT_CX, BATT_CY, FLOOR_T + (BATT_H + BATT_LIP)/2])
            cube([BATT_W, BATT_D, BATT_H + BATT_LIP + 0.1], center=true);

        // Servo cavity
        translate([SERVO_CX, SERVO_CY, FLOOR_T + SERVO_H/2])
            cube([SERVO_W, SERVO_D, SERVO_H + 0.1], center=true);

        // Servo horn clearance slot (+X of servo, connects to rail)
        translate([SERVO_CX + SERVO_W/2 + 2.5, SERVO_CY, FLOOR_T + SERVO_H/2 + 2])
            cube([7, SERVO_D, 5], center=true);

        // Rail slot (lateral, near servo top height)
        translate([0, 0, RAIL_Z + RAIL_SLOT_H/2])
            cube([RAIL_L, RAIL_W, RAIL_SLOT_H + 0.1], center=true);

        // XIAO pocket
        translate([XIAO_CX, XIAO_CY, FLOOR_T + XIAO_H/2])
            cube([XIAO_W, XIAO_D, XIAO_H + 0.1], center=true);

        // USB-C cutout through back wall (-Y direction)
        translate([XIAO_CX, -(PUCK_D/2 - 0.1), FLOOR_T + 2.5])
            cube([USBC_W, WALL+0.5, USBC_H], center=true);

        // DRV pocket (above battery)
        translate([DRV_CX, DRV_CY, DRV_Z + DRV_H/2])
            cube([DRV_W, DRV_D, DRV_H + 0.1], center=true);

        // Perfboard pocket (above DRV)
        translate([PFB_CX, PFB_CY, PFB_Z + PFB_H/2])
            cube([PFB_W, PFB_D, PFB_H + 0.1], center=true);

        // I2C wire channel: DRV/battery zone to XIAO
        hull() {
            translate([BATT_CX, BATT_CY - BATT_D/2, FLOOR_T + 1.5])
                cube([3, 1, 3], center=true);
            translate([XIAO_CX, XIAO_CY + XIAO_D/2, FLOOR_T + 1.5])
                cube([3, 1, 3], center=true);
        }

        // Servo PWM wire channel: servo to XIAO
        hull() {
            translate([SERVO_CX + SERVO_W/2, SERVO_CY - 4, FLOOR_T + 1.5])
                cube([1, 3, 3], center=true);
            translate([XIAO_CX, XIAO_CY + XIAO_D/2 + 2, FLOOR_T + 1.5])
                cube([1, 3, 3], center=true);
        }

        // M2 standoff holes
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, -0.1])
                    cylinder(h = FLOOR_T + POST_H + 1, d = POST_ID);
    }

    // M2 standoff posts (added back after difference)
    difference() {
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, FLOOR_T])
                    cylinder(h = POST_H, d = POST_OD);
        for (a = [0,90,180,270])
            rotate([0,0,a+45])
                translate([POST_RADIUS, 0, -0.1])
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
            for (i = [0:SNAP_N-1])
                rotate([0,0, i*(360/SNAP_N) + 45])
                    translate([PUCK_D/2 - WALL/2, 0, -SNAP_H])
                        cube([WALL - CLEARANCE*2, SNAP_W - CLEARANCE,
                              SNAP_H], center=true);
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

else if (RENDER == "preview") {
    bottom_shell();

    translate([0, 0, PUCK_H - LID_T])
        color("SteelBlue", 0.3)
            lid();

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

    // Perfboard (above DRV)
    color("OliveDrab", 0.75)
        translate([PFB_CX, PFB_CY, PFB_Z + PFB_H/2])
            cube([PFB_W-CLEARANCE, PFB_D-CLEARANCE, PFB_H], center=true);

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
