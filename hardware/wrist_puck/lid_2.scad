// ============================================================
// Ornate lid — layered relief exploration
// Piranesi/Escher-density recursive border + a small "robotic
// pastoral" scene (Pollen-Pod-like creature among coral/vine
// mounds) in the center, using the heightmap/surface() pipeline
// from the cameo project (deliberately, this time, for a piece
// whose only job is to be looked at).
//
// Standalone exploration -- not yet matched to a specific box
// body. LID_D is a starting guess; true up once a box diameter
// is actually chosen.
// ============================================================

LID_D        = 70;     // lid diameter, mm -- placeholder until a box exists
RELIEF_DEPTH = 3.2;     // mm, total height variation across the relief
BASE_T       = 2.2;     // mm, solid base thickness under the relief
HM_PX        = 240;     // heightmap resolution (must match gen_heightmap.py)

// Simple lip on the underside so this can seat into a box opening
// later -- sized generously for now, true up once the box exists.
LIP_D = LID_D - 6;
LIP_H = 3.0;

$fn = 100;

module lid_blank() {
    union() {
        // base disc
        cylinder(h = BASE_T, d = LID_D);

        // seating lip, underside
        translate([0, 0, -LIP_H + 0.1])
            cylinder(h = LIP_H, d = LIP_D);

        // relief surface, scaled from pixel space into real mm and
        // into RELIEF_DEPTH, then trimmed round by the intersection
        // below
        intersection() {
            translate([-LID_D/2, -LID_D/2, BASE_T])
                scale([LID_D / HM_PX, LID_D / HM_PX, RELIEF_DEPTH / 65535])
                    surface(file = "lid_heightmap.png", center = false, convexity = 10);
            translate([0, 0, BASE_T])
                cylinder(h = RELIEF_DEPTH + 1, d = LID_D);
        }
    }
}

lid_blank();
