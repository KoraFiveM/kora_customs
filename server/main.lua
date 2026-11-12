local purchasing = {}

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return nil end
    local normalized = plate:match('^%s*(.-)%s*$'):upper()
    return normalized ~= '' and normalized or nil
end

local function core(name, ...)
    local args = { ... }
    local ok, first, second = pcall(function()
        return exports.kora_core[name](exports.kora_core, table.unpack(args))
    end)
    if not ok then return nil, 'kora_core is unavailable' end
    return first, second
end

local function resolveShop(src, shopId)
    if type(shopId) ~= 'string' then return nil, 'invalid custom shop' end
    local shop = Config.shops[shopId]
    if not shop then return nil, 'unknown custom shop' end

    if type(GetPlayerPed) ~= 'function' or type(DoesEntityExist) ~= 'function'
        or type(GetEntityCoords) ~= 'function' then return nil, 'position validation unavailable' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil, 'player entity unavailable' end

    local bucket = tonumber(shop.bucket)
    if Config.interaction.requireSameBucket ~= false then
        if not bucket then return nil, 'custom shop routing bucket is not configured' end
        if type(GetPlayerRoutingBucket) ~= 'function' then return nil, 'routing bucket validation unavailable' end
        if GetPlayerRoutingBucket(src) ~= bucket then return nil, 'custom shop is not in your world' end
    end

    if not Kora.distance.coords(GetEntityCoords(ped), shop.coords,
        tonumber(Config.interaction.checkoutDistance) or 12.0) then
        return nil, 'too far from the custom shop'
    end
    return { shop = shop, ped = ped, bucket = bucket }
end

local function resolveVehicle(src, resolved, netId)
    local vehicle, reason = Kora.world.resolveNetworkEntity(src, tonumber(netId), {
        entityType = 'vehicle',
        maxDistance = tonumber(Config.interaction.checkoutDistance) or 12.0,
        sameBucket = Config.interaction.requireSameBucket ~= false,
        requireDriver = true,
    })
    if not vehicle then
        if reason == 'driver_required' then return nil, 'you must be driving the vehicle' end
        if reason == 'routing_bucket_mismatch' then return nil, 'vehicle is not in your world' end
        if reason == 'too_far' then return nil, 'vehicle is too far away' end
        return nil, 'vehicle does not exist'
    end
    if not Kora.distance.coords(GetEntityCoords(vehicle), resolved.shop.coords,
        tonumber(Config.interaction.checkoutDistance) or 12.0) then
        return nil, 'vehicle is not at the custom shop'
    end
    return vehicle
end

local function ownedRow(src, vehicle)
    if type(GetVehicleNumberPlateText) ~= 'function' then return nil, 'vehicle details unavailable' end
    local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
    if not plate then return nil, 'vehicle has no plate' end

    local row = core('getByPlate', plate)
    if type(row) ~= 'table' then return nil, 'this vehicle is not owned' end
    local citizenid = core('getPlayerData', src, { 'citizenid' })
    if type(citizenid) ~= 'string' or row.citizenid ~= citizenid then return nil, 'this is not your vehicle' end
    if row.state ~= 'out' then return nil, 'vehicle ownership state is invalid' end

    if type(GetEntityModel) == 'function' then
        local expected = tonumber(row.model)
        if not expected and type(joaat) == 'function' then expected = joaat(row.model) end
        if expected and GetEntityModel(vehicle) ~= expected then return nil, 'vehicle model does not match its ownership record' end
    end
    return row
end

local function prepare(src, shopId, netId, requestedPatch)
    local resolved, resolveErr = resolveShop(src, shopId)
    if not resolved then return nil, resolveErr end
    local vehicle, vehicleErr = resolveVehicle(src, resolved, netId)
    if not vehicle then return nil, vehicleErr end
    local row, rowErr = ownedRow(src, vehicle)
    if not row then return nil, rowErr end

    local patch, patchErr = Customs.sanitizePatch(requestedPatch)
    if not patch then return nil, patchErr end
    patch = Customs.changedPatch(patch, type(row.mods) == 'table' and row.mods or {})
    if next(patch) == nil then return nil, 'no changes selected' end

    local price = Customs.price(patch)
    if price <= 0 then return nil, 'custom shop pricing is invalid' end
    if Config.interaction.allowFreeFields ~= true and #Customs.unpriced(patch) > 0 then
        return nil, 'custom shop pricing is invalid'
    end
    return { row = row, patch = patch, price = price }
