info = {
    id = "strong_functional",
    type = "print.print_mode",
    title = "Strong functional part",
    params = {
        {name = "perimeters", label = "Minimum perimeters", type = "int", default = 4},
        {name = "shell_thickness", label = "Minimum top/bottom thickness (mm)", type = "double", default = 1.2},
        {name = "infill", label = "Minimum infill (%)", type = "int", default = 20}
    }
}

local function clamp(value, low, high) return math.max(low, math.min(value, high)) end
local function at_least(value, minimum)
    local function raise(current) return math.max(current, minimum) end
    if type(value) ~= "table" then return raise(value) end
    local result = {}
    for slot, current in ipairs(value) do result[slot] = raise(current) end
    return result
end

function execute(opts)
    local config = api.config
    local perimeters = clamp(opts.perimeters, 2, 20)
    local thickness = clamp(opts.shell_thickness, 0.2, 10)
    local solid_layers = math.max(1, math.ceil(thickness / config:value("layer_height") - 1e-9))
    local infill = clamp(opts.infill, 0, 100)

    return {
        perimeters = at_least(config:value("perimeters"), perimeters),
        top_solid_layers = at_least(config:value("top_solid_layers"), solid_layers),
        bottom_solid_layers = at_least(config:value("bottom_solid_layers"), solid_layers),
        fill_density = at_least(config:value("fill_density"), infill),
        ensure_vertical_shell_thickness = "enabled",
        extra_perimeters = true,
        gap_fill_enabled = true,
        infill_first = false,
        ironing = false
    }
end
