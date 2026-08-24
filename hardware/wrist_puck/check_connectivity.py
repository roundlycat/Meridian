"""
Check whether an STL is a single connected solid, or several
disconnected islands held together by nothing (which is exactly the
failure mode that produced the two floating ears + support-lattice
print). "Simple: yes" from OpenSCAD does NOT check this -- it only
checks that each individual piece is locally manifold, not that the
pieces are joined to each other. This does the check that was
actually missing.

Method: parse all triangles, merge vertices that share a position
(within a small tolerance -- ASCII STL doesn't share vertex indices
between triangles, so position-matching is required), then union-find
over triangles that share a vertex. One connected component = good.
More than one = the model will print as separate islands, exactly
like the ear failure.
"""
import sys


def read_ascii_stl(path):
    tris = []
    with open(path) as f:
        cur = []
        for line in f:
            line = line.strip()
            if line.startswith('vertex'):
                parts = line.split()
                cur.append((round(float(parts[1]), 3),
                            round(float(parts[2]), 3),
                            round(float(parts[3]), 3)))
                if len(cur) == 3:
                    tris.append(tuple(cur))
                    cur = []
    return tris


def read_binary_stl(path):
    import struct
    tris = []
    with open(path, 'rb') as f:
        f.read(80)
        n = struct.unpack('<I', f.read(4))[0]
        for _ in range(n):
            f.read(12)
            verts = []
            for _ in range(3):
                x, y, z = struct.unpack('<3f', f.read(12))
                verts.append((round(x, 3), round(y, 3), round(z, 3)))
            f.read(2)
            tris.append(tuple(verts))
    return tris


def read_stl(path):
    with open(path, 'rb') as f:
        head = f.read(5)
    if head == b'solid':
        return read_ascii_stl(path)
    return read_binary_stl(path)


class UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))

    def find(self, x):
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[ra] = rb


def check_connectivity(path):
    tris = read_stl(path)
    n = len(tris)
    uf = UnionFind(n)

    vertex_to_tris = {}
    for i, tri in enumerate(tris):
        for v in tri:
            vertex_to_tris.setdefault(v, []).append(i)

    for v, tri_list in vertex_to_tris.items():
        first = tri_list[0]
        for other in tri_list[1:]:
            uf.union(first, other)

    components = {}
    for i in range(n):
        root = uf.find(i)
        components.setdefault(root, []).append(i)

    return components


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'piece_ears_v2.stl'
    components = check_connectivity(path)
    print(f"{path}: {len(components)} connected component(s), "
          f"{sum(len(v) for v in components.values())} triangles total")
    for root, tri_indices in sorted(components.items(), key=lambda kv: -len(kv[1])):
        print(f"  component: {len(tri_indices)} triangles")
    if len(components) == 1:
        print("PASS -- single connected solid")
    else:
        print(f"FAIL -- {len(components)} disconnected islands, will print like the ear bug")
