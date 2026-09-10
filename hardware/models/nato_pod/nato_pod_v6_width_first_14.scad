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
lra_dia = 10.0;   // v14: VG1040003D measured -- was 9.95 for the old
                   // VG1030001XH wire-lead motor
// LRA thickness
lra_thick = 4.5;   // v14: VG1040003D measured -- was 3.5 for the old
                    // motor. Real dimension change, not tolerance --
                    // flows through to pocket_h, ledge_h, inner_z below.
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
liner_radial = 0.15;   // v14: tightened from 0.5 -- Sean confirmed the
                        // faint-vibration diagnosis found no foam was
                        // ever actually installed in this reserved gap,
                        // so it was pure unfilled play, not a liner.
                        // This is now just print-fit clearance. Set
                        // back to 0.5 if foam sized to fill it is
                        // actually going in.
// Extra depth added to the pocket floor side, leaving room for a thin foam
liner_axial = 0.15;    // v14: same reasoning as liner_radial -- was
                        // unfilled axial slack letting the motor lift
                        // off the aperture shoulder. Set back to 0.4
                        // only if foam of that thickness is installed.

/* [Board Mounting] */
// Foam mounting tape thickness under the DRV board on the ledges --
// PLACEHOLDER, not yet measured against Sean's actual tape. Confirmed real
// requirement: board sits on the base's existing ledges (not moved to the
// lid), so this stacks with ledge_h + board thickness inside the SAME
// shared cavity budget, not a separate one.
foam_tape_t = 0.5;

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
// v11 CORRECTION: v10's max()-based shrink assumed the LRA and the DRV
// stack lived in separate parts. Confirmed wrong -- the board stays on the
// base's existing ledges, not moved to the lid. They DO share one cavity,
// so it's back to summing, not taking the max -- PLUS foam_tape_t, which
// wasn't in the budget at all before and is exactly what made "add foam to
// the ledges" stop fitting under the lid.
ledge_h = lra_thick + 0.4;
inner_z = ledge_h + foam_tape_t + drv_pcb + drv_comp_h + clearance;

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
            
        // LRA Pocket in the center floor -- v13 FIX: this used to start
        // at a fixed z=-1, a number that predates several height changes
        // tonight and never tracked them. With the real floor now down at
        // -main_body_h/2, that left an un-cut layer between the true
        // bottom and where the pocket actually began -- the LRA was
        // resting on top of that layer instead of at the real outer
        // surface, which is exactly the air gap Sean felt. floor_t is a
        // deliberately thin remaining step (not zero -- needs *some*
        // material to retain the LRA at all), placed relative to the
        // real bottom instead of a stale absolute number.
        floor_t = 0.6;
        pocket_z0 = -main_body_h/2 + floor_t;
        pocket_r = (lra_dia + 0.2 + (liner_radial * 2)) / 2;
        pocket_h = lra_thick + 1 + 0.1 + liner_axial;
        translate([0, 0, pocket_z0])
            cylinder(d = pocket_r * 2, h = pocket_h);
        // Aperture cut separately, anchored well below the true bottom so
        // it always fully punches through regardless of pocket_z0.
        translate([0, 0, -main_body_h/2 - 5])
            cylinder(d = lra_aperture, h = main_body_h + 10);

        // Relief for the LRA's own wire-exit tab -- the molded plastic
        // sheath on the LRA body itself, which was holding it off the
        // pocket floor since the pocket was a plain circle with nowhere
        // for the tab to go. Angled per Sean's plan to split the
        // difference between the two DRV pads so short leads can reach
        // both without extensions.
        tab_w = 6.3;       // v14: VG1040003D measured -- 5.7mm across the
                           // rigid contact-pad flex tab (a real PCB tang,
                           // not the old motor's molded wire sheath) plus
                           // 0.3mm clearance per side, same convention as
                           // port_w below. The old 3.19 was sized for a
                           // different motor's different tab shape.
        tab_reach = 4.0;   // v14: VG1040003D measured -- 14mm overall
                           // length (body + tab) minus the 10mm body
                           // diameter. The cube cut below already adds
                           // +1mm past this, so no extra margin needed here.
        tab_angle = 45;
        rotate([0, 0, tab_angle])
            translate([pocket_r - 0.5, -tab_w/2, pocket_z0])
                cube([tab_reach + 1, tab_w, pocket_h]);
        
        // LRA Wire routing relief groove -- widened (was 1.2mm tall, a
        // shallow scratch that didn't reach ledge height). This is meant
        // to be a fully internal path from the pocket to the board -- the
        // LRA's 2 leads have no reason to ever leave the sealed case, so
        // routing them out through the port and back in was a workaround
        // for a groove that wasn't tall enough, not a real requirement.
        translate([0, 0, wall + (ledge_h/2)]) {
            cube([2.2, 15, ledge_h], center=true);
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

        // v12: except the lid's underside was still blocking part of the
        // port opening at the seam -- adding a small relief at both Y
        // ends. Cutting both rather than guessing which one Sean meant by
        // "upper" -- harmless if one side turns out not to need it.
        translate([0, -(outer_y/2 + 2), -outer_z/2 + port_h/2])
            cube([port_w, 10, outer_z + port_h], center=true);
        translate([0, (outer_y/2 + 2), -outer_z/2 + port_h/2])
            cube([port_w, 10, outer_z + port_h], center=true);

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
