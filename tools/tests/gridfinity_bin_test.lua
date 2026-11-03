dofile("tools/tests/mock.lua")
dofile("plugins/dev.leotrax3d.box-generator/box_generator.lua")

execute {
    units_x=2, units_y=1, height_units=3, wall=1.2, floor_th=1.2,
    columns=2, rows=1, divider_th=1.2, magnet_holes=true,
    stacking_lip=true, label="BITS"
}

check("one generated bin object", #objects, 1)
local boxes = world_boxes(objects[1])
local solids = extent(boxes, function(b) return b.type=="Solid" end)
check("2U Gridfinity width", solids.x1-solids.x0, 83.5)
check("1U Gridfinity depth", solids.y1-solids.y0, 41.5)
check("3U body plus stacking lip", solids.z1-solids.z0, 25.4)
check("bin sits on bed", solids.z0, 0)

-- Every low solid used by the Gridfinity base must remain inside the nominal
-- footprint. This catches independently translated corner cylinders turning
-- into puzzle-like tabs or notches.
local escaped_base_volumes = 0
for _, b in ipairs(boxes) do
    if b.type == "Solid" and b.z0 < 4.75
       and (b.x0 < -1e-6 or b.y0 < -1e-6
            or b.x1 > 83.5 + 1e-6 or b.y1 > 41.5 + 1e-6) then
        escaped_base_volumes = escaped_base_volumes + 1
    end
end
check("base volumes stay inside footprint", escaped_base_volumes, 0)

local cavity = extent(boxes, function(b)
    return b.type=="Negative" and b.z0 >= 5.9 and b.tag ~= "text:BITS"
end)
check("cavity starts above base and floor", cavity.z0, 5.95)
check("left wall", cavity.x0, 1.2)
check("right wall", 83.5-cavity.x1, 1.2)

-- No cavity may cross the intended 1.2 mm centre divider. This specifically
-- guards against the old add-solid-after-negative ordering bug.
local divider_center = 83.5 * 0.5
local crossings = 0
for _, b in ipairs(boxes) do
    if b.type=="Negative" and b.z0 >= 5.9 and b.tag ~= "text:BITS"
       and b.x0 < divider_center and b.x1 > divider_center then
        crossings = crossings + 1
    end
end
check("centre divider survives all cavity cuts", crossings, 0)

local magnets = 0
for _, b in ipairs(boxes) do
    if b.type=="Negative" and b.tag=="cyl" and b.z0 < 0 then magnets=magnets+1 end
end
check("four magnet pockets per grid cell", magnets, 8)

done()
