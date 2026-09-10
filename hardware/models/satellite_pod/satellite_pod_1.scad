// ===================================================================
// Meridian wrist array — satellite pod, single-chamber redesign
// Board: Adafruit DRV2605L (STEMMA QT breakout), ~25.8 x 17.8mm
// Motor: Vybronics VG1030001XH, measured 9.93mm dia x 3.30mm (bare can)
// ===================================================================
// Change a number in this block rather than editing geometry below.
// Anything marked CONFIRM is a placeholder against your real board;
// the rest come from your caliper measurements / earlier decisions.

// --- Board ---
board_l        = 25.8;   // long axis (STEMMA connector direction)
board_w        = 17.8;
board_t        = 1.6;    // typical PCB thickness — CONFIRM
hole_inset     = 2.5;    // mounting hole center, inset from each board edge — CONFIRM
standoff_h     = 3.5;    // clearance under board for solder joints + STEMMA connector
standoff_od    = 3.4;    // standoff post diameter
screw_pilot_d  = 1.8;    // pilot hole, self-tapping M2

// --- Case shell ---
wall_t         = 1.6;
floor_t        = 1.2;    // general chamber floor, under the board area
margin         = 3.0;    // board edge to inner wall
lid_lip_h      = 2.0;    // step the lid seats into

// --- Motor pocket (from your measurements) ---
motor_d_meas   = 9.93;
motor_t_meas   = 3.30;
bore_clear     = 0.17;   // diametral clearance — tune from your test coupon
bore_d         = motor_d_meas + bore_clear;
pocket_depth   = motor_t_meas + 0.10;    // slight axial clearance
skin_floor_t   = 0.90;   // thin floor left under the motor: the skin coupling layer
boss_d         = bore_d + 2*wall_t;      // material ring around the bore
boss_h         = pocket_depth + skin_floor_t;
boss_drop      = boss_h - floor_t;       // how far the boss hangs below the general floor

// Pocket position, relative to chamber center — nudge to sit under
// wherever your OUT+/OUT- pads land. Keep it clear of both the standoffs
// AND the outer wall: distance from (motor_x,motor_y) to any standoff
// center must exceed standoff_od/2 + boss_d/2, and |motor_x|+boss_d/2 /
// |motor_y|+boss_d/2 must stay inside outer_l/2 / outer_w/2 minus wall_t.
// Centered clears both by a comfortable margin — move it once you know
// your board's actual pad layout.
motor_x        = 0;
motor_y        = 0;

// --- Derived chamber ---
chamber_l = board_l + 2*margin;
chamber_w = board_w + 2*margin;
chamber_h = standoff_h + board_t + 3;   // headroom above board for wire dressing

outer_l = chamber_l + 2*wall_t;
outer_w = chamber_w + 2*wall_t;

// --- Sewing tabs (for mounting to the fabric wrist band) ---
add_sew_tabs   = true;
tab_w          = 5.0;    // tab width
tab_len        = 6.0;    // how far it extends past the corner
tab_t          = 1.6;    // tab thickness — thin enough to stay flexible against fabric
tab_hole_d     = 1.8;    // stitch hole diameter, room for doubled thread
tab_hole_pos   = 0.65;   // hole center, as a fraction along tab_len

$fn = 48;

module standoff(x, y) {
    // small -0.2 overlap into the floor below so this fuses into one solid
    // instead of just touching it (touching-but-not-overlapping geometry
    // slices fine most of the time, but it's a common source of hairline
    // non-manifold errors — cheap to avoid)
    translate([x, y, -0.2])
        difference() {
            cylinder(d=standoff_od, h=standoff_h + 0.2);
            translate([0, 0, 0.1])
                cylinder(d=screw_pilot_d, h=standoff_h + 0.2);
        }
}

module standoffs() {
    translate([0, 0, floor_t]) {
        standoff( board_l/2 - hole_inset,   board_w/2 - hole_inset);
        standoff(-(board_l/2 - hole_inset),  board_w/2 - hole_inset);
        standoff( board_l/2 - hole_inset,  -(board_w/2 - hole_inset));
        standoff(-(board_l/2 - hole_inset), -(board_w/2 - hole_inset));
    }
}

module pod_bottom() {
    difference() {
        union() {
            // outer shell: floor + walls
            translate([-outer_l/2, -outer_w/2, 0])
                cube([outer_l, outer_w, floor_t + chamber_h]);

            // motor boss: extra material dropped below the general floor,
            // only under the motor footprint — gives room for the pocket
            // without thickening the whole case, and doubles as the raised
            // skin-contact point right where the actuator is
            translate([motor_x, motor_y, -boss_drop])
                cylinder(d=boss_d, h=boss_drop);
        }

        // hollow the chamber interior, leaving walls + floor
        translate([-chamber_l/2, -chamber_w/2, floor_t])
            cube([chamber_l, chamber_w, chamber_h + 1]);

        // lid seating lip
        translate([-chamber_l/2 - wall_t/2, -chamber_w/2 - wall_t/2, floor_t + chamber_h - lid_lip_h])
            cube([chamber_l + wall_t, chamber_w + wall_t, lid_lip_h + 1]);

        // motor pocket: blind hole cut down from the chamber floor's top
        // face, stopping short of the outer skin-facing surface. It opens
        // straight into the same chamber the board sits in, so the leads
        // just run free from the pocket to the board — no separate wire
        // channel needed now that there's only one chamber.
        translate([motor_x, motor_y, floor_t - pocket_depth])
            cylinder(d=bore_d, h=pocket_depth + 0.01);
    }

    standoffs();
}

module sew_tab() {
    // flat rounded tab extending in +X from its own origin, with one
    // stitch hole — placed and rotated per-corner by sew_tabs()
    difference() {
        hull() {
            cylinder(d=tab_w, h=tab_t);
            translate([tab_len, 0, 0])
                cylinder(d=tab_w, h=tab_t);
        }
        translate([tab_len * tab_hole_pos, 0, -0.1])
            cylinder(d=tab_hole_d, h=tab_t + 0.2);
    }
}

module sew_tabs() {
    // one tab per corner, angled outward on the diagonal so it clears
    // both adjoining walls; sits at the floor plane (Z=0..tab_t) so it's
    // a flat extension of the base rather than the taller wall
    corners = [[1, 1, 45], [-1, 1, 135], [-1, -1, 225], [1, -1, 315]];
    for (c = corners) {
        translate([c[0] * outer_l/2, c[1] * outer_w/2, 0])
            rotate([0, 0, c[2]])
                sew_tab();
    }
}

pod_bottom();
if (add_sew_tabs) sew_tabs();
