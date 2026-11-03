Prints a flat anti-warp disc on each corner of the first layer, for any model, before the print starts.

### How to use it
1. Run **Plugins → Generators → Mouse Ears**.
2. Click into the text field, press **Ctrl+A**, then **Ctrl+C**.
3. Open **Printer Settings → Custom G-code → Start G-code** and paste at the **end**, after the purge line.
4. Save the printer preset under a new name, for example "CORE One + ears", so you can switch the ears on and off by switching presets.
5. Slice and check the preview: four discs should sit on the corners of your part.

### Good to know
- PrusaSlicer supplies the positions itself, from the first layer's bounding box, so it works on any model, including ones you did not generate with a plugin.
- The disc is about 24 line widths across, around 10.8 mm with a 0.4 mm nozzle. Line width, flow and retraction come from your profile.
- Ears sit on the corners of the bounding box: ideal for rectangular parts aligned to the axes, off the part for round or rotated ones. With several objects, only the outer corners of the whole layout get ears.
- Uses G2 arcs. Prusa Buddy firmware and Marlin with arc support handle them.
- Why a text field: a plugin cannot change your start G-code or see your objects, so it hands you the code to paste once.

[Full documentation](https://github.com/leotrax3d/prusaslicer-plugins-unofficial/blob/main/docs/snippets/mouse-ears.md)
