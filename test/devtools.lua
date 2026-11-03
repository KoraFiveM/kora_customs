-- F#426: the getVehprop dev command only exists when Config.debug is on.
-- F#427: kora_customs uses no SQL, so it must not load kora_sql.
local source = assert(io.open("client/main.lua")):read("a")
local guarded = source:match("if Config%.debug then%s*RegisterCommand%('getVehprop'")
assert(guarded, "getVehprop is registered only inside `if Config.debug then`")
local _, count = source:gsub("RegisterCommand%('getVehprop'", "")
assert(count == 1, "getVehprop is registered in exactly one place")

local manifest = assert(io.open("fxmanifest.lua")):read("a")
assert(not manifest:find("@kora_sql/", 1, true), "fxmanifest does not load kora_sql")
print("devtools: ok")
