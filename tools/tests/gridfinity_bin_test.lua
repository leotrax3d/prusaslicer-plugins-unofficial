dofile("tools/tests/mock.lua")
dofile("plugins/dev.leotrax3d.box-generator/box_generator.lua")

local function tagged(boxes, tag)
    local out = {}
    for _, b in ipairs(boxes) do
        if b.tag == tag then out[#out + 1] = b end
    end
    return out
end

-- Compartments and magnets: the solid base, one pocket per compartment.
execute {
    units_x=2, units_y=1, height_units=3, ultralight=true, floor_th=1.2,
    columns=2, rows=1, divider_th=1.2, magnet_holes=true,
    stacking_lip=true, label="BITS"
}

check("one generated bin object", #objects, 1)
local boxes = world_boxes(objects[1])
local solids = extent(boxes, function(b) return b.type=="Solid" end)
check("2U Gridfinity width", solids.x1-solids.x0, 83.5)
check("1U Gridfinity depth", solids.y1-solids.y0, 41.5)
check("3U body plus stacking lip", solids.z1-solids.z0, 24.7)
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

local feet = {}
for _, b in ipairs(boxes) do
    if b.tag == "stl:foot" then feet[#feet + 1] = b end
end
check("one STL foot per grid cell", #feet, 2)
check("first foot centred in its cell", (feet[1].x0 + feet[1].x1) * 0.5, 20.75)
check("second foot one grid unit along", (feet[2].x0 + feet[2].x1) * 0.5, 62.75)
check("feet start on the bed", math.min(feet[1].z0, feet[2].z0), 0)
check("feet overlap into the body", feet[1].z1 > 4.75 and 1 or 0, 1)

-- Stacking lip: four corners, and per side n - 1 pieces of 42 mm plus one of 34.
-- Every piece must sit on the body top, inside the footprint, hugging an edge.
local lip = {corner = {}, long = {}, short = {}}
for _, b in ipairs(boxes) do
    if b.tag == "stl:lip_corner" then lip.corner[#lip.corner + 1] = b end
    if b.tag == "stl:lip_42" then lip.long[#lip.long + 1] = b end
    if b.tag == "stl:lip_34" then lip.short[#lip.short + 1] = b end
end
check("four lip corners", #lip.corner, 4)
check("2 x 1 bin: two 42 mm lip pieces", #lip.long, 2)
check("2 x 1 bin: four 34 mm lip pieces", #lip.short, 4)
local lip_all = extent(boxes, function(b) return b.tag and b.tag:find("stl:lip") end)
check("lip spans the bin width", lip_all.x1 - lip_all.x0, 83.5)
check("lip spans the bin depth", lip_all.y1 - lip_all.y0, 41.5)
check("lip starts on the body top", lip_all.z0, 21)
check("lip is 3.7 mm tall", lip_all.z1 - lip_all.z0, 3.7)
local misplaced = 0
for _, kind in pairs(lip) do
    for _, b in ipairs(kind) do
        local on_edge = math.abs(b.x0) < 1e-6 or math.abs(b.y0) < 1e-6
            or math.abs(b.x1 - 83.5) < 1e-6 or math.abs(b.y1 - 41.5) < 1e-6
        if not on_edge or b.x0 < -1e-6 or b.y0 < -1e-6
           or b.x1 > 83.5 + 1e-6 or b.y1 > 41.5 + 1e-6 then
            misplaced = misplaced + 1
        end
    end
end
check("every lip piece hugs an outer edge", misplaced, 0)
-- The straight pieces and corners of each side must tile it without gaps.
local front = 0
for _, b in ipairs(boxes) do
    if b.tag and b.tag:find("stl:lip") and math.abs(b.y0) < 1e-6 then
        front = front + (b.x1 - b.x0)
    end
end
check("front side tiles 83.5 mm", front, 83.5)

local cavity = extent(boxes, function(b)
    return b.type=="Negative" and b.z0 >= 5.9 and b.tag ~= "text:BITS"
end)
check("cavity starts above base and floor", cavity.z0, 5.95)
check("left wall", cavity.x0, 1.2)
check("right wall", 83.5-cavity.x1, 1.2)

local compartment_cuts = 0
for _, b in ipairs(boxes) do
    if b.type == "Negative" and b.tag == "cube"
       and math.abs(b.z0 - 5.95) < 1e-6 then
        compartment_cuts = compartment_cuts + 1
    end
end
check("one connected negative volume per compartment", compartment_cuts, 2)

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

check("no hollow base with compartments or magnets", #tagged(boxes, "stl:pocket"), 0)
check("no lip support with compartments", #tagged(boxes, "stl:support_42"), 0)

-- UltraLight, one cell, 1 unit high: the reference design. Hollow foot over a
-- 1.0 mm floor, cavity open to the wall, lip support ring right on the pocket.
objects = {}
execute {
    units_x=1, units_y=1, height_units=1, ultralight=true, floor_th=1.2,
    columns=1, rows=1, divider_th=1.2, magnet_holes=false,
    stacking_lip=true, label=""
}
boxes = world_boxes(objects[1])
local pockets = tagged(boxes, "stl:pocket")
check("one hollow pocket", #pockets, 1)
check("pocket over a 1.0 mm floor", pockets[1].z0, 1.0)
check("pocket centred", (pockets[1].x0 + pockets[1].x1) * 0.5, 20.75)
check("1U bin is 7 mm plus the lip", extent(boxes, function(b) return b.type=="Solid" end).z1, 10.7)
local support = extent(boxes, function(b) return b.tag and b.tag:find("stl:support") end)
check("support starts 2 mm below the lip", support.z0, 5.0)
check("support is 1.4 mm tall", support.z1 - support.z0, 1.4)
check("support starts at the 1.2 mm wall", support.x0, 1.2)
check("support mirrored on the far wall", 41.5 - support.x1, 1.2)
local front = 0
for _, b in ipairs(boxes) do
    if b.tag and b.tag:find("stl:support") and math.abs(b.y0 - 1.2) < 1e-6 then
        front = front + (b.x1 - b.x0)
    end
end
-- 34 mm straight plus two corners, each 2.55 mm from the wall to its arc centre.
check("front support tiles the side", front, 34 + 2 * 2.55)
for _, b in ipairs(tagged(boxes, "stl:support_corner")) do
    if b.type ~= "Negative" then error("support corner must be a negative volume") end
end
local backing = extent(boxes, function(b)
    return b.type == "Negative" and b.tag == "cube" and b.z1 > 6.9
end)
check("open area above the support is inside the 2.6 mm lip backing", backing.x0, 2.6)

-- UltraLight over 2 x 1 cells: a pocket per cell, a floor between them.
objects = {}
execute {
    units_x=2, units_y=1, height_units=3, ultralight=true, floor_th=1.2,
    columns=1, rows=1, divider_th=1.2, magnet_holes=false,
    stacking_lip=true, label=""
}
boxes = world_boxes(objects[1])
check("one pocket per cell", #tagged(boxes, "stl:pocket"), 2)
local between = 0
for _, b in ipairs(boxes) do
    if b.type == "Negative" and b.x0 < 41.75 and b.x1 > 41.75 and b.z0 < 5.75 - 1e-6 then
        between = between + 1
    end
end
check("nothing cuts the floor between the cells", between, 0)

-- A 1 unit high multi-cell bin has no room for that floor: solid base instead.
objects = {}
execute {
    units_x=2, units_y=1, height_units=1, ultralight=true, floor_th=1.2,
    columns=1, rows=1, divider_th=1.2, magnet_holes=false,
    stacking_lip=true, label=""
}
check("1U multi-cell falls back to a solid base", #tagged(world_boxes(objects[1]), "stl:pocket"), 0)

done()
