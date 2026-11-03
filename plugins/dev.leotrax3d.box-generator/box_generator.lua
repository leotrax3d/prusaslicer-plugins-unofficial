-- Gridfinity-compatible bin generator.
-- Sloped foot faces are approximated in printable 0.2 mm steps because the
-- current project.plugin API exposes primitives but no arbitrary mesh builder.

info = {
    id = "dev.leotrax3d.box-generator",
    type = "project.plugin",
    title = "Gridfinity Bin Generator",
    menu = "Generators/Gridfinity Bin",
    params = {
        {name = "units_x",       label = "Grid Units X",            type = "int",    default = 1},
        {name = "units_y",       label = "Grid Units Y",            type = "int",    default = 1},
        {name = "height_units",  label = "Height Units (7 mm)",     type = "int",    default = 3},
        {name = "wall",          label = "Wall Thickness [mm]",     type = "float",  default = 1.2},
        {name = "floor_th",      label = "Floor Thickness [mm]",    type = "float",  default = 1.2},
        {name = "columns",       label = "Compartments Across",     type = "int",    default = 1},
        {name = "rows",          label = "Compartments Deep",       type = "int",    default = 1},
        {name = "divider_th",    label = "Divider Thickness [mm]",  type = "float",  default = 1.2},
        {name = "magnet_holes",  label = "6x2 mm Magnet Pockets",   type = "bool",   default = false},
        {name = "stacking_lip",  label = "Stacking Lip",            type = "bool",   default = true},
        {name = "label",         label = "Front Label",             type = "string", default = ""}
    }
}

local GRID, XY_CLEARANCE, HEIGHT_UNIT = 42.0, 0.5, 7.0
local BASE_HEIGHT = 4.75
local FOOT_BOTTOM, FOOT_MIDDLE, FOOT_TOP = 35.6, 37.2, 41.5
local FOOT_RADIUS, LIP_HEIGHT = 3.75, 4.4
local LIP_LOWER, LIP_VERTICAL, LIP_UPPER = 0.7, 1.8, 1.9
local MAGNET_RADIUS, MAGNET_DEPTH, MAGNET_OFFSET = 3.25, 2.4, 13.0
local BREAK, PROFILE_STEP = 0.2, 0.2

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function integer(value, low, high)
    return math.floor(clamp(value, low, high) + 0.5)
end

local function add_profile(shapes, builder, cx, cy, z0, h, from_size, to_size)
    local count = math.max(1, math.ceil(h / PROFILE_STEP))
    local step_h = h / count
    for step = 1, count do
        local size = from_size + (to_size - from_size) * step / count
        builder:add_slab(
            shapes.rounded_slab(size, size, step_h + 0.01, math.min(FOOT_RADIUS, size * 0.5)),
            {x = cx - size * 0.5, y = cy - size * 0.5, z = z0 + (step - 1) * step_h}
        )
    end
end

local function lip_opening_at(z)
    local size
    if z <= LIP_LOWER then
        size = FOOT_BOTTOM + 2 * z
    elseif z <= LIP_LOWER + LIP_VERTICAL then
        size = FOOT_BOTTOM + 2 * LIP_LOWER
    else
        size = FOOT_BOTTOM + 2 * LIP_LOWER
             + 2 * math.min(LIP_UPPER, z - LIP_LOWER - LIP_VERTICAL)
    end
    -- Published stacking profile calls for 0.25 mm offset per side.
    return size + XY_CLEARANCE
end

local function add_stacking_lip(shapes, builder, outer_w, outer_d, ux, uy, z0)
    local count = math.ceil(LIP_HEIGHT / PROFILE_STEP)
    local step_h = LIP_HEIGHT / count
    for step = 1, count do
        local z = (step - 1) * step_h
        local opening = lip_opening_at(math.min(LIP_HEIGHT, z + step_h))
        local inner_w = math.min(outer_w - 0.2, (ux - 1) * GRID + opening)
        local inner_d = math.min(outer_d - 0.2, (uy - 1) * GRID + opening)
        local bx, by = (outer_w - inner_w) * 0.5, (outer_d - inner_d) * 0.5
        builder:add(shapes.cube_at(outer_w, by, step_h, 0, 0, z0 + z))
        builder:add(shapes.cube_at(outer_w, by, step_h, 0, outer_d - by, z0 + z))
        builder:add(shapes.cube_at(bx, inner_d, step_h, 0, by, z0 + z))
        builder:add(shapes.cube_at(bx, inner_d, step_h, outer_w - bx, by, z0 + z))
    end
