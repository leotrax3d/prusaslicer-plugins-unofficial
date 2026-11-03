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

-- Every volume carries its own offset, so replay them independently and check
-- the layout. Shared by the placement checks below.
local function world(volume)
    local b = volume.mesh:bounds()
    local t = volume.translate
    return { x0 = b.min_x + t.x, x1 = b.max_x + t.x, y0 = b.min_y + t.y,
             y1 = b.max_y + t.y, z0 = b.min_z + t.z, z1 = b.max_z + t.z }
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

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

-- The pillar stands on the bed beside the tower and is as tall as it.
reset()
execute { min_fan = 0, max_fan = 100, steps = 5, step_height = 8, size = 20, enable_labels = false }
local tower = world(added[1])
local pillar = world(added[1].other_volumes[1])
assert(near(tower.z0, 0) and near(pillar.z0, 0), "fan tower and pillar on the bed")
assert(near(pillar.z1, tower.z1), "fan pillar as tall as the tower")
assert(pillar.x0 > tower.x1, "fan pillar beside the tower")
assert(pillar.y0 > tower.y0 and pillar.y1 < tower.y1, "fan pillar centred on the tower's depth")

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

-- Each speed modifier covers exactly its own band of the tower.
reset()
execute { min_speed = 30, max_speed = 180, steps = 5, step_height = 8, size = 60, enable_labels = false }
tower = world(added[1])
for i, volume in ipairs(added[1].other_volumes) do
    local band = world(volume)
    assert(near(band.z0, (i - 1) * 8) and near(band.z1, i * 8), "speed band " .. i .. " height")
    assert(band.x0 <= tower.x0 and band.x1 >= tower.x1, "speed band " .. i .. " covers the tower in X")
    assert(band.y0 <= tower.y0 and band.y1 >= tower.y1, "speed band " .. i .. " covers the tower in Y")
end

-- Tolerance Test: clearance is diametral, sorted, and object-local settings
-- avoid modifying the current project's global print profile.
dofile("plugins/dev.leotrax3d.tolerance-test/tolerance_test.lua")
reset()
execute {
    pin_diameter = 0.1, min_clearance = 1.0, max_clearance = 0.2,
    steps = 1, thickness = -2, enable_labels = false
}
eq(#added, 1, "tolerance plate and pins share one object")
eq(#added[1].other_volumes, 6, "tolerance two holes, two shafts, two tips")
eq(added[1].other_volumes[1].mesh.a, 1.1, "tolerance sorted minimum radius")
eq(added[1].other_volumes[2].mesh.a, 1.5, "tolerance sorted maximum radius")
eq(added[1].object_params.fill_density, "100%", "tolerance local infill")
eq(added[1].other_volumes[4].mesh.kind, "cone", "first pin lead-in")
eq(added[1].other_volumes[6].mesh.kind, "cone", "second pin lead-in")

local plate = world(added[1])
for i = 1, 2 do
    local hole = world(added[1].other_volumes[i])
    assert(hole.x0 > plate.x0 and hole.x1 < plate.x1, "hole " .. i .. " inside plate in X")
    assert(hole.y0 > plate.y0 and hole.y1 < plate.y1, "hole " .. i .. " inside plate in Y")
end
for i = 0, 1 do
    local shaft = world(added[1].other_volumes[3 + i * 2])
    local tip = world(added[1].other_volumes[4 + i * 2])
    assert(shaft.y0 > plate.y1, "pin " .. (i + 1) .. " clear of the plate")
    assert(near(shaft.z0, 0), "pin " .. (i + 1) .. " on the bed")
    assert(near(tip.z0, shaft.z1), "tip " .. (i + 1) .. " on top of its shaft")
    assert(near(tip.x0 + tip.x1, shaft.x0 + shaft.x1)
           and near(tip.y0 + tip.y1, shaft.y0 + shaft.y1), "tip " .. (i + 1) .. " centred on shaft")
end
eq(next(print_sets), nil, "tolerance leaves global print settings alone")

print("ok   calibration plugin validation and isolation")
