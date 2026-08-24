"""
Build a watertight, printable lid mesh directly from a heightmap
array -- bypassing OpenSCAD's surface()/CGAL pipeline entirely.

Why: CGAL Nef polyhedron booleans (what OpenSCAD uses under the hood
for union/intersection/difference) scale terribly with triangle
count, regardless of *why* the count is high -- concave-shape unions
(the cameo project) or just a dense heightmap grid (this lid) hit the
same wall. The fix here is the same fix lithophane generators use:
skip CSG entirely. Sample the heightmap on a polar grid, build
top surface + side wall + bottom cap + lip as one manifold mesh by
hand, write STL directly. No booleans, so no CGAL ceiling -- this
scales to hundreds of thousands of triangles fine because it's just
vectorized numpy + a triangle list, not a Nef polyhedron operation.
"""
import numpy as np
import struct

def bilinear_sample(height_arr, cx_px, cy_px, R_px, R_mm, r_mm, theta):
    """Sample the heightmap at real-world (r_mm, theta) via bilinear
    interpolation. r_mm/theta can be numpy arrays."""
    H, W = height_arr.shape
    r_px = r_mm / R_mm * R_px
    px = cx_px + r_px * np.cos(theta)
    py = cy_px + r_px * np.sin(theta)
    px = np.clip(px, 0, W - 1.001)
    py = np.clip(py, 0, H - 1.001)
    x0 = np.floor(px).astype(int); x1 = x0 + 1
    y0 = np.floor(py).astype(int); y1 = y0 + 1
    fx = px - x0; fy = py - y0
    v00 = height_arr[y0, x0]; v10 = height_arr[y0, x1]
    v01 = height_arr[y1, x0]; v11 = height_arr[y1, x1]
    top = v00 * (1 - fx) + v10 * fx
    bot = v01 * (1 - fx) + v11 * fx
    return top * (1 - fy) + bot * fy


def build_lid_mesh(height_arr, LID_D, BASE_T, RELIEF_DEPTH,
                    LIP_D, LIP_H, n_rings=220, n_theta=480):
    H, W = height_arr.shape
    cx_px, cy_px = W / 2, H / 2
    R_px = min(W, H) / 2 * 0.97   # matches the R used in gen_heightmap.py
    R_mm = LID_D / 2

    thetas = np.linspace(0, 2 * np.pi, n_theta, endpoint=False)
    radii = np.linspace(0, R_mm, n_rings)   # radii[0] = 0 (apex)

    verts = []
    tris = []

    # ---- apex (top center) ----
    apex_h = bilinear_sample(height_arr, cx_px, cy_px, R_px, R_mm,
                              np.array([0.0]), np.array([0.0]))[0]
    verts.append((0.0, 0.0, BASE_T + RELIEF_DEPTH * apex_h))
    apex_i = 0

    # ---- top surface rings (index 1..n_rings-1) ----
    ring_first_idx = [None] * n_rings   # ring_first_idx[0] unused (apex)
    for ri in range(1, n_rings):
        r = radii[ri]
        hs = bilinear_sample(height_arr, cx_px, cy_px, R_px, R_mm,
                              np.full(n_theta, r), thetas)
        ring_first_idx[ri] = len(verts)
        for j, th in enumerate(thetas):
            x = r * np.cos(th); y = r * np.sin(th)
            z = BASE_T + RELIEF_DEPTH * hs[j]
            verts.append((x, y, z))

    # fan the apex to ring 1
    r1 = ring_first_idx[1]
    for j in range(n_theta):
        j2 = (j + 1) % n_theta
        tris.append((apex_i, r1 + j, r1 + j2))

    # connect ring i to ring i+1 with quads (2 tris each)
    for ri in range(1, n_rings - 1):
        a0 = ring_first_idx[ri]
        b0 = ring_first_idx[ri + 1]
        for j in range(n_theta):
            j2 = (j + 1) % n_theta
            a, a2 = a0 + j, a0 + j2
            b, b2 = b0 + j, b0 + j2
            tris.append((a, b, b2))
            tris.append((a, b2, a2))

    outer_top_first = ring_first_idx[n_rings - 1]

    # ---- outer side wall: top outer ring down to a matching bottom
    # outer ring at z=0 ----
    bottom_outer_first = len(verts)
    for j in range(n_theta):
        th = thetas[j]
        x = R_mm * np.cos(th); y = R_mm * np.sin(th)
        verts.append((x, y, 0.0))
    for j in range(n_theta):
        j2 = (j + 1) % n_theta
        t, t2 = outer_top_first + j, outer_top_first + j2
        b, b2 = bottom_outer_first + j, bottom_outer_first + j2
        tris.append((t, t2, b2))
        tris.append((t, b2, b))

    # ---- bottom cap: flat disc at z=0, from bottom outer ring in to
    # the lip's outer radius, then the lip drops down to LIP_H, then
    # a small flat lip-bottom cap closes it off ----
    lip_r = LIP_D / 2
    bottom_lip_top_first = len(verts)
    for j in range(n_theta):
        th = thetas[j]
        x = lip_r * np.cos(th); y = lip_r * np.sin(th)
        verts.append((x, y, 0.0))
    # ring connecting bottom_outer (R_mm, z=0) to bottom_lip_top (lip_r, z=0)
    for j in range(n_theta):
        j2 = (j + 1) % n_theta
        o, o2 = bottom_outer_first + j, bottom_outer_first + j2
        l, l2 = bottom_lip_top_first + j, bottom_lip_top_first + j2
        tris.append((o, o2, l2))
        tris.append((o, l2, l))

    # lip wall: drop from z=0 to z=-LIP_H at radius lip_r
    lip_bottom_first = len(verts)
    for j in range(n_theta):
        th = thetas[j]
        x = lip_r * np.cos(th); y = lip_r * np.sin(th)
        verts.append((x, y, -LIP_H))
    for j in range(n_theta):
        j2 = (j + 1) % n_theta
        t, t2 = bottom_lip_top_first + j, bottom_lip_top_first + j2
        b, b2 = lip_bottom_first + j, lip_bottom_first + j2
        tris.append((t, t2, b2))
        tris.append((t, b2, b))

    # cap the very bottom of the lip (flat disc at z=-LIP_H)
    lip_center_i = len(verts)
    verts.append((0.0, 0.0, -LIP_H))
    for j in range(n_theta):
        j2 = (j + 1) % n_theta
        tris.append((lip_center_i, lip_bottom_first + j2, lip_bottom_first + j))

    return np.array(verts, dtype=np.float64), np.array(tris, dtype=np.int64)


