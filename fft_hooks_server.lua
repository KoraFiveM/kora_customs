-- Optional FFT development hooks (server). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- Depends on the approved seam in server/main.lua (Customs._fftResetRepair),
-- which clears one entry of the file-local self-repair cooldown table so the
-- repair scenarios can be repeated without waiting Config.selfRepair.cooldownSeconds.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1

local function authorised(src)
    if GetResourceState(RUNNER) ~= 'started' then return false end
    if type(src) ~= 'number' or src <= 0 or src ~= math.floor(src) then return false end
    if not GetPlayerName(src) then return false end
    return type(Player(src).state.fftSession) == 'string'
end

local actions = {}

-- Clears the tester's own self-repair cooldown. The key mirrors checkRepair in
-- server/main.lua: the character's citizenid, or 'player:<src>' without one.
-- It never touches a ticket, a price, a balance or another player's cooldown.
function actions.resetRepairCooldown(src)
    if type(Customs) ~= 'table' or type(Customs._fftResetRepair) ~= 'function' then
        return false, 'Repair cooldown seam is missing', 'blocked'
    end
    local ok, citizenid = pcall(function() return exports.kora_core:getPlayerData(src, { 'citizenid' }) end)
    local key = ok and type(citizenid) == 'string' and citizenid or ('player:%d'):format(src)
    Customs._fftResetRepair(key)
    return true
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, src, ...)
    if GetInvokingResource() ~= RUNNER or not authorised(src) then
        return false, 'FFT hooks are disabled or session is not authorised', 'blocked'
    end
    if type(action) ~= 'string' or #action > 64 then return false, 'Unsupported FFT action', 'invalid' end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. action, 'invalid' end
    return handler(src, ...)
end)
