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
- Wall, floor and divider thickness are adjustable.

### Good to know
- One grid unit is 41.5 × 41.5 mm outside, which leaves 0.5 mm play in a 42 mm grid.
- The base and lip slopes are printed in 0.2 mm steps, because the plugin API cannot create arbitrary shapes.
- An independent implementation of the published dimensions. Not affiliated with Zack Freedman or the Gridfinity community.
- Formerly *Parametric Box Generator*. Version 2.0 replaces the box with Gridfinity bins.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/box-generator.md)
