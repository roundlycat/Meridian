"""
Connectivity checker for presence_node_v0.9.scad.
Models every additive feature as an axis-aligned box (or bounding
box for cylinders), and checks whether it has REAL overlap (not
just zero-gap touching) with the wall shell or with another
feature that's already confirmed connected. This replaces doing
this arithmetic by hand, which has produced wrong answers twice
already in this project (the rain_hood detachment, the lid_boss
0.1mm gap).
"""

# ---- params.scad values (v0.9) ----
body_width, body_depth, body_height = 68, 45, 55
wall = 2.4
bat_len, bat_wid, bat_thick = 56, 34, 11
ld_len, ld_wid, ld_thick = 35, 7, 7.4

hx, hy, hz = body_width/2, body_depth/2, body_height/2

# ---- Wall zones (the "shell" - solid material) ----
# Note: top has ZERO thickness in this design (open top, for the
# lid) - the inner cavity's top face coincides with the outer top
# face exactly, so there is no top wall to anchor to.
walls = {
    "left":   (-hx, -hx+wall,  -hy, hy,        -hz, hz),
    "right":  (hx-wall, hx,    -hy, hy,        -hz, hz),
    "front":  (-hx, hx,         hy-wall, hy,   -hz, hz),
    "back":   (-hx, hx,        -hy, -hy+wall,  -hz, hz),
    "bottom": (-hx, hx,         -hy, hy,       -hz, -hz+wall*2),  # 4.8mm thick due to asymmetric cavity offset
}

def overlap_1d(a0, a1, b0, b1):
    return max(0.0, min(a1, b1) - max(a0, b0))

def overlap_3d(box_a, box_b):
    ax0,ax1,ay0,ay1,az0,az1 = box_a
    bx0,bx1,by0,by1,bz0,bz1 = box_b
    ox = overlap_1d(ax0,ax1,bx0,bx1)
    oy = overlap_1d(ay0,ay1,by0,by1)
    oz = overlap_1d(az0,az1,bz0,bz1)
    return ox, oy, oz, (ox > 0 and oy > 0 and oz > 0)

# ---- Features, AFTER the proposed v0.10 fixes ----
shelf_z = body_height/6
features = {
    "rain_hood": (-39, 39, 16.1, 40.5, 16.66, 19.66),  # unrotated approx, fine for overlap check
    "mcu_plate_FIXED": (-(body_width-2*wall-4)/2, (body_width-2*wall-4)/2,
                         -(body_depth-2*wall+1.2)/2, (body_depth-2*wall+1.2)/2,
                         -4, -2),
    "ld_shelf_FIXED": (19.5-2, 19.5+2,
                        -(body_depth-2*wall+1.2)/2, (body_depth-2*wall+1.2)/2,
                        shelf_z-ld_thick/2-1, shelf_z-ld_thick/2+1),
    "ld_side_stop_R": (ld_len/2+2-1, ld_len/2+2+1, -5, 5,
                        shelf_z-ld_thick/2-2-1, shelf_z+ld_thick/2+2-1+ (ld_thick+4)),
    "ld_rear_stop": (-(ld_len+8)/2, (ld_len+8)/2,
                      -(body_depth/2-wall-4)-1.5, -(body_depth/2-wall-4)+1.5,
                      shelf_z-(ld_thick+4)/2, shelf_z+(ld_thick+4)/2),
    "battery_floor": (-(bat_len+4)/2, (bat_len+4)/2, -(bat_wid+4)/2, (bat_wid+4)/2,
                       -hz+wall+1-1, -hz+wall+1+1),
    "battery_rail_FIXED": (bat_len/2+1-1, bat_len/2+1+1, -(bat_wid+4)/2, (bat_wid+4)/2,
                            -hz+wall+0.8, -hz+wall+0.8+bat_thick),
    "lid_boss_pp": (24-5, 24+5, 17.5-5, 17.5+5, 14, 22),  # one corner, representative
    "gusset_base": (-39, 39, 21-2, 21+2, -6-2, -6+2),
    "gusset_tip": (-39, 39, 38-2, 38+2, 16-3, 16+3),
}

# ---- Window clearance check ----
# Window cutout (from presence_body): x in [-20.5,20.5],
# y in [20.9,24.3], z in [2.67,15.67]. The wedge does NOT get
# this cutout applied to it (only presence_body's own geometry
# gets the window subtracted) - so if the wedge's hull extends
# into this box at all, it would fill in the window.
window_box = (-20.5, 20.5, 20.9, 24.3, 2.67, 15.67)

def steepest_corner_z_at_y(y_target, base_y, base_top_z, tip_y, tip_bottom_z):
    # Worst-case (fastest-rising) line through the hull: from the
    # most-forward point of the base box's TOP to the most-rearward
    # point of the tip box's BOTTOM.
    base_front_y = base_y + 2   # base cube half-depth = 2
    tip_rear_y = tip_y - 2      # tip cube half-depth = 2
    run = tip_rear_y - base_front_y
    rise = tip_bottom_z - base_top_z
    if y_target <= base_front_y:
        return base_top_z
    frac = (y_target - base_front_y) / run
    return base_top_z + frac * rise

z_at_window_far_edge = steepest_corner_z_at_y(24.3, 21, -6+2, 38, 16-3)
print(f"\nWedge worst-case z at window's far Y edge (24.3): {z_at_window_far_edge:.2f}")
print(f"Window bottom z: 2.67  ->  clearance: {2.67 - z_at_window_far_edge:.2f}mm")


print(f"{'Feature':<22} {'vs':<12} {'ox':>6} {'oy':>6} {'oz':>6}  connected?")
print("-"*70)

connected = set()
all_boxes = {**{f"WALL:{k}": v for k,v in walls.items()}}
for name, box in features.items():
    best = None
    for ref_name, ref_box in {**walls, **{n:b for n,b in features.items() if n != name}}.items():
        ox, oy, oz, ok = overlap_3d(box, ref_box)
        if ok and (best is None or min(ox,oy,oz) > best[1]):
            best = (ref_name, min(ox,oy,oz))
    if best:
        print(f"{name:<22} {best[0]:<12} {'':>6} {'':>6} {'':>6}  YES (min overlap {best[1]:.2f}mm)")
        connected.add(name)
    else:
        print(f"{name:<22} {'NONE':<12} {'':>6} {'':>6} {'':>6}  *** FLOATING ***")
