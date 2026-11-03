local function vector(x, y, z)
    return { x = x, y = y, z = z }
end

vector3 = vector
Config = nil
dofile('config.lua')
dofile('shared/catalog.lua')

local handlers = {}
Kora = {
    distance = { coords = function(a, b, distance)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return dx * dx + dy * dy + dz * dz <= distance * distance
    end },
    callback = {
        register = function(name, callback)
            handlers[name] = callback
        end,
    },
    world = {
        resolveNetworkEntity = function(src, networkId, options)
            local entity = NetworkGetEntityFromNetworkId(networkId)
            local ped = GetPlayerPed(src)
            if entity == 0 or not DoesEntityExist(entity) then return nil, 'entity_unavailable' end
            if GetEntityType(entity) ~= 2 then return nil, 'wrong_entity_type' end
            if options.sameBucket and GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entity) then
                return nil, 'routing_bucket_mismatch'
            end
            if options.requireDriver and GetPedInVehicleSeat(entity, -1) ~= ped then return nil, 'driver_required' end
            return entity
        end,
    },
}

local calls = {}
local row = {
    plate = 'TEST01', model = '100', citizenid = 'CID1', state = 'out',
    mods = { color1 = 1, extras = { ['1'] = false } },
}
local saveSucceeds = true
local balance = 5000
local core = {}

function core.getByPlate(_, plate)
    calls.plate = plate
    return row
end

function core.getPlayerData()
    return 'CID1'
end

function core.removeMoney(_, _, account, amount)
    calls.charge = { account = account, amount = amount }
    if balance < amount then return false, 'insufficient funds' end
    balance = balance - amount
    return true
end

function core.addMoney(_, _, account, amount, reason, ignoreTax)
    calls.refund = { account = account, amount = amount, reason = reason, ignoreTax = ignoreTax }
    balance = balance + amount
    return true
end

function core.saveVehicleProperties(_, plate, properties)
    calls.save = { plate = plate, properties = properties }
    return saveSucceeds, saveSucceeds and nil or 'database unavailable'
end

function core.logEvent() return true end

exports = { kora_core = core }
GetPlayerPed = function() return 10 end
DoesEntityExist = function(entity) return entity == 10 or entity == 20 end
GetEntityCoords = function() return vector(-211.55, -1324.55, 30.89) end
GetPlayerRoutingBucket = function() return 0 end
NetworkGetEntityFromNetworkId = function(netId) return netId == 99 and 20 or 0 end
GetEntityType = function(entity) return entity == 20 and 2 or 1 end
GetVehiclePedIsIn = function() return 20 end
GetPedInVehicleSeat = function() return 10 end
GetEntityRoutingBucket = function() return 0 end
GetVehicleNumberPlateText = function() return ' TEST01 ' end
GetEntityModel = function() return 100 end
joaat = function() return 100 end

AddEventHandler = function() end
GetGameTimer = function() return 0 end
dofile('server/main.lua')
local quote = handlers['qbcustoms:quote']
local purchase = handlers['qbcustoms:purchase']
assert(type(quote) == 'function' and type(purchase) == 'function', 'shop callbacks registered')

local configuredBucket = Config.shops.bennys.bucket
Config.shops.bennys.bucket = nil
local ok, result = quote(1, 'bennys', 99, { color1 = 2 })
assert(ok == false and result:find('routing bucket', 1, true), 'shops fail closed without a routing bucket')
Config.shops.bennys.bucket = configuredBucket

ok, result = quote(1, 'bennys', 99, { color1 = 2, modSpoilers = 1 })
assert(ok == true and result.price == 850, 'quote is computed server-side')
assert(calls.charge == nil, 'quote does not charge')

ok, result = purchase(1, 'bennys', 99, { color1 = 2, modSpoilers = 1 }, result.price)
assert(ok == true, result)
assert(result.price == 850, 'server computes the price')
assert(calls.charge.account == 'bank' and calls.charge.amount == 850, 'server charges configured account')
assert(calls.save.properties.color1 == 2 and calls.save.properties.modSpoilers == 1, 'validated fields persist')
assert(calls.save.properties.extras['1'] == false, 'existing cosmetic properties remain')

calls.charge = nil
ok, result = purchase(1, 'bennys', 99, { color1 = 3 }, 1)
assert(ok == false and result:find('price changed', 1, true), 'a stale or forged quote is refused')
assert(calls.charge == nil, 'quote mismatch is not charged')

ok, result = purchase(1, 'bennys', 99, { modEngine = 3 }, 0)
assert(ok == false and result:find('unsupported', 1, true), 'performance upgrades are refused')
assert(calls.charge == nil, 'invalid requests are not charged')

row.citizenid = 'OTHER'
ok, result = purchase(1, 'bennys', 99, { color1 = 3 }, 350)
assert(ok == false and result == 'this is not your vehicle', 'ownership is enforced')
row.citizenid = 'CID1'

