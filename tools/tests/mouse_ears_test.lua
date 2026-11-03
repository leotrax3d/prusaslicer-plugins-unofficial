-- The plugin carries the start G-code as a string; the snippet file is the copy
-- people read on GitHub. They must never drift apart.
dofile("plugins/dev.leotrax3d.mouse-ears/mouse_ears.lua")

local f = assert(io.open("docs/snippets/mouse-ears-start-gcode.gcode", "rb"))
local snippet = f:read("a"):gsub("\r\n", "\n")
f:close()

local default
for _, p in ipairs(info.params) do
    if p.name == "gcode" then default = p.default end
end
assert(default == snippet, "mouse_ears.lua START_GCODE differs from the snippet file")

-- OK must leave the project untouched.
api = setmetatable({}, {__index = function(_, k) error("execute touched api." .. k) end})
execute {gcode = default}

print("ok   mouse ears plugin carries the snippet and changes nothing")
