#!/usr/bin/env python3
"""Generates the Gridfinity locating foot as a binary STL.

The plugin API has primitives but no way to build a sloped mesh, so the 45 degree
faces of the foot used to be stairs of 0.2 mm slabs. This script writes the exact
shape once; box_generator.lua loads it with api.load_stl and places one copy per
grid cell.

The foot is lofted through rounded-square outlines. At each height the outline
is an offset of the 41.5 mm top square, so the corner radius shrinks with the
size exactly as an offset would: r = 3.75 - (41.5 - size) / 2.

    z [mm]   size [mm]   corner radius [mm]
    0.00     35.6        0.80      lower 45 degree ramp starts
    0.80     37.2        1.60      vertical section
    2.60     37.2        1.60      upper 45 degree ramp starts
    4.75     41.5        3.75      top of the base
    4.80     41.5        3.75      0.05 mm overlap into the bin body

Output: centred in X and Y, bottom at z = 0. Run from the repository root:

    python3 tools/gen-gridfinity-foot.py
"""

import math
import struct

OUT = "plugins/dev.leotrax3d.box-generator/gridfinity_foot.stl"
TOP_SIZE, TOP_RADIUS = 41.5, 3.75
PROFILE = [(0.0, 35.6), (0.8, 37.2), (2.6, 37.2), (4.75, 41.5), (4.8, 41.5)]
CORNER_SEGMENTS = 12  # per 90 degrees


def outline(size):
    """Counter-clockwise rounded square, same point count for every size."""
    r = TOP_RADIUS - (TOP_SIZE - size) / 2
    h = size / 2 - r
    points = []
    for cx, cy, start in ((h, h, 0), (-h, h, 90), (-h, -h, 180), (h, -h, 270)):
        for i in range(CORNER_SEGMENTS + 1):
            a = math.radians(start + 90 * i / CORNER_SEGMENTS)
            # Rounded so the file is byte-identical on every platform's libm,
            # which lets CI check that the committed STL is up to date.
            points.append((round(cx + r * math.cos(a), 4), round(cy + r * math.sin(a), 4)))
    return points


def normal(a, b, c):
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    n = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
    length = math.sqrt(sum(x * x for x in n)) or 1.0
    return tuple(x / length for x in n)


def main():
    rings = [[(x, y, z) for x, y in outline(size)] for z, size in PROFILE]
    n = len(rings[0])
    triangles = []

    # Side walls between consecutive rings, wound outwards.
    for lower, upper in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            triangles.append((lower[i], lower[j], upper[j]))
            triangles.append((lower[i], upper[j], upper[i]))

    # Caps: the outline is convex, so a fan from the centre is valid.
    bottom, top = rings[0], rings[-1]
    bc, tc = (0.0, 0.0, bottom[0][2]), (0.0, 0.0, top[0][2])
    for i in range(n):
        j = (i + 1) % n
        triangles.append((bc, bottom[j], bottom[i]))
        triangles.append((tc, top[i], top[j]))

    with open(OUT, "wb") as f:
        f.write(b"Gridfinity foot, tools/gen-gridfinity-foot.py".ljust(80, b" "))
        f.write(struct.pack("<I", len(triangles)))
        for a, b, c in triangles:
            f.write(struct.pack("<3f", *normal(a, b, c)))
            for p in (a, b, c):
                f.write(struct.pack("<3f", *p))
            f.write(b"\0\0")
    print(f"{OUT}: {len(triangles)} triangles")


if __name__ == "__main__":
    main()
