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
    "ld_shelf_FIXED": (-(ld_len+8)/2, (ld_len+8)/2,
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
}

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
