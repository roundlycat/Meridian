/* ============================================================
   Meridian Shed — Parametric Parts Tray
   Companion piece to satellite_pod_v2.scad / Meridian Hub Case
   ============================================================
   Recessed wells sized per sub-project, with an engraved label
   strip along the front edge — readable at a glance from above
   without moving or opening anything.

   HOW TO USE
   ----------
   1. Edit the `wells` array below — one entry per compartment:
        [x_pos, y_pos, width, length, depth, "label", shape]
      shape is "round" (width = diameter) or "rect".
      x_pos/y_pos are the CENTER of the well, in a coordinate
      system that starts at (0,0) — the tray auto-sizes and
      auto-offsets around whatever you put in the array, so you
      can lay wells out on paper first and just copy positions.
   2. Tray footprint is fully automatic. If you want a fixed
      size instead (e.g. to match a shelf/bin), set tray_w_fixed
      and tray_l_fixed below zero.
   3. Render (F6), export STL. No supports needed — every well
      is an open top-down pocket with a flared top for easy
      fingertip pickup.
   4. Requires OpenSCAD 2019.05+ (uses list-comprehension max()).

   DEFAULTS BELOW are sized for: M3 heat-set inserts, LRA coin
   motors, a JST-SH connector kit, and loose DRV2605L boards /
   fasteners — i.e. today's bench. Change freely per tray.
   ============================================================ */

// ---------- General parameters ----------
wall          = 2.4;   // outer wall thickness
floor         = 2.2;   // floor thickness under the deepest well
tray_h        = 18;    // overall tray height
corner_r      = 4;     // rounded exterior corner radius
well_gap      = 4;     // spacing between adjacent wells
label_strip   = 11;    // depth (mm) of the engraved front label band
label_depth   = 0.4;   // engrave depth
label_size    = 4.2;   // text height (mm)
flare         = 2;     // extra radius/offset at well top for fingertip access
flare_h       = 3;     // height of the flared lead-in at each well's top

tray_w_fixed  = -1;    // set >0 to override auto width
tray_l_fixed  = -1;    // set >0 to override auto length

$fn = 64;

// ---------- Well definitions ----------
// [x, y, w, l, depth, label, shape]
wells = [
    [0,   0, 22, 22, 10, "M3 INSERTS", "round"],
    [34,  0, 18, 18,  7, "LRA",        "round"],
    [64,  0, 28, 36, 10, "JST KIT",    "rect"],
    [104, 0, 42, 32,  9, "DRV / MISC", "rect"]
];

// ---------- Auto-fit tray footprint ----------
function well_half_x(w) = (w[6] == "round") ? w[2]/2 : w[2]/2;
function well_half_y(w) = (w[6] == "round") ? w[2]/2 : w[3]/2;

max_x = max([for (w = wells) w[0] + well_half_x(w)]);
min_x = min([for (w = wells) w[0] - well_half_x(w)]);
max_y = max([for (w = wells) w[1] + well_half_y(w)]);
min_y = min([for (w = wells) w[1] - well_half_y(w)]);

auto_w = (max_x - min_x) + 2*(wall + well_gap);
auto_l = (max_y - min_y) + 2*(wall + well_gap) + label_strip;

tray_w = (tray_w_fixed > 0) ? tray_w_fixed : auto_w;
tray_l = (tray_l_fixed > 0) ? tray_l_fixed : auto_l;

offset_x = wall + well_gap - min_x;
offset_y = wall + well_gap + label_strip - min_y;

// ---------- Modules ----------

module rounded_box(w, l, h, r) {
    hull() {
        for (dx = [r, w - r])
            for (dy = [r, l - r])
                translate([dx, dy, 0])
                    cylinder(r = r, h = h);
    }
}

module well_round(d, depth, x, y) {
    // straight-walled pocket
    translate([x, y, tray_h - depth])
        cylinder(d = d, h = depth - flare_h + 0.01);
    // flared lead-in at the top for fingertip pickup
    translate([x, y, tray_h - flare_h])
        cylinder(d1 = d, d2 = d + 2*flare, h = flare_h + 0.5);
}

module well_rect(w, l, depth, x, y) {
    translate([x - w/2, y - l/2, tray_h - depth])
        cube([w, l, depth - flare_h + 0.01]);
    hull() {
        translate([x - w/2, y - l/2, tray_h - flare_h])
            cube([w, l, 0.01]);
        translate([x - w/2 - flare, y - l/2 - flare, tray_h])
            cube([w + 2*flare, l + 2*flare, 0.01]);
    }
}

module label(text_str, x) {
    translate([x, label_strip/2 + wall, tray_h - label_depth])
        linear_extrude(height = label_depth + 0.2)
            text(text_str, size = label_size, halign = "center",
                 valign = "center", font = "Liberation Sans:style=Bold");
}

// ---------- Assembly ----------
difference() {
    rounded_box(tray_w, tray_l, tray_h, corner_r);

    for (w = wells) {
        x = w[0] + offset_x;
        y = w[1] + offset_y;
        if (w[6] == "round") {
            well_round(w[2], w[4], x, y);
        } else {
            well_rect(w[2], w[3], w[4], x, y);
        }
    }

    for (w = wells)
        label(w[5], w[0] + offset_x);
}
