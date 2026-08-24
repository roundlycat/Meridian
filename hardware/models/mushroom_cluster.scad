// Woodland Mushroom Cluster
// Three mushrooms of varying size and lean on a low mossy hummock.
// Deliberately built from smooth, roundable primitives (domes, tapered
// stems, a squashed-sphere base) rather than fine detail -- this is a form
// that translates to soapstone, where you're removing material with files
// and rifflers and every sharp internal corner is a place the stone will
// fight you. Print it, hold it, and use it as the maquette to carve against.
//
// FORM NOTES FOR CARVING: the undercut where each cap overhangs its stem is
// the hard part in stone. If carving, consider leaving that junction fuller
// than the print shows and only undercutting at the very end, once the
// overall mass is right -- an undercut cut too early leaves you nothing to
// hold onto while you work the rest.

$fn = 48;

// ---- Parameters ----
BASE_R      = 26;    // radius of the mossy hummock
BASE_H      = 9;     // how tall the hummock domes up
BASE_FLAT   = 2.5;   // flat foot at the bottom so it sits without rocking

// each mushroom: [x, y, scale, lean_deg, lean_dir_deg]
MUSHROOMS = [
    [  0,   2, 1.00,  0,   0],   // tall central one
    [-15,  -6, 0.62,  9, 200],   // smaller, leaning away
    [ 13,  -9, 0.78, -7,  20],   // mid-size, leaning the other way
];

CAP_R       = 15;    // cap radius at scale 1.0
CAP_H       = 10;    // cap height at scale 1.0
CAP_LIP     = 0.82;  // how far down the cap skirt comes (fraction of CAP_H)
STEM_R      = 4.6;   // stem radius at scale 1.0
STEM_H      = 20;    // stem height at scale 1.0
STEM_FLARE  = 1.5;   // how much wider the stem foot is than its neck

N_SPOTS     = 7;     // raised spots on the big cap (set 0 for a plain cap)
SPOT_R      = 1.9;

// ---- Mossy hummock base ----
module hummock() {
    intersection() {
        // squashed sphere, sunk so the equator is below the cut plane
        translate([0, 0, BASE_FLAT - BASE_R * (BASE_H / BASE_R)])
            scale([1, 1, (BASE_H + BASE_FLAT) / BASE_R])
                sphere(r = BASE_R);
        // trim to a flat-bottomed slab
        translate([-BASE_R, -BASE_R, 0])
            cube([2 * BASE_R, 2 * BASE_R, BASE_H + BASE_FLAT]);
    }
}

// ---- One mushroom ----
module mushroom_solid() {
    union() {
        // stem: flared foot tapering to a narrower neck.
        // Starts well below z=0 so it always fuses into the hummock.
        translate([0, 0, -6])
            cylinder(r1 = STEM_R * STEM_FLARE, r2 = STEM_R, h = STEM_H + 6);

        // cap: upper portion of a squashed sphere, dropped slightly onto
        // the stem so the two overlap in real volume (never merely touch)
        translate([0, 0, STEM_H - CAP_H * (1 - CAP_LIP) - 1.5])
            intersection() {
                scale([1, 1, CAP_H / CAP_R]) sphere(r = CAP_R);
                translate([-CAP_R, -CAP_R, -CAP_H * CAP_LIP])
                    cube([2 * CAP_R, 2 * CAP_R, CAP_H * (1 + CAP_LIP)]);
            }
    }
}

// spots on the cap: small domes half-sunk into the cap surface,
// scattered by a deterministic pseudo-random walk so it looks natural
// but regenerates identically every time
module cap_spots() {
    for (i = [0 : N_SPOTS - 1]) {
        az = (i * 137) % 360;                       // golden-angle-ish spread
        tilt = 18 + ((i * 53) % 100) / 100 * 42;    // 18..60 deg off vertical
        // place on the cap's outer surface
        rr = CAP_R * sin(tilt) * 0.92;
        zz = STEM_H - CAP_H * (1 - CAP_LIP) - 1.5 + CAP_H * cos(tilt) * 0.92;
        translate([rr * cos(az), rr * sin(az), zz])
            sphere(r = SPOT_R);
    }
}

module mushroom_with_spots() {
    union() {
        mushroom_solid();
        if (N_SPOTS > 0)
            intersection() {
                cap_spots();
                // clip the spots so they can only ever ADD to the cap,
                // never float free of it
                scale([1.06, 1.06, 1.06]) mushroom_solid();
            }
    }
}

// ---- Assembly ----
union() {
    hummock();
    for (m = MUSHROOMS) {
        translate([m[0], m[1], BASE_H * 0.55])
            rotate([0, 0, m[4]])
                rotate([0, m[3], 0])
                    scale([m[2], m[2], m[2]])
                        mushroom_with_spots();
    }
}
