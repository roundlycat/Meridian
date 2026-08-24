//////////////////////////////////////////////////////////////
// LD2410B Presence Node — LID v0.4
// Standalone file — print this separately from the body.
//
// Fixes the floating-cantilever warning from v0.3: the plug
// (54.6 x 39.6) used to jump straight to the brim (66 x 51) in
// one step — a 5.7mm unsupported overhang. Now there's a
// sloped taper between them, tall enough to print without
// support. Lid is ~7mm taller overall as a result.
//
// Dimensions come from params.scad — keep all three files
// (params.scad, presence_node_v0.5.scad, lid.scad) together.
//////////////////////////////////////////////////////////////
include <params.scad>

// --- Lid-specific ---
brim_overhang = 3;    // how far the brim extends past the body, each side
taper_h       = 7;    // height of the ramp from plug width up to brim width
                       // (>= the overhang distance, for a printable slope)
brim_h        = 2;    // thickness of the flat brim ledge
dome_h        = 5;    // height of the tapered cap above the brim
dome_inset    = 4;    // how much narrower the cap top is, each side
                       // (kept small so screw holes stay inside material
                       // at the very top — see lid() comments below)
step_h        = 3;    // depth of the plug that drops into the body opening
step_gap      = 0.6;  // clearance so the plug slides in without jamming

module lid() {
    plug_w = body_width - 2*wall - step_gap;
    plug_d = body_depth - 2*wall - step_gap;
    brim_w = body_width + 2*brim_overhang;
    brim_d = body_depth + 2*brim_overhang;

    union() {
        // --- Plug: straight-walled, drops into the body opening ---
        // Left solid (not holed) — screws don't need to reach down here,
        // they thread into the body's bosses near the top edge.
        translate([0, 0, -step_h/2])
            cube([plug_w, plug_d, step_h], center = true);

        // --- Everything from the top of the plug upward gets the screw holes ---
        difference() {
            union() {
                // Ramp: gradual taper from plug width up to brim width.
                // Height (taper_h) is sized so the ~5.7mm radial growth
                // happens over enough vertical distance to print without
                // support (roughly 40 deg from vertical here).
                hull() {
                    cube([plug_w, plug_d, 0.1], center = true);
                    translate([0, 0, taper_h])
                        cube([brim_w, brim_d, 0.1], center = true);
                }

                // Flat brim ledge at full width — this is the drip edge
                translate([0, 0, taper_h + brim_h/2])
                    cube([brim_w, brim_d, brim_h], center = true);

                // Cap: steps inward to the body footprint (safe, smaller
                // sitting on larger), then tapers further to a small top
                translate([0, 0, taper_h + brim_h])
                    hull() {
                        cube([body_width, body_depth, 0.1], center = true);
                        translate([0, 0, dome_h])
                            cube([body_width - 2*dome_inset,
                                  body_depth - 2*dome_inset,
                                  0.1], center = true);
                    }
            }
            // Corner screw holes, aligned to the body's lid_bosses()
            // (cx = body_width/2 - 10, cy = body_depth/2 - 5 — must
            // match the body file exactly or the screws won't land).
            // Run from just above the plug through the top of the cap.
            for (x = [-1, 1])
                for (y = [-1, 1])
                    translate([x * (body_width/2 - 10),
                               y * (body_depth/2 - 5),
                               (taper_h + brim_h + dome_h)/2])
                        cylinder(h = taper_h + brim_h + dome_h + 4,
                                 d = screw_hole_d + clearance,
                                 $fn = 32, center = true);
        }
    }
}

// Render — without this line, nothing prints.
lid();