saveSucceeds = false
calls.refund = nil
local before = balance
ok, result = purchase(1, 'bennys', 99, { color1 = 4 }, 350)
assert(ok == false and result == 'database unavailable', 'save failure is surfaced')
assert(balance == before, 'failed persistence is refunded')
assert(calls.refund.ignoreTax == true, 'refund is tax-free')

-- Current clients still send full preview properties as the sixth argument.
saveSucceeds = true
calls = {}
row.mods = { color1 = 1, modEngine = 1, extras = { ['1'] = false } }
local previewProperties = { color1 = 255, modEngine = 4, modSpoilers = 200, plate = 'OTHER', fuelLevel = 100 }
before = balance
ok, result = purchase(1, 'bennys', 99, { color1 = 2 }, 350, previewProperties)
assert(ok == true, result)
assert(balance == before - 350 and calls.refund == nil, 'valid checkout charges once without refunding')
assert(calls.save.properties.color1 == 2, 'only selected paint reaches persistence')
assert(calls.save.properties.modEngine == 1, 'existing performance data is preserved')
assert(calls.save.properties.modSpoilers == nil, 'unselected preview fields cannot reach persistence')
assert(calls.save.properties.plate == nil and calls.save.properties.fuelLevel == nil, 'preview identity and condition stay out')
assert(calls.save.properties.extras['1'] == false, 'existing cosmetic fields remain')
assert(previewProperties.color1 == 255 and row.mods.color1 == 1, 'input and stored snapshots remain unchanged')

-- Paint and window tint are charged and persisted like everything else, and a
-- client-reported price or full preview blob changes neither.
saveSucceeds = true
calls = {}
row.mods = { color1 = 1, windowTint = 0, extras = { ['1'] = false } }
before = balance
ok, result = quote(1, 'bennys', 99, { windowTint = 3, pearlescentColor = 9, color2 = { r = 1, g = 2, b = 3 } })
local paintOrder = Config.prices.windowTint + Config.prices.pearlescent + Config.prices.customSecondary
assert(ok == true and result.price == paintOrder, 'quote covers tint, pearlescent and custom RGB at their own prices')
ok, result = purchase(1, 'bennys', 99, { windowTint = 3, pearlescentColor = 9, color2 = { r = 1, g = 2, b = 3 } }, 1)
assert(ok == false and result:find('price changed', 1, true) and balance == before, 'a forged price is refused uncharged')
ok, result = purchase(1, 'bennys', 99, { windowTint = 3, pearlescentColor = 9, color2 = { r = 1, g = 2, b = 3 } }, paintOrder,
    { windowTint = 0, color1 = 255 })
assert(ok == true and balance == before - paintOrder, 'tint, pearlescent and custom RGB are all charged')
assert(calls.save.properties.windowTint == 3 and calls.save.properties.color1 == 1, 'only the purchased fields change')

-- nothing is persisted unless the charge went through
saveSucceeds = true
calls = {}
local funds = balance
balance = 0
ok, result = purchase(1, 'bennys', 99, { windowTint = 4, color1 = 7 }, Config.prices.windowTint + Config.prices.primaryPaint)
assert(ok == false and result == 'insufficient funds', 'an order that cannot be paid is refused')
assert(calls.save == nil and calls.refund == nil, 'an unpaid order is never saved')
balance = funds

-- an unchanged order is not a purchase
ok, result = quote(1, 'bennys', 99, { color1 = 1 })
assert(ok == false and result == 'no changes selected', 'identical paint is not an order')

-- every paint category is priced and charged by the server
for field, key in pairs({ color1 = 'primaryPaint', color2 = 'secondaryPaint', pearlescentColor = 'pearlescent',
    wheelColor = 'wheelPaint', windowTint = 'windowTint' }) do
    assert(Config.prices[key] > 0, key .. ' has a default price')
    calls = {}
    row.mods = { color1 = 1, color2 = 1, pearlescentColor = 1, wheelColor = 1, windowTint = 0 }
    before = balance
    ok, result = purchase(1, 'bennys', 99, { [field] = 5 }, Config.prices[key])
    assert(ok == true and calls.charge.amount == Config.prices[key] and balance == before - Config.prices[key], field .. ' is charged ' .. key)
end
for field, key in pairs({ color1 = 'customPrimary', color2 = 'customSecondary' }) do
    calls = {}
    ok, result = quote(1, 'bennys', 99, { [field] = { r = 9, g = 9, b = 9 } })
    assert(ok == true and result.price == Config.prices[key], field .. ' custom RGB is priced as ' .. key)
end

