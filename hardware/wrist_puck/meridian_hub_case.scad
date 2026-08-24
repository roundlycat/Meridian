// ============================================================
// Meridian Hub Enclosure — battery + mux/ESP32 controller box
// Vanilla parametric OpenSCAD, no external libraries required.
// ============================================================
// Everything below the PARAMS block derives from these numbers.
// The battery/board dimensions are placeholders — measure your
// actual pack and TCA9548A/ESP32 stack and edit before printing.

$fn = 64; // arc smoothness — drop to 32 while iterating, bump for final render

// ---------------- PARAMS (measure & edit these) ----------------

wall = 2.0; // overall wall thickness

// --- Battery bay ---
// Placeholder: typical 2000mAh 1S LiPo pouch. Measure yours.
batt_l = 60;
batt_w = 35;
batt_h = 8;
batt_clearance = 0.6; // per-side slop so the pack slides in

// --- Mux/ESP32 board mount ---
// Placeholder footprint. If mux and ESP32 are two separate boards,
// duplicate the standoff loop below and offset the second set.
board_l = 55;
board_w = 28;
board_standoff_h = 5;       // height of board above the floor
board_standoff_od = 6;      // standoff post diameter
board_mount_hole_inset = 3; // mounting hole inset from board corner

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
// Standard M3 insert wants a ~4.0-4.2mm pilot hole in a boss with
// at least ~1.2mm of wall around it. See the walkthrough for install.
insert_hole_d = 4.0;
insert_boss_od = 7.0;
insert_boss_h = 6.0; // >= insert length (usually 4-6mm) plus margin

// ---------------- DERIVED ----------------

case_l = max(batt_l, board_l) + 2*wall + 10;
case_w = batt_w + board_w + 3*wall + 6; // battery bay + board bay, side by side
case_h = max(batt_h, board_standoff_h + 12) + 2*wall;

echo(str("Case footprint: ", case_l, " x ", case_w, " x ", case_h, " mm"));

// ---------------- MODULES ----------------

module insert_boss(h = insert_boss_h) {
    difference() {
        cylinder(d = insert_boss_od, h = h);
        cylinder(d = insert_hole_d, h = h + 1);
    }
}

module base() {
    difference() {
        union() {
            cube([case_l, case_w, case_h]);

            // corner bosses for heat-set inserts
            for (x = [insert_boss_od, case_l - insert_boss_od])
                for (y = [insert_boss_od, case_w - insert_boss_od])
                    translate([x, y, wall])
                        insert_boss();
        }

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

    // board standoffs, in the second bay
    for (x = [board_mount_hole_inset, board_l - board_mount_hole_inset])
        for (y = [board_mount_hole_inset, board_w - board_mount_hole_inset])
            translate([wall + batt_l + wall + x, wall + y, wall])
                cylinder(d = board_standoff_od, h = board_standoff_h);
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
