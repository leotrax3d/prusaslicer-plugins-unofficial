info = {
    id = "small_parts",
    type = "print.print_mode",
    title = "Small parts",
    params = {
        {name = "small_speed", label = "Small perimeter speed (mm/s)", type = "int", default = 20},
        {name = "outer_speed", label = "Outer perimeter speed (mm/s)", type = "int", default = 25},
        {name = "layer_time", label = "Minimum layer time (s)", type = "int", default = 10}
    }
}

local function positive(value, fallback)
    return value > 0 and value or fallback
end

local function cap_speed(value, maximum)
    local function cap(current) return current > 0 and math.min(current, maximum) or maximum end
    if type(value) ~= "table" then return cap(value) end
    local result = {}
    for slot, current in ipairs(value) do result[slot] = cap(current) end
    return result
end

function execute(opts)
    local config = api.config
    local small_speed = positive(opts.small_speed, 20)
    local outer_speed = positive(opts.outer_speed, 25)
    local layer_time = math.max(0, math.min(opts.layer_time, 120))

    return {
        small_perimeter_speed = cap_speed(config:value("small_perimeter_speed"), small_speed),
        external_perimeter_speed = cap_speed(config:value("external_perimeter_speed"), outer_speed),
        cooling = true,
        cooling_slowdown_logic = "uniform_cooling",
        slowdown_below_layer_time = layer_time,
        min_print_speed = 5,
        avoid_crossing_perimeters = true,
        ironing = false
    }
end
