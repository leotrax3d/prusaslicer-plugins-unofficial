local values = {
    layer_height = 0.2,
    perimeters = {3, 2},
    top_solid_layers = {4, 3},
    bottom_solid_layers = {4, 3},
    fill_density = {20, 15},
    fill_pattern = {"grid", "rectilinear"},
    small_perimeter_speed = {35, 0},
    external_perimeter_speed = {45, 0},
    top_solid_infill_speed = {40, 30},
    perimeter_speed = {55, 45},
    bridge_speed = {60, 20},
    overhang_speed_0 = {20, 10},
    overhang_speed_1 = {25, 15},
    overhang_speed_2 = {30, 20},
    overhang_speed_3 = {35, 25}
}

api = {config = {value = function(_, key)
    assert(values[key] ~= nil, "unexpected config key: " .. key)
    return values[key]
end}}

package.path = "plugins/dev.leotrax3d.smart-print-presets/?.lua;" .. package.path

local function load_preset(name)
    info = nil
    execute = nil
    dofile("plugins/dev.leotrax3d.smart-print-presets/" .. name .. ".lua")
    assert(info.type == "print.print_mode", name .. " has the wrong plugin type")
end

load_preset("fast_prototype")
local fast = execute{perimeters = 2, shell_thickness = 0.6, infill = 10}
assert(fast.perimeters[1] == 2 and fast.perimeters[2] == 2)
assert(fast.top_solid_layers[1] == 3 and fast.bottom_solid_layers[1] == 3)
assert(fast.fill_density[1] == 10 and fast.fill_density[2] == 10)
assert(fast.fill_pattern == "lightning" and fast.ironing == false)

load_preset("small_parts")
local small = execute{small_speed = 20, outer_speed = 25, layer_time = 10}
assert(small.small_perimeter_speed[1] == 20 and small.small_perimeter_speed[2] == 20)
assert(small.external_perimeter_speed[1] == 25 and small.external_perimeter_speed[2] == 25)
assert(small.cooling == true and small.slowdown_below_layer_time == 10)
assert(small.min_print_speed == 5 and small.avoid_crossing_perimeters == true)

load_preset("strong_functional")
local strong = execute{perimeters = 4, shell_thickness = 1.2, infill = 20}
assert(strong.perimeters[1] == 4 and strong.top_solid_layers[1] == 6)
assert(strong.bottom_solid_layers[2] == 6 and strong.fill_density[1] == 20)
assert(strong.ensure_vertical_shell_thickness == "enabled")
assert(strong.extra_perimeters == true and strong.gap_fill_enabled == true)

load_preset("surface_quality")
local surface = execute{outer_speed = 25, top_speed = 25, top_thickness = 1.0, ironing = true}
assert(surface.external_perimeter_speed[1] == 25 and surface.external_perimeter_speed[2] == 25)
assert(surface.top_solid_infill_speed[1] == 25 and surface.top_solid_infill_speed[2] == 25)
assert(surface.perimeters[1] == 3 and surface.top_solid_layers[1] == 5)
assert(surface.top_fill_pattern == "monotonic" and surface.ironing == true)

load_preset("dimensional_accuracy")
local accurate = execute{outer_speed = 30, perimeter_speed = 40, apply_xy = false, xy_compensation = 0.1}
assert(accurate.external_perimeter_speed[1] == 30 and accurate.external_perimeter_speed[2] == 30)
assert(accurate.perimeter_speed[1] == 40 and accurate.perimeter_speed[2] == 40)
assert(accurate.perimeters[1] == 3 and accurate.external_perimeters_first == true)
assert(accurate.perimeter_generator == "classic" and accurate.xy_size_compensation == nil)

local compensated = execute{outer_speed = 30, perimeter_speed = 40, apply_xy = true, xy_compensation = 0.1}
assert(compensated.xy_size_compensation == 0.1)

load_preset("thin_features_overhangs")
local thin = execute{outer_speed = 30, bridge_speed = 25, curled_avoidance = true}
assert(thin.perimeter_generator == "arachne" and thin.thin_walls == true)
assert(thin.external_perimeters_first == false and thin.extra_perimeters_on_overhangs == true)
assert(thin.bridge_speed[1] == 25 and thin.bridge_speed[2] == 20)
assert(thin.overhang_speed_0[1] == 15 and thin.overhang_speed_0[2] == 10)
assert(thin.overhang_speed_3[1] == 25 and thin.overhang_speed_3[2] == 25)
assert(thin.enable_dynamic_overhang_speeds == true and thin.overhangs == true)
assert(thin.avoid_crossing_curled_overhangs == true)

-- An automatic speed of zero still receives the preset's explicit cap.
values.external_perimeter_speed = {0, 0}
load_preset("small_parts")
local automatic = execute{small_speed = 20, outer_speed = 25, layer_time = 10}
assert(automatic.external_perimeter_speed[1] == 25)

print("ok   smart print presets")
