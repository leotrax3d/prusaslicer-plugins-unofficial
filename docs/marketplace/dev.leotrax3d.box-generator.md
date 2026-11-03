Generates Gridfinity-compatible storage bins in 42 mm grid units, with compartments, stacking lip, magnet pockets and an optional front label.

### How to use it
1. Run **Plugins → Generators → Gridfinity Bin**.
2. Set the footprint in grid units (X × Y) and the height in 7 mm units.
3. Optionally add compartments, magnet pockets (6 × 2 mm) and a front label.
4. Slice and print. No supports needed.

### Options
- **Compartments across / deep:** splits the bin into separate pockets.
- **Stacking lip:** lets another bin sit on top.
- **Magnet pockets:** four per grid cell, for 6 × 2 mm magnets.
- **Front label:** text engraved into the front wall.
- **UltraLight hollow base:** the foot is hollowed to a 1 mm shell over a 1 mm floor. Saves material and time and adds about 4 mm of usable height. Used for bins with one compartment and no magnets.
- Floor and divider thickness are adjustable; the wall is a fixed 1.2 mm.

### Good to know
- One grid unit is 41.5 × 41.5 mm outside, which leaves 0.5 mm play in a 42 mm grid.
- Foot and stacking lip have exact 45° faces, from STLs shipped with the plugin. The lip has a 45° support underneath instead of an overhang, and a flat top instead of a knife edge.
- An independent implementation of the published dimensions. Not affiliated with Zack Freedman or the Gridfinity community.
- Formerly *Parametric Box Generator*. Version 2.0 replaces the box with Gridfinity bins.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/box-generator.md)
