Finds the clearance your parts need to fit together, for this printer and this filament.

### How to use it
1. Run **Plugins → Calibration → Tolerance Test**.
2. Set the pin diameter (default 6 mm), the clearance range (default 0.0–0.5 mm) and the number of holes.
3. Slice and print. You get a plate with a row of holes and two matching pins.
4. Try a pin in each hole, starting with the tightest.

### Reading the result
- **The first hole the pin enters without force** is your clearance. The value is engraved in front of it.
- The value is **diametral**. Split it in half if you apply it per side.
- A press fit, a sliding fit and a free-running fit need different clearances. This test finds where contact stops; add to it for parts that have to move.
- Rerun it when you change filament or nozzle temperature.

### Good to know
- Pure geometry: no G-code tricks and no settings changing mid-print.
- 100 % infill and 3 perimeters are set on the generated objects only. Your print and filament presets stay unchanged.
- The pins have a conical tip, so the first-layer bulge does not spoil the fit.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/plugins/tolerance-test.md)
