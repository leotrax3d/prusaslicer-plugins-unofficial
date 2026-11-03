#!/usr/bin/env python3
"""Generates the Gridfinity meshes the bin generator loads with api.load_stl.

The plugin API has primitives but no way to build a sloped mesh, and a loaded mesh
cannot be stretched. So the sloped parts are generated here once, in pieces that
tile every bin size:

gridfinity_foot.stl
    The locating foot, one per grid cell. Lofted through rounded-square outlines;
    each is an offset of the 41.5 mm top square, so the corner radius shrinks with
    the size: r = 3.75 - (41.5 - size) / 2.

        z [mm]   size [mm]   corner radius [mm]
        0.00     35.6        0.80      lower 45 degree ramp starts
        0.80     37.2        1.60      vertical section
        2.60     37.2        1.60      upper 45 degree ramp starts
        4.75     41.5        3.75      top of the base
        4.80     41.5        3.75      0.05 mm overlap into the bin body

gridfinity_lip_corner.stl, gridfinity_lip_42.stl, gridfinity_lip_34.stl
    The stacking lip. Its cross-section, measured inwards from the outer wall, is
    the published 0.7 / 1.8 / 1.9 mm profile. The vertical face sits 1.9 mm in,
    which leaves the 37.2 mm foot of the bin above 0.25 mm per side. The knife
    edge on top is cut off at 0.7 mm, which prints cleanly and does not change
    the fit: stacking bins touch only the slopes.

        z [mm]   wall [mm]
        0.0      2.6       sits on the body top
        0.7      1.9       45 degree chamfer
        2.5      1.9       vertical
        3.7      0.7       45 degree chamfer, flat top

gridfinity_support_corner.stl, gridfinity_support_42.stl, gridfinity_support_34.stl
    Negative volumes that carve a 45 degree support under the lip, so the lip's
    2.6 mm inner edge does not overhang the cavity. They remove the triangle
    below the slope from the 1.2 mm wall to 2.6 mm; tiled like the lip.

        z [mm]   wall [mm]
        0.0      1.2 .. 2.6   bottom edge of the removed triangle
        1.4      2.6          apex, where the support meets the lip backing

gridfinity_pocket.stl
    Negative volume for the hollow UltraLight base, one per grid cell: the foot
    offset 1.0 mm inwards, over a 1.0 mm floor, opening up to the 1.2 mm wall.

        z [mm]   size [mm]
        1.000    35.2      floor top
        3.014    35.2      vertical, 1.0 mm inside the foot
        4.964    39.1      45 degree, 1.0 mm normal to the foot slope
        5.000    39.1      0.036 mm overlap into the cavity above

    A bin side of n units is 42 n - 0.5 mm long; minus two 3.75 mm corners that
    leaves 42 n - 8 mm, covered by n - 1 straight 42 mm pieces and one 34 mm piece.
    The straight pieces run along +X with the wall inwards along +Y. The corner is
    the front-left quarter, swept about its arc centre at the origin. The generator
    rotates both into place.

Every file is centred or anchored as described and rounded to 0.1 um, so it is
byte-identical on every platform. CI regenerates the files and fails on a diff.
Run from the repository root:

    python3 tools/gen-gridfinity-meshes.py
"""

import math
import struct

DIR = "plugins/dev.leotrax3d.box-generator/"
TOP_SIZE, TOP_RADIUS = 41.5, 3.75
FOOT_PROFILE = [(0.0, 35.6), (0.8, 37.2), (2.6, 37.2), (4.75, 41.5), (4.8, 41.5)]
LIP_PROFILE = [(0.0, 0.0), (2.6, 0.0), (1.9, 0.7), (1.9, 2.5), (0.7, 3.7), (0.0, 3.7)]
SUPPORT_PROFILE = [(1.2, 0.0), (2.6, 0.0), (2.6, 1.4)]
# The foot's upper slope runs x = 18.6 + (z - 2.6) from the centre. Offset 1.0 mm
# along its normal is sqrt(2) mm horizontally, so the pocket's slope runs
# x = 16.0 + z - sqrt(2): it leaves the 17.6 mm vertical face at z = 1.6 + sqrt(2)
# and reaches the 19.55 mm wall (41.5 / 2 - 1.2) at z = 3.55 + sqrt(2).
SQRT2 = math.sqrt(2)
POCKET_PROFILE = [(1.0, 35.2), (1.6 + SQRT2, 35.2), (3.55 + SQRT2, 39.1), (5.0, 39.1)]
CORNER_SEGMENTS = 12  # per 90 degrees


def r4(v):
    return round(v, 4)


