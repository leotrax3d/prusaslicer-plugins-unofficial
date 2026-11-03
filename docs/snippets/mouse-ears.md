# Mouse ears (start G-code snippet)

Prints a flat disc on each corner of the first layer before the object starts, to hold
down corners that would otherwise warp. It works on any model, including ones the
plugins did not generate, because the slicer itself supplies the positions.

This is a start G-code snippet, not a plugin. A plugin cannot do it; see
[why not](#why-this-is-not-a-plugin).

**Status: untested.** Derived from PrusaSlicer's source, but not yet sliced or printed.
Follow the checks below before printing with it.

## Install

1. Printer Settings → Custom G-code → **Start G-code**.
2. Paste [`mouse-ears-start-gcode.gcode`](mouse-ears-start-gcode.gcode) at the **end**,
   after the purge line. At that point the nozzle is hot and primed.
3. Save the printer preset under a new name, such as "MINI + ears", so you can switch
   ears on and off by switching presets.

## Check before the first print

1. **Slice.** If a variable does not exist in your build, slicing stops with an error
   naming the variable. Prime suspects are `first_layer_height` (if it is a percentage)
   and `skirts`.
2. **Preview.** The G-code viewer draws custom G-code moves, so four discs must appear
   at the corners of the part. A disc that is missing, a fraction of a circle, or a
   spiral heading off across the bed means the arc command was rejected or
   misinterpreted.
3. **Watch the first disc.** Stop if it under- or over-extrudes. The flow is computed
   from `nozzle_diameter`, `first_layer_height` and `filament_diameter`.

## How it works

`GCode.cpp` sets `first_layer_print_min` and `first_layer_print_max` (the bounding box of
the first layer's convex hull) before it processes the start G-code. Prusa's own profiles
place the purge line with the same variables. The snippet takes the four corners of that
box and prints 12 concentric circles around each, about 24 line widths across, with
`G2` arcs in relative extrusion. Afterwards it restores the extrusion mode and resets `E`.

## Limits

- **Box corners, not part corners.** On a rectangular part aligned to the axes they are
  the same. On a round part, or one rotated 45°, the box corners lie outside the part
  and the discs miss it.
- **One box for the whole plate.** With several objects there are ears on the outer
  corners of the whole layout only.
- **Skirt.** The box includes the skirt, so the snippet steps back by
  `skirt_distance + skirts × line width`. A brim belongs to the part's footprint, so
  ears land on the brim. A draft shield is not accounted for.
- **Bed edge.** A part placed less than about 5.5 mm from the edge puts part of an ear
  off the bed.
- **Firmware.** `G2` full circles (start = end) work in Marlin with arc support and in
  Prusa's Buddy firmware. Other firmware is unverified; check the preview and the first
  disc.
- The slicer does not know about the ears: no collision avoidance and no settings from
  the print profile. Speed is fixed at 20 mm/s.

## Why this is not a plugin

Read against `ProjectApi.cpp` and `GCode.cpp` in PrusaSlicer `master`, November 2026:

- The API has no call that lists existing objects or returns their positions.
- `insert_layer_custom_gcode` stores the text as `Custom` G-code, which is written out
  verbatim (`gcode += custom_gcode.extra`). Variables are not expanded there.
- `layer_gcode` and `before_layer_gcode` skip the first layer (`if (!first_layer && …)`).
- `ConfigBox:set` writes only numbers, percentages and enums. Strings such as
  `start_gcode` fall through to the catch-all branch and fail silently, so a plugin
  cannot install this snippet for you.
