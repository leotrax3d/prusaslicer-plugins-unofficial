# Smart Print Presets

Smart Print Presets adds temporary Print Goals. A preset is an override layer on top of
the selected print, printer and filament profiles. Disabling it restores the underlying
configuration; it does not create or modify a saved PrusaSlicer profile.

The presets deliberately leave temperatures, cooling, maximum volumetric flow and machine
limits to the active profiles.

## Fast prototype

For early form and fit checks. Defaults cap the print at two perimeters, approximately
0.6 mm top and bottom thickness and 10% Lightning infill. The layer count is calculated
from the selected layer height. Ironing and the slower avoid-crossing-perimeters travel
strategy are disabled. Existing lower shell or infill values remain lower.

## Small parts

Caps small perimeters at 20 mm/s and external perimeters at 25 mm/s by default. It enables
automatic cooling with uniform slowdown, targets at least ten seconds per layer and permits
slowing to 5 mm/s. The material profile's fan limits remain authoritative, so enabling
cooling does not invent an unsafe fan percentage for ABS, ASA or another material.

## Strong functional part

Uses at least four perimeters, approximately 1.2 mm top and bottom thickness and 20% infill
by default. It also preserves vertical shell thickness, enables necessary extra perimeters
and gap fill, and prints perimeters before infill. It deliberately keeps the profile's
infill pattern because the best pattern depends on the load direction. Part orientation,
material and layer adhesion still determine whether a part is suitable for a load.

## Surface quality

Caps external-perimeter and top-surface speeds at 25 mm/s, uses at least three perimeters
and approximately 1.0 mm of top shell, and selects monotonic top fill. It preserves vertical
shell thickness, enables necessary extra perimeters, keeps the supported inner-to-outer wall
order and avoids crossing perimeters. Top-surface ironing is optional because it is not
beneficial on every geometry or material.

## Dimensional accuracy

Caps external perimeters at 30 mm/s and inner perimeters at 40 mm/s, uses at least three
perimeters, selects the Classic generator for constant-width walls, and prints the external
wall first. Thin-wall detection is disabled and Classic gap fill is enabled. These choices
favour predictable geometry but may be worse for very thin features and overhangs.

Measured XY compensation can optionally be applied, but defaults to off. Elephant-foot
compensation cannot currently be changed by a Print Goal and remains part of the selected
profile.

## Thin features & overhangs

Selects the Arachne perimeter generator and thin-wall detection, keeps gap fill enabled and
uses at least two perimeters where the geometry permits them. Inner walls remain first so
they support the outer overhang. Vertical shell thickness, necessary extra perimeters and
the experimental anchored overhang perimeters are enabled.

Dynamic overhang speeds are capped at 15, 15, 20 and 25 mm/s from unsupported to mostly
supported extrusion. Bridge speed is capped at 25 mm/s and the general external-wall speed
at 30 mm/s by default. Existing lower speeds stay lower. Curled-overhang travel avoidance
is enabled by default but can be disabled because it increases slicing and print time.

Fan percentages, bridge flow and support generation remain untouched: suitable values
depend on material, nozzle and the actual model rather than on this general print goal.

## Current API limitation

PrusaSlicer 3.0.0-alpha13 does not expose `layer_height` as a macro-overridable setting.
Choose the desired layer height in the normal print controls before selecting a preset.
