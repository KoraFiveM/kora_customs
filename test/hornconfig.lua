vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
dofile("shared/horn.lua")
local h = Config.hornPreview
assert(type(h.holdToTest) == "boolean", "holdToTest is a documented boolean")
assert(h.holdToTest == false and h.holdKey == false,
    "Test horn plays once per click by default (hold to test is the opt-in); no key is bound unless asked")
assert(h.maxHoldMs >= 500, "maxHoldMs is a sane cap")
assert(h.method == "input", "the preview holds the horn on the player's own vehicle by default (the stand-in was silent)")
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

-- The game only taps a horn while a player sits in the driver seat, so on the
-- player's own vehicle the horn key is held for the preview; and a preview
-- sounds once per press: a timer that re-triggers StartVehicleHorn loops the
-- first fraction. One StartVehicleHorn per method, none in a loop.
local source = assert(io.open("client/main.lua")):read("a")
local sounded = {}
for args in source:gmatch("StartVehicleHorn%(([^,]*),") do sounded[#sounded + 1] = args end
table.sort(sounded)
assert(#sounded == 2 and sounded[1] == "proxy" and sounded[2] == "vehicle",
    "StartVehicleHorn once on the proxy and once on the player's vehicle, got " .. table.concat(sounded, ","))
assert(source:find("return Config.hornPreview and Config.hornPreview.method == 'proxy' and 'proxy' or 'input'", 1, true),
    "any method but 'proxy' (or none) holds the horn on the player's vehicle")
local keyBody = assert(source:match("local function holdHornKey%(token, vehicle, duration%)(.-)\nend"), "holdHornKey exists")
local beforeLoop = assert(keyBody:match("^(.-)CreateThread"), "holdHornKey starts its thread")
assert(beforeLoop:find("StartVehicleHorn(vehicle, duration", 1, true), "the horn is started once, before the key loop")
local loop = assert(keyBody:match("while (.-)\n%s*end"), "holdHornKey holds the key in a loop")
assert(loop:find("token == hornToken", 1, true) and loop:find("untilAt", 1, true) and loop:find("SetControlNormal(0, HORN_CONTROL, 1.0)", 1, true)
    and not loop:find("StartVehicleHorn", 1, true), "the key loop only holds the key, for this preview's length, until a stop")
assert(not source:find("SetHornPermanentlyOn%w*%("), "no horn native that the driver seat cuts short")
assert(not source:find("hornHold", 1, true), "no re-triggering hold loop")

-- Hold to test: the button is a kora_lib hold action; press starts one
-- continuous horn (maxHoldMs), release stops it. Nothing re-triggers it.
assert(source:find("hold = hold or nil", 1, true), "the horn button is declared as a hold action when holdToTest is on")
assert(source:find("context.hold == 'start' or context.hold == 'end'", 1, true), "onAction handles hold press and release")
local holdBody = assert(source:match("local function holdHorn%(held%)(.-)\nend"), "holdHorn exists")
assert(holdBody:find("stopHorn()", 1, true), "release stops the horn")
local plays = 0
for _ in holdBody:gmatch("playHorn%(") do plays = plays + 1 end
assert(plays == 1 and holdBody:find("maxHoldMs", 1, true), "press starts the horn once, capped at maxHoldMs")
assert(not holdBody:find("while", 1, true), "a held horn is not re-triggered")
local _, timers = holdBody:gsub("SetTimeout%(", "")
assert(timers == 1 and holdBody:find("if token == hornToken then stopHorn() end", 1, true),
    "release only defers one stop of the same horn")
-- A click on the hold button is press + release ~0.1 s apart, before the
-- start delay is over: without clickPlaysFull it played nothing at all.
assert(h.clickPlaysFull == true, "a click on the hold button plays the whole horn once by default")
assert(holdBody:find("clickPlaysFull ~= false", 1, true) and holdBody:find("hornLength(vehicle)", 1, true),
    "a click keeps the horn for its normal preview length")

-- Default (holdToTest = false): Next / Previous / Choose and Test horn each
-- play the fitted horn once for its whole preview length, and a new click
-- cuts the running preview and starts again from the beginning.
assert(source:find("hold and 'Hold to test horn' or 'Test horn'", 1, true), "without holdToTest the button is a plain Test horn")
assert(source:find("horn = testHorn", 1, true), "the plain button runs testHorn")
local testBody = assert(source:match("local function testHorn%(%)(.-)\nend"), "testHorn exists")
assert(testBody:find("playHorn()", 1, true) and not testBody:find("SetTimeout", 1, true) and not testBody:find("while", 1, true),
    "Test horn plays the horn once, at its own preview length")
assert(source:find("Config.hornPreview.autoPlay then playHorn() end", 1, true), "Next / Previous / Choose play the new horn once")
local playBody = assert(source:match("local function playHorn%(duration%)(.-)\nend"), "playHorn exists")
assert(playBody:find("stopHorn()", 1, true) and playBody:find("hornLength(vehicle)", 1, true),
    "a new click cuts the running preview and plays the whole horn")
assert(source:find("Config.hornPreview.holdToTest then holdHorn(false) end", 1, true),
    "releasing the hold key only stops a held horn, never a click's preview")
print("kora_customs horn config: ok")
