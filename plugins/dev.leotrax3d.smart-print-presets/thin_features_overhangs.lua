info = {
    id = "thin_features_overhangs",
    type = "print.print_mode",
    title = "Thin features & overhangs",
    params = {
        {name = "outer_speed", label = "Maximum outer wall speed (mm/s)", type = "int", default = 30},
        {name = "bridge_speed", label = "Maximum bridge speed (mm/s)", type = "int", default = 25},
        {name = "curled_avoidance", label = "Avoid curled overhangs", type = "bool", default = true}
    }
}

local function map(value, fn)
    if type(value) ~= "table" then return fn(value) end
    local result = {}
    for slot, current in ipairs(value) do result[slot] = fn(current) end
    return result
end

local function cap_speed(value, maximum)
    return map(value, function(current)
        return current > 0 and math.min(current, maximum) or maximum
    end)
end

local function at_least(value, minimum)
    return map(value, function(current) return math.max(current, minimum) end)
end

function execute(opts)
    local config = api.config
    local outer_speed = opts.outer_speed > 0 and opts.outer_speed or 30
    local bridge_speed = opts.bridge_speed > 0 and opts.bridge_speed or 25

    return {
        perimeter_generator = "arachne",
        thin_walls = true,
        gap_fill_enabled = true,
        external_perimeters_first = false,
        perimeters = at_least(config:value("perimeters"), 2),
        ensure_vertical_shell_thickness = "enabled",
        extra_perimeters = true,
        extra_perimeters_on_overhangs = true,
        external_perimeter_speed = cap_speed(config:value("external_perimeter_speed"), outer_speed),
        bridge_speed = cap_speed(config:value("bridge_speed"), bridge_speed),
        enable_dynamic_overhang_speeds = true,
        overhang_speed_0 = cap_speed(config:value("overhang_speed_0"), 15),
        overhang_speed_1 = cap_speed(config:value("overhang_speed_1"), 15),
        overhang_speed_2 = cap_speed(config:value("overhang_speed_2"), 20),
        overhang_speed_3 = cap_speed(config:value("overhang_speed_3"), 25),
        overhangs = true,
        avoid_crossing_curled_overhangs = opts.curled_avoidance,
        ironing = false
    }
end
