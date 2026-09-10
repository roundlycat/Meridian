// ============================================================
// Meridian Hub Enclosure — battery + ESP32 + mux controller box
// Vanilla parametric OpenSCAD, no external libraries required.
// ============================================================
// Layout: battery bay and board bay sit side by side along the
// LENGTH (X) axis. case_l is a SUM of both bays' lengths.

$fn = 64; // arc smoothness — drop to 32 while iterating

// ---------------- PARAMS (measure & edit these) ----------------

wall = 2.0;
// Minimum clear space between any board/battery footprint edge
// and the case edge, so the corner heat-insert bosses never
// overlap a board or its standoffs. Increase if you still see
// interference for your real mux dimensions.
boss_margin = 12;

// --- Battery bay ---
batt_l = 42;
batt_w = 21;
batt_h = 7;
batt_clearance = 0.6;

// --- ESP32 board (confirmed) ---
esp_l = 22.61;
esp_w = 17;
esp_h = 5;

// --- Mux board (confirmed) ---
// Adafruit PCA9548A, measured 2026-08-24: 40.6 x 20.36mm.
// Replaces the earlier 55x36 SparkFun TCA9548A placeholder.
mux_l = 40.6;
mux_w = 20.36;
mux_h = 5;

board_gap = 4; // gap between ESP and mux within the shared bay

// Support posts — plain pillars, not fastener bosses, no screw
// hole. Rest boards on them and tack with hot glue or foam tape.
standoff_h = 5;
standoff_od = 4;
standoff_inset = 2;

// --- Ports (side wall cutouts) ---
// USB-C port, battery end — this is a CABLE PASS-THROUGH slot, not
// a precision board-USB cutout: the XIAO sits mid-case (sandwiched
// between the battery bay and the mux) with no wall directly at its
// own USB-C connector, so a cable comes in through this slot and
// plugs into the board's own port inside the shared open cavity.
// usbc_w/usbc_h are sized for a standard USB-C cable's connector
// shell — bump them if your cable is chunkier and reprint the base.
usbc_w = 12;  // was 9 in v2.5 — most cable shells run 10-12mm wide
usbc_h = 7;   // was 4 in v2.5 — too tight for almost any real cable
usbc_z = 6;   // still used by the power switch cutout below, unchanged
// Anchor is unchanged from v2.5 (wall+10, usbc_z) — that corner
// already had ~1.5mm clearance to the heat-insert boss, so the slot
// just grows outward (+Y, +Z) from the same corner rather than
// re-centering, which would eat that clearance. If you bump usbc_w/h
// much further, re-check clearance against the boss at y≈10.5.

switch_w = 8;
switch_h = 4;

// JST-SH connector housing is 2.9 x 7mm — slot, not round hole
cable_port_clearance = 0.6; // added to each dimension for fit
cable_port_w = 7 + cable_port_clearance;
cable_port_h = 2.9 + cable_port_clearance;
cable_port_count = 4;   // connectors per side — matches the mux's 4+4 channel headers
cable_port_margin = 6;  // inset from each end of the mux footprint to the first/last hole

// --- Heat-set insert bosses (M3 brass inserts) ---
insert_hole_d = 4.0;
insert_boss_od = 7.0;
insert_boss_h = 6.0;

// ---------------- DERIVED ----------------

board_bay_l = esp_l + board_gap + mux_l;
board_bay_w = max(esp_w, mux_w);

case_w = max(batt_w, board_bay_w) + 2*wall + 2*boss_margin;
case_l = wall + batt_l + wall + board_bay_l + wall + boss_margin;
case_h = max(batt_h, standoff_h + 12) + 2*wall;

echo(str("Case footprint: ", case_l, " x ", case_w, " x ", case_h, " mm"));

board_bay_x0 = wall + batt_l + wall; // where the board bay starts along X
batt_y0 = wall + (case_w - 2*wall - batt_w) / 2;
board_bay_y0 = wall + (case_w - 2*wall - board_bay_w) / 2;

esp_y0 = board_bay_y0 + (board_bay_w - esp_w) / 2;
mux_x0 = board_bay_x0 + esp_l + board_gap;
mux_y0 = board_bay_y0 + (board_bay_w - mux_w) / 2;

// ---------------- MODULES ----------------

module insert_boss(h = insert_boss_h) {
    difference() {
        cylinder(d = insert_boss_od, h = h);
        cylinder(d = insert_hole_d, h = h + 1);
    }
}

module board_standoffs(bl, bw, ox, oy) {
    for (x = [standoff_inset, bl - standoff_inset])
        for (y = [standoff_inset, bw - standoff_inset])
            translate([ox + x, oy + y, wall])
                cylinder(d = standoff_od, h = standoff_h);
}

module base() {
    difference() {
        cube([case_l, case_w, case_h]);

        translate([wall, wall, wall])
            cube([case_l - 2*wall, case_w - 2*wall, case_h]);

        // battery bay pocket
        translate([wall, batt_y0, wall])
            cube([batt_l + batt_clearance, batt_w + batt_clearance, batt_h + 1]);

        // USB-C port, battery end (pass-through slot — see note above)
        translate([-1, wall + 10, usbc_z])
            cube([wall + 2, usbc_w, usbc_h]);

        // power switch, board end
        translate([case_l - wall - 1, wall + 10, usbc_z])
            cube([wall + 2, switch_w, switch_h]);

        // Note: battery and board areas share one open cavity (no
        // internal divider), so the JST battery connector just
        // routes through open space — no pass-through hole needed.

        // cable exit ports — aligned to the mux footprint, rectangular
        // slots sized to the actual JST-SH connector housing, 4 through
        // the back wall and 4 through the front wall.
        cable_port_step = (mux_l - 2*cable_port_margin) / (cable_port_count - 1);
        for (i = [0 : cable_port_count - 1]) {
            cx = mux_x0 + cable_port_margin + i*cable_port_step;

            // back wall
            translate([cx - cable_port_w/2, case_w - wall - 1, case_h/2 - cable_port_h/2])
                cube([cable_port_w, wall + 2, cable_port_h]);

            // front wall
            translate([cx - cable_port_w/2, -1, case_h/2 - cable_port_h/2])
                cube([cable_port_w, wall + 2, cable_port_h]);
        }
    }

    // corner bosses for heat-set inserts
    for (x = [insert_boss_od, case_l - insert_boss_od])
        for (y = [insert_boss_od, case_w - insert_boss_od])
            translate([x, y, wall])
                insert_boss();

    // ESP32 standoffs
    board_standoffs(esp_l, esp_w, board_bay_x0, esp_y0);

    // mux standoffs
    board_standoffs(mux_l, mux_w, mux_x0, mux_y0);
}

module lid() {
    difference() {
        cube([case_l, case_w, wall]);
        for (x = [insert_boss_od, case_l - insert_boss_od])
            for (y = [insert_boss_od, case_w - insert_boss_od])
                translate([x, y, -1])
                    cylinder(d = insert_hole_d + 0.6, h = wall + 2);
    }
}

// ---------------- LAYOUT ----------------

base();
translate([0, case_w + 10, 0])
    lid();
