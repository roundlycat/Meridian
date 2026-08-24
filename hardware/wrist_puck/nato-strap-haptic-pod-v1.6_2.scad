// =========================================================================
// MERIDIAN ECOSYSTEM - SENSOR SPECIES FAMILY
// ARCHETYPE B: NATO STRAP SLOTTED HAPTIC POD (v1.6)
// Designed by Sean Pond, Whitehorse, YT, Canada
// =========================================================================
// This is a highly optimized, parametric, two-part snap-fit enclosure
// designed to house a single flat coin LRA (10mm) and a DRV2605L breakout board.
// The pod features integrated 22mm watch strap slots (lugs) that keep the
// bottom floor pressed firmly against the skin for maximum haptic coupling,
// while shielding the electronics from sweat and tension.
//
// v1.6 CHANGE: the LRA pocket in v1.5 was a direct rigid press-fit, unibody
// with the DRV ledges and both strap lugs -- no vibration isolation at all.
// This revision widens the pocket radially and recesses it slightly deeper
// axially so a wrapped foam tape / silicone liner can sit between the LRA
// and the shell, breaking the rigid transmission path into the DRV mount
// and lugs while keeping the LRA's active face registered at the skin
// aperture. See the "Vibration Isolation Liner" section below.
//
// v1.6 ALSO FIXES: the "male snap lip rim" in v1.5 was positioned at a
// hardcoded outer_z/2, which left it floating ~1.25mm above the main
// body's actual top surface -- a disconnected island with nothing under
// it. That's almost certainly why the sliced print needed supports
// throughout the whole cavity: the slicer was holding up a floating rim
// with support_on_build_plate_only disabled. The rim now anchors to the
// main body's real height (main_body_h), sitting flush with a small
// overlap for a clean union.
//
// v1.6.1 FIX: after re-slicing, a second floating-geometry bug turned up
// in the same family -- both NATO strap lugs were centered on world Z=0
// independent of the main body, so their outer (non-overlapping) bulk
// floated ~0.75mm above the actual floor with nothing under it. That's
// what the residual support columns in the v1.6 slice were holding up.
// Both lugs now extend down to lug_bottom, flush with the main body's
// real floor, while keeping their top edge where it was. Re-slice after
// this fix -- the cavity and the lug slots should both come out
// essentially support-free now.
// =========================================================================

/* [General Enclosure Settings] */
// Part to render
part = "both"; // [both, base, lid]
// Detail level (smoothness of cylinders)
$fn = 60;
// Outer wall thickness
wall = 1.6;
// Internal hardware clearance
clearance = 0.2;
// Filament squeeze / snap tolerance
snap_clearance = 0.15;

/* [NATO Strap Slot Settings] */
// Width of the watch strap (standard is 22mm)
strap_width = 22.2;
// Thickness of heavy-duty nylon NATO strap
strap_thickness = 1.8;
// Structural wall around strap slots
strap_wall = 1.6;

/* [Haptic Actuator Settings] */
// 10mm LRA outer diameter
lra_dia = 10.0;
// LRA thickness
lra_thick = 3.5;
// Skin-contact aperture diameter (prevents LRA falling out, exposes active face)
lra_aperture = 8.5;

/* [Vibration Isolation Liner] */
// Radial gap added around the LRA's sides (per side) for a compliant liner --
// foam tape or a silicone sleeve wrapped around the LRA before it's pressed
// in. 0.5mm is roughly one wrap of thin (~0.5mm) foam tape; bump this up if
// you're double-wrapping or using thicker silicone.
liner_radial = 0.5;
// Extra depth added to the pocket floor side, leaving room for a thin foam
// or silicone washer under the LRA's resting rim. Without this the LRA's
// rim sits directly on a rigid shelf that's unibody with the DRV ledges and
// both strap lugs -- this is the main hidden coupling path. A washer close
// to this thickness restores roughly the original skin-contact depth.
liner_axial = 0.4;
// NOTE: this trims the exterior floor thickness under the LRA pocket by
// liner_axial. Check the rendered wall there isn't paper-thin for your
// nozzle/layer height before printing; reduce liner_axial if it looks weak.

