// LD2410B + BME280 Presence Node Housing v0.15
// First outdoor node — PVC saddle mount
//
// Fix in v0.10, found via your photos of the failed print plus
// a connectivity checker (check_connectivity.py) rather than
// more hand arithmetic:
//
//  1. mcu_plate was the real bug — fully disconnected, touching
//     NOTHING. It was deliberately sized 4mm smaller than the
//     interior in both x and y, with no anchoring logic at all.
//     This is almost certainly the lattice-pattern floating block
//     in your photos. Fixed by extending it to overlap the
//     front/back walls by 0.6mm each side.
//  2. ld2410b_mount's shelf and battery_bay's rails were both
//     exact zero-gap touches rather than real overlap — the same
//     risky pattern as the lid_boss bug a few versions back.
//     Both now have genuine overlap margin instead of relying on
//     coincidence.
//
// The checker verified every additive feature in this file now
// connects to the shell (directly or transitively) with real
// overlap, not just a touch.
//
// Dimensions come from params.scad (keep both files together
// in the same folder).
//
// Fix in v0.8: removed the gasket_channel groove entirely — it
// left only ~0.4mm of wall remaining at that height (24.1-27.1
// in this file's coordinates), too thin to mesh reliably. That
// was the exact cause of the "empty layer between 51.6 and 54.8"
// error in Bambu Studio (54.8 - 27.5 = 27.3, 51.6 - 27.5 = 24.1 —
// matches the channel's band almost exactly). Use a flat strip
// of adhesive foam tape on the plain top rim instead.
//
// Carried from v0.6/v0.7:
//  - rain_hood was fully detached from the body (math error:
//    increased the forward offset without increasing depth to
//    match, so the whole slab cleared the wall). Now anchored
//    with a real 4mm overlap into the wall.
//  - lid_bosses sat ~0.1mm short of the interior wall face —
//    invisible in preview, read as floating by the slicer.
//    Repositioned to span fully through the wall thickness, and
//    moved below the (now-removed) channel's old z-band.
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

// --- Rain hood support wedge (replaces v0.11's gussets) ---
// The two ribs in v0.11 only held up the few mm directly above
// themselves — support generation is local, so the other ~75mm
// of hood width still needed just as much slicer support as
// before. This is the actual fix: a solid wedge spanning the
// FULL width, full thickness at the wall, tapering up to meet
// the hood's underside at the front. Every point across the
// width now has material ramping up beneath it — no overhang
// gap left anywhere for the slicer to fill with lattice.
//
// Window clearance: pushed the base lower (z=-6, vs the rib's
// z=-2) specifically to build in real margin here. The window
// cutout only exists in a thin Y-band right at the wall
// (y=20.9-24.3) — checked the wedge's steepest possible rise
// through that exact band (corner-to-corner, not just center-
// line) and it stays at z<-2 there, ~5mm clear of the window's
// bottom edge (2.67) rather than the ~1.5mm a naive estimate
// would have given. Learned that lesson the hard way a few
// versions back.
module rain_hood_support_wedge() {
    base_y = 21;
    base_z = -6;
    tip_y  = 38;
    tip_z  = 16;
    full_w = body_width + 10;  // matches the hood's width exactly

    hull() {
        translate([0, base_y, base_z])
            cube([full_w, 4, 4], center=true);
        translate([0, tip_y, tip_z])
            cube([full_w, 4, 6], center=true);
    }
}
// v0.13 fix: the old shelf was one solid slab, 43mm wide, full
// depth — sitting directly across the only path from the open
// top down to the battery bay below. Found the hard way: the
// battery couldn't get past it during assembly. The shelf was
// checked for connectivity (does it touch the walls) but never
// for buildability (can anything get past it) — same blind spot
// as the support-vs-connectivity mixup a few versions back, just
// in the assembly sequence instead of the slicer.
//
// Fix: two narrow rails near the side stops instead of one solid
// slab, leaving a 35mm-wide clear channel straight down the
// center — comfortably more than the battery's 34mm width. The
// rear stop is split the same way for the same reason.
module ld2410b_mount() {
    shelf_z = body_height/6;
    rail_x = [-19.5, 19.5];   // aligned with the side stops below
    rail_w = 4;

    for (rx = rail_x)
        translate([rx, 0, shelf_z - ld_thick/2])
            cube([rail_w, body_depth - 2*wall + 1.2, 2], center=true);

    for (side = [-1, 1])
        translate([side*(ld_len/2 + 2), 0, shelf_z])
            cube([2, 10, ld_thick + 4], center=true);

    for (side = [-1, 1])
        translate([side*19.5, -(body_depth/2 - wall - 4), shelf_z])
            cube([rail_w, 3, ld_thick + 4], center=true);
}

