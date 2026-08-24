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

// --- Mux board — confirm this is your real footprint, not a
// leftover placeholder. 55x36 is what's currently set.
mux_l = 55;
mux_w = 36;
mux_h = 5;

board_gap = 4; // gap between ESP and mux within the shared bay

// Support posts — plain pillars, not fastener bosses, no screw
// hole. Rest boards on them and tack with hot glue or foam tape.
standoff_h = 5;
standoff_od = 4;
standoff_inset = 2;

// --- Ports (side wall cutouts) ---
usbc_w = 9;
usbc_h = 4;
usbc_z = 6;

switch_w = 8;
switch_h = 4;

cable_port_d = 4;
cable_port_count = 5;
cable_port_spacing = 6;

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

        // USB-C port, battery end
        translate([-1, wall + 10, usbc_z])
            cube([wall + 2, usbc_w, usbc_h]);

        // power switch, board end
        translate([case_l - wall - 1, wall + 10, usbc_z])
            cube([wall + 2, switch_w, switch_h]);

        // Note: battery and board areas share one open cavity (no
        // internal divider), so the JST battery connector just
        // routes through open space — no pass-through hole needed.

        // cable exit ports, back wall
        for (i = [0 : cable_port_count - 1])
            translate([board_bay_x0 + 10 + i*cable_port_spacing, case_w - wall - 1, case_h/2])
                rotate([-90, 0, 0])
                    cylinder(d = cable_port_d, h = wall + 2);
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
