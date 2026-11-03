Prints a tower in speed bands to find the highest print speed your printer holds without losing quality.

### How to use it
1. Start a new, throwaway project and select your printer, filament and nozzle.
2. Run **Plugins → Calibration → Speed Tower**.
3. Set the speed range (default 30–180 mm/s), the number of bands (default 5) and the tower size.
4. Slice. In the preview, check the **Speed** view: a band that prints slower than engraved is limited by your hot end or motion settings, which is a result in itself.
5. Print and pick the fastest band before the first one that shows defects.

### Reading the result
- **Ringing or ghosting after corners:** acceleration or frame stiffness is the limit.
- **Thin, weak or gappy walls:** the hot end cannot melt plastic fast enough.
- **Clean walls:** the speed is usable.

### Good to know
- Each band uses a modifier volume that sets perimeter, infill and gap-fill speeds to the same value. This is the same mechanism Prusa's own Flow Tower uses.
- Layer-time slowdown is turned off and cooling is fixed at 100 %, so cooling does not confound the comparison. Your maximum volumetric flow stays active as a safety limit.
- These filament changes are not restored. Use a throwaway project.
- Speeds are requested, not guaranteed: on short walls the head may never reach them. A larger tower gives it more room.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/speed-tower.md)