end

Kora.callback.register('kora_customs:quote', function(src, shopId, netId, requestedPatch)
    local prepared, err = prepare(src, shopId, netId, requestedPatch)
    if not prepared then return false, err end
    return true, { price = prepared.price, plate = prepared.row.plate }
end, { rateLimit = { max = 8, window = 10000 } })

-- Keep the extra client argument compatible; only the validated patch reaches persistence.
Kora.callback.register('kora_customs:purchase', function(src, shopId, netId, requestedPatch, quotedPrice, mods)
    local prepared, prepareErr = prepare(src, shopId, netId, requestedPatch)
    if not prepared then return false, prepareErr end
    local row, patch, price = prepared.row, prepared.patch, prepared.price
    if tonumber(quotedPrice) ~= price then return false, 'customisation price changed; review the new quote' end
    if purchasing[row.plate] then return false, 'this vehicle already has a purchase in progress' end

    purchasing[row.plate] = true
    local charged = false
    local refunded = false
    local ok, result, err = pcall(function()
        local paid, payErr = core('removeMoney', src, Config.interaction.account, price, Config.interaction.reason)
        if not paid then return false, payErr or 'insufficient funds' end
        charged = true

        local properties = Customs.merge(type(row.mods) == 'table' and row.mods or {}, patch)
        local saved, saveErr = core('saveVehicleProperties', row.plate, properties)
        if not saved then
            core('addMoney', src, Config.interaction.account, price, 'vehicle-customisation-refund', true)
            refunded = true
            return false, saveErr or 'could not save vehicle customisation'
        end

        pcall(function()
            exports.kora_core:logEvent('vehicle-customisation', src, {
                plate = row.plate, shop = shopId, price = price, fields = patch,
            })
        end)
        return true, { price = price, plate = row.plate }
    end)
    purchasing[row.plate] = nil

    if not ok then
        if charged and not refunded then
            core('addMoney', src, Config.interaction.account, price, 'vehicle-customisation-refund', true)
        end
        return false, 'customisation purchase failed'
    end
    if not result then return false, err end
    return true, err
end, { rateLimit = { max = 4, window = 10000 } })

-- Factory look (Config.factoryLook). A bought car is saved with no look and the
-- garage stores none for it, so the client sends the properties it read when
-- the session opened, before any preview. They are kept only for the driver's
-- own car at the shop, only while its row has no look (or, with fillMissing,
-- for the fields it lacks), only the shop's cosmetic fields, and once per plate
-- while the resource runs. Previews are local to the client, so the server
-- cannot see them: the snapshot must be the one taken before the first.
local lookTaken = {}

local function factoryLookSettings()
    return type(Config.factoryLook) == 'table' and Config.factoryLook or {}
end

Kora.callback.register('kora_customs:factoryLook', function(src, shopId, netId, properties)
    local settings = factoryLookSettings()
    if settings.enabled ~= true then return false, 'factory look is not stored' end
    if type(properties) ~= 'table' then return false, 'invalid vehicle properties' end

    local resolved, resolveErr = resolveShop(src, shopId)
    if not resolved then return false, resolveErr end
    local vehicle, vehicleErr = resolveVehicle(src, resolved, netId)
    if not vehicle then return false, vehicleErr end
    local row, rowErr = ownedRow(src, vehicle)
    if not row then return false, rowErr end

    -- the snapshot must be of this car
    if properties.plate ~= nil and normalizePlate(properties.plate) ~= normalizePlate(row.plate) then
        return false, 'vehicle properties are for another vehicle'
    end
    -- (model hashes compared as unsigned: one side may report them signed)
    local model = tonumber(properties.model)
    if properties.model ~= nil and type(GetEntityModel) == 'function'
        and (not model or model % 4294967296 ~= GetEntityModel(vehicle) % 4294967296) then
        return false, 'vehicle properties are for another model'
    end

    if lookTaken[row.plate] then return true, { stored = false } end
    if purchasing[row.plate] then return false, 'this vehicle already has a purchase in progress' end
    local stored = type(row.mods) == 'table' and row.mods or {}
    if Customs.hasLook(stored) and settings.fillMissing ~= true then
        lookTaken[row.plate] = true
        return true, { stored = false }
    end
    local look = Customs.lookOf(properties)
    if not look then return false, 'invalid vehicle properties' end
    local missing = Customs.missingLook(stored, look)
    if next(missing) == nil then
        lookTaken[row.plate] = true
        return true, { stored = false }
    end

    purchasing[row.plate] = true
    local saved, saveErr = core('saveVehicleProperties', row.plate, Customs.merge(stored, missing))
    purchasing[row.plate] = nil
    if not saved then return false, saveErr or 'could not store the factory look' end
    lookTaken[row.plate] = true
    return true, { stored = true }
end, { rateLimit = { max = 4, window = 10000 } })