/* [DRV2605L Breakout Settings] */
// Width of the DRV board (y-axis)
drv_w = 18.0;
// Length of the DRV board (x-axis)
drv_l = 26.0;
// PCB thickness of the breakout
drv_pcb = 1.6;
// Tallest component clearance on DRV (inductor/capacitors)
drv_comp_h = 2.5;

/* [Cable Exit Ports] */
// Width of the daisy-chain cable ports (fits 4-wire silicone bus)
port_w = 4.5;
// Height of the daisy-chain cable ports
port_h = 2.5;

// =========================================================================
// DERIVED DIMENSIONS (Mathematical Optimization)
// =========================================================================
inner_x = drv_l + (clearance * 2);
inner_y = drv_w + (clearance * 2);
inner_z = lra_thick + drv_pcb + drv_comp_h + clearance;

outer_x = inner_x + (wall * 2);
outer_y = inner_y + (wall * 2);
outer_z = inner_z + (wall * 2);

// Height of the main body shell. The snap lip and both lugs need to
// reference this real value rather than a hardcoded outer_z/2 -- that
// mismatch is what caused two separate floating-geometry bugs in v1.5.
main_body_h = outer_z / 2 + 1;

// Strap lug dimensions
lug_x = strap_thickness + (strap_wall * 2);
lug_y = strap_width + (strap_wall * 2);
lug_offset = (outer_x / 2) + (lug_x / 2) - 0.5; // slight overlap for solid union

// v1.6 FIX: in v1.5 each lug was a standalone rounded_box centered on
// world Z=0 (height = strap_thickness + strap_wall*2, spanning roughly
// -2.5 to +2.5), while the main body's actual bottom sits at
// -main_body_h/2 (around -3.25). That's a ~0.75mm gap -- the outer,
// non-overlapping bulk of each lug was floating above the bed with
// nothing under it, which is exactly what the residual supports in the
// v1.6 slice were holding up. Keep the lug's *top* where it was
// (lug_top) and extend its bottom down to flush with the main body's
// real bottom instead.
lug_top = (strap_thickness + (strap_wall * 2)) / 2;
lug_bottom = -main_body_h / 2;
lug_h = lug_top - lug_bottom;
lug_z_offset = (lug_top + lug_bottom) / 2;

// =========================================================================
// RENDER ROUTER
// =========================================================================
if (part == "both") {
    translate([0, 0, 0]) base();
    translate([0, outer_y + 8, 0]) lid();
} else if (part == "base") {
    base();
} else if (part == "lid") {
    lid();
}

