; ---- mouse ears (dev.leotrax3d) -- paste at the END of Start G-code ----
; Prints a solid disc on each corner of the first layer's bounding box,
; before the object starts. Positions come from first_layer_print_min/max,
; which PrusaSlicer sets before it processes the start G-code.
; Disc diameter is about 24 line widths (~10.8 mm with a 0.4 mm nozzle).
{local w = nozzle_diameter[initial_tool] * 1.125}
{local z = first_layer_height + z_offset}
{local k = 4 * w * first_layer_height / (3.14159265 * filament_diameter[initial_tool] * filament_diameter[initial_tool])}
{local retr = retract_length[initial_tool]}
; The first-layer box includes the skirt; step back inside it to reach the part.
{local inset = skirts > 0 ? skirt_distance + skirts * w : 0}
{local cx = 0}
{local cy = 0}
M83 ; relative extrusion for the ears
; ear: front left
{cx = first_layer_print_min[0] + inset}
{cy = first_layer_print_min[1] + inset}
G1 E{-retr} F2100
G1 Z{z + 0.4} F720
G1 X{cx + 0.5 * w} Y{cy} F9000
G1 Z{z} F720
G1 E{retr} F2100
G1 F1200 ; 20 mm/s
G2 X{cx + 0.5 * w} Y{cy} I{-0.5 * w} J0 E{2 * 3.14159265 * 0.5 * w * k}
G1 X{cx + 1.5 * w} Y{cy} E{w * k}
G2 X{cx + 1.5 * w} Y{cy} I{-1.5 * w} J0 E{2 * 3.14159265 * 1.5 * w * k}
G1 X{cx + 2.5 * w} Y{cy} E{w * k}
G2 X{cx + 2.5 * w} Y{cy} I{-2.5 * w} J0 E{2 * 3.14159265 * 2.5 * w * k}
G1 X{cx + 3.5 * w} Y{cy} E{w * k}
G2 X{cx + 3.5 * w} Y{cy} I{-3.5 * w} J0 E{2 * 3.14159265 * 3.5 * w * k}
G1 X{cx + 4.5 * w} Y{cy} E{w * k}
G2 X{cx + 4.5 * w} Y{cy} I{-4.5 * w} J0 E{2 * 3.14159265 * 4.5 * w * k}
G1 X{cx + 5.5 * w} Y{cy} E{w * k}
G2 X{cx + 5.5 * w} Y{cy} I{-5.5 * w} J0 E{2 * 3.14159265 * 5.5 * w * k}
G1 X{cx + 6.5 * w} Y{cy} E{w * k}
G2 X{cx + 6.5 * w} Y{cy} I{-6.5 * w} J0 E{2 * 3.14159265 * 6.5 * w * k}
G1 X{cx + 7.5 * w} Y{cy} E{w * k}
G2 X{cx + 7.5 * w} Y{cy} I{-7.5 * w} J0 E{2 * 3.14159265 * 7.5 * w * k}
G1 X{cx + 8.5 * w} Y{cy} E{w * k}
G2 X{cx + 8.5 * w} Y{cy} I{-8.5 * w} J0 E{2 * 3.14159265 * 8.5 * w * k}
G1 X{cx + 9.5 * w} Y{cy} E{w * k}
G2 X{cx + 9.5 * w} Y{cy} I{-9.5 * w} J0 E{2 * 3.14159265 * 9.5 * w * k}
G1 X{cx + 10.5 * w} Y{cy} E{w * k}
G2 X{cx + 10.5 * w} Y{cy} I{-10.5 * w} J0 E{2 * 3.14159265 * 10.5 * w * k}
G1 X{cx + 11.5 * w} Y{cy} E{w * k}
G2 X{cx + 11.5 * w} Y{cy} I{-11.5 * w} J0 E{2 * 3.14159265 * 11.5 * w * k}
; ear: front right
{cx = first_layer_print_max[0] - inset}
{cy = first_layer_print_min[1] + inset}
G1 E{-retr} F2100
G1 Z{z + 0.4} F720
G1 X{cx + 0.5 * w} Y{cy} F9000
G1 Z{z} F720
G1 E{retr} F2100
G1 F1200 ; 20 mm/s
G2 X{cx + 0.5 * w} Y{cy} I{-0.5 * w} J0 E{2 * 3.14159265 * 0.5 * w * k}
G1 X{cx + 1.5 * w} Y{cy} E{w * k}
G2 X{cx + 1.5 * w} Y{cy} I{-1.5 * w} J0 E{2 * 3.14159265 * 1.5 * w * k}
G1 X{cx + 2.5 * w} Y{cy} E{w * k}
G2 X{cx + 2.5 * w} Y{cy} I{-2.5 * w} J0 E{2 * 3.14159265 * 2.5 * w * k}
G1 X{cx + 3.5 * w} Y{cy} E{w * k}
G2 X{cx + 3.5 * w} Y{cy} I{-3.5 * w} J0 E{2 * 3.14159265 * 3.5 * w * k}
G1 X{cx + 4.5 * w} Y{cy} E{w * k}
G2 X{cx + 4.5 * w} Y{cy} I{-4.5 * w} J0 E{2 * 3.14159265 * 4.5 * w * k}
G1 X{cx + 5.5 * w} Y{cy} E{w * k}
G2 X{cx + 5.5 * w} Y{cy} I{-5.5 * w} J0 E{2 * 3.14159265 * 5.5 * w * k}
G1 X{cx + 6.5 * w} Y{cy} E{w * k}
G2 X{cx + 6.5 * w} Y{cy} I{-6.5 * w} J0 E{2 * 3.14159265 * 6.5 * w * k}
G1 X{cx + 7.5 * w} Y{cy} E{w * k}
G2 X{cx + 7.5 * w} Y{cy} I{-7.5 * w} J0 E{2 * 3.14159265 * 7.5 * w * k}
G1 X{cx + 8.5 * w} Y{cy} E{w * k}
G2 X{cx + 8.5 * w} Y{cy} I{-8.5 * w} J0 E{2 * 3.14159265 * 8.5 * w * k}
G1 X{cx + 9.5 * w} Y{cy} E{w * k}
G2 X{cx + 9.5 * w} Y{cy} I{-9.5 * w} J0 E{2 * 3.14159265 * 9.5 * w * k}
G1 X{cx + 10.5 * w} Y{cy} E{w * k}
G2 X{cx + 10.5 * w} Y{cy} I{-10.5 * w} J0 E{2 * 3.14159265 * 10.5 * w * k}
G1 X{cx + 11.5 * w} Y{cy} E{w * k}
G2 X{cx + 11.5 * w} Y{cy} I{-11.5 * w} J0 E{2 * 3.14159265 * 11.5 * w * k}
; ear: back right
{cx = first_layer_print_max[0] - inset}
{cy = first_layer_print_max[1] - inset}
G1 E{-retr} F2100
G1 Z{z + 0.4} F720
G1 X{cx + 0.5 * w} Y{cy} F9000
G1 Z{z} F720
G1 E{retr} F2100
G1 F1200 ; 20 mm/s
G2 X{cx + 0.5 * w} Y{cy} I{-0.5 * w} J0 E{2 * 3.14159265 * 0.5 * w * k}
G1 X{cx + 1.5 * w} Y{cy} E{w * k}
G2 X{cx + 1.5 * w} Y{cy} I{-1.5 * w} J0 E{2 * 3.14159265 * 1.5 * w * k}
G1 X{cx + 2.5 * w} Y{cy} E{w * k}
G2 X{cx + 2.5 * w} Y{cy} I{-2.5 * w} J0 E{2 * 3.14159265 * 2.5 * w * k}
G1 X{cx + 3.5 * w} Y{cy} E{w * k}
G2 X{cx + 3.5 * w} Y{cy} I{-3.5 * w} J0 E{2 * 3.14159265 * 3.5 * w * k}
G1 X{cx + 4.5 * w} Y{cy} E{w * k}
G2 X{cx + 4.5 * w} Y{cy} I{-4.5 * w} J0 E{2 * 3.14159265 * 4.5 * w * k}
G1 X{cx + 5.5 * w} Y{cy} E{w * k}
G2 X{cx + 5.5 * w} Y{cy} I{-5.5 * w} J0 E{2 * 3.14159265 * 5.5 * w * k}
G1 X{cx + 6.5 * w} Y{cy} E{w * k}
G2 X{cx + 6.5 * w} Y{cy} I{-6.5 * w} J0 E{2 * 3.14159265 * 6.5 * w * k}
G1 X{cx + 7.5 * w} Y{cy} E{w * k}
G2 X{cx + 7.5 * w} Y{cy} I{-7.5 * w} J0 E{2 * 3.14159265 * 7.5 * w * k}
G1 X{cx + 8.5 * w} Y{cy} E{w * k}
G2 X{cx + 8.5 * w} Y{cy} I{-8.5 * w} J0 E{2 * 3.14159265 * 8.5 * w * k}
G1 X{cx + 9.5 * w} Y{cy} E{w * k}
G2 X{cx + 9.5 * w} Y{cy} I{-9.5 * w} J0 E{2 * 3.14159265 * 9.5 * w * k}
G1 X{cx + 10.5 * w} Y{cy} E{w * k}
G2 X{cx + 10.5 * w} Y{cy} I{-10.5 * w} J0 E{2 * 3.14159265 * 10.5 * w * k}
G1 X{cx + 11.5 * w} Y{cy} E{w * k}
G2 X{cx + 11.5 * w} Y{cy} I{-11.5 * w} J0 E{2 * 3.14159265 * 11.5 * w * k}
; ear: back left
{cx = first_layer_print_min[0] + inset}
{cy = first_layer_print_max[1] - inset}
G1 E{-retr} F2100
G1 Z{z + 0.4} F720
G1 X{cx + 0.5 * w} Y{cy} F9000
G1 Z{z} F720
G1 E{retr} F2100
G1 F1200 ; 20 mm/s
G2 X{cx + 0.5 * w} Y{cy} I{-0.5 * w} J0 E{2 * 3.14159265 * 0.5 * w * k}
G1 X{cx + 1.5 * w} Y{cy} E{w * k}
G2 X{cx + 1.5 * w} Y{cy} I{-1.5 * w} J0 E{2 * 3.14159265 * 1.5 * w * k}
G1 X{cx + 2.5 * w} Y{cy} E{w * k}
G2 X{cx + 2.5 * w} Y{cy} I{-2.5 * w} J0 E{2 * 3.14159265 * 2.5 * w * k}
G1 X{cx + 3.5 * w} Y{cy} E{w * k}
G2 X{cx + 3.5 * w} Y{cy} I{-3.5 * w} J0 E{2 * 3.14159265 * 3.5 * w * k}
G1 X{cx + 4.5 * w} Y{cy} E{w * k}
G2 X{cx + 4.5 * w} Y{cy} I{-4.5 * w} J0 E{2 * 3.14159265 * 4.5 * w * k}
G1 X{cx + 5.5 * w} Y{cy} E{w * k}
G2 X{cx + 5.5 * w} Y{cy} I{-5.5 * w} J0 E{2 * 3.14159265 * 5.5 * w * k}
G1 X{cx + 6.5 * w} Y{cy} E{w * k}
G2 X{cx + 6.5 * w} Y{cy} I{-6.5 * w} J0 E{2 * 3.14159265 * 6.5 * w * k}
G1 X{cx + 7.5 * w} Y{cy} E{w * k}
G2 X{cx + 7.5 * w} Y{cy} I{-7.5 * w} J0 E{2 * 3.14159265 * 7.5 * w * k}
G1 X{cx + 8.5 * w} Y{cy} E{w * k}
G2 X{cx + 8.5 * w} Y{cy} I{-8.5 * w} J0 E{2 * 3.14159265 * 8.5 * w * k}
G1 X{cx + 9.5 * w} Y{cy} E{w * k}
G2 X{cx + 9.5 * w} Y{cy} I{-9.5 * w} J0 E{2 * 3.14159265 * 9.5 * w * k}
G1 X{cx + 10.5 * w} Y{cy} E{w * k}
G2 X{cx + 10.5 * w} Y{cy} I{-10.5 * w} J0 E{2 * 3.14159265 * 10.5 * w * k}
G1 X{cx + 11.5 * w} Y{cy} E{w * k}
G2 X{cx + 11.5 * w} Y{cy} I{-11.5 * w} J0 E{2 * 3.14159265 * 11.5 * w * k}
G1 E{-retr} F2100
G1 Z{z + 0.4} F720
G1 E{retr} F2100
{if not use_relative_e_distances}M82 ; back to absolute extrusion{endif}
G92 E0
; ---- end mouse ears ----
