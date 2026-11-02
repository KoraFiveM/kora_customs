vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile("config.lua")
local ui = Config.ui
assert(ui.blockPauseMenu == true, "the pause menu is blocked over the shop by default")
assert(type(ui.pauseGuardMs) == "number" and ui.pauseGuardMs >= 0 and ui.pauseGuardMs <= 2000,
    "pauseGuardMs is a short, non-negative grace period")

local source = assert(io.open("client/main.lua")):read("a")
assert(source:find("Esc / Backspace cancel", 1, true), "the freecam help text names Escape as cancel")
assert(source:find("pressed(177) or pressed(200)", 1, true), "Escape (200) cancels like Backspace")
