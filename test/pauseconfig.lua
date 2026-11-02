vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
local ui = Config.ui
assert(ui.blockPauseMenu == true, "the pause menu is blocked over the shop by default")
assert(type(ui.pauseGuardMs) == "number" and ui.pauseGuardMs >= 0 and ui.pauseGuardMs <= 2000,
    "pauseGuardMs is a short, non-negative grace period")

local source = assert(io.open("client/main.lua")):read("a")
assert(source:find("pcall(Kora.nui.registerApp, appDefinition)", 1, true), "a left-hand panel falls back when the shell refuses it")
assert(source:find("elseif DoesEntityExist(session.vehicle) then", 1, true), "a purchase finishing after Escape is shown on the vehicle")
assert(source:find("Esc / Backspace cancel", 1, true), "the freecam help text names Escape as cancel")
assert(source:find("pressed(177) or pressed(200)", 1, true), "Escape (200) cancels like Backspace")
