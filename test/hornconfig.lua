vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
dofile("shared/horn.lua")
local h = Config.hornPreview
assert(type(h.holdToTest) == "boolean", "holdToTest is a documented boolean")
assert(h.holdToTest == false and h.holdKey == false, "one-shot preview is the default; no key is bound unless asked")
assert(h.maxHoldMs >= 500, "maxHoldMs is a sane cap")
assert(h.method == "proxy", "the preview sounds from a stand-in with nobody in the driver seat by default")
assert(h.durationMs >= 500 and h.durationMs <= 3000, "a plain horn sounds like a short press")
assert(h.startDelayMs >= 0 and h.startDelayMs <= 1000, "start delay is short")
assert(h.mode == "HELDDOWN" or h.mode == "NORMAL", "mode is a StartVehicleHorn mode")

-- Length per horn type
local function length(index, name) return Customs.hornDuration(h, index, name) end
assert(length(0, "Truck Horn") == h.durationMs, "plain horns use durationMs")
assert(length(-1, nil) == h.durationMs, "the stock horn uses durationMs")
assert(length(16, "Scale - Do") == h.durationMs, "scale notes are plain horns")
assert(length(3, "Musical Horn 1") >= 4000, "a musical horn gets time to finish")
assert(length(8, "Sad Trombone") >= 4000, "sad trombone is musical")
assert(length(9, "CLASSICAL HORN 1") >= 4000, "names match in any case")
local loop = length(27, "Jazz Horn Loop")
assert(loop >= 4000 and loop == length(32, "Classical Horn Loop 1"), "loop horns get one pass, whatever the tune")
assert(Customs.hornDuration({ durationMs = 1500, byIndex = { [27] = 9000 }, durations = h.durations }, 27, "Jazz Horn Loop") == 9000,
    "byIndex wins over the name rules")
assert(Customs.hornDuration({ durationMs = 1500, byIndex = { ["5"] = 2500 } }, 5, "x") == 2500, "byIndex accepts string keys")
assert(Customs.hornDuration({ durations = { { match = "hupe", ms = 3000 } } }, 1, "Polizei-Hupe") == 3000, "rules translate")
assert(Customs.hornDuration(nil, 1, "Truck Horn") == 1500, "works without a config")
assert(Customs.hornDuration({ durationMs = "bad", durations = { { match = "", ms = 9 } } }, 1, "x") == 1500,
    "bad values fall back")

-- The game only taps a horn while a player sits in the driver seat, so the
-- preview must never sound the player's own vehicle, and must sound once
-- per press: a timer that re-triggers StartVehicleHorn loops the first fraction.
local source = assert(io.open("client/main.lua")):read("a")
local calls = 0
for args in source:gmatch("StartVehicleHorn%(([^,]*),") do
    calls = calls + 1
    assert(args == "proxy", "StartVehicleHorn only sounds the proxy, got " .. args)
end
assert(calls == 1, "one StartVehicleHorn per preview")
assert(not source:find("SetHornPermanentlyOn%w*%("), "no horn native that the driver seat cuts short")
assert(not source:find("hornHold", 1, true), "no re-triggering hold loop")
print("kora_customs horn config: ok")
