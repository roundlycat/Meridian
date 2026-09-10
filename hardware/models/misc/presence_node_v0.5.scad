//////////////////////////////////////////////////////////////
// LD2410B + BME280 Presence Node Housing v0.5
// First outdoor node — PVC saddle mount
// Dimensions come from params.scad (keep both files together
// in the same folder).
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

// --- Rain visor: real overhang (18mm forward) + slight slope to drain ---
module rain_hood() {
    translate([0, body_depth/2 + 11, body_height/6 + 9])
        rotate([-8, 0, 0])
            cube([body_width + 10, 20, 3], center=true);
}

// --- LD2410B mounting shelf + side stops + REAR STOP (new) ---
module ld2410b_mount() {
    shelf_z = body_height/6;
    // Shelf spans full depth, touches both walls
    translate([0, 0, shelf_z - ld_thick/2])
        cube([ld_len + 8, body_depth - 2*wall, 2], center=true);
    // Side stops along the length
    for (side = [-1, 1])
        translate([side*(ld_len/2 + 2), 0, shelf_z])
            cube([2, 10, ld_thick + 4], center=true);
    // Rear stop — board butts against this, keeping it pressed
    // against the window instead of able to slide backward
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

// --- Battery bay: floor shelf + retaining rails (no nested cavity) ---
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

// --- Lid screw bosses at top corners (added; starter hole subtracted) ---
module lid_bosses() {
    for (x = [-1, 1])
        for (y = [-1, 1])
            translate([x*(body_width/2 - 6),
                       y*(body_depth/2 - 6),
                       body_height/2 - 6])
                difference() {
                    cylinder(h = 8, d = 7, $fn = 32);
                    cylinder(h = 9, d = screw_hole_d, $fn = 32);
                }
}

// --- Cable gland port, bottom face, offset toward the back (subtracted) ---
module cable_gland_port() {
    translate([10, -5, -body_height/2])
        cylinder(h = wall + 1, d = 12.5, $fn = 32);
}

// --- BME280 ventilation louvres, angled to drain, on the left wall (subtracted) ---
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

// --- Drip lips above each vent slot (added) ---
module bme280_vent_lips() {
    vent_w = 14;
    for (i = [0:3]) {
        z = -6 + i*7;
        translate([-body_width/2 - wall/2, 2, z + 3.5])
            cube([wall + 1.5, vent_w + 2, 1.5], center=true);
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