def check_manifold(verts, tris):
    """Every edge should be shared by exactly 2 triangles for a
    closed, watertight manifold mesh."""
    from collections import Counter
    edge_count = Counter()
    for a, b, c in tris:
        for u, v in ((a, b), (b, c), (c, a)):
            edge_count[(min(u, v), max(u, v))] += 1
    bad = [e for e, n in edge_count.items() if n != 2]
    return bad


def write_binary_stl(path, verts, tris):
    # NOTE: tris are wound with the OPPOSITE convention to what
    # produces outward-facing normals for this mesh (confirmed by
    # computing signed volume -- came out negative before this fix).
    # Swapping b/c here rather than rederiving every triangle's
    # winding above.
    with open(path, 'wb') as f:
        f.write(b'\x00' * 80)
        f.write(struct.pack('<I', len(tris)))
        for a, b, c in tris:
            v0, v1, v2 = verts[a], verts[c], verts[b]   # swapped b/c
            n = np.cross(v1 - v0, v2 - v0)
            norm = np.linalg.norm(n)
            n = n / norm if norm > 0 else np.array([0.0, 0.0, 1.0])
            f.write(struct.pack('<3f', *n))
            for v in (v0, v1, v2):
                f.write(struct.pack('<3f', *v))
            f.write(struct.pack('<H', 0))


def signed_volume(verts, tris):
    """Should be positive for a correctly-wound (outward-normal)
    closed mesh. If negative, winding is inverted -- fix in
    write_binary_stl, not by hand-editing an STL after the fact."""
    v = 0.0
    for a, b, c in tris:
        v0, v1, v2 = verts[a], verts[c], verts[b]  # matches the STL winding fix
        v += np.dot(v0, np.cross(v1, v2)) / 6.0
    return v


if __name__ == '__main__':
    height_arr = np.load('lid_heightmap.npy')

    LID_D        = 77   # measured case rim OD 75.5mm + ~0.75mm overhang per side
    RELIEF_DEPTH = 3.2
    BASE_T       = 2.2
    LIP_D        = 70.7   # measured case inner opening 71.5mm - 0.8mm clearance (0.4/side), loose dry-fit
    LIP_H        = 3.0

    verts, tris = build_lid_mesh(height_arr, LID_D, BASE_T, RELIEF_DEPTH,
                                  LIP_D, LIP_H, n_rings=220, n_theta=480)
    print(f"vertices: {len(verts)}  triangles: {len(tris)}")

    bad_edges = check_manifold(verts, tris)
    print(f"non-manifold edges: {len(bad_edges)}")
    if bad_edges[:5]:
        print("  sample:", bad_edges[:5])

    vol = signed_volume(verts, tris)
    print(f"signed volume: {vol:.1f} mm^3  ({'OK, outward normals' if vol > 0 else 'INVERTED -- fix winding'})")

    write_binary_stl('lid_direct.stl', verts, tris)
    print("wrote lid_direct.stl")