// =========================================================================
// ENCLOSURE BASE MODULE
// =========================================================================
module base() {
    difference() {
        union() {
            // Main rounded outer base body
            rounded_box(outer_x, outer_y, main_body_h, 3.0);
            
            // Left Watch Lug -- solid body extended down to lug_bottom
            // (flush with the main body's real floor) instead of floating
            // ~0.75mm above the bed. The strap slot cut below is unchanged:
            // its h=100 already fully punches through regardless of the
            // lug's height.
            translate([-lug_offset, 0, 0]) {
                difference() {
                    translate([0, 0, lug_z_offset])
                        rounded_box(lug_x, lug_y, lug_h, 2.0);
                    // Strap Slot
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Right Watch Lug -- same floor-flush fix as the left lug
            translate([lug_offset, 0, 0]) {
                difference() {
                    translate([0, 0, lug_z_offset])
                        rounded_box(lug_x, lug_y, lug_h, 2.0);
                    // Strap Slot
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Male snap lip rim -- sits flush on the main body's top surface
            // (0.2mm overlap for a clean, watertight union) instead of the
            // old hardcoded outer_z/2, which left it floating in mid-air.
            translate([0, 0, main_body_h/2 + 0.8])
                difference() {
                    rounded_box(inner_x + wall + (snap_clearance/2), inner_y + wall + (snap_clearance/2), 2.0, 2.0);
                    rounded_box(inner_x + (snap_clearance/2), inner_y + (snap_clearance/2), 10.0, 1.5);
                }
        }
        
        // Inner cavity for electronics
        translate([0, 0, wall])
            rounded_box(inner_x, inner_y, outer_z, 1.5);
            
        // LRA Pocket in the center floor
        translate([0, 0, -1 - liner_axial]) {
            // Main LRA cylinder pocket (blind hole), widened radially for a
            // compliant liner sleeve and recessed deeper on the floor side
            // for a liner washer. Height is padded by liner_axial too, so
            // the pocket's top (DRV-side clearance) lands in the same place
            // it did in v1.5 -- only the floor side moves.
            cylinder(d = lra_dia + 0.2 + (liner_radial * 2), h = lra_thick + 1 + 0.1 + liner_axial);
            // Skin contact aperture (smaller hole through floor)
            cylinder(d = lra_aperture, h = 10, center=true);
        }
        
        // LRA Wire routing relief groove leading to corner
        translate([0, 0, wall]) {
            translate([0, 0, 0])
                cube([15, 2.2, 1.2], center=true);
        }
        
        // Left Cable daisy-chain port cutout
        translate([-(outer_x/2 + 2), 0, (outer_z / 2) - port_h/2 + 0.5])
            cube([10, port_w, port_h], center=true);
            
        // Right Cable daisy-chain port cutout
        translate([(outer_x/2 + 2), 0, (outer_z / 2) - port_h/2 + 0.5])
            cube([10, port_w, port_h], center=true);
    }
    
    // Internal PCB support ledges (holds DRV2605L elevated above LRA)
    ledge_w = 1.5;
    ledge_h = lra_thick + 0.4;
    
    // Support shelf at the X-boundaries
    translate([-inner_x/2 + ledge_w/2, 0, wall + ledge_h/2])
        cube([ledge_w, inner_y, ledge_h], center=true);
    translate([inner_x/2 - ledge_w/2, 0, wall + ledge_h/2])
        cube([ledge_w, inner_y, ledge_h], center=true);
}

// =========================================================================
// ENCLOSURE LID MODULE
// =========================================================================
module lid() {
    difference() {
        union() {
            // Main lid body
            rounded_box(outer_x, outer_y, outer_z / 2, 3.0);
        }
        
        // Inner hollow area for components
        translate([0, 0, -wall])
            rounded_box(inner_x + (snap_clearance * 2), inner_y + (snap_clearance * 2), outer_z / 2, 1.5);
            
        // Female snap groove (receives the base snap lip)
        translate([0, 0, -0.1])
            difference() {
                rounded_box(inner_x + wall + (snap_clearance * 2), inner_y + wall + (snap_clearance * 2), 2.2, 2.0);
                rounded_box(inner_x - 0.2, inner_y - 0.2, 10.0, 1.5);
            }
            
        // Left Cable daisy-chain port cutout (completes the port arch)
        translate([-(outer_x/2 + 2), 0, -0.1])
            cube([10, port_w + (clearance*2), port_h], center=true);
            
        // Right Cable daisy-chain port cutout
        translate([(outer_x/2 + 2), 0, -0.1])
            cube([10, port_w + (clearance*2), port_h], center=true);
            
        // Aesthetic Top Logo / Ventilation slots (Meridian Ripple motif)
        for(i = [-2 : 2]) {
            translate([0, i * 3.5, outer_z/4])
                cube([drv_l * 0.5, 1.2, wall * 2], center=true);
        }
    }
}

// =========================================================================
// HELPER: HIGH-SPEED ROUNDED BOX GENERATOR
// =========================================================================
// Replaces slow minkowski() operations with a clean, mathematically precise
// cylinder-and-hull rounding function.
// =========================================================================
module rounded_box(x, y, z, r) {
    hx = x/2 - r;
    hy = y/2 - r;
    hz = z/2;
    
    hull() {
        translate([-hx, -hy, 0]) cylinder(r=r, h=z, center=true);
        translate([ hx, -hy, 0]) cylinder(r=r, h=z, center=true);
        translate([-hx,  hy, 0]) cylinder(r=r, h=z, center=true);
        translate([ hx,  hy, 0]) cylinder(r=r, h=z, center=true);
    }
}
