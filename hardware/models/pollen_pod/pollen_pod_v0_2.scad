//////////////////////////////////////////////////////////////
// Pollen Pod v0.1‑G — Open‑Face Variant + Snap‑Fit Ready
// Author: sean + copilot
// Date: 2026‑05‑19
//////////////////////////////////////////////////////////////

//////////////////////////////
// PARAMETERS
//////////////////////////////

pod_diameter       = 60;      // mm — overall pod size
pod_height         = 40;      // mm — base height
lid_thickness      = 3;       // mm — lid wall
sensor_window_d    = 28;      // mm — grille opening
bolt_circle_d      = 48;      // mm — screw pattern diameter
screw_hole_d       = 3.2;     // mm — M3 clearance
snap_clearance     = 0.4;     // mm — radial clearance for PETG
snap_gap           = 2.2;     // mm — snap opening width
boss_height        = 6;       // mm — pod saddle height

//////////////////////////////
// MODULES
//////////////////////////////

// --- Pod Base ---
module pod_base() {
    difference() {
        cylinder(h = pod_height, d = pod_diameter, $fn=96);
        // Internal cavity
        translate([0,0,2])
            cylinder(h = pod_height-2, d = pod_diameter-4, $fn=96);
        // Screw holes
        for (i=[0:3]) {
            angle = i*90;
            x = (bolt_circle_d/2)*cos(angle);
            y = (bolt_circle_d/2)*sin(angle);
            translate([x,y,-1])
                cylinder(h = pod_height+2, d = screw_hole_d, $fn=24);
        }
    }
}

// --- Open‑Face Lid ---
module lid_open_face() {
    difference() {
        // Main lid disc
        cylinder(h = lid_thickness, d = pod_diameter, $fn=96);
        // Grille recess
        translate([0,0,lid_thickness/2])
            cylinder(h = lid_thickness, d = sensor_window_d, $fn=64);
        // Grille bars
        for (i = [-3:3])
            translate([i*3, 0, -1])
                cube([1.2, sensor_window_d, lid_thickness+2], center=true);
        // Screw holes
        for (i=[0:3]) {
            angle = i*90;
            x = (bolt_circle_d/2)*cos(angle);
            y = (bolt_circle_d/2)*sin(angle);
            translate([x,y,-1])
                cylinder(h = lid_thickness+2, d = screw_hole_d, $fn=24);
        }
    }
}

// --- Snap‑Fit Collar (for Garland Integration) ---
module snapfit_collar() {
    difference() {
        cylinder(d = pod_diameter + 6, h = boss_height, $fn=64);
        cylinder(d = pod_diameter + 6 - snap_clearance, h = boss_height + 0.2, $fn=64);
        // Snap gap
        rotate([0,0,0])
            cube([pod_diameter + 6, snap_gap, boss_height+0.2], center=true);
    }
}

// --- Assembled Pod ---
module assembled_pod() {
    snapfit_collar();
    translate([0,0,boss_height]) pod_base();
    translate([0,0,pod_height + boss_height]) lid_open_face();
}

//////////////////////////////
// RENDER
//////////////////////////////

assembled_pod();
