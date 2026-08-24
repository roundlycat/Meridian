// =========================================================================
// MERIDIAN ECOSYSTEM - SENSOR SPECIES FAMILY
// ARCHETYPE B: NATO STRAP SLOTTED HAPTIC POD (v1.5)
// Designed by Sean Pond, Whitehorse, YT, Canada
// =========================================================================
// This is a highly optimized, parametric, two-part snap-fit enclosure
// designed to house a single flat coin LRA (10mm) and a DRV2605L breakout board.
// The pod features integrated 22mm watch strap slots (lugs) that keep the
// bottom floor pressed firmly against the skin for maximum haptic coupling,
// while shielding the electronics from sweat and tension.
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

// Strap lug dimensions
lug_x = strap_thickness + (strap_wall * 2);
lug_y = strap_width + (strap_wall * 2);
lug_offset = (outer_x / 2) + (lug_x / 2) - 0.5; // slight overlap for solid union

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
            rounded_box(outer_x, outer_y, outer_z / 2 + 1, 3.0);
            
            // Left Watch Lug
            translate([-lug_offset, 0, 0]) {
                difference() {
                    rounded_box(lug_x, lug_y, strap_thickness + (strap_wall * 2), 2.0);
                    // Strap Slot
                    translate([0, 0, 0])
                        cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Right Watch Lug
            translate([lug_offset, 0, 0]) {
                difference() {
                    rounded_box(lug_x, lug_y, strap_thickness + (strap_wall * 2), 2.0);
                    // Strap Slot
                    translate([0, 0, 0])
                        cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Male snap lip rim
            translate([0, 0, (outer_z / 2)])
                difference() {
                    rounded_box(inner_x + wall + (snap_clearance/2), inner_y + wall + (snap_clearance/2), 2.0, 2.0);
                    rounded_box(inner_x + (snap_clearance/2), inner_y + (snap_clearance/2), 10.0, 1.5);
                }
        }
        
        // Inner cavity for electronics
        translate([0, 0, wall])
            rounded_box(inner_x, inner_y, outer_z, 1.5);
            
        // LRA Pocket in the center floor
        translate([0, 0, -1]) {
            // Main LRA cylinder pocket (blind hole)
            cylinder(d = lra_dia + 0.2, h = lra_thick + 1 + 0.1);
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
