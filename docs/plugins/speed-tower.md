# Speed Tower

**Menu:** Calibration → Speed Tower · **Plugin:** `dev.leotrax3d.speed-tower`

Finds the highest print speed a printer holds without visible quality loss.

## What it builds

A square tower divided into height bands. Each band carries a modifier volume that
overrides the speed settings for that region, and the speed is engraved into the front
face.

Unlike fan speed, print speed is not firmware state — it is a slicer setting, so it cannot
be stepped with custom G-code. Modifier volumes are the mechanism that works, and it is
the same one Prusa's own Flow Tower uses.

## Parameters

| Parameter | Default | Meaning |
| --- | --- | --- |
| Min Speed [mm/s] | 30 | Speed of the bottom band |
| Max Speed [mm/s] | 180 | Requested speed of the top band |
| Num Steps | 5 | Number of bands; minimum 2 |
| Step Height [mm] | 8 | Height of each band |
| Tower Size [mm] | 60 | Edge length of the square tower; larger gives acceleration room |
| Engrave Labels | on | Engrave each band's speed into the front face |

Each band sets perimeter, small-perimeter, gap-fill, infill and solid-infill speeds to the
same requested value.

## How to read the result

Ringing and ghosting after corners, walls that bulge or thin out, layers that stop meeting
cleanly — these appear at the speed your machine's acceleration and extruder stop keeping
up. The useful answer is the band below the first one that shows them.

This measures the complete configured system: motion limits, acceleration, hot-end flow
and filament can all become the first bottleneck.

## Settings it changes

Print settings are applied to the current bed; cooling and layer-time settings are
applied to every active material slot.

| Setting | Value | Why |
| --- | --- | --- |
| `fill_density` | 0% | An open interior, so speed decides the result |
| `perimeters` | 2 | As above |
| `top_solid_layers` / `bottom_solid_layers` | 0 / 3 | |
| `cooling` | 0 | See below |
| `fan_always_on` / `min_fan_speed` | 1 / 100 | Constant cooling, so it does not confound the comparison |
| `slowdown_below_layer_time` | 0 | Prevents short-layer cooling slowdown |

**Why only layer-time slowdown is disabled.** Cooling slowdown would quietly defeat the
comparison. The configured maximum volumetric flow remains active as a safety limit.

A compact tower has short layers, and PrusaSlicer's `CoolingBuffer` slows any layer
that would print faster than `slowdown_below_layer_time` — so without disabling auto
cooling, every band could print at roughly the same speed while claiming otherwise.
If the preview reports less than the engraved request, the hot-end flow or machine motion
limits are the result: the plugin no longer removes those safeguards.

## Limitations

- With auto cooling off, cooling is fixed at 100%. That is deliberate for comparability
  but is not how you would print normally.
- Speeds are requested, not guaranteed: on short walls, acceleration limits mean the head
  may never reach the commanded speed. Larger `Tower Size` gives the machine more room to
  get there.
