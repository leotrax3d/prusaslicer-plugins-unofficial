info = {
    id = "surface_quality",
    type = "print.print_mode",
    title = "Surface quality",
    params = {
        {name = "outer_speed", label = "Outer perimeter speed (mm/s)", type = "int", default = 25},
        {name = "top_speed", label = "Top surface speed (mm/s)", type = "int", default = 25},
        {name = "top_thickness", label = "Minimum top thickness (mm)", type = "double", default = 1.0},
        {name = "ironing", label = "Enable top-surface ironing", type = "bool", default = false}
    }
}

local function positive(value, fallback)
    return value > 0 and value or fallback
end

local function map(value, fn)
    if type(value) ~= "table" then return fn(value) end
    local result = {}
    for slot, current in ipairs(value) do result[slot] = fn(current) end
    return result
end
local function cap_speed(value, maximum)
    return map(value, function(current) return current > 0 and math.min(current, maximum) or maximum end)
end
local function at_least(value, minimum)
    return map(value, function(current) return math.max(current, minimum) end)
end

function execute(opts)
    local config = api.config
    local outer_speed = positive(opts.outer_speed, 25)
    local top_speed = positive(opts.top_speed, 25)
    local thickness = math.max(0.2, math.min(opts.top_thickness, 10))
    local top_layers = math.max(1, math.ceil(thickness / config:value("layer_height") - 1e-9))

    return {
        external_perimeter_speed = cap_speed(config:value("external_perimeter_speed"), outer_speed),
        top_solid_infill_speed = cap_speed(config:value("top_solid_infill_speed"), top_speed),
        top_solid_layers = at_least(config:value("top_solid_layers"), top_layers),
        perimeters = at_least(config:value("perimeters"), 3),
        top_fill_pattern = "monotonic",
        ensure_vertical_shell_thickness = "enabled",
        extra_perimeters = true,
        external_perimeters_first = false,
        avoid_crossing_perimeters = true,
        ironing = opts.ironing
    }
end
