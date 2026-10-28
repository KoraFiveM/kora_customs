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
    if not ok then return nil, 'qbcore is unavailable' end
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

    if not QB.distance.coords(GetEntityCoords(ped), shop.coords,
        tonumber(Config.interaction.checkoutDistance) or 12.0) then
        return nil, 'too far from the custom shop'
    end
    return { shop = shop, ped = ped, bucket = bucket }
end

local function resolveVehicle(src, resolved, netId)
    local vehicle, reason = QB.world.resolveNetworkEntity(src, tonumber(netId), {
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
    if not QB.distance.coords(GetEntityCoords(vehicle), resolved.shop.coords,
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
    return { row = row, patch = patch, price = price }
end

QB.callback.register('qbcustoms:quote', function(src, shopId, netId, requestedPatch)
    local prepared, err = prepare(src, shopId, netId, requestedPatch)
    if not prepared then return false, err end
    return true, { price = prepared.price, plate = prepared.row.plate }
end, { rateLimit = { max = 8, window = 10000 } })

-- Keep the extra client argument compatible; only the validated patch reaches persistence.
QB.callback.register('qbcustoms:purchase', function(src, shopId, netId, requestedPatch, quotedPrice, mods)
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
