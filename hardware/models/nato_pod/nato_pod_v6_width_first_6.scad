// =========================================================================
// MERIDIAN ECOSYSTEM - SENSOR SPECIES FAMILY
// ARCHETYPE B: NATO STRAP SLOTTED HAPTIC POD & RECEIVER BRAIN (v3.0)
// Designed by Sean Pond, Whitehorse, YT, Canada
// =========================================================================
// This is a highly optimized, parametric, two-part snap-fit enclosure
// system designed for a 5-LRA array wearable.
// It includes:
// 1. The Haptic Pod: Houses a single 10mm LRA and a DRV2605L breakout board.
// 2. The Receiver Brain: Houses the physical receiver stack (Seeed XIAO ESP32-C3,
//    TCA9548A multiplexer, PowerBoost 500C, and a 602040 LiPo battery).
// Both enclosures feature integrated 22mm watch strap slots (lugs) to keep them
// secured firmly to a heavy-duty NATO strap for direct mechanical skin coupling.
// =========================================================================

/* [General Enclosure Settings] */
// Part to render
part = "both"; // [both, base, lid, receiver_both, receiver_base, receiver_lid]
// Detail level (smoothness of cylinders)
$fn = 60;
// Outer wall thickness
wall = 1.6;
// Internal hardware clearance
clearance = 0.2;
// Filament squeeze / snap tolerance
snap_clearance = 0.4; // Adjusted to 0.4 to fix the lid fitting issue (lid too tight/small)

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
// Width of the daisy-chain cable ports -- Sean's caliper measurement of
// the actual connector (7.0mm) plus 0.3mm clearance per side
port_w = 7.6;
// Height of the daisy-chain cable ports -- measured connector (3.0mm)
// plus 0.3mm clearance per side
port_h = 3.6;

/* [Receiver Cable Exit Ports] */
// Width of the receiver cable ports (widened to 6.0 mm for thick bundles)
rec_port_w = 6.0;
// Height of the receiver cable ports (height of 3.5 mm)
rec_port_h = 3.5;

/* [Vibration Isolation Liner] */
// Radial gap added around the LRA's sides for a compliant liner
liner_radial = 0.5;
// Extra depth added to the pocket floor side, leaving room for a thin foam
liner_axial = 0.4;

/* [Receiver Brain Settings] */
// Width of the receiver cavity (y-axis)
rec_w = 26.0;
// Length of the receiver cavity (x-axis, fits PowerBoost + battery side-by-side or stacked)
rec_l = 46.0;
// Height of the receiver cavity (z-axis, fits Battery + PowerBoost + Mux + XIAO)
rec_h = 21.0;
// USB-C/Micro-USB port cutout width for charging/serial access
usb_port_w = 9.0;
// USB-C/Micro-USB port cutout height
usb_port_h = 4.5;

// =========================================================================
// DERIVED DIMENSIONS (Mathematical Optimization)
// =========================================================================
// Haptic Pod Dimensions
// v6: swapped from v5 -- width now runs along the circumference (x) axis
// instead of length, to shorten each pod's footprint around the wrist.
// Cable ports are untouched below since they're keyed off outer_x, not off
// drv_l/drv_w directly -- confirmed against Sean's actual board, connectors
// exit on the ends that are now the x-axis ends, same as before the swap.
inner_x = drv_w + (clearance * 2);
inner_y = drv_l + (clearance * 2);
// v10: was lra_thick + drv_pcb + drv_comp_h + clearance (summed, as if both
// had to stack in one shared cavity). They don't have to anymore -- the real
// requirement is whichever one needs more headroom, not both added together.
inner_z = max(lra_thick + liner_axial, drv_pcb + drv_comp_h + clearance) + 1.0;

outer_x = inner_x + (wall * 2);
outer_y = inner_y + (wall * 2);
outer_z = inner_z + (wall * 2);

// v1.6.1 LRA Pod Lugs & Body Alignment
main_body_h = outer_z / 2 + 1;
lug_top = (strap_thickness + (strap_wall * 2)) / 2;
lug_bottom = -main_body_h / 2;
lug_h = lug_top - lug_bottom;
lug_z_offset = (lug_top + lug_bottom) / 2;

// Receiver Brain Dimensions
rec_inner_x = rec_l + (clearance * 2);
rec_inner_y = rec_w + (clearance * 2);
rec_inner_z = rec_h + (clearance * 2);

rec_outer_x = rec_inner_x + (wall * 2);
rec_outer_y = rec_inner_y + (wall * 2);
rec_outer_z = rec_inner_z + (wall * 2);

// v1.6.1 Receiver Brain Lugs & Body Alignment
rec_main_body_h = rec_outer_z / 2 + 1;
rec_lug_top = (strap_thickness + (strap_wall * 2)) / 2;
rec_lug_bottom = -rec_main_body_h / 2;
rec_lug_h = rec_lug_top - rec_lug_bottom;
rec_lug_z_offset = (rec_lug_top + rec_lug_bottom) / 2;

// Strap lug dimensions (Shared across both configurations)
lug_x = strap_thickness + (strap_wall * 2);
lug_y = strap_width + (strap_wall * 2);

