# Plugin reference

One page per plugin: what it builds, every parameter, how to read the result, and which
slicer settings it changes.

| Plugin | Plugin ID | Purpose |
| --- | --- | --- |
| [Fan Tower](fan-tower.md) | `dev.leotrax3d.fan-tower` | Find the right part cooling |
| [Speed Tower](speed-tower.md) | `dev.leotrax3d.speed-tower` | Find the highest usable print speed |
| [Tolerance Test](tolerance-test.md) | `dev.leotrax3d.tolerance-test` | Find the clearance parts need to fit |
| [Gridfinity Bin Generator](box-generator.md) | `dev.leotrax3d.box-generator` | Gridfinity-compatible compartment bins |
| [Ambigram](ambigram.md) | `dev.leotrax3d.ambigram` | A word that stays readable turned around |

Fan Tower and Speed Tower change print or filament settings in the project they create and
do not restore them afterwards, so run those in a throwaway project. Tolerance Test, Box
Gridfinity Bin Generator and Ambigram use object-local settings or geometry only.

See [`../installation.md`](../installation.md) to install, and
[`../../DEVINFO.md`](../../DEVINFO.md) for how the plugin system works underneath.
