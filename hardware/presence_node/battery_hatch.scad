//////////////////////////////////////////////////////////////
// Battery Access Hatch — bottom panel, v0.1
// Standalone file — print separately from the body and lid.
//
// Covers the 60x38mm opening cut into the body's bottom wall
// (see battery_hatch_opening() in presence_node_v0.15.scad).
// Held with 4 screws into the body's pilot holes, sealed with a
// flat strip of foam tape against the bottom face — same simple
// approach as the lid, after the recessed-channel lesson a few
// versions back.
//
// Two things pass through THIS panel's footprint that have
// nothing to do with the battery, both checked for clearance:
//  - All four saddle-mount bolts (radius 18mm pattern) — the
//    panel is large enough that the entire bolt circle sits
//    inside it, so it needs its own clearance holes too.
//  - The cable gland, relocated here from the body — its old
//    spot at (10,-5) fell inside the new hatch opening, so it
//    couldn't stay on the fixed wall.
//////////////////////////////////////////////////////////////
include <params.scad>

panel_x = 68;
panel_y = 46;
panel_thick = 3;

// Hatch's own attachment screws — must match
// battery_hatch_screw_holes() in the body file exactly.
screw_x = [-31, 31];
screw_y = [-20, 20];

// Saddle bolt pattern — must match saddle_bolts() in the body.
saddle_r = bolt_circle_d / 2;

// Cable gland, relocated off the fixed wall onto this panel.
// Checked clear of every screw hole and saddle bolt position by
// at least 10mm center-to-center.
gland_x = 15;
gland_y = -15;
gland_d = 12.5;

module battery_hatch() {
    difference() {
        cube([panel_x, panel_y, panel_thick], center = true);

        for (x = screw_x)
            for (y = screw_y)
                translate([x, y, 0])
                    cylinder(h = panel_thick + 2,
                             d = screw_hole_d + clearance,
                             $fn = 32, center = true);

        for (i = [0:3]) {
            angle = i*90;
            translate([saddle_r*cos(angle), saddle_r*sin(angle), 0])
                cylinder(h = panel_thick + 2,
                         d = screw_hole_d + clearance,
                         $fn = 32, center = true);
        }

        translate([gland_x, gland_y, 0])
            cylinder(h = panel_thick + 2, d = gland_d, $fn = 32, center = true);
    }
}

// Render — without this line, nothing prints.
battery_hatch();
