-- Tolerance Test -- determines the fit allowance your parts need.
--
-- Produces a plate with a row of holes, each one a different amount larger than
-- the test pin printed alongside it. After printing, work along the row to find
-- the first hole the pin seats cleanly in; that clearance is what your own
-- designs need for this printer and this filament.
--
-- Pure geometry: no G-code tricks and no setting changes mid-print.

info = {
    id = "dev.leotrax3d.tolerance-test",
    type = "project.plugin",
    title = "Tolerance Test",
    menu = "Calibration/Tolerance Test",
    params = {
        {name = "pin_diameter",  label = "Pin Diameter  [mm]",  type = "float", default = 6},
        {name = "min_clearance", label = "Min Diameter Clearance [mm]", type = "float", default = 0.0},
        {name = "max_clearance", label = "Max Diameter Clearance [mm]", type = "float", default = 0.5},
        {name = "steps",         label = "Num Steps",           type = "int",   default = 6},
        {name = "thickness",     label = "Plate Thickness [mm]",type = "float", default = 6},
        {name = "enable_labels", label = "Engrave Labels",      type = "bool",  default = true}
    }
}

local MARGIN = 4.0      -- material margin around the holes [mm]
local LABEL_ROW = 6.0   -- depth of the label strip in front of the holes [mm]
local PIN_GAP = 10.0    -- gap between the test pin and the plate [mm]
local PIN_TIP = 1.5     -- conical lead-in that avoids measuring the first-layer bulge

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function integer(value, low, high)
    return math.floor(clamp(value, low, high) + 0.5)
end

-- Modules are required inside execute() rather than at file level: the scan that
-- collects `info` runs each file in a bare Lua engine that has neither `api` nor
-- the custom `require`, so a top-level require aborts the file and the plugin
-- never appears in the menu. Prusa's own flow_tower.lua does the same.
function execute(opts)
    local labels = require('labels')

    local steps = integer(opts.steps, 2, 12)
    local pin_d = clamp(opts.pin_diameter, 2, 30)
    local thickness = clamp(opts.thickness, 2, 20)
    local clearance_a = clamp(opts.min_clearance, 0, 3)
    local clearance_b = clamp(opts.max_clearance, 0, 3)
    local min_clearance = math.min(clearance_a, clearance_b)
    local max_clearance = math.max(clearance_a, clearance_b)

    local pitch = pin_d + max_clearance + MARGIN
    local plate_w = pitch * steps
    local plate_d = pin_d + max_clearance + MARGIN * 2 + LABEL_ROW
    local hole_cy = LABEL_ROW + (plate_d - LABEL_ROW) * 0.5

    local other_volumes = {}
    local clearance_span = max_clearance - min_clearance

    for i = 1, steps do
        local clearance = min_clearance + clearance_span * (i - 1) / (steps - 1)
        local hole_cx = pitch * (i - 0.5)

        -- Position from the mesh's own bounds rather than assuming where
        -- make_cylinder puts its origin: this centres the hole correctly
        -- whether the primitive is centred in XY or anchored at a corner.
        -- Overhangs both ends slightly so the cut passes cleanly through.
        local hole = api.make_cylinder((pin_d + clearance) * 0.5, thickness + 2)
        local hb = hole:bounds()
        table.insert(other_volumes, {
            mesh = hole,
            type = VolumeType.Negative,
            translate = {
                x = hole_cx - (hb.min_x + hb.max_x) * 0.5,
                y = hole_cy - (hb.min_y + hb.max_y) * 0.5,
                z = -1 - hb.min_z
            }
        })

        if opts.enable_labels then
            table.insert(other_volumes, labels.top_label {
                text = labels.fmt(clearance, 2),
                center_x = hole_cx,
                center_y = LABEL_ROW * 0.5,
                top_z = thickness,
                size = 3.5
            })
        end
    end

    api.project:add_object {
        mesh = api.make_cube(plate_w, plate_d, thickness),
        other_volumes = other_volumes,
        object_params = {
            fill_density = "100%",
            perimeters = 3
        }
    }

    -- Two pins make a damaged or locally over-extruded sample obvious. Each has
    -- a conical lead-in at the top, so the first-layer bulge at its flat base is
    -- never the edge used to start the fit test.
    for sample = 1, 2 do
        local shaft_h = math.max(2, thickness * 2 - PIN_TIP)
        local pin = api.make_cylinder(pin_d * 0.5, shaft_h)
        local pb = pin:bounds()
        local tip = api.make_cone(pin_d * 0.5, PIN_TIP)
        local tb = tip:bounds()
        local center_x = plate_w * 0.5 + (sample - 1.5) * (pin_d + 4)
        api.project:add_object {
            mesh = pin,
            translate = {
                x = center_x - (pb.min_x + pb.max_x) * 0.5,
                y = plate_d + PIN_GAP - pb.min_y,
                z = -pb.min_z
            },
            other_volumes = {{
                mesh = tip,
                translate = {
                    x = -(tb.min_x + tb.max_x) * 0.5,
                    y = -(tb.min_y + tb.max_y) * 0.5,
                    z = shaft_h - tb.min_z
                }
            }},
            object_params = {
                fill_density = "100%",
                perimeters = 3
            }
        }
    end
end
