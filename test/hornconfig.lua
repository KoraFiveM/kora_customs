vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
local h = Config.hornPreview
assert(type(h.holdToTest) == "boolean", "holdToTest is a documented boolean")
assert(h.maxHoldMs >= 500, "maxHoldMs is a sane cap")
assert(h.durationMs >= 1200, "single preview is long enough to hear")