-- a field priced at zero cannot ride along in a paid order
local tintPrice = Config.prices.windowTint
Config.prices.windowTint = 0
calls.charge = nil
ok, result = purchase(1, 'bennys', 99, { windowTint = 5, modSpoilers = 1 }, 500)
assert(ok == false and result == 'custom shop pricing is invalid' and calls.charge == nil, 'free field is refused')
Config.interaction.allowFreeFields = true
ok, result = purchase(1, 'bennys', 99, { windowTint = 5, modSpoilers = 1 }, 500)
assert(ok == true and calls.charge.amount == 500, 'allowFreeFields restores the old behaviour')
Config.interaction.allowFreeFields = false
Config.prices.windowTint = tintPrice

-- Factory look (Config.factoryLook): a car with no stored look keeps the look
-- read when the session opened as its baseline, once; paid orders merge on top.
local factoryLook = handlers['kora_customs:factoryLook']
assert(type(factoryLook) == 'function', 'factory look callback registered')
assert(Config.factoryLook.enabled == true and Config.factoryLook.fillMissing == true, 'the factory look is stored by default')

local function useCar(plate, mods)
    GetVehicleNumberPlateText = function() return ' ' .. plate .. ' ' end
    row.plate, row.mods, row.citizenid = plate, mods, 'CID1'
    calls = {}
end
local snapshot = {
    plate = 'FRESH1', model = 100, fuelLevel = 63.0, engineHealth = 1000.0, bodyHealth = 990.0,
    modEngine = 3, modTurbo = true, tireHealth = { [0] = 1000.0 },
    color1 = 27, color2 = 0, pearlescentColor = 5, wheelColor = 156, windowTint = -1, xenonColor = 255,
    neonEnabled = { false, false, false, false }, extras = { ['1'] = true, ['2'] = false }, modSpoilers = -1,
}

useCar('FRESH1', nil)
ok, result = factoryLook(1, 'bennys', 99, 'not a table')
assert(ok == false and calls.save == nil, 'a snapshot that is not a props table is refused')
snapshot.plate = 'OTHER9'
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and calls.save == nil, 'a snapshot of another car is refused')
snapshot.plate = 'FRESH1'
snapshot.model = 101
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and calls.save == nil, 'a snapshot of another model is refused')
snapshot.model = 100
row.citizenid = 'OTHER'
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and result == 'this is not your vehicle' and calls.save == nil, 'only the player\'s own car')
row.citizenid = 'CID1'
row.state = 'garaged'
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and calls.save == nil, 'only a car that is out')
row.state = 'out'
Config.factoryLook.enabled = false
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and calls.save == nil, 'enabled = false stores nothing')
Config.factoryLook.enabled = true

before = balance
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == true and result.stored == true and calls.save.plate == 'FRESH1', 'a car with no stored look gets its baseline')
local base = calls.save.properties
assert(base.color1 == 27 and base.color2 == 0 and base.pearlescentColor == 5 and base.wheelColor == 156
    and base.windowTint == -1 and base.modSpoilers == -1 and base.neonEnabled[1] == false
    and base.extras['1'] == true and base.extras['2'] == false, 'the cosmetic fields are stored as read')
assert(base.modEngine == nil and base.modTurbo == nil and base.plate == nil and base.model == nil and base.fuelLevel == nil
    and base.engineHealth == nil and base.bodyHealth == nil and base.tireHealth == nil,
    'performance, identity and condition never come from the snapshot')
assert(base.xenonColor == nil, 'a field that fails its check is left out')
assert(balance == before and calls.charge == nil, 'storing the baseline charges nothing')

row.mods = nil
calls = {}
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == true and result.stored == false and calls.save == nil, 'the baseline is stored once per plate')

row.mods = base
ok, result = purchase(1, 'bennys', 99, { windowTint = 3 }, Config.prices.windowTint)
assert(ok == true and calls.save.properties.windowTint == 3 and calls.save.properties.color1 == 27
    and calls.save.properties.wheelColor == 156, 'a paid order merges on top of the baseline')

-- a row with part of a look (customised before it was first parked)
useCar('PAID01', { windowTint = 3, color1 = 12, modEngine = 2 })
snapshot.plate = 'PAID01'
ok, result = factoryLook(1, 'bennys', 99, snapshot)
local filled = calls.save and calls.save.properties
assert(ok == true and result.stored == true and filled.windowTint == 3 and filled.color1 == 12 and filled.modEngine == 2
    and filled.color2 == 0 and filled.wheelColor == 156, 'fillMissing adds only the missing fields; stored ones win')

Config.factoryLook.fillMissing = false
useCar('PAID02', { windowTint = 3 })
snapshot.plate = 'PAID02'
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == true and result.stored == false and calls.save == nil, 'without fillMissing a row with a look is left alone')
Config.factoryLook.fillMissing = true

-- a failed save may be retried by the next session
useCar('FAIL01', nil)
snapshot.plate = 'FAIL01'
saveSucceeds = false
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == false and result == 'database unavailable', 'a failed save is reported')
saveSucceeds = true
ok, result = factoryLook(1, 'bennys', 99, snapshot)
assert(ok == true and result.stored == true, 'a failed save does not use up the one baseline')

print('qbcustoms server: ok')
