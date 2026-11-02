local function vector(x, y, z)
    return { x = x, y = y, z = z }
end

vector3 = vector
Config = nil
dofile('config.lua')
dofile('shared/catalog.lua')

-- pure helper shared by client and server
assert(Customs.mechanicsOnDuty({ 'mechanic', 'bennys' }, function(job) return ({ mechanic = 2, bennys = 1 })[job] end) == 3)
assert(Customs.mechanicsOnDuty({ 'mechanic' }, function() return nil end) == 0, 'missing counts are zero')
assert(Customs.mechanicsOnDuty(nil, function() return 5 end) == 0, 'no jobs configured counts nobody')

local handlers = {}
Kora = {
    distance = { coords = function(a, b, distance)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return dx * dx + dy * dy + dz * dz <= distance * distance
    end },
    callback = { register = function(name, callback) handlers[name] = callback end },
    world = {
        resolveNetworkEntity = function(src, networkId, options)
            if networkId ~= 99 then return nil, 'entity_unavailable' end
            if options.requireDriver and not driving then return nil, 'driver_required' end
            return 20
        end,
    },
}

local now, onDuty, balance, charges = 0, 0, 5000, {}
driving = true
local playerCoords = vector(-211.55, -1324.55, 30.89)
exports = { kora_core = {
    getDutyCount = function(_, job) return job == 'mechanic' and onDuty or 0 end,
    getPlayerData = function() return 'CID1' end,
    removeMoney = function(_, _, account, amount)
        if balance < amount then return false, 'insufficient funds' end
        balance = balance - amount
        charges[#charges + 1] = { account = account, amount = amount }
        return true
    end,
    logEvent = function() return true end,
} }
GetGameTimer = function() return now end
AddEventHandler = function() end
GetPlayerPed = function() return 10 end
DoesEntityExist = function() return true end
GetEntityCoords = function(entity) return entity == 10 and playerCoords or vector(-211.55, -1324.55, 30.89) end
GetPlayerRoutingBucket = function() return 0 end

dofile('server/main.lua')
local start, finish = handlers['kora_customs:repairStart'], handlers['kora_customs:repairFinish']
assert(type(start) == 'function' and type(finish) == 'function', 'repair callbacks registered')
local settings = Config.selfRepair

-- a mechanic on duty means no self-service repair
onDuty = 1
local ok, result = start(1, 'bennys', 99)
assert(ok == false and result:find('mechanic', 1, true), 'refused while a mechanic is on duty')
settings.onlyWhenNoMechanics = false
ok = start(1, 'bennys', 99)
assert(ok == true, 'onlyWhenNoMechanics = false always offers it')
settings.onlyWhenNoMechanics = true
onDuty = 0

-- shop, seat and distance are checked on the server
ok, result = start(1, 'nowhere', 99)
assert(ok == false and result == 'unknown custom shop')
driving = false
ok, result = start(1, 'bennys', 99)
assert(ok == false and result == 'you must be driving the vehicle')
driving = true
playerCoords = vector(0, 0, 0)
ok, result = start(1, 'bennys', 99)
assert(ok == false and result == 'too far from the custom shop')
playerCoords = vector(-211.55, -1324.55, 30.89)

-- finishing early, or without a ticket, is refused and not charged
ok, result = start(1, 'bennys', 99)
assert(ok == true and result.price == settings.price and result.durationMs == settings.durationMs)
now = 1000
ok, result = finish(1)
assert(ok == false and result == 'the repair was not finished' and #charges == 0)
ok, result = finish(1)
assert(ok == false and result == 'start the repair again', 'tickets are single use')

-- a completed repair is charged once to the configured account
now = 10000
ok = start(1, 'bennys', 99)
now = now + settings.durationMs
ok, result = finish(1)
assert(ok == true and result.price == settings.price, result)
assert(#charges == 1 and charges[1].account == settings.account and charges[1].amount == settings.price)

-- cooldown per character
ok, result = start(1, 'bennys', 99)
assert(ok == false and result:find('again in', 1, true), 'cooldown applies')
now = now + settings.cooldownSeconds * 1000

-- a mechanic clocking in during the bar stops the charge
ok = start(1, 'bennys', 99)
assert(ok == true)
now = now + settings.durationMs
onDuty = 1
ok, result = finish(1)
assert(ok == false and #charges == 1, 'rechecked at the end, uncharged')
onDuty = 0

-- cannot pay, no repair
balance = 0
ok = start(1, 'bennys', 99)
now = now + settings.durationMs
ok, result = finish(1)
assert(ok == false and result == 'insufficient funds' and #charges == 1)

settings.enabled = false
ok, result = start(1, 'bennys', 99)
assert(ok == false, 'disabled means no repairs')

print('kora_customs self repair: ok')
