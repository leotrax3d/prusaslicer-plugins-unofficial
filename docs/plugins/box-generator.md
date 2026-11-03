# Gridfinity Bin Generator

**Plugin:** `dev.leotrax3d.box-generator` · **Menu:** Generators → Gridfinity Bin

Generates Gridfinity-compatible storage bins from the published 42 mm grid and 7 mm
height unit. Gridfinity was created by Zack Freedman; this independently implemented
generator is not affiliated with or endorsed by him or the Gridfinity community.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| Grid Units X / Y | 1 × 1 | Footprint in 42 mm grid cells |
| Height Units | 3 | Body height in 7 mm units |
| Wall Thickness | 1.2 mm | Outer wall thickness |
| Floor Thickness | 1.2 mm | Material above the locating foot |
| Compartments Across / Deep | 1 × 1 | Separate internal pockets |
| Divider Thickness | 1.2 mm | Material left between pockets |
| 6×2 mm Magnet Pockets | off | Four 6.5×2.4 mm pockets per grid cell |
| Stacking Lip | on | Adds the upper locating rim |
| Front Label | empty | Engraves text into the front wall |

One unit is 41.5 × 41.5 mm outside, leaving 0.5 mm total clearance in a 42 mm grid.
The locating base is 4.75 mm high: 0.8 mm lower 45° ramp, 1.8 mm vertical section and
2.15 mm upper 45° ramp. The 4.4 mm stacking profile uses the published 0.7 / 1.8 /
1.9 mm sections and 0.25 mm offset per side.

The locating foot is a real mesh, `gridfinity_foot.stl`, with exact 45° faces and corner
radii that shrink with the offset (3.75 mm at the top, 0.8 mm at the bottom). The plugin
loads it once and places one copy per grid cell. `tools/gen-gridfinity-foot.py` generates
it, and CI fails if the committed file does not match the script. The stacking lip is
still built in printable 0.2 mm steps: its length depends on the bin size, and the plugin
API can neither build a sloped mesh nor stretch a loaded one.

## Implementation and validation

Each compartment is cut as an independent negative pocket. The solid material between
pockets therefore remains a divider even though PrusaSlicer sorts all positive volumes
before all negative volumes. This replaces the invalid ordering assumption in version
1.0.0.

The automated geometry test checks the 41.5 mm footprint, 7 mm height system, locating
foot, divider survival and four magnet pockets per occupied grid cell. A physical
Gridfinity baseplate and stacking test is still required before calling the fit proven.

Gridfinity is available under the MIT licence. No third-party generator code or mesh is
included here; the dimensions are implemented directly.