end

function execute(opts)
    local shapes = require('shapes')
    local labels = require('labels')

    local ux = integer(opts.units_x, 1, 6)
    local uy = integer(opts.units_y, 1, 6)
    local hu = integer(opts.height_units, 1, 12)
    local wall = clamp(opts.wall, 0.8, 4)
    local floor_th = clamp(opts.floor_th, 0.8, 4)
    local divider = clamp(opts.divider_th, 0.8, 4)
    local ow, od = ux * GRID - XY_CLEARANCE, uy * GRID - XY_CLEARANCE
    local body_top = math.max(hu * HEIGHT_UNIT, BASE_HEIGHT + floor_th + 2)
    local body_h = body_top - BASE_HEIGHT
    local max_columns = math.max(1, math.floor((ow - 2 * wall) / (2 * divider)))
    local max_rows = math.max(1, math.floor((od - 2 * wall) / (2 * divider)))
    local columns = integer(opts.columns, 1, math.min(20, max_columns))
    local rows = integer(opts.rows, 1, math.min(20, max_rows))
    local bin = shapes.builder()

    -- One standard locating foot per occupied grid cell.
    for gx = 0, ux - 1 do
        for gy = 0, uy - 1 do
            local cx, cy = gx * GRID + FOOT_TOP * 0.5, gy * GRID + FOOT_TOP * 0.5
            add_profile(shapes, bin, cx, cy, 0, 0.8, FOOT_BOTTOM, FOOT_MIDDLE)
            bin:add_slab(
                shapes.rounded_slab(FOOT_MIDDLE, FOOT_MIDDLE, 1.8, FOOT_RADIUS),
                {x = cx - FOOT_MIDDLE * 0.5, y = cy - FOOT_MIDDLE * 0.5, z = 0.8}
            )
            add_profile(shapes, bin, cx, cy, 2.6, BASE_HEIGHT - 2.6, FOOT_MIDDLE, FOOT_TOP)
        end
    end

    bin:add_slab(
        shapes.rounded_slab(ow, od, body_h, FOOT_RADIUS),
        {x = 0, y = 0, z = BASE_HEIGHT}
    )

    -- Each compartment is its own negative pocket. The material between the
    -- pockets is therefore a divider even after PrusaSlicer sorts volume types.
    local usable_w = ow - 2 * wall - (columns - 1) * divider
    local usable_d = od - 2 * wall - (rows - 1) * divider
    local cell_w, cell_d = usable_w / columns, usable_d / rows
    local cavity_z = BASE_HEIGHT + floor_th
    local cavity_h = body_top - cavity_z
    for col = 0, columns - 1 do
        for row = 0, rows - 1 do
            local x = wall + col * (cell_w + divider)
            local y = wall + row * (cell_d + divider)
            bin:add_slab(
                shapes.rounded_slab(cell_w, cell_d, cavity_h,
                                    math.min(2.8, cell_w * 0.25, cell_d * 0.25)),
                {x = x, y = y, z = cavity_z}, VolumeType.Negative
            )
        end
    end

    if opts.magnet_holes then
        for gx = 0, ux - 1 do
            for gy = 0, uy - 1 do
                local cx, cy = gx * GRID + FOOT_TOP * 0.5, gy * GRID + FOOT_TOP * 0.5
                for _, dx in ipairs({-MAGNET_OFFSET, MAGNET_OFFSET}) do
                    for _, dy in ipairs({-MAGNET_OFFSET, MAGNET_OFFSET}) do
                        local hole = shapes.cylinder_at(MAGNET_RADIUS, MAGNET_DEPTH + BREAK,
                                                        cx + dx, cy + dy, -BREAK)
                        hole.type = VolumeType.Negative
                        bin:add(hole)
                    end
                end
            end
        end
    end

    if opts.stacking_lip then
        add_stacking_lip(shapes, bin, ow, od, ux, uy, body_top)
    end

    if opts.label ~= "" then
        bin:add_definition(labels.front_label {
            text = opts.label,
            center_x = ow * 0.5,
            center_z = BASE_HEIGHT + body_h * 0.55,
            face_y = 0,
            size = math.min(8, math.max(3, body_h * 0.25))
        })
    end

    bin:emit({x = 0, y = 0, z = 0})
end
