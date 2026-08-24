// Receiver Stack Housing for NATO Strap (22mm)
// Holds: PowerBoost 500C, Seeed XIAO ESP32-C3, TCA9548A Multiplexer

// Parameters
wall_thickness = 2.0;
strap_width = 22.5;
strap_thickness = 1.8;
lug_width = 5.0;
lug_clearance = 1.5;

// Component approximate dimensions (L x W x H)
// PowerBoost 500C: 29 x 22 x 7
// XIAO ESP32-C3: 21 x 17.5 x 5
// TCA9548A: 25.5 x 18 x 5 (Adafruit size)
// Stacked with clearance: 
inner_length = 34; 
inner_width = 26;
inner_height = 22;

module rounded_box(w, l, h, r) {
    hull() {
        translate([r, r, 0]) cylinder(r=r, h=h, $fn=32);
        translate([w-r, r, 0]) cylinder(r=r, h=h, $fn=32);
        translate([r, l-r, 0]) cylinder(r=r, h=h, $fn=32);
        translate([w-r, l-r, 0]) cylinder(r=r, h=h, $fn=32);
    }
}

module receiver_housing() {
    outer_w = inner_width + wall_thickness*2;
    outer_l = inner_length + wall_thickness*2;
    outer_h = inner_height + wall_thickness; // open top (lid assumed separate)
    
    difference() {
        // Main Body
        rounded_box(outer_w, outer_l, outer_h, 3);
        
        // Inner Cavity
        translate([wall_thickness, wall_thickness, wall_thickness])
            rounded_box(inner_width, inner_length, inner_height + 1, 1.5);
            
        // Cutout for USB-C / Power
        translate([outer_w/2 - 6, -1, wall_thickness + 1])
            cube([12, wall_thickness + 2, 10]);
            
        // Cutout for I2C and Power cables to the pods
        translate([outer_w/2 - 6, outer_l - wall_thickness - 1, wall_thickness + 1])
            cube([12, wall_thickness + 2, 10]);
    }
    
    // NATO Strap Lugs (Side mounts)
    lug_offset_x = 4;
    for (y = [2, outer_l - lug_width - 2]) {
        // Left Lug
        translate([-lug_offset_x, y, 0]) {
            difference() {
                cube([lug_offset_x + wall_thickness, lug_width, strap_thickness + wall_thickness*2]);
                translate([-0.1, -0.1, wall_thickness])
                    cube([lug_offset_x + wall_thickness + 0.2, lug_width + 0.2, strap_thickness]);
            }
        }
        // Right Lug
        translate([outer_w - wall_thickness, y, 0]) {
            difference() {
                cube([lug_offset_x + wall_thickness, lug_width, strap_thickness + wall_thickness*2]);
                translate([-0.1, -0.1, wall_thickness])
                    cube([lug_offset_x + wall_thickness + 0.2, lug_width + 0.2, strap_thickness]);
            }
        }
    }
    
    // Internal Standoffs for Stacking
    standoff_w = 4;
    standoff_l = 4;
    
    // Lower Standoffs (for PowerBoost)
    for (x = [wall_thickness, outer_w - wall_thickness - standoff_w]) {
        for (y = [wall_thickness, outer_l - wall_thickness - standoff_l]) {
            translate([x, y, wall_thickness])
                cube([standoff_w, standoff_l, 6]);
        }
    }
    
    // Upper Standoffs (for XIAO / Mux)
    for (x = [wall_thickness, outer_w - wall_thickness - standoff_w]) {
        for (y = [wall_thickness, outer_l - wall_thickness - standoff_l]) {
            translate([x, y, wall_thickness + 6 + 1.5]) // 1.5 PCB thickness
                cube([standoff_w, standoff_l, 6]);
        }
    }
}

receiver_housing();