def foot_outline(size):
    """Counter-clockwise rounded square, same point count for every size."""
    r = TOP_RADIUS - (TOP_SIZE - size) / 2
    h = size / 2 - r
    points = []
    for cx, cy, start in ((h, h, 0), (-h, h, 90), (-h, -h, 180), (h, -h, 270)):
        for i in range(CORNER_SEGMENTS + 1):
            a = math.radians(start + 90 * i / CORNER_SEGMENTS)
            points.append((r4(cx + r * math.cos(a)), r4(cy + r * math.sin(a))))
    return points


def loft(rings, closed):
    """Quads between consecutive rings of equal length, plus fan caps."""
    tris = []
    n = len(rings[0])
    span = n if closed else n - 1
    for lower, upper in zip(rings, rings[1:]):
        for i in range(span):
            j = (i + 1) % n
            tris.append((lower[i], lower[j], upper[j]))
            tris.append((lower[i], upper[j], upper[i]))
    return tris


def fan(points):
    return [(points[0], points[i], points[i + 1]) for i in range(1, len(points) - 1)]


def signed_volume(tris):
    v = 0.0
    for a, b, c in tris:
        v += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0])
              + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6
    return v


def orient(tris):
    """Makes the winding consistent across shared edges, then outward."""
    edges = {}
    for k, (a, b, c) in enumerate(tris):
        for e in ((a, b), (b, c), (c, a)):
            edges.setdefault(frozenset(e), []).append(k)
    tris = [list(t) for t in tris]
    done = [False] * len(tris)
    for seed in range(len(tris)):
        if done[seed]:
            continue
        done[seed] = True
        stack = [seed]
        while stack:
            k = stack.pop()
            a, b, c = tris[k]
            for u, v in ((a, b), (b, c), (c, a)):
                for m in edges[frozenset((u, v))]:
                    if m == k or done[m]:
                        continue
                    x, y, z = tris[m]
                    # A neighbour must traverse the shared edge the other way.
                    if (u, v) in ((x, y), (y, z), (z, x)):
                        tris[m] = [x, z, y]
                    done[m] = True
                    stack.append(m)
    tris = [tuple(t) for t in tris]
    if signed_volume(tris) < 0:
        tris = [(a, c, b) for a, b, c in tris]
    return tris


def write(name, tris):
    tris = orient(tris)
    with open(DIR + name, "wb") as f:
        f.write(f"{name}, tools/gen-gridfinity-meshes.py".encode().ljust(80, b" "))
        f.write(struct.pack("<I", len(tris)))
        for a, b, c in tris:
            u = [b[i] - a[i] for i in range(3)]
            v = [c[i] - a[i] for i in range(3)]
            n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            length = math.sqrt(sum(x * x for x in n)) or 1.0
            f.write(struct.pack("<3f", *(x / length for x in n)))
            for p in (a, b, c):
                f.write(struct.pack("<3f", *p))
            f.write(b"\0\0")
    print(f"{DIR + name}: {len(tris)} triangles")




def straight(profile, length):
    # Profile in the YZ plane: y is the wall thickness inwards from the outer face.
    start = [(0.0, t, z) for t, z in profile]
    end = [(r4(length), t, z) for t, z in profile]
    return loft([start, end], closed=True) + fan(start) + fan(end)


def corner(profile):
    # Swept 180 -> 270 degrees about the origin, the corner's arc centre. A wall
    # thickness t sits at radius TOP_RADIUS - t, exactly as an offset would.
    rings = []
    for i in range(CORNER_SEGMENTS + 1):
        a = math.radians(180 + 90 * i / CORNER_SEGMENTS)
        rings.append([(r4((TOP_RADIUS - t) * math.cos(a)), r4((TOP_RADIUS - t) * math.sin(a)), z)
                      for t, z in profile])
    return loft(rings, closed=True) + fan(rings[0]) + fan(rings[-1])


def rounded_loft(profile):
    rings = [[(x, y, r4(z)) for x, y in foot_outline(size)] for z, size in profile]
    tris = loft(rings, closed=True)
    tris += fan([(0.0, 0.0, rings[0][0][2])] + rings[0] + [rings[0][0]])
    tris += fan([(0.0, 0.0, rings[-1][0][2])] + rings[-1] + [rings[-1][0]])
    return tris


def main():
    write("gridfinity_foot.stl", rounded_loft(FOOT_PROFILE))
    write("gridfinity_pocket.stl", rounded_loft(POCKET_PROFILE))
    for name, profile in (("lip", LIP_PROFILE), ("support", SUPPORT_PROFILE)):
        write(f"gridfinity_{name}_corner.stl", corner(profile))
        write(f"gridfinity_{name}_42.stl", straight(profile, 42.0))
        write(f"gridfinity_{name}_34.stl", straight(profile, 34.0))


if __name__ == "__main__":
    main()
