include <wrist_puck_keyhole_1_0.scad>

// Shallow test tray -- same outer silhouette and cavity footprints
// as the real shell, but at a fraction of the height, purely to
// physically check the XY layout against the real components before
// committing to a full print. Cavities cut straight through this
// shallow height (not testing Z-stack fit, just footprint/spacing).
TEST_H = FLOOR_T + 5;

module floorplan() {
    difference() {
        outer_silhouette(TEST_H);

        translate([SERVO_CX, SERVO_CY, TEST_H/2])
            cube([SERVO_W, SERVO_D, TEST_H + 2], center = true);

        translate([LRA_CX, LRA_CY, -0.2])
            cylinder(h = LRA_H + 0.2, d = LRA_DIAM);

        translate([PWR_CX, PWR_CY, TEST_H/2])
            cube([BATT_D, BATT_W, TEST_H + 2], center = true);

        translate([CPU_CX, CPU_CY, TEST_H/2])
            cube([XIAO_W, XIAO_D, TEST_H + 2], center = true);
    }
}

floorplan();
