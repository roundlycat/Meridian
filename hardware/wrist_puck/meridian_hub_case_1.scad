// ============================================================
// Meridian Hub Enclosure — battery + ESP32 + mux controller box
// Vanilla parametric OpenSCAD, no external libraries required.
// ============================================================
// PARAMS block below is the only part you should need to edit.
// mux_l/mux_w/mux_h are still placeholders (common TCA9548A
// breakout footprint) — swap in real numbers once you've got
// calipers on your actual mux board.

$fn = 64; // arc smoothness — drop to 32 while iterating

// ---------------- PARAMS (measure & edit these) ----------------

wall = 2.0; // overall wall thickness

// --- Battery bay ---
batt_l = 42;
batt_w = 21;
batt_h = 7;
batt_clearance = 0.6; // per-side slop so the pack slides in

// --- ESP32 board (confirmed) ---
esp_l = 22.61;
esp_w = 17;
esp_h = 5;

// --- Mux board (PLACEHOLDER — measure your actual TCA9548A breakout) ---
mux_l = 25.4;
mux_w = 18;
mux_h = 5;

board_gap = 4; // gap between ESP and mux within the shared bay

// Support posts for both small boards. These are plain support
// pillars, not fastener bosses — no screw hole. If your boards
// don't have mounting holes, rest them on these and tack with a
// dab of hot glue or double-sided foam tape.
standoff_h = 5;
standoff_od = 4;
standoff_inset = 2; // inset from each board's corner

// --- Ports (side wall cutouts) ---
usbc_w = 9;
usbc_h = 4;
usbc_z = 6; // height of USB-C slot center off the floor

switch_w = 8;
switch_h = 4;

batt_conn_d = 4; // JST battery connector pass-through

cable_port_d = 4;      // one hole per satellite pod lead
cable_port_count = 5;
cable_port_spacing = 6;

// --- Heat-set insert bosses (M3 brass inserts) ---
insert_hole_d = 4.0;
insert_boss_od = 7.0;
insert_boss_h = 6.0;

// ---------------- DERIVED ----------------

board_bay_l = esp_l + board_gap + mux_l;
board_bay_w = max(esp_w, mux_w);

case_l = max(batt_l, board_bay_l) + 2*wall + 10;
case_w = batt_w + board_bay_w + 3*wall + 6;
case_h = max(batt_h, standoff_h + 12) + 2*wall;

echo(str("Case footprint: ", case_l, " x ", case_w, " x ", case_h, " mm"));

// ---------------- MODULES ----------------

module insert_boss(h = insert_boss_h) {
    difference() {
        cylinder(d = insert_boss_od, h = h);
        cylinder(d = insert_hole_d, h = h + 1);
    }
}

// Four support posts at the corners of a bl x bw footprint,
// inset by standoff_inset, placed at local origin (ox, oy).
module board_standoffs(bl, bw, ox, oy) {
    for (x = [standoff_inset, bl - standoff_inset])
        for (y = [standoff_inset, bw - standoff_inset])
            translate([ox + x, oy + y, wall])
                cylinder(d = standoff_od, h = standoff_h);
}

module base() {
    // Shell + all subtractive cuts happen first, as a single
    // difference(). Bosses and standoffs are unioned on AFTER,
    // so later cuts can never eat into them.
    difference() {
        cube([case_l, case_w, case_h]);

        // hollow interior
        translate([wall, wall, wall])
            cube([case_l - 2*wall, case_w - 2*wall, case_h]);

        // battery bay pocket
        translate([wall + 2, wall + 2, wall])
            cube([batt_l + batt_clearance, batt_w + batt_clearance, batt_h + 1]);

        // USB-C port, short wall
        translate([-1, wall + 10, usbc_z])
            cube([wall + 2, usbc_w, usbc_h]);

        // power switch, opposite short wall
        translate([case_l - wall - 1, wall + 10, usbc_z])
            cube([wall + 2, switch_w, switch_h]);

        // battery connector pass-through, into the divider between bays
        translate([wall + batt_l/2, wall + batt_w + wall/2, wall + 3])
            rotate([90, 0, 0])
                cylinder(d = batt_conn_d, h = wall + 2);

        // cable exit ports for satellite pod leads, back wall
        for (i = [0 : cable_port_count - 1])
            translate([wall + 10 + i*cable_port_spacing, case_w - wall - 1, case_h/2])
                rotate([-90, 0, 0])
                    cylinder(d = cable_port_d, h = wall + 2);
    }

    // corner bosses for heat-set inserts — added AFTER the hollow cut
    for (x = [insert_boss_od, case_l - insert_boss_od])
        for (y = [insert_boss_od, case_w - insert_boss_od])
            translate([x, y, wall])
                insert_boss();

    // ESP32 standoffs — also added after, in the board bay
    board_standoffs(esp_l, board_bay_w,
        wall + batt_l + wall,
        wall + (board_bay_w - esp_w)/2);

    // mux standoffs — offset past the ESP footprint plus the gap
    board_standoffs(mux_l, board_bay_w,
        wall + batt_l + wall + esp_l + board_gap,
        wall + (board_bay_w - mux_w)/2);
}

module lid() {
    difference() {
        cube([case_l, case_w, wall]);
        for (x = [insert_boss_od, case_l - insert_boss_od])
            for (y = [insert_boss_od, case_w - insert_boss_od])
                translate([x, y, -1])
                    cylinder(d = insert_hole_d + 0.6, h = wall + 2); // M3 screw clearance
    }
}

// ---------------- LAYOUT ----------------

base();
translate([0, case_w + 10, 0])
    lid();
