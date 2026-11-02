vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
local h = Config.hornPreview
assert(type(h.holdToTest) == "boolean", "holdToTest is a documented boolean")
assert(h.holdToTest == false and h.holdKey == false, "one-shot preview is the default; no key is bound unless asked")
assert(h.maxHoldMs >= 500, "maxHoldMs is a sane cap")
assert(h.durationMs >= 3000, "one preview is long enough for a musical horn to finish")
assert(h.startDelayMs >= 0 and h.startDelayMs <= 1000, "start delay is short")
assert(h.mode == "HELDDOWN" or h.mode == "NORMAL", "mode is a StartVehicleHorn mode")

-- The preview must sound the horn once per press: a timer that re-triggers
-- StartVehicleHorn restarts the sample and loops the first fraction of it.
local source = assert(io.open("client/main.lua")):read("a")
local calls = 0
for _ in source:gmatch("StartVehicleHorn%(") do calls = calls + 1 end
assert(calls == 2, "one StartVehicleHorn to play, one 1 ms horn to stop")
assert(not source:find("hornHold", 1, true), "no re-triggering hold loop")
print("kora_customs horn config: ok")
