Six temporary print presets for common goals without duplicating or permanently changing
your printer, filament and print profiles.

## Included presets

- **Fast Prototype** reduces shells, infill and finishing work for form and fit checks.
- **Small Parts** limits wall speed and gives short layers enough cooling time.
- **Strong Functional Part** prioritizes wall count and physical shell thickness.
- **Surface Quality** slows visible surfaces and uses monotonic top fill.
- **Dimensional Accuracy** favors constant-width walls and offers optional measured XY compensation.
- **Thin Features & Overhangs** combines Arachne walls with progressive overhang speed limits.

Each preset appears as a PrusaSlicer Print Goal. Enabling one adds a reversible override
layer; disabling it restores the active profiles unchanged. Temperatures, machine limits
and maximum volumetric flow stay under the control of those profiles.

Requires PrusaSlicer 3.0.0-alpha13 or newer.

[Full preset documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/smart-print-presets.md)
