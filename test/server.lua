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
assert(ok == true and result.price == 350 + 350 + 600, 'quote covers tint, pearlescent and custom RGB')
ok, result = purchase(1, 'bennys', 99, { windowTint = 3, pearlescentColor = 9, color2 = { r = 1, g = 2, b = 3 } }, 1)
assert(ok == false and result:find('price changed', 1, true) and balance == before, 'a forged price is refused uncharged')
ok, result = purchase(1, 'bennys', 99, { windowTint = 3, pearlescentColor = 9, color2 = { r = 1, g = 2, b = 3 } }, 1300,
    { windowTint = 0, color1 = 255 })
assert(ok == true and balance == before - 1300, 'tint, pearlescent and custom RGB are all charged')
assert(calls.save.properties.windowTint == 3 and calls.save.properties.color1 == 1, 'only the purchased fields change')

-- nothing is persisted unless the charge went through
saveSucceeds = true
calls = {}
local funds = balance
balance = 0
ok, result = purchase(1, 'bennys', 99, { windowTint = 4, color1 = 7 }, 700)
assert(ok == false and result == 'insufficient funds', 'an order that cannot be paid is refused')
assert(calls.save == nil and calls.refund == nil, 'an unpaid order is never saved')
balance = funds

-- an unchanged order is not a purchase
ok, result = quote(1, 'bennys', 99, { color1 = 1 })
assert(ok == false and result == 'no changes selected', 'identical paint is not an order')

-- a field priced at zero cannot ride along in a paid order
local paintPrice = Config.prices.paint
Config.prices.paint = 0
calls.charge = nil
ok, result = purchase(1, 'bennys', 99, { windowTint = 5, modSpoilers = 1 }, 500)
assert(ok == false and result == 'custom shop pricing is invalid' and calls.charge == nil, 'free field is refused')
Config.interaction.allowFreeFields = true
ok, result = purchase(1, 'bennys', 99, { windowTint = 5, modSpoilers = 1 }, 500)
assert(ok == true and calls.charge.amount == 500, 'allowFreeFields restores the old behaviour')
Config.interaction.allowFreeFields = false
Config.prices.paint = paintPrice

print('qbcustoms server: ok')
