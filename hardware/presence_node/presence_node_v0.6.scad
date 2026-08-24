//////////////////////////////////////////////////////////////
// LD2410B + BME280 Presence Node Housing v0.6
// First outdoor node — PVC saddle mount
// Dimensions come from params.scad (keep both files together
// in the same folder).
//
// Fixes from v0.5:
//  - rain_hood was fully detached from the body (math error:
//    increased the forward offset without increasing depth to
//    match, so the whole slab cleared the wall). Now anchored
//    with a real 4mm overlap into the wall.
//  - lid_bosses sat ~0.1mm short of the interior wall face —
//    invisible in preview, read as floating by the slicer.
//    Repositioned to span fully through the wall thickness.
//////////////////////////////////////////////////////////////
include <params.scad>

// --- Main shell with sensor window ---
module presence_body() {
    difference() {
        cube([body_width, body_depth, body_height], center=true);
        translate([0, 0, wall])
            cube([body_width - 2*wall,
                  body_depth - 2*wall,
                  body_height - 2*wall], center=true);
        // Front sensor window
        translate([0, body_depth/2 + 0.1, body_height/6])
            rotate([90, 0, 0])
                cube([window_width, window_height, wall + 1], center=true);
    }
}

// --- Rain visor: anchored with a real overlap into the wall,
//     extends forward for the actual drip overhang ---
module rain_hood() {
    overlap_into_wall = 4;   // how far it reaches PAST the inner wall
                             // face, back into the interior — this is
                             // what guarantees contact, not just a gap
    overhang_forward  = 18;  // how far it sticks out past the outer
                              // wall face, for rain to actually clear

    wall_inner_y = body_depth/2 - wall;          // 20.1
    hood_rear_y  = wall_inner_y - overlap_into_wall;
    hood_front_y = body_depth/2 + overhang_forward;
    hood_depth   = hood_front_y - hood_rear_y;
    hood_center_y = (hood_front_y + hood_rear_y) / 2;

    translate([0, hood_center_y, body_height/6 + 9])
        rotate([-8, 0, 0])
            cube([body_width + 10, hood_depth, 3], center=true);
}

// --- LD2410B mounting shelf + side stops + rear stop ---
module ld2410b_mount() {
    shelf_z = body_height/6;
    translate([0, 0, shelf_z - ld_thick/2])
        cube([ld_len + 8, body_depth - 2*wall, 2], center=true);
    for (side = [-1, 1])
        translate([side*(ld_len/2 + 2), 0, shelf_z])
            cube([2, 10, ld_thick + 4], center=true);
    translate([0, -(body_depth/2 - wall - 4), shelf_z])
        cube([ld_len + 8, 3, ld_thick + 4], center=true);
}

// --- MCU plate ---
module mcu_plate() {
    plate_z = -3;
    translate([0, 0, plate_z])
        cube([body_width - 2*wall - 4,
              body_depth - 2*wall - 4,
              2], center=true);
}

// --- Battery bay: floor shelf + retaining rails ---
module battery_bay() {
    floor_z = -body_height/2 + wall + 1;
    translate([0, 0, floor_z])
        cube([bat_len + 4, bat_wid + 4, 2], center=true);
    for (s = [-1, 1])
        translate([s*(bat_len/2 + 1), 0, floor_z + 1 + bat_thick/2])
            cube([2, bat_wid + 4, bat_thick], center=true);
}

// --- Saddle bolt pattern (subtracted) ---
module saddle_bolts() {
    for (i = [0:3]) {
        angle = i*90;
        x = (bolt_circle_d/2)*cos(angle);
        y = (bolt_circle_d/2)*sin(angle);
        translate([x, y, -body_height/2])
            cylinder(h = body_height, d = screw_hole_d + clearance, $fn = 32);
    }
}

// --- Gasket channel for the lid seal foam tape (subtracted) ---
module gasket_channel() {
    translate([0, 0, body_height/2 - wall + 0.5])
        difference() {
            cube([body_width - 2*wall + 4,
                  body_depth - 2*wall + 4, 3], center=true);
            cube([body_width - 2*wall,
                  body_depth - 2*wall, 4], center=true);
        }
}

// --- Lid screw bosses — now spans fully through the Y wall ---
// Positioned against the front/back walls (not the tricky double-
// corner case) with the boss's outer edge flush with the outer
// wall face and its inner edge well into open interior space —
// guaranteed contact across the full 2.4mm wall thickness, with
// margin either side.
module lid_bosses() {
    boss_r = 5;
    cx = body_width/2 - 10;     // 20 — inboard of the side walls
    cy = body_depth/2 - boss_r; // 17.5 — outer edge flush with the
                                //  outer wall face; inner edge at
                                //  12.5, well past the inner wall
                                //  face (20.1) for solid overlap

    for (x = [-1, 1])
        for (y = [-1, 1])
            translate([x*cx, y*cy, body_height/2 - 6])
                difference() {
                    cylinder(h = 8, d = boss_r*2, $fn = 32);
                    cylinder(h = 9, d = screw_hole_d, $fn = 32);
                }
}

// --- Cable gland port, bottom face (subtracted) ---
module cable_gland_port() {
    translate([10, -5, -body_height/2])
        cylinder(h = wall + 1, d = 12.5, $fn = 32);
}

// --- BME280 ventilation louvres, left wall (subtracted) ---
module bme280_vents() {
    vent_w = 14;
    vent_h = 2.5;
    for (i = [0:3]) {
        z = -6 + i*7;
        translate([-body_width/2, 2, z])
            rotate([0, 90, -20])
                cube([vent_h, vent_w, wall + 1], center=true);
    }
}

// --- Drip lips above each vent slot — thickened for safer overlap ---
module bme280_vent_lips() {
    vent_w = 14;
    for (i = [0:3]) {
        z = -6 + i*7;
        translate([-body_width/2 - wall/2, 2, z + 3.5])
            cube([wall + 3, vent_w + 2, 1.5], center=true);
    }
}

// --- Assembly ---
module ld2410b_presence_housing() {
    difference() {
        union() {
            presence_body();
            rain_hood();
            ld2410b_mount();
            mcu_plate();
            battery_bay();
            lid_bosses();
            bme280_vent_lips();
        }
        saddle_bolts();
        gasket_channel();
        cable_gland_port();
        bme280_vents();
    }
}

// Render
ld2410b_presence_housing();
