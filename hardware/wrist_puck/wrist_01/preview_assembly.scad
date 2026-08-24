use <wrist_mount_piece.scad>

// Rough visual check only -- axis alignment against a real puck
// model isn't attempted here, just spacing the two mirrored
// pieces apart by a placeholder puck width.
puck_width = 32;

translate([puck_width/2, 0, 0])
    color("steelblue")
    mount_piece();

translate([-puck_width/2, 0, 0])
    color("steelblue")
    mirror([1, 0, 0])
        mount_piece();
