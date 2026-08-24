// Squirrel Relief Box
// A small lidded box with a stylized, raised squirrel silhouette on the lid.
// Artistic interpretation of a red squirrel spotted mid-bite in a burnt pine,
// reduced to a sitting-with-curled-tail pictogram built from unioned primitives
// (deliberately geometric/CSG-native rather than a traced photo outline).

$fn = 64;

// ---- Parameters ----
BOX_W   = 70;   // outer box width (x)
BOX_D   = 55;   // outer box depth (y)
BOX_H   = 28;   // outer box height, walls only (not counting lid)
WALL_T  = 2.4;  // wall thickness
FLOOR_T = 2.2;  // floor thickness
CORNER_R = 5;   // outer corner rounding radius

LID_T      = 3.0;  // lid slab thickness
LID_LIP_H  = 4.0;  // depth of the lip that plugs into the box cavity
LID_CLEARANCE = 0.25; // fit clearance, print-friendly

RELIEF_H  = 2.6;   // how far the squirrel stands proud of the lid surface
RELIEF_SCALE = 1.3; // overall scale of the silhouette on the lid
// approximate centroid of squirrel_silhouette() in its own local coordinates,
// used below to center the (scaled) relief on the lid
RELIEF_CENTROID = [-2.5, 9.5];

// ---- Helper: rounded rectangle ----
module rounded_rect(w, d, r) {
    hull() {
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx*(w/2 - r), sy*(d/2 - r)])
                circle(r = r);
    }
}

// ---- Squirrel silhouette, built as a union of primitives ----
// Local coordinate origin sits roughly at the squirrel's haunches.
// Tail is a chain of hulled circles along a curling arc -- thick where it
// leaves the body, tapering as it sweeps up and over the back -- which
// keeps it fused to the body silhouette rather than reading as a separate
// crescent/moon shape.
module squirrel_silhouette() {
    tail_pts = [
        [-4, -11, 9.5],
        [-15, -4, 10.5],
        [-18, 8,  9.5],
        [-13, 19, 7.5],
        [-4, 25,  5.0],
    ];

    module tail() {
        for (i = [0 : len(tail_pts) - 2]) {
            hull() {
                translate([tail_pts[i][0], tail_pts[i][1]]) circle(r = tail_pts[i][2]);
                translate([tail_pts[i+1][0], tail_pts[i+1][1]]) circle(r = tail_pts[i+1][2]);
            }
        }
    }

    union() {
        tail();
        // body: haunches (wide/low) blending to shoulders (narrower/higher)
        hull() {
            translate([0, -8]) scale([1.1, 0.95]) circle(r = 11);
            translate([2, 5])  circle(r = 7.5);
        }
        // chest bump / paws
        translate([8, 3]) circle(r = 3.8);
        // head
        translate([4, 13.5]) circle(r = 6.5);
        // ears
        translate([0.5, 18.8]) circle(r = 2.2);
        translate([7.5, 18.8]) circle(r = 2.2);
        // acorn at the mouth
        translate([11, 3.5]) circle(r = 1.9);
    }
}

// ---- Box body ----
module box_body() {
    difference() {
        // outer shell
        linear_extrude(height = BOX_H)
            rounded_rect(BOX_W, BOX_D, CORNER_R);
        // hollow cavity
        translate([0, 0, FLOOR_T])
            linear_extrude(height = BOX_H) // taller than needed, fine since it's a difference
                rounded_rect(BOX_W - 2*WALL_T, BOX_D - 2*WALL_T, max(CORNER_R - WALL_T, 1));
    }
}

// ---- Lid ----
module lid() {
    inner_w = BOX_W - 2*WALL_T - 2*LID_CLEARANCE;
    inner_d = BOX_D - 2*WALL_T - 2*LID_CLEARANCE;

    union() {
        // top slab, sized to the full outer footprint (overhangs the walls slightly like a proper lid)
        linear_extrude(height = LID_T)
            rounded_rect(BOX_W, BOX_D, CORNER_R);

        // plug/lip on the underside that registers into the box cavity
        translate([0, 0, -LID_LIP_H])
            linear_extrude(height = LID_LIP_H)
                rounded_rect(inner_w, inner_d, max(CORNER_R - WALL_T, 1));

        // raised squirrel relief on top of the lid, centered
        translate([-RELIEF_CENTROID[0]*RELIEF_SCALE, -RELIEF_CENTROID[1]*RELIEF_SCALE, LID_T])
            linear_extrude(height = RELIEF_H, scale = 1.0)
                scale(RELIEF_SCALE)
                    squirrel_silhouette();
    }
}

// ---- Layout: box on the left, lid (relief-up) on the right, both print-ready ----
box_body();
translate([BOX_W + 20, 0, 0]) lid();
