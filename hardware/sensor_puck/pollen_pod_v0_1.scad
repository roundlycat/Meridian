//////////////////////////////////////////////////////////////
// Pollen Pod v0.1 — Variant Lid + Assembled View
//////////////////////////////////////////////////////////////

// --- Open-face lid variant ---
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

// --- Assembled view using the open-face lid ---
module assembled_pod() {
    pod_base();
    translate([0,0,pod_height/2]) lid_open_face();
}

// --- Render the assembled pod ---
assembled_pod();
