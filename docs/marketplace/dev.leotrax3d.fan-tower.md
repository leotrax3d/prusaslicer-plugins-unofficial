Prints every part-cooling fan speed in one tower, so you can see which setting a filament really needs.

### How to use it
1. Start a new, throwaway project and select your printer, filament and nozzle.
2. Run **Plugins → Calibration → Fan Tower**.
3. Set the fan range (default 0–100 %), the number of bands (default 5) and the band height.
4. Slice and print.
5. Enter the winning value in **Filament Settings → Cooling**.

### Reading the result
- **Look at the thin pillar first.** The head travels to it every layer, so it barely cools and shows problems before the tower does.
- **Sagging overhangs, bulging corners, fused layers:** too little cooling.
- **Pick the lowest speed that still looks clean.** More cooling past that point only costs layer adhesion. PLA usually wants the top of the range, PETG and ABS much less.

### Good to know
- Each band's fan speed is engraved into its front face.
- To stop PrusaSlicer's automatic cooling from overwriting the bands, the plugin turns off auto cooling and the fan ramp-up in the project's filament settings. It does not restore them, so use a throwaway project.
- Adds a 5 mm brim so the slender pillar stays on the bed.
- Runs fully inside PrusaSlicer's plugin sandbox, with no network access and no files written.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/fan-tower.md)