// --- MCU plate ---
// v0.10 fix: this plate touched NOTHING. It was sized 4mm
// smaller than the interior in BOTH x and y, fully centered,
// with no connection logic at all - confirmed by a connectivity
// checker (see check_connectivity.py) as the actual cause of the
// "printing in the air" failure. Now extended in y to genuinely
// overlap the front/back walls by 0.6mm each side, same approach
// as ld2410b_mount's shelf.
module mcu_plate() {
    plate_z = -3;
    translate([0, 0, plate_z])
        cube([body_width - 2*wall - 4,
              body_depth - 2*wall + 1.2,
              2], center=true);
}

// --- Battery bay: floor shelf + retaining rails ---
// v0.10 fix: the rails' bottom face exactly equaled the floor's
// top face (both at the same z) — another zero-gap touch. Pulled
// the rails down by 0.2mm (the "+1" became "+0.8") so they
// genuinely overlap the floor instead of just meeting it.
//
// v0.14 fix: the rail POSITION had the same disease as that
// joint did — bat_len/2+1 with a 2mm-wide rail works out to
// exactly 56mm of gap for a 56mm battery. Zero clearance, so the
// battery couldn't drop down between the rails at all — it was
// resting on top of their upper edges instead, ~10.8mm above the
// floor (rail height bat_thick=11mm minus the floor's ~0.2mm
// step), which matches what got measured on the real part almost
// exactly. Now built from explicit clearance + rail width
// variables instead of a bare "+1" so this can't silently
// regress to zero again.
module battery_bay() {
    floor_z = -body_height/2 + wall + 1;
    rail_width = 1.5;
    rail_clearance = 1.5;  // real gap between battery end and rail, each side
    rail_x = bat_len/2 + rail_clearance + rail_width/2;

    translate([0, 0, floor_z])
        cube([bat_len + 4, bat_wid + 4, 2], center=true);
    for (s = [-1, 1])
        translate([s*rail_x, 0, floor_z + 0.8 + bat_thick/2])
            cube([rail_width, bat_wid + 4, bat_thick], center=true);
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

// --- Gasket: REMOVED in v0.8. The recessed channel left only
// ~0.4mm of original wall remaining outside the groove — thinner
// than a nozzle line, which is exactly what caused the "empty
// layer between 51.6 and 54.8" error. Use a flat strip of
// adhesive foam tape on the plain top rim instead — compressed
// by the lid screws, it seals just as well without the risk.

// --- Lid screw bosses — spans fully through the Y wall, and
//     sits BELOW the gasket channel (24.1-27.1) so the channel
//     cut can't notch through the boss. Missing center=true was
//     also a bug — without it, OpenSCAD builds cylinders upward
//     from z=0, not symmetric around the translate point, so the
//     boss was 2mm taller than intended and poking past the rim.
module lid_bosses() {
    boss_r = 5;
    boss_h = 8;
    cx = body_width/2 - 10;     // 20 — inboard of the side walls
    cy = body_depth/2 - boss_r; // 17.5 — outer edge flush with the
                                //  outer wall face; inner edge at
                                //  12.5, well past the inner wall
                                //  face (20.1) for solid overlap
    boss_z = 18;                // top at 22 — 2.1mm clear of the
                                 //  gasket channel's bottom (24.1)

    for (x = [-1, 1])
        for (y = [-1, 1])
            translate([x*cx, y*cy, boss_z])
                difference() {
                    cylinder(h = boss_h, d = boss_r*2, $fn = 32, center = true);
                    cylinder(h = boss_h + 1, d = screw_hole_d, $fn = 32, center = true);
                }
}

// --- Cable gland REMOVED from here in v0.15 — its old position
// (10,-5) falls inside the new hatch opening below, so it's been
// relocated onto the hatch panel itself instead (see
// battery_hatch.scad), clear of the panel's screw holes and the
// saddle bolt pattern that also passes through this area.

// --- Battery access hatch (NEW in v0.15) ---
// Bottom-access hatch for the battery instead of fighting a
// top-down path past the LD2410B mount and MCU plate — their
// footprints genuinely overlap the battery's 56mm length, so no
// amount of channel-narrowing was going to give a clear straight
// drop (confirmed the hard way, twice). This cuts a clean
// rectangular opening through the bottom wall, sized 60x38mm —
// real margin over the battery's 56x34mm footprint — plus four
// pilot holes in the surrounding rim for the hatch panel's
// screws to bite into.
module battery_hatch_opening() {
    translate([0, 0, -25.1])
        cube([60, 38, 10], center=true);
}

module battery_hatch_screw_holes() {
    for (x = [-1, 1])
        for (y = [-1, 1])
            translate([x*31, y*20, -25.1])
                cylinder(h = 10, d = screw_hole_d, $fn = 32, center = true);
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
            rain_hood_support_wedge();
            ld2410b_mount();
            mcu_plate();
            battery_bay();
            lid_bosses();
            bme280_vent_lips();
        }
        saddle_bolts();
        battery_hatch_opening();
        battery_hatch_screw_holes();
        bme280_vents();
    }
}

// Render
ld2410b_presence_housing();
