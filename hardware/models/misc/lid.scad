//////////////////////////////////////////////////////////////
// LD2410B Presence Node — LID v0.2
// Standalone file — print this separately from the body.
// "Hat" geometry: overhanging brim (rain drip edge) + tapered
// cap on top + a plug underneath that registers into the
// body's top opening.
//
// Dimensions below MUST match presence_node_v0.4.scad.
//////////////////////////////////////////////////////////////

// --- Match these to the body file ---
body_width    = 60;
body_depth    = 45;
wall          = 2.4;
screw_hole_d  = 1.6;
clearance     = 0.6;

// --- Lid-specific ---
brim_overhang = 3;    // how far the lid extends past the body on each side
brim_h        = 2;    // thickness of the overhanging brim
dome_h        = 5;    // height of the tapered cap above the brim
dome_inset    = 6;     // how much narrower the cap top is than the body, each side
step_h        = 3;    // depth of the plug that drops into the body opening
step_gap      = 0.6;  // total clearance so the plug slides in without jamming

module lid() {
    union() {
        difference() {
            union() {
                // --- Brim: wider than the body, this is the drip edge ---
                translate([0, 0, brim_h/2])
                    cube([body_width + 2*brim_overhang,
                          body_depth + 2*brim_overhang,
                          brim_h], center = true);

                // --- Cap: tapers up from the body footprint to a smaller top ---
                translate([0, 0, brim_h])
                    hull() {
                        cube([body_width, body_depth, 0.1], center = true);
                        translate([0, 0, dome_h])
                            cube([body_width - 2*dome_inset,
                                  body_depth - 2*dome_inset,
                                  0.1], center = true);
                    }
            }
            // --- Corner screw holes, full height, aligned to the body's bosses ---
            for (x = [-1, 1])
                for (y = [-1, 1])
                    translate([x * (body_width/2 - 6),
                               y * (body_depth/2 - 6),
                               (brim_h + dome_h)/2])
                        cylinder(h = brim_h + dome_h + 4,
                                 d = screw_hole_d + clearance,
                                 $fn = 32, center = true);
        }

        // --- Plug: drops down into the body's top opening for registration ---
        translate([0, 0, -step_h/2])
            cube([body_width - 2*wall - step_gap,
                  body_depth - 2*wall - step_gap,
                  step_h], center = true);
    }
}

// Render — without this line, nothing prints.
lid();
