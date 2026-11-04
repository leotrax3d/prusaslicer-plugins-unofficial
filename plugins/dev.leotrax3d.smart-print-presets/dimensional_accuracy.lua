info = {
    id = "dimensional_accuracy",
    type = "print.print_mode",
    title = "Dimensional accuracy",
    params = {
        {name = "outer_speed", label = "Outer perimeter speed (mm/s)", type = "int", default = 30},
        {name = "perimeter_speed", label = "Inner perimeter speed (mm/s)", type = "int", default = 40},
        {name = "apply_xy", label = "Apply measured XY compensation", type = "bool", default = false},
        {name = "xy_compensation", label = "XY compensation (mm)", type = "double", default = 0.0}
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
    local outer_speed = positive(opts.outer_speed, 30)
    local perimeter_speed = positive(opts.perimeter_speed, 40)

    return {
        external_perimeter_speed = cap_speed(config:value("external_perimeter_speed"), outer_speed),
        perimeter_speed = cap_speed(config:value("perimeter_speed"), perimeter_speed),
        perimeters = at_least(config:value("perimeters"), 3),
        perimeter_generator = "classic",
        external_perimeters_first = true,
        thin_walls = false,
        gap_fill_enabled = true,
        infill_first = false,
        xy_size_compensation = opts.apply_xy and math.max(-2, math.min(opts.xy_compensation, 2)) or nil,
        ironing = false
    }
end
