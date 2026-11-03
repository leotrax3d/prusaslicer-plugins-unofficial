-- Speed Tower -- finds the highest print speed that still holds quality.
--
-- Unlike fan speed, print speed is not firmware state but a slicer setting. It is
-- therefore not switched via G-code but applied through modifier volumes that
-- override the speed parameters per height band -- the same approach Prusa's own
-- Flow Tower uses.

info = {
    id = "dev.leotrax3d.speed-tower",
    type = "project.plugin",
    title = "Speed Tower",
    menu = "Calibration/Speed Tower",
    params = {
        {name = "min_speed",     label = "Min Speed  [mm/s]",  type = "float", default = 30},
        {name = "max_speed",     label = "Max Speed  [mm/s]",  type = "float", default = 180},
        {name = "steps",         label = "Num Steps",          type = "int",   default = 5},
        {name = "step_height",   label = "Step Height  [mm]",  type = "float", default = 8},
        {name = "size",          label = "Tower Size  [mm]",   type = "float", default = 60},
        {name = "enable_labels", label = "Engrave Labels",     type = "bool",  default = true}
    }
}

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function integer(value, low, high)
    return math.floor(clamp(value, low, high) + 0.5)
end

local function for_each_material(bed, fn)
    for slot = 0, 15 do
        local ok, material = pcall(function() return bed:material_presets(slot) end)
        if not ok then break end
        fn(material)
    end
end

-- Modules are required inside execute() rather than at file level: the scan that
-- collects `info` runs each file in a bare Lua engine that has neither `api` nor
-- the custom `require`, so a top-level require aborts the file and the plugin
-- never appears in the menu. Prusa's own flow_tower.lua does the same.
function execute(opts)
    local labels = require('labels')

    local steps = integer(opts.steps, 2, 20)
    local step_height = clamp(opts.step_height, 2, 30)
    local size = clamp(opts.size, 40, 120)
    local total_height = step_height * steps

    local bed = api.project:current_bed()

    -- Few perimeters and an open interior, so speed determines the result rather
    -- than the perimeter count.
    bed:print_presets():set("fill_density", "0%")
    bed:print_presets():set("perimeters", 2)
    bed:print_presets():set("top_solid_layers", 0)
    bed:print_presets():set("bottom_solid_layers", 3)
    bed:print_presets():set("brim_type", "outer_only")
    bed:print_presets():set("brim_width", 5)

    -- Stop the slicer from quietly undoing the test.
    --
    -- A 20 mm tower has very short layers, so CoolingBuffer would slow them
    -- down to slowdown_below_layer_time and every band would print at roughly
    -- the same speed. Disabling auto cooling removes that, while
    -- fan_always_on with a fixed speed keeps cooling constant so it does not
    -- confound the comparison.
    for_each_material(bed, function(material)
        material:set("cooling", 0)
        material:set("fan_always_on", 1)
        material:set("min_fan_speed", 100)
        -- Prevent minimum-layer-time slowdown, but retain the configured
        -- volumetric-flow safety limit. The preview may therefore show a lower
        -- effective speed when the hot end, rather than motion, is the limit.
        material:set("slowdown_below_layer_time", 0)
    end)

    local other_volumes = {}
    local min_speed = clamp(opts.min_speed, 5, 500)
    local max_speed = clamp(opts.max_speed, 5, 250)
    local speed_span = max_speed - min_speed

    for i = 1, steps do
        local band_z = step_height * (i - 1)
        local speed = min_speed + speed_span * (i - 1) / (steps - 1)

        -- The modifier covers exactly one height band and sets the speeds there.
        table.insert(other_volumes, {
            mesh = api.make_cube(size, size, step_height),
            type = VolumeType.Modifier,
            translate = { z = band_z },
            params = {
                perimeter_speed = speed,
                external_perimeter_speed = speed,
                small_perimeter_speed = speed,
                gap_fill_speed = speed,
                infill_speed = speed,
                solid_infill_speed = speed
            }
        })

        if opts.enable_labels then
            table.insert(other_volumes, labels.front_label {
                text = labels.fmt(speed, 0),
                center_x = size * 0.5,
                center_z = band_z + step_height * 0.5,
                face_y = 0,
                size = math.min(6, step_height * 0.6)
            })
        end
    end

    api.project:add_object {
        mesh = api.make_cube(size, size, total_height),
        other_volumes = other_volumes,
        object_params = {
            fill_density = "0%"
        }
    }
end
