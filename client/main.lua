local owner = GetCurrentResourceName()
local active

local wheelTypes = {
    'Sport', 'Muscle', 'Lowrider', 'SUV', 'Offroad', 'Tuner', 'Bike',
    'High End', "Benny's Original", "Benny's Bespoke", 'Open Wheel', 'Street', 'Track',
}
local tintNames = { 'Stock', 'Pure Black', 'Dark Smoke', 'Light Smoke', 'Standard', 'Limo', 'Green' }
local plateNames = { 'Blue on White 1', 'Yellow on Black', 'Yellow on Blue', 'Blue on White 2', 'Blue on White 3', 'North Yankton' }
local xenonNames = { 'Stock', 'White', 'Blue', 'Electric Blue', 'Mint Green', 'Lime Green', 'Yellow', 'Golden Shower', 'Orange', 'Red', 'Pony Pink', 'Hot Pink', 'Purple', 'Blacklight' }

local function notify(message, kind)
    QB.notify.send({ title = 'Custom Shop', message = message, type = kind or 'info' })
end

local function dollars(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function vehicleIsUsable(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and QB.vehicle.isDriver(vehicle)
end

local function localizedModName(vehicle, slot, index)
    local key = GetModTextLabel(vehicle, slot, index)
    if key and key ~= '' then
        local label = GetLabelText(key)
        if label and label ~= '' and label ~= 'NULL' then return label end
    end
    return ('Option %d'):format(index + 1)
end

local function indexedValue(value, index)
    if type(value) ~= 'table' then return nil end
    local result = value[index]
    if result == nil then result = value[tostring(index)] end
    return result
end

local function setPending(field, value)
    if not active then return end
    if Customs.equal(value, active.original[field]) then active.pending[field] = nil
    else active.pending[field] = value end
end

local function setExtra(id, enabled)
    if not active then return end
    local original = indexedValue(active.original.extras, id)
    active.pending.extras = active.pending.extras or {}
    active.pending.extras[tostring(id)] = enabled ~= original and enabled or nil
    if next(active.pending.extras) == nil then active.pending.extras = nil end
end

local function preview(field, value)
    if not active or not vehicleIsUsable(active.vehicle) then return end
    local ok, err = QB.vehicle.setProperties(active.vehicle, { [field] = value })
    if not ok then return notify(err or 'Could not preview that option.', 'error') end
    setPending(field, value)
end

local function restore()
    if not active then return end
    local session = active
    active = nil
    if DoesEntityExist(session.vehicle) then
        QB.vehicle.setProperties(session.vehicle, session.original, { timeout = 2000 })
        FreezeEntityPosition(session.vehicle, session.wasFrozen)
    end
end

local function paletteValues()
    local values = {}
    for color = Config.palette.min, Config.palette.max do
        values[#values + 1] = ('Colour %d'):format(color)
    end
    return values
end

local function scalarOption(label, field, values, minimum, current, priceGroup)
    local defaultIndex = math.floor(tonumber(current) or minimum) - minimum + 1
    defaultIndex = math.max(1, math.min(defaultIndex, #values))
    return {
        label = label,
        description = ('Charged once: %s'):format(dollars(Config.prices[priceGroup])),
        values = values,
        defaultIndex = defaultIndex,
        close = false,
        args = { field = field, minimum = minimum },
    }
end

local function modOption(vehicle, definition, current)
    local count = GetNumVehicleMods(vehicle, definition.slot)
    if definition.slot == 48 then count = math.max(count, GetVehicleLiveryCount(vehicle)) end
    if count <= 0 then return nil end
    local values = { 'Stock' }
    for index = 0, count - 1 do values[#values + 1] = localizedModName(vehicle, definition.slot, index) end
    return scalarOption(definition.label, definition.field, values, -1, current, definition.price)
end

local function total()
    if not active then return 0 end
    local patch = Customs.sanitizePatch(active.pending)
    if not patch then return 0 end
    return Customs.price(Customs.changedPatch(patch, active.original))
end

local showMenu

local function customColor(field, label)
    CreateThread(function()
        if not active then return end
        local current = active.pending[field] or active.original[field]
        local default = '#ffffff'
        if type(current) == 'table' then
            default = ('#%02x%02x%02x'):format(current.r or 255, current.g or 255, current.b or 255)
        end
        local response = QB.nui.openInputDialog({
            { id = 'color', label = label, type = 'color', default = default, required = true },
        }, label)
        if response and not response.cancelled then
            local hex = tostring(response.values.color or ''):match('^#?(%x%x%x%x%x%x)$')
            if hex then
                local color = {
                    r = tonumber(hex:sub(1, 2), 16),
                    g = tonumber(hex:sub(3, 4), 16),
                    b = tonumber(hex:sub(5, 6), 16),
                }
                if field == 'tyreSmokeColor' then preview('modSmokeEnabled', true) end
                preview(field, color)
            end
        end
        if active then showMenu() end
    end)
end

local function checkout()
    CreateThread(function()
        if not active or not vehicleIsUsable(active.vehicle) then
            restore()
            return notify('You must remain in the driver seat.', 'error')
        end
        local amount = total()
        if amount <= 0 then
            showMenu()
            return notify('No changes are selected.', 'warning')
        end
        local session = active
        local netId = NetworkGetNetworkIdFromEntity(session.vehicle)
        local quoted, quote = QB.callback.trigger('qbcustoms:quote', session.shopId, netId, session.pending)
        if not quoted then
            restore()
            return notify(quote or 'Could not quote these changes; previews were reverted.', 'error')
        end

        local confirmation = QB.nui.openAlert({
            title = 'Confirm customisation',
            message = ('Purchase the selected cosmetic changes for %s?'):format(dollars(quote.price)),
            confirmLabel = 'Purchase',
        })
        if not confirmation or not confirmation.confirmed then
            if active then showMenu() end
            return
        end

        local purchased, result = QB.callback.trigger(
            'qbcustoms:purchase', session.shopId, netId, session.pending, quote.price
        )
        if not purchased then
            restore()
            return notify(result or 'Purchase failed; preview changes were reverted.', 'error')
        end

        active = nil
        FreezeEntityPosition(session.vehicle, session.wasFrozen)
        notify(('Customisation saved for %s (%s).'):format(result.plate, dollars(result.price)), 'success')
    end)
end

local function buildOptions()
    local vehicle, original = active.vehicle, active.original
    local options = {
        { label = ('Pending total: %s'):format(dollars(total())), icon = 'receipt', disabled = true },
    }
    local colors = paletteValues()
    for _, entry in ipairs({
        { 'Primary paint', 'color1', 'paint' },
        { 'Secondary paint', 'color2', 'paint' },
        { 'Pearlescent colour', 'pearlescentColor', 'paint' },
        { 'Wheel colour', 'wheelColor', 'paint' },
        { 'Dashboard colour', 'dashboardColor', 'interior' },
        { 'Interior colour', 'interiorColor', 'interior' },
    }) do
        local current = active.pending[entry[2]]
        if type(current) ~= 'number' then current = original[entry[2]] end
        if type(current) ~= 'number' then current = Config.palette.min end
        options[#options + 1] = scalarOption(entry[1], entry[2], colors, Config.palette.min, current, entry[3])
    end
    options[#options + 1] = { label = 'Custom primary RGB', icon = 'palette', args = { action = 'color', field = 'color1', label = 'Primary RGB' } }
    options[#options + 1] = { label = 'Custom secondary RGB', icon = 'palette', args = { action = 'color', field = 'color2', label = 'Secondary RGB' } }

    local wheelCategory = scalarOption('Wheel category', 'wheels', wheelTypes, 0, GetVehicleWheelType(vehicle), 'wheels')
    wheelCategory.description = wheelCategory.description .. ' · Select to refresh wheel designs'
    wheelCategory.close = true
    wheelCategory.args.action = 'refresh'
    options[#options + 1] = wheelCategory
    for _, definition in ipairs(Customs.modFields) do
        local current = active.pending[definition.field]
        if current == nil then current = original[definition.field] end
        local option = modOption(vehicle, definition, current)
        if option then options[#options + 1] = option end
    end

    options[#options + 1] = scalarOption('Window tint', 'windowTint', tintNames, -1,
        active.pending.windowTint or original.windowTint, 'paint')
    options[#options + 1] = scalarOption('Plate style', 'plateIndex', plateNames, 0,
        active.pending.plateIndex or original.plateIndex, 'plate')
    local xenonColor = active.pending.xenonColor
    if type(xenonColor) ~= 'number' then xenonColor = original.xenonColor end
    options[#options + 1] = scalarOption('Xenon colour', 'xenonColor', xenonNames, -1,
        type(xenonColor) == 'number' and xenonColor or -1, 'lighting')
    local xenonEnabled = active.pending.modXenon
    if xenonEnabled == nil then xenonEnabled = original.modXenon == true end
    options[#options + 1] = { label = 'Xenon headlights', checked = xenonEnabled, close = false, args = { field = 'modXenon' } }
    local neon = active.pending.neonEnabled or original.neonEnabled or {}
    local neonOn = neon[1] == true or neon[2] == true or neon[3] == true or neon[4] == true
    options[#options + 1] = { label = 'Neon underglow', checked = neonOn, close = false, args = { field = 'neonEnabled', all = true } }
    options[#options + 1] = { label = 'Custom neon RGB', icon = 'lightbulb', args = { action = 'color', field = 'neonColor', label = 'Neon RGB' } }
    options[#options + 1] = { label = 'Custom tyre-smoke RGB', icon = 'cloud', args = { action = 'color', field = 'tyreSmokeColor', label = 'Tyre-smoke RGB' } }
    local customFront = active.pending.modCustomTiresF
    if customFront == nil then customFront = original.modCustomTiresF == true end
    local customRear = active.pending.modCustomTiresR
    if customRear == nil then customRear = original.modCustomTiresR == true end
    options[#options + 1] = { label = 'Custom front tyres', checked = customFront, close = false, args = { field = 'modCustomTiresF' } }
    options[#options + 1] = { label = 'Custom rear tyres', checked = customRear, close = false, args = { field = 'modCustomTiresR' } }

    for id = 0, 20 do
        if DoesExtraExist(vehicle, id) then
            local enabled = active.pending.extras and active.pending.extras[tostring(id)]
            if enabled == nil then enabled = indexedValue(original.extras, id) == true end
            options[#options + 1] = {
                label = ('Vehicle extra %d'):format(id),
                description = ('Charged individually: %s'):format(dollars(Config.prices.extra)),
                checked = enabled,
                close = false,
                args = { extra = id },
            }
        end
    end

    options[#options + 1] = { label = 'Purchase changes', icon = 'credit-card', args = { action = 'purchase' } }
    options[#options + 1] = { label = 'Discard changes', icon = 'x', args = { action = 'discard' } }
    return options
end

showMenu = function()
    if not active or not vehicleIsUsable(active.vehicle) then
        restore()
        return notify('You must remain in the driver seat.', 'error')
    end
    local menu = {
        id = 'qbcustoms:menu',
        title = active.label,
        position = 'top-right',
        options = buildOptions(),
        onSideScroll = function(_, valueIndex, args)
            if args and args.field then preview(args.field, valueIndex + args.minimum - 1) end
        end,
        onSelected = function(_, valueIndex, args)
            if args and args.isScroll and args.field then preview(args.field, valueIndex + args.minimum - 1) end
        end,
        onCheck = function(_, checked, args)
            if not args then return end
            if args.extra ~= nil then
                if active and vehicleIsUsable(active.vehicle) then
                    QB.vehicle.setProperties(active.vehicle, { extras = { [tostring(args.extra)] = checked } })
                    setExtra(args.extra, checked)
                end
            elseif args.all then
                preview(args.field, { checked, checked, checked, checked })
            elseif args.field then
                preview(args.field, checked)
            end
        end,
        onClose = function() restore() end,
    }
    QB.ox.registerMenu(menu, function(_, _, args)
        if not args then return end
        if not args.action then
            -- A close=false confirmation causes qblib's menu loop to render
            -- again. Refresh its registered options first so totals and
            -- defaults reflect every preview selected so far.
            QB.ox.setMenuOptions(menu.id, buildOptions(), nil, owner)
            return
        end
        if args.action == 'purchase' then checkout()
        elseif args.action == 'discard' then restore()
        elseif args.action == 'color' then customColor(args.field, args.label)
        elseif args.action == 'refresh' then showMenu() end
    end, owner)
    QB.ox.showMenu(menu.id, nil, owner)
end

local function open(shopId)
    if active then return notify('A customisation session is already open.', 'warning') end
    local shop = Config.shops[shopId]
    if not shop then return end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicleIsUsable(vehicle) then return notify('Sit in the driver seat of your vehicle.', 'error') end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return notify('This vehicle is not networked.', 'error') end

    SetVehicleModKit(vehicle, 0)
    local original, err = QB.vehicle.getProperties(vehicle)
    if not original then return notify(err or 'Could not read this vehicle.', 'error') end
    active = {
        shopId = shopId,
        label = shop.label,
        vehicle = vehicle,
        original = original,
        pending = {},
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(vehicle) or false,
    }
    FreezeEntityPosition(vehicle, true)
    showMenu()
end

local targetIds = {}
local function registerTargets()
    for _, id in pairs(targetIds) do exports.qbtarget:removeZone(id) end
    targetIds = {}
    for shopId, shop in pairs(Config.shops) do
        targetIds[#targetIds + 1] = exports.qbtarget:addBoxZone({
            coords = shop.coords,
            size = shop.size,
            rotation = shop.rotation,
            distance = Config.interaction.distance,
            debug = Config.debug,
            options = {
                {
                    label = ('Customise vehicle at %s'):format(shop.label),
                    icon = 'palette',
                    canInteract = function()
                        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                        return vehicleIsUsable(vehicle)
                    end,
                    onSelect = function() open(shopId) end,
                },
            },
        })
    end
end

local function registerBlips()
    if Config.blip.enabled == false then return end
    for _, shop in pairs(Config.shops) do
        QB.blips.create(shop.coords, {
            name = shop.label,
            sprite = Config.blip.sprite,
            color = Config.blip.color,
            scale = Config.blip.scale,
            shortRange = Config.blip.shortRange,
            category = Config.blip.category,
            info = {
                title = shop.label,
                rows = {
                    { kind = 'wrappedText', value = 'Cosmetic vehicle customisation. No repairs or performance tuning.' },
                },
            },
        })
    end
end

registerTargets()
registerBlips()
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'qbtarget' then registerTargets() end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == owner then restore() end
end)

exports('open', open)
