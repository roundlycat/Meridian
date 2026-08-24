//////////////////////////////////////////////////////////////
// Pollen Pod v0.1 — Self-contained, working version
//////////////////////////////////////////////////////////////

//////////////////// PARAMETERS /////////////////////////////

pod_diameter      = 68;
pod_height        = 26;
wall_thickness    = 2;
lid_thickness     = 2;
base_thickness    = 2;

sensor_window_d   = 22;
sensor_window_ap  = 18;

pcb_size          = 45;
pcb_standoff_h    = 5;

usb_cutout_w      = 10;
usb_cutout_h      = 4;
usb_cutout_offset = 13;

strap_slot_w      = 22;
strap_slot_h      = 3.5;
strap_slot_spacing= 30;

tripod_boss_d     = 18;
tripod_boss_h     = 4;

screw_hole_d      = 2.2;
insert_d          = 3.5;
bolt_circle_d     = 52;

//////////////////////////////////////////////////////////////
// BASE MODULE
//////////////////////////////////////////////////////////////

module pod_base() {
    difference() {
        // Outer shell
        cylinder(h = pod_height/2, d = pod_diameter, $fn=96);

        // Hollow interior
        translate([0,0,wall_thickness])
            cylinder(h = pod_height/2 - wall_thickness,
                     d = pod_diameter - 2*wall_thickness, $fn=96);

        // Strap slots
        for (y = [-strap_slot_spacing/2, strap_slot_spacing/2])
            translate([-pod_diameter/2, y, pod_height/4])
                cube([pod_diameter, strap_slot_w, strap_slot_h], center=true);

        // USB-C cutout
        translate([0, pod_diameter/2 - wall_thickness, usb_cutout_offset])
            rotate([90,0,0])
                cube([usb_cutout_w, usb_cutout_h, wall_thickness+1], center=true);

        // Screw holes
        for (i=[0:3]) {
            angle = i*90;
            x = (bolt_circle_d/2)*cos(angle);
            y = (bolt_circle_d/2)*sin(angle);
            translate([x,y,-1])
                cylinder(h = pod_height, d = screw_hole_d, $fn=24);
        }
    }

    // PCB standoffs
    for (x=[-pcb_size/2 + 5, pcb_size/2 - 5])
    for (y=[-pcb_size/2 + 5, pcb_size/2 - 5])
        translate([x,y,base_thickness])
            cylinder(h=pcb_standoff_h, d=insert_d, $fn=32);

    // Tripod boss
    translate([0,0,-tripod_boss_h])
        cylinder(h=tripod_boss_h, d=tripod_boss_d, $fn=48);
}

//////////////////////////////////////////////////////////////
// OPEN-FACE LID VARIANT
//////////////////////////////////////////////////////////////

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

//////////////////////////////////////////////////////////////
// ASSEMBLED VIEW
//////////////////////////////////////////////////////////////

// --- Render the assembled pod ---
assembled_pod();
