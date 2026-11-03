VolumeType = { Modifier = "modifier", Negative = "negative" }

package.path = table.concat({
    "plugins/dev.leotrax3d.fan-tower/?.lua",
    "plugins/dev.leotrax3d.speed-tower/?.lua",
    "plugins/dev.leotrax3d.tolerance-test/?.lua",
    package.path
}, ";")

local added = {}
local gcodes = {}
local material_sets = {}
local print_sets = {}

local function mesh(kind, a, b, c)
    local value = { kind = kind, a = a, b = b, c = c }
    function value:bounds()
        if self.kind == "cube" then
            return { min_x = -self.a/2, min_y = -self.b/2, min_z = -self.c/2,
                     max_x = self.a/2, max_y = self.b/2, max_z = self.c/2 }
        end
        return { min_x = -self.a, min_y = -self.a, min_z = 0,
                 max_x = self.a, max_y = self.a, max_z = self.b }
    end
    return value
end

local bed = {}
function bed:print_presets()
    return {
        value = function(_, key)
            assert(key == "layer_height")
            return 0.2
        end,
        set = function(_, key, value) print_sets[key] = value end
    }
end
function bed:material_presets(slot)
    if slot > 1 then error("missing material slot") end
    return {
        set = function(_, key, value)
            material_sets[slot] = material_sets[slot] or {}
            material_sets[slot][key] = value
        end
    }
end

api = {
    make_cube = function(w, d, h) return mesh("cube", w, d, h) end,
    make_cylinder = function(r, h) return mesh("cylinder", r, h) end,
    make_cone = function(r, h) return mesh("cone", r, h) end,
    project = {
        current_bed = function() return bed end,
        clear_layer_custom_steps = function() gcodes = {} end,
        insert_layer_custom_gcode = function(_, _, z, code)
            gcodes[#gcodes + 1] = { z = z, code = code }
        end,
        add_object = function(_, definition) added[#added + 1] = definition end
    }
}

local function reset()
    added, gcodes, material_sets, print_sets = {}, {}, {}, {}
end

local function eq(actual, expected, label)
    assert(actual == expected,
           string.format("%s: got %s, expected %s", label, tostring(actual), tostring(expected)))
end

-- Fan Tower: invalid inputs are clamped and all material slots are controlled.
dofile("plugins/dev.leotrax3d.fan-tower/fan_tower.lua")
reset()
execute {
    min_fan = -50, max_fan = 150, steps = 1, step_height = -1,
    size = -5, enable_labels = false
}
eq(#added, 1, "fan object count")
eq(added[1].mesh.a, 10, "fan minimum width")
eq(added[1].mesh.c, 4, "fan minimum total height")
eq(#gcodes, 20, "fan command on every layer")
eq(gcodes[1].code, "M107 ; Leotrax3D Fan Tower", "fan minimum command")
eq(gcodes[20].code, "M106 S255 ; Leotrax3D Fan Tower", "fan maximum command")
eq(material_sets[0].cooling, 0, "fan slot zero")
eq(material_sets[1].cooling, 0, "fan slot one")

-- Speed Tower: extreme ranges are bounded and produce modifier-only bands.
dofile("plugins/dev.leotrax3d.speed-tower/speed_tower.lua")
reset()
execute {
    min_speed = 0, max_speed = 999, steps = 1, step_height = -1,
    size = -5, enable_labels = false
}
eq(#added, 1, "speed object count")
eq(added[1].mesh.a, 40, "speed minimum width")
eq(added[1].mesh.c, 4, "speed minimum total height")
eq(#added[1].other_volumes, 2, "speed modifier count")
eq(added[1].other_volumes[1].params.perimeter_speed, 5, "speed lower bound")
eq(added[1].other_volumes[2].params.perimeter_speed, 250, "speed upper bound")
eq(material_sets[1].slowdown_below_layer_time, 0, "speed disables layer slowdown")
eq(material_sets[1].filament_max_volumetric_speed, nil, "speed retains flow safety limit")

-- Tolerance Test: clearance is diametral, sorted, and object-local settings
-- avoid modifying the current project's global print profile.
dofile("plugins/dev.leotrax3d.tolerance-test/tolerance_test.lua")
reset()
execute {
    pin_diameter = 0.1, min_clearance = 1.0, max_clearance = 0.2,
    steps = 1, thickness = -2, enable_labels = false
}
eq(#added, 3, "tolerance plate and two pins")
eq(#added[1].other_volumes, 2, "tolerance hole count")
eq(added[1].other_volumes[1].mesh.a, 1.1, "tolerance sorted minimum radius")
eq(added[1].other_volumes[2].mesh.a, 1.5, "tolerance sorted maximum radius")
eq(added[1].object_params.fill_density, "100%", "tolerance local infill")
eq(added[2].other_volumes[1].mesh.kind, "cone", "first pin lead-in")
eq(added[3].other_volumes[1].mesh.kind, "cone", "second pin lead-in")
eq(next(print_sets), nil, "tolerance leaves global print settings alone")

print("ok   calibration plugin validation and isolation")
