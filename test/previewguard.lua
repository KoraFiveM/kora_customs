vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")

-- Config.previewGuard: documented defaults
local g = Config.previewGuard
assert(type(g) == "table", "previewGuard exists")
assert(g.recheckMs == 500 and g.attempts == 3 and g.reapplyOnOpen == true, "re-check after 500 ms, up to 3 times; put stuck previews back on open")

local source = assert(io.open("client/main.lua")):read("a")
local function body(signature)
    return assert(source:match("local function " .. signature .. "(.-)\nend\n"), signature .. " exists")
end

-- Every unpaid way out goes through restore(): it remembers the previews and
-- schedules a re-check of what it put back.
local restore = body("restore%(%)")
assert(restore:find("Customs.rememberUnpaid(unpaidPreviews[session.plate], session.original, session.shown)", 1, true),
    "restore remembers the session's unpaid previews")
assert(restore:find("recheckRevert(session, 1)", 1, true), "restore re-checks the revert")
assert(restore:find("revertAppearance(vehicle, session.appearance)", 1, true), "paint and glass are still put back directly")

-- The re-check is a few one-off timers, never a loop, and never undoes a
-- purchase or touches a car with a new session open.
local recheck = body("recheckRevert%(session, attempt%)")
assert(not recheck:find("while", 1, true) and not recheck:find("CreateThread", 1, true), "no polling loop")
assert(recheck:find("session.paid", 1, true) and recheck:find("active.vehicle == vehicle", 1, true),
    "a paid order or a new session stops the re-check")
assert(recheck:find("Customs.previewDrift(current, session.original, session.touched)", 1, true), "only previewed fields are compared")
assert(recheck:find("recheckRevert(session, attempt + 1)", 1, true) and recheck:find("attempts", 1, true), "bounded retries")

-- Opening puts stuck previews back before the car is read (and before the
-- factory look is sent).
local openBody = assert(source:match("local function open%(shopId%)(.-)\nend\n"), "open exists")
local putBack = openBody:find("putBackUnpaid(vehicle, plate)", 1, true)
local read = openBody:find("Kora.vehicle.getProperties(vehicle)", 1, true)
local factory = openBody:find("kora_customs:factoryLook", 1, true)
assert(putBack and read and factory and putBack < read and read < factory, "stuck previews are put back before the car is read")
assert(body("putBackUnpaid%(vehicle, plate%)"):find("reapplyOnOpen == false", 1, true), "reapplyOnOpen can turn it off")

-- A paid order clears the memory and stops re-checks before the paid look is
-- shown again.
local paid = source:find("session.paid = true", 1, true)
local shown = source:find("pcall(Kora.vehicle.setProperties, session.vehicle, session.pending", 1, true)
assert(paid and shown and paid < shown, "a purchase is marked paid before its look is applied")
assert(source:find("if session.plate then unpaidPreviews[session.plate] = nil end", 1, true), "a purchase clears the unpaid memory")

-- Every preview records what it showed; a paint preview also marks the
-- pearlescent and wheel colours it pins, so a revert re-checks them too.
local previewBody = body("preview%(field, value%)")
assert(previewBody:find("active.shown[field] = value", 1, true), "previews are recorded")
assert(previewBody:find("active.touched.pearlescentColor, active.touched.wheelColor = true, true", 1, true),
    "paint previews put back and re-check pearlescent and wheel colour")

-- Factory tint (-1) goes on as clear glass (0): a bare -1 leaves the tint showing.
local tint = body("applyTint%(vehicle, tint%)")
assert(tint:find("SetVehicleWindowTint(vehicle, tint < 0 and 0 or tint)", 1, true)
    and not tint:find("SetVehicleWindowTint(vehicle, tint)", 1, true), "-1 is applied as none (0), never set bare")
assert(body("applyAppearance%(vehicle, wanted%)"):find("applyTint(vehicle, wanted.tint)", 1, true), "reverts use applyTint")
print("kora_customs preview guard: ok")
