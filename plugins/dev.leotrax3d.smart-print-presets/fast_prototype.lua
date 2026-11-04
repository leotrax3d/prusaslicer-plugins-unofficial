info = {
    id = "fast_prototype",
    type = "print.print_mode",
    title = "Fast prototype",
    params = {
        {name = "perimeters", label = "Maximum perimeters", type = "int", default = 2},
        {name = "shell_thickness", label = "Target top/bottom thickness (mm)", type = "double", default = 0.6},
        {name = "infill", label = "Maximum infill (%)", type = "int", default = 10}
    }
}

local function clamp(value, low, high) return math.max(low, math.min(value, high)) end
local function map(value, fn)
    if type(value) ~= "table" then return fn(value) end
    local result = {}
    for slot, current in ipairs(value) do result[slot] = fn(current) end
    return result
end
local function at_most(value, maximum)
    return map(value, function(current) return math.min(current, maximum) end)
end

function execute(opts)
    local config = api.config
    local perimeters = clamp(opts.perimeters, 1, 20)
    local thickness = clamp(opts.shell_thickness, 0.2, 5)
    local solid_layers = math.max(1, math.ceil(thickness / config:value("layer_height") - 1e-9))
    local infill = clamp(opts.infill, 0, 100)
    local current_infill = config:value("fill_density")

    return {
        perimeters = at_most(config:value("perimeters"), perimeters),
        top_solid_layers = at_most(config:value("top_solid_layers"), solid_layers),
        bottom_solid_layers = at_most(config:value("bottom_solid_layers"), solid_layers),
        fill_density = at_most(current_infill, infill),
        fill_pattern = "lightning",
        ironing = false,
        avoid_crossing_perimeters = false
    }
end