-- Self-service repair (Config.selfRepair). repairStart checks everything and
-- opens a ticket; repairFinish, once the progress bar has had time to run,
-- checks it all again, charges, and lets the client fix the vehicle.
local repairTickets, repairCooldowns = {}, {}
-- FFT seam (approved): lets fft_hooks_server.lua clear one repair cooldown.
function Customs._fftResetRepair(key) repairCooldowns[key] = nil end

local function repairSettings()
    return type(Config.selfRepair) == 'table' and Config.selfRepair or {}
end

local function repairPrice()
    return math.max(0, math.floor(tonumber(repairSettings().price) or 0))
end

local function checkRepair(src, shopId, netId)
    local settings = repairSettings()
    if settings.enabled ~= true then return nil, 'repairs are not offered here' end
    local resolved, resolveErr = resolveShop(src, shopId)
    if not resolved then return nil, resolveErr end
    local vehicle, vehicleErr = resolveVehicle(src, resolved, netId)
    if not vehicle then return nil, vehicleErr end

    if settings.onlyWhenNoMechanics ~= false then
        local onDuty = Customs.mechanicsOnDuty(settings.mechanicJobs, function(job) return core('getDutyCount', job) end)
        if onDuty > 0 then return nil, 'a mechanic is on duty; ask them for a repair' end
    end

    local citizenid = core('getPlayerData', src, { 'citizenid' })
    local key = type(citizenid) == 'string' and citizenid or ('player:%d'):format(src)
    local wait = (repairCooldowns[key] or 0) - GetGameTimer()
    if wait > 0 then return nil, ('you can repair here again in %d seconds'):format(math.ceil(wait / 1000)) end
    return { key = key }
end

Kora.callback.register('kora_customs:repairStart', function(src, shopId, netId)
    local checked, err = checkRepair(src, shopId, netId)
    if not checked then return false, err end
    local duration = math.max(1000, math.floor(tonumber(repairSettings().durationMs) or 10000))
    repairTickets[src] = { shopId = shopId, netId = netId, startedAt = GetGameTimer(), duration = duration }
    return true, { price = repairPrice(), durationMs = duration }
end, { rateLimit = { max = 4, window = 10000 } })

Kora.callback.register('kora_customs:repairFinish', function(src)
    local ticket = repairTickets[src]
    repairTickets[src] = nil -- single use, even when refused
    if not ticket then return false, 'start the repair again' end
    local elapsed = GetGameTimer() - ticket.startedAt
    -- the bar runs on the client after the start reply; allow for the round trip
    if elapsed < ticket.duration - 1000 then return false, 'the repair was not finished' end
    if elapsed > ticket.duration + 60000 then return false, 'the repair took too long; start again' end

    local checked, err = checkRepair(src, ticket.shopId, ticket.netId)
    if not checked then return false, err end

    local settings, price = repairSettings(), repairPrice()
    if price > 0 then
        local paid, payErr = core('removeMoney', src, settings.account or Config.interaction.account, price, 'vehicle-self-repair')
        if not paid then return false, payErr or 'insufficient funds' end
    end
    repairCooldowns[checked.key] = GetGameTimer() + math.max(0, tonumber(settings.cooldownSeconds) or 0) * 1000
    pcall(function()
        exports.kora_core:logEvent('vehicle-self-repair', src, { shop = ticket.shopId, price = price })
    end)
    return true, { price = price }
end, { rateLimit = { max = 4, window = 10000 } })

AddEventHandler('playerDropped', function()
    repairTickets[source] = nil
end)