// Lug offsets for assembly union
pod_lug_offset = (outer_x / 2) + (lug_x / 2) - 0.5;
rec_lug_offset = (rec_outer_x / 2) + (lug_x / 2) - 0.5;

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
} else if (part == "receiver_both") {
    translate([0, 0, 0]) receiver_base();
    translate([0, rec_outer_y + 8, 0]) receiver_lid();
} else if (part == "receiver_base") {
    receiver_base();
} else if (part == "receiver_lid") {
    receiver_lid();
}

// =========================================================================
// MODULE: STANDARD HAPTIC POD BASE
// =========================================================================
module base() {
    difference() {
        union() {
            // Main rounded outer base body
            rounded_box(outer_x, outer_y, main_body_h, 3.0);
            
            // Left Watch Lug (v1.6.1 aligned flush with bed)
            translate([-pod_lug_offset, 0, lug_z_offset]) {
                difference() {
                    rounded_box(lug_x, lug_y, lug_h, 2.0);
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Right Watch Lug (v1.6.1 aligned flush with bed)
            translate([pod_lug_offset, 0, lug_z_offset]) {
                difference() {
                    rounded_box(lug_x, lug_y, lug_h, 2.0);
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Male snap lip rim (v1.6 aligned flush to main body top surface)
            translate([0, 0, main_body_h / 2])
                difference() {
                    rounded_box(inner_x + wall + (snap_clearance/2), inner_y + wall + (snap_clearance/2), 2.0, 2.0);
                    rounded_box(inner_x + (snap_clearance/2), inner_y + (snap_clearance/2), 10.0, 1.5);
                }
        }
        
        // Inner cavity for electronics -- v10 FIX: this was sized to
        // outer_z (the FULL case height) and centered on `wall`, so it
        // reached ~4mm below the base's own floor -- erasing the floor
        // completely everywhere except right at the aperture. Confirmed
        // by slicing cross-sections at multiple heights: no floor existed
        // anywhere. Rescoped to only remove what's actually above the
        // LRA pocket, leaving a real floor beneath it.
        translate([0, 0, wall + (inner_z/2) ])
            rounded_box(inner_x, inner_y, inner_z, 1.5);
            
        // LRA Pocket in the center floor
        translate([0, 0, -1]) {
            cylinder(d = lra_dia + 0.2 + (liner_radial * 2), h = lra_thick + 1 + 0.1 + liner_axial);
            cylinder(d = lra_aperture, h = 10, center=true);
        }
        
        // LRA Wire routing relief groove -- now leads toward the Y-end
        // ports (rotated 90° from before) since the notches moved there
        translate([0, 0, wall]) {
            cube([2.2, 15, 1.2], center=true);
        }
        
        // Notches moved to the Y-axis ends -- confirmed against Sean's
        // actual board photo: STEMMA connectors sit on the edges with no
        // strap running through them, not the lug edges. Same open-at-
        // top-edge notch as before, just on the other pair of walls.
        //
        // BUG FIX: rounded_box() is z-centered, so the real top surface is
        // at main_body_h/2 (3.25mm here), not main_body_h (6.5mm) -- the
        // previous version cut almost 3mm too high, only grazing the edge
        // of the part instead of the full port_h depth. That's why the
        // printed opening measured ~2.6mm instead of the intended 4.26.
        // Port size also updated to Sean's caliper measurement of the
        // actual connector (7 x 3mm) plus 0.3mm clearance per side.
        port_top = main_body_h/2 + 1;   // 1mm above the real top surface, through the lip
        translate([0, -(outer_y/2 + 2), port_top - port_h/2])
            cube([port_w, 10, port_h + 2], center=true);

        // Right Cable notch (opposite Y end)
        translate([0, (outer_y/2 + 2), port_top - port_h/2])
            cube([port_w, 10, port_h + 2], center=true);
    }
    
    // Internal PCB support ledges (holds DRV2605L elevated above LRA)
    ledge_w = 1.5;
    ledge_h = lra_thick + 0.4;
    
    translate([-inner_x/2 + ledge_w/2, 0, wall + ledge_h/2])
        cube([ledge_w, inner_y, ledge_h], center=true);
    translate([inner_x/2 - ledge_w/2, 0, wall + ledge_h/2])
        cube([ledge_w, inner_y, ledge_h], center=true);
}

// =========================================================================
// MODULE: STANDARD HAPTIC POD LID
// =========================================================================
module lid() {
    difference() {
        union() {
            rounded_box(outer_x, outer_y, outer_z / 2, 3.0);
        }
        
        translate([0, 0, -wall])
            rounded_box(inner_x + (snap_clearance * 2), inner_y + (snap_clearance * 2), outer_z / 2, 1.5);
            
        // Snap-fit groove REMOVED (v9->v10) -- it was carving into the
        // same ~1.2mm rim the main cavity wall depends on, and between
        // rounded-corner mismatches it was eating through that rim
        // entirely in places. Confirmed by slicing the model at the
        // heights Sean's slicer flagged as empty: genuinely zero material
        // there, not a false alarm. The base's lip still presses into the
        // main cavity below without this -- friction fit, not interlock.
            
        // No matching port cutout here anymore -- the notch is now entirely
        // in the base (open at its top edge) and this lid's flat underside
        // just caps it. See base() for the actual notch.

        // Aesthetic Top Logo / Ventilation slots (Meridian Ripple motif)
        for(i = [-2 : 2]) {
            translate([0, i * 3.5, outer_z/4])
                cube([drv_l * 0.5, 1.2, wall * 2], center=true);
        }
    }
}

// =========================================================================
// MODULE: RECEIVER BRAIN STACK BASE
// =========================================================================
module receiver_base() {
    difference() {
        union() {
            // Main rounded outer receiver body
            rounded_box(rec_outer_x, rec_outer_y, rec_main_body_h, 4.0);
            
            // Left Strap Lug (v1.6.1 aligned flush with bed)
            translate([-rec_lug_offset, 0, rec_lug_z_offset]) {
                difference() {
                    rounded_box(lug_x, lug_y, rec_lug_h, 2.0);
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Right Strap Lug (v1.6.1 aligned flush with bed)
            translate([rec_lug_offset, 0, rec_lug_z_offset]) {
                difference() {
                    rounded_box(lug_x, lug_y, rec_lug_h, 2.0);
                    cube([strap_thickness, strap_width, 100], center=true);
                }
            }
            
            // Male snap lip rim (v1.6 aligned flush to main receiver top surface)
            translate([0, 0, rec_main_body_h / 2])
                difference() {
                    rounded_box(rec_inner_x + wall + (snap_clearance/2), rec_inner_y + wall + (snap_clearance/2), 2.0, 2.0);
                    rounded_box(rec_inner_x + (snap_clearance/2), rec_inner_y + (snap_clearance/2), 10.0, 1.5);
                }
        }
        
        // Inner cavity for electronics stack (Battery + PowerBoost + Mux + XIAO)
        translate([0, 0, wall])
            rounded_box(rec_inner_x, rec_inner_y, rec_outer_z, 2.0);
            
        // Left Cable Exit Port (Sends 4-wire haptic bus out to CH0-CH4)
        translate([-(rec_outer_x/2 + 2), 0, (rec_outer_z / 2) - rec_port_h/2 + 0.5])
            cube([10, rec_port_w, rec_port_h], center=true);
            
        // Right Cable Exit Port
        translate([(rec_outer_x/2 + 2), 0, (rec_outer_z / 2) - rec_port_h/2 + 0.5])
            cube([10, rec_port_w, rec_port_h], center=true);
            
        // USB-C / Micro-USB Programming Port Cutout (Centered on one end face)
        translate([0, -(rec_outer_y/2 + 1), wall + usb_port_h/2 + 1.0])
            cube([usb_port_w, 10, usb_port_h], center=true);
    }
    
    // Internal Battery Isolator Ledges (Z = 6.5mm)
    // Suspends the electronics board card-deck above the soft LiPo battery pouch
    deck_shelf_z = wall + 6.5;
    shelf_w = 1.6;
    
    // Left & Right internal shelves to hold the board platform
    translate([-rec_inner_x/2 + shelf_w/2, 0, deck_shelf_z])
        cube([shelf_w, rec_inner_y, 1.2], center=true);
    translate([rec_inner_x/2 - shelf_w/2, 0, deck_shelf_z])
        cube([shelf_w, rec_inner_y, 1.2], center=true);
}

// =========================================================================
// MODULE: RECEIVER BRAIN STACK LID
// =========================================================================
module receiver_lid() {
    difference() {
        union() {
            rounded_box(rec_outer_x, rec_outer_y, rec_outer_z / 2, 4.0);
        }
        
        // Internal hollow dome clearance
        translate([0, 0, -wall])
            rounded_box(rec_inner_x + (snap_clearance * 2), rec_inner_y + (snap_clearance * 2), rec_outer_z / 2, 2.0);
            
        // Female snap groove rim
        translate([0, 0, -0.1])
            difference() {
                rounded_box(rec_inner_x + wall + (snap_clearance * 2), rec_inner_y + wall + (snap_clearance * 2), 2.2, 2.0);
                rounded_box(rec_inner_x - 0.2, rec_inner_y - 0.2, 10.0, 1.5);
            }
            
        // Port cutouts matching base
        translate([-(rec_outer_x/2 + 2), 0, -0.1])
            cube([10, rec_port_w + (clearance*2), rec_port_h], center=true);
        translate([(rec_outer_x/2 + 2), 0, -0.1])
            cube([10, rec_port_w + (clearance*2), rec_port_h], center=true);
            
        // Aesthetic Ventilation & Monitoring slots (Meridian Ripple motif)
        for(i = [-4 : 4]) {
            translate([i * 4.0, 0, rec_outer_z/4])
                cube([1.5, rec_inner_y * 0.6, wall * 2], center=true);
        }
    }
}

// =========================================================================
// HELPER: HIGH-SPEED ROUNDED BOX GENERATOR
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
