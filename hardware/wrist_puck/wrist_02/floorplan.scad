use <wrist_puck_keyhole_1_0.scad>

// Shallow test tray -- calls the EXACT SAME cavity modules as the
// real bottom_shell(), just with a shallow cut_top_z instead of the
// full shell height. use<> imports modules (fine) but not variables
// (not needed here -- no positioning numbers are duplicated at all,
// unlike the previous version of this file).
//
// Previous versions of this file used include<>, which executes the
// included file's own top-level bottom_shell() call as well as this
// file's content -- silently unioning the FULL 26.5mm shell with this
// shallow tray. That's what Bambu Studio's 1h46m/27g slicing estimate
// was actually showing: the full shell, not a quick test print. This
// version cannot make that mistake structurally, not just by
// convention -- use<> never executes the included file's top-level
// statements at all.
// TEST_H is a plain absolute number, NOT "FLOOR_T + 5" -- use<>
// doesn't import variables (only modules), so FLOOR_T would be
// undef here, and undef arithmetic silently produced a near-zero
// height rather than an error. Real floor thickness is 2mm
// (defined inside wrist_puck_keyhole_1_0.scad); keep TEST_H a
// few mm above that if you change it.
TEST_H = 7;

module floorplan() {
    difference() {
        outer_silhouette(TEST_H);
        servo_cavity(TEST_H + 1);
        lra_cavity();
        power_cavity(TEST_H + 1);
        compute_cavity(TEST_H + 1);
    }
}

floorplan();
