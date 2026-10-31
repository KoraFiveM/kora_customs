local owner = GetCurrentResourceName()
local APP_ID = 'qbcustoms:shop'
local active

local wheelTypes = {
    'Sport', 'Muscle', 'Lowrider', 'SUV', 'Offroad', 'Tuner', 'Bike',
    'High End', "Benny's Original", "Benny's Bespoke", 'Open Wheel', 'Street', 'Track',
}
local tintNames = { 'Stock', 'Pure Black', 'Dark Smoke', 'Light Smoke', 'Standard', 'Limo', 'Green' }
local plateNames = { 'Blue on White 1', 'Yellow on Black', 'Yellow on Blue', 'Blue on White 2', 'Blue on White 3', 'North Yankton' }
local xenonNames = { 'Stock', 'White', 'Blue', 'Electric Blue', 'Mint Green', 'Lime Green', 'Yellow', 'Golden Shower', 'Orange', 'Red', 'Pony Pink', 'Hot Pink', 'Purple', 'Blacklight' }

local fieldLabels = {
    color1 = 'Primary paint',
    color2 = 'Secondary paint',
    pearlescentColor = 'Pearlescent colour',
    wheelColor = 'Wheel colour',
    dashboardColor = 'Dashboard colour',
    interiorColor = 'Interior colour',
    wheels = 'Wheel category',
    windowTint = 'Window tint',
    plateIndex = 'Plate style',
    xenonColor = 'Xenon colour',
    modXenon = 'Xenon headlights',
    neonEnabled = 'Neon underglow',
    neonColor = 'Neon colour',
    tyreSmokeColor = 'Tyre-smoke colour',
    modSmokeEnabled = 'Tyre smoke',
    modCustomTiresF = 'Custom front tyres',
    modCustomTiresR = 'Custom rear tyres',
    extras = 'Vehicle extras',
}
for _, definition in ipairs(Customs.modFields) do fieldLabels[definition.field] = definition.label end

-- Cosmetic mod slots are grouped into shop sections by their price group.
local modSections = { body = 'body', interior = 'interior', wheels = 'wheels', plate = 'plate' }

local function notify(message, kind)
    Kora.notify.send({ title = 'Custom Shop', message = message, type = kind or 'info' })
end

local function dollars(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function vehicleIsUsable(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and Kora.vehicle.isDriver(vehicle)
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

------------------------------------------------------------------------
-- Session state
------------------------------------------------------------------------

local function setPending(field, value)
    if not active then return end
    if Customs.equal(value, active.original[field]) then active.pending[field] = nil
    else active.pending[field] = value end
end

local function setExtra(id, enabled)
    if not active then return end
    local original = indexedValue(active.original.extras, id) == true
    active.pending.extras = active.pending.extras or {}
    -- Not `enabled ~= original and enabled or nil`: that idiom yields nil when
    -- enabled is false, silently dropping "turn this extra off" from the order.
    if enabled == original then active.pending.extras[tostring(id)] = nil
    else active.pending.extras[tostring(id)] = enabled end
    if next(active.pending.extras) == nil then active.pending.extras = nil end
end

local function preview(field, value)
    if not active or not vehicleIsUsable(active.vehicle) then return end
    local ok, err = Kora.vehicle.setProperties(active.vehicle, { [field] = value })
    if not ok then return notify(err or 'Could not preview that option.', 'error') end
    setPending(field, value)
end

local function restore()
    if not active then return end
    local session = active
    active = nil
    if DoesEntityExist(session.vehicle) then
        Kora.vehicle.setProperties(session.vehicle, session.original, { timeout = 2000 })
        FreezeEntityPosition(session.vehicle, session.wasFrozen)
    end
end

-- The number the vehicle currently shows for a field: the pending preview if
-- there is one, otherwise what it already had.
local function currentNumber(field, fallback)
    local value = active.pending[field]
    if type(value) ~= 'number' then value = active.original[field] end
    if type(value) ~= 'number' then value = fallback end
    return value
end

local function currentBool(field)
    local value = active.pending[field]
    if value == nil then value = active.original[field] end
    return value == true
end

local function total()
    if not active then return 0 end
    local patch = Customs.sanitizePatch(active.pending)
    if not patch then return 0 end
    return Customs.price(Customs.changedPatch(patch, active.original))
end

local function changeRows()
    local patch = active and Customs.sanitizePatch(active.pending)
    if not patch then return {} end

    local rows = {}
    for field, value in pairs(Customs.changedPatch(patch, active.original)) do
        local label = fieldLabels[field] or field
        if field == 'extras' then
            local count = 0
            for _ in pairs(value) do count = count + 1 end
            label = ('%s (%d)'):format(label, count)
        elseif (field == 'color1' or field == 'color2') and type(value) == 'table' then
            label = label .. ' (custom RGB)'
        end
        rows[#rows + 1] = { change = label, price = dollars(Customs.price({ [field] = value })) }
    end
    table.sort(rows, function(a, b) return a.change < b.change end)
    return rows
end

------------------------------------------------------------------------
-- AppShell content
------------------------------------------------------------------------

-- The menu's side-scroll option: Previous/Next step through the values
-- (wrapping, previewing straight away) and Choose jumps to one. Pass `names`
-- for a labelled list, or `maximum` for a plain numeric range (paint palette).
local function scalarItem(field, price, minimum, current, names, maximum)
    local count = names and #names or (maximum - minimum + 1)
    local last = minimum + count - 1
    current = math.max(minimum, math.min(last, math.floor(tonumber(current) or minimum)))

    local label = fieldLabels[field]
    local changed = active.pending[field] ~= nil
    local valueName = names and names[current - minimum + 1] or ('Colour %d'):format(current)

    local chooser
    if names then
        local options = {}
        for index, name in ipairs(names) do options[index] = { value = tostring(minimum + index - 1), label = name } end
        chooser = { id = 'value', label = label, type = 'select', options = options, searchable = count > 10, default = tostring(current) }
    else
        chooser = { id = 'value', label = label, type = 'number', min = minimum, max = last, wholeNumber = true, default = current }
    end
    -- openInputDialog documents `default`; AppShell forms elsewhere in this
    -- stack prefill through `value`. Setting both pre-fills either way.
    chooser.value, chooser.required = chooser.default, true

    active.specs[field] = { minimum = minimum, last = last, current = current }
    return {
        id = field,
        label = label,
        description = ('%s · %s once%s'):format(valueName, dollars(Config.prices[price]), changed and ' · changed' or ''),
        tone = changed and 'primary' or nil,
        actions = {
            { id = ('step:%s:-1'):format(field), label = 'Previous', icon = 'ChevronLeft', variant = 'outline' },
            { id = ('step:%s:1'):format(field), label = 'Next', icon = 'ChevronRight', variant = 'outline' },
            { id = 'set:' .. field, label = 'Choose', icon = 'List', variant = 'ghost', fields = { chooser } },
        },
    }
end

local function modItem(definition)
    local vehicle = active.vehicle
    local count = GetNumVehicleMods(vehicle, definition.slot)
    if definition.slot == 48 then count = math.max(count, GetVehicleLiveryCount(vehicle)) end
    if count <= 0 then return nil end

    local names = { 'Stock' }
    for index = 0, count - 1 do names[#names + 1] = localizedModName(vehicle, definition.slot, index) end
    return scalarItem(definition.field, definition.price, -1, currentNumber(definition.field, -1), names)
end

local function paletteItem(field, price)
    local minimum, maximum = Config.palette.min, Config.palette.max
    return scalarItem(field, price, minimum, currentNumber(field, minimum), nil, maximum)
end

local function toggleItem(field, enabled, price)
    active.toggles[field] = enabled
    local changed = active.pending[field] ~= nil
    return {
        id = field,
        label = fieldLabels[field],
        description = ('%s once%s'):format(dollars(Config.prices[price]), changed and ' · changed' or ''),
        tone = changed and 'primary' or nil,
        actions = { { id = 'toggle:' .. field, label = enabled and 'Turn off' or 'Turn on', state = enabled } },
    }
end

local function rgbItem(field, label)
    local current = active.pending[field]
    if current == nil then current = active.original[field] end

    local hex = '#ffffff'
    if type(current) == 'table' then
        hex = ('#%02x%02x%02x'):format(current.r or 255, current.g or 255, current.b or 255)
    end

    local price = (field == 'color1' or field == 'color2') and 'customPaint' or 'lighting'
    local changed = type(active.pending[field]) == 'table'
    return {
        id = 'rgb_' .. field,
        label = label,
        description = ('%s once%s'):format(dollars(Config.prices[price]), changed and ' · changed' or ''),
        tone = changed and 'primary' or nil,
        actions = { {
            id = 'color:' .. field,
            label = 'Pick colour',
            icon = 'Palette',
            variant = 'outline',
            fields = { { id = 'color', label = label, type = 'color', default = hex, value = hex, required = true } },
        } },
    }
end

local function extraItem(id)
    local enabled = active.pending.extras and active.pending.extras[tostring(id)]
    if enabled == nil then enabled = indexedValue(active.original.extras, id) == true end
    active.extras[id] = enabled

    local changed = active.pending.extras ~= nil and active.pending.extras[tostring(id)] ~= nil
    return {
        id = 'extra_' .. id,
        label = ('Vehicle extra %d'):format(id),
        description = ('%s each%s'):format(dollars(Config.prices.extra), changed and ' · changed' or ''),
        tone = changed and 'primary' or nil,
        actions = { { id = 'extra:' .. id, label = enabled and 'Turn off' or 'Turn on', state = enabled } },
    }
end

local function section(id, items, emptyTitle)
    if #items == 0 then return { type = 'empty', title = emptyTitle } end
    return { type = 'list', id = id, layout = 'list', items = items }
end

-- `leading` items come first, then every cosmetic mod slot in this section
-- that the current vehicle actually has options for.
local function sectionItems(sectionName, leading)
    local items = leading or {}
    for _, definition in ipairs(Customs.modFields) do
        if modSections[definition.price] == sectionName then
            local item = modItem(definition)
            if item then items[#items + 1] = item end
        end
    end
    return items
end

local function buildNavigation()
    local session = active
    session.specs, session.toggles, session.extras = {}, {}, {}

    local amount = total()
    local headerActions = {
        { id = 'freecam', label = 'Freecam', icon = 'Camera', variant = 'outline' },
        { id = 'checkout', label = 'Purchase changes', icon = 'CreditCard', variant = 'primary' },
        {
            id = 'discard',
            label = 'Discard changes',
            icon = 'X',
            variant = 'outline',
            confirm = amount > 0 and 'Discard every previewed change and close?' or nil,
        },
    }

    local function view(id, label, icon, blocks)
        return {
            id = id,
            label = label,
            icon = icon,
            content = {
                title = label,
                description = ('Pending total: %s'):format(dollars(amount)),
                actions = headerActions,
                blocks = blocks,
            },
        }
    end

    local paint = {
        paletteItem('color1', 'paint'),
        paletteItem('color2', 'paint'),
        paletteItem('pearlescentColor', 'paint'),
        rgbItem('color1', 'Custom primary RGB'),
        rgbItem('color2', 'Custom secondary RGB'),
    }

    -- The wheel category leads its section: the designs below it depend on it.
    local wheels = sectionItems('wheels', { scalarItem('wheels', 'wheels', 0, GetVehicleWheelType(session.vehicle), wheelTypes) })
    wheels[#wheels + 1] = paletteItem('wheelColor', 'paint')
    wheels[#wheels + 1] = toggleItem('modCustomTiresF', currentBool('modCustomTiresF'), 'wheels')
    wheels[#wheels + 1] = toggleItem('modCustomTiresR', currentBool('modCustomTiresR'), 'wheels')

    local interior = sectionItems('interior', {
        paletteItem('dashboardColor', 'interior'),
        paletteItem('interiorColor', 'interior'),
    })

    local neon = session.pending.neonEnabled or session.original.neonEnabled or {}
    local neonOn = neon[1] == true or neon[2] == true or neon[3] == true or neon[4] == true
    local lighting = {
        toggleItem('modXenon', currentBool('modXenon'), 'lighting'),
        scalarItem('xenonColor', 'lighting', -1, currentNumber('xenonColor', -1), xenonNames),
        toggleItem('neonEnabled', neonOn, 'lighting'),
        rgbItem('neonColor', 'Custom neon RGB'),
        rgbItem('tyreSmokeColor', 'Custom tyre-smoke RGB'),
    }

    local plate = sectionItems('plate', {
        scalarItem('windowTint', 'paint', -1, currentNumber('windowTint', -1), tintNames),
        scalarItem('plateIndex', 'plate', 0, currentNumber('plateIndex', 0), plateNames),
    })

    local extras = {}
    for id = 0, 20 do
        if DoesExtraExist(session.vehicle, id) then extras[#extras + 1] = extraItem(id) end
    end

    local rows = changeRows()
    local navigation = {
        view('paint', 'Paint', 'Palette', { section('paint', paint) }),
        view('body', 'Body', 'Car', { section('body', sectionItems('body'), 'No body options for this vehicle') }),
        view('wheels', 'Wheels', 'CircleDot', { section('wheels', wheels) }),
        view('interior', 'Interior', 'Armchair', { section('interior', interior) }),
        view('lighting', 'Lighting', 'Lightbulb', { section('lighting', lighting) }),
        view('plate', 'Plate & glass', 'RectangleHorizontal', { section('plate', plate) }),
    }
    if #extras > 0 then
        navigation[#navigation + 1] = view('extras', 'Extras', 'Puzzle', { section('extras', extras) })
    end
    navigation[#navigation + 1] = view('review', 'Review', 'Receipt', {
        {
            type = 'stats',
            items = {
                { label = 'Pending total', value = dollars(amount), icon = 'Receipt', tone = amount > 0 and 'primary' or 'neutral' },
                { label = 'Changes', value = #rows, icon = 'List' },
            },
        },
        #rows > 0 and {
            type = 'table',
            id = 'changes',
            title = 'Selected changes',
            columns = { { key = 'change', label = 'Change' }, { key = 'price', label = 'Price', align = 'right' } },
            rows = rows,
        } or { type = 'empty', title = 'No changes selected', description = 'Preview options in the other sections to see them here.' },
    })
    return navigation
end

local function refresh()
    if not active then return end
    Kora.nui.updateApp(APP_ID, { title = active.label, navigation = buildNavigation() })
end

------------------------------------------------------------------------
-- Freecam
------------------------------------------------------------------------

-- Flying is Kora.freecam. The shell holds NUI focus, so the button closes it, then
-- waits for Enter (keep the view) or Backspace (back to the previous view) and
-- reopens it. The camera handle stays live while the shell is open and is
-- stopped when the whole session ends.
local viewHandle
local helpText = 'WASD move  |  Q/E down/up  |  Shift fast  |  Mouse look  |  Enter save view  |  Backspace cancel'
-- vehicle inputs that would fire while flying (E is the horn in a vehicle)
local blockedControls = { 23, 71, 72, 75, 76, 86 }

local function stopCamera()
    if viewHandle then
        viewHandle.stop()
        viewHandle = nil
    end
end

local function poseOf(handle)
    local coords, rotation = handle.getCoords(), handle.getRotation()
    if not coords or not rotation then return nil end
    return {
        coords = coords,
        rotation = { x = rotation.pitch, y = rotation.roll, z = rotation.yaw },
        fov = GetCamFov(handle.getCamera()),
    }
end

-- Starts at `pose`, or at the normal gameplay view when there isn't one.
local function startView(pose)
    local handle, err = Kora.freecam.start({
        coords = pose and pose.coords,
        rotation = pose and pose.rotation,
        fov = pose and pose.fov,
        upControl = 38,
        downControl = 44,
    })
    if not handle then
        notify(err or 'Could not start the freecam.', 'error')
        return nil
    end
    viewHandle = handle
    return handle
end

local function pressed(control)
    return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end

-- Blocks until Enter or Backspace. Backspace goes back to the view the camera had
-- when this run began, or to the normal camera if it had none.
local function runFreecam(session)
    local existing = viewHandle and viewHandle.isActive()
    local before = existing and poseOf(viewHandle) or nil
    local handle = existing and viewHandle or startView()
    if not handle then return end

    Wait(150) -- let the shell release NUI focus first

    while handle.isActive() and vehicleIsUsable(session.vehicle) do
        Wait(0)
        for _, control in ipairs(blockedControls) do DisableControlAction(0, control, true) end

        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(helpText)
        EndTextCommandDisplayHelp(0, false, false, -1)

        if pressed(191) then return end -- Enter
        if pressed(177) then            -- Backspace
            stopCamera()
            if before then startView(before) end
            return
        end
    end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

local function stepField(field, delta)
    local spec = active.specs[field]
    if not spec then return end
    local value = spec.current + (tonumber(delta) == -1 and -1 or 1)
    if value < spec.minimum then value = spec.last
    elseif value > spec.last then value = spec.minimum end
    preview(field, value)
end

local function setField(field, context)
    local spec = active.specs[field]
    local value = tonumber(context.value and context.value.value)
    if not spec or not value or value % 1 ~= 0 or value < spec.minimum or value > spec.last then return end
    preview(field, value)
end

local function toggleField(field)
    local enabled = active.toggles[field]
    if enabled == nil then return end
    local value = not enabled
    preview(field, field == 'neonEnabled' and { value, value, value, value } or value)
end

local function toggleExtra(text)
    local id = tonumber(text)
    local enabled = id and active.extras[id]
    if enabled == nil then return end
    Kora.vehicle.setProperties(active.vehicle, { extras = { [tostring(id)] = not enabled } })
    setExtra(id, not enabled)
end

local colorFields = { color1 = true, color2 = true, neonColor = true, tyreSmokeColor = true }

local function pickColor(field, context)
    if not colorFields[field] then return end
    local hex = tostring(context.value and context.value.color or ''):match('^#?(%x%x%x%x%x%x)$')
    if not hex then return end
    if field == 'tyreSmokeColor' then preview('modSmokeEnabled', true) end
    preview(field, {
        r = tonumber(hex:sub(1, 2), 16),
        g = tonumber(hex:sub(3, 4), 16),
        b = tonumber(hex:sub(5, 6), 16),
    })
end

local function closeShell()
    if Kora.nui.isAppOpen(APP_ID) then Kora.nui.closeApp(APP_ID) end
end

-- Callbacks and the confirmation dialog block, so checkout runs in its own
-- thread and reports back through notifications and app updates.
local function checkout()
    local session = active
    if total() <= 0 then
        return { notice = { tone = 'warning', message = 'No changes are selected.' } }
    end

    session.busy = true
    CreateThread(function()
        local function abort(message)
            restore()
            closeShell()
            notify(message, 'error')
        end

        local netId = NetworkGetNetworkIdFromEntity(session.vehicle)
        local quoted, quote = Kora.callback.trigger('qbcustoms:quote', session.shopId, netId, session.pending)
        if active ~= session then return end
        if not quoted then return abort(quote or 'Could not quote these changes; previews were reverted.') end

        local confirmation = Kora.nui.openAlert({
            title = 'Confirm customisation',
            message = ('Purchase the selected cosmetic changes for %s?'):format(dollars(quote.price)),
            confirmLabel = 'Purchase',
        })
        if active ~= session then return end
        if not confirmation or not confirmation.confirmed then
            session.busy = false
            return refresh()
        end

        local purchased, result = Kora.callback.trigger(
            'qbcustoms:purchase', session.shopId, netId, session.pending, quote.price, Kora.vehicle.getProperties(session.vehicle)
        )
        if not purchased then
            if active == session then return abort(result or 'Purchase failed; preview changes were reverted.') end
            return notify(result or 'Purchase failed.', 'error')
        end

        if active == session then
            active = nil
            FreezeEntityPosition(session.vehicle, session.wasFrozen)
            closeShell()
        end
        notify(('Customisation saved for %s (%s).'):format(result.plate, dollars(result.price)), 'success')
    end)
end

local scalarActions = { step = stepField, set = setField, toggle = toggleField, extra = toggleExtra, color = pickColor }

local function onAction(actionId, context)
    local session = active
    if not session or session.busy then return end

    if not vehicleIsUsable(session.vehicle) then
        restore()
        notify('You must remain in the driver seat.', 'error')
        return { close = true }
    end

    -- remember which tab the shell was on so the freecam can reopen it there
    if type(context) == 'table' and type(context.viewId) == 'string' then session.viewId = context.viewId end

    if actionId == 'checkout' then return checkout() end
    if actionId == 'discard' then
        restore()
        return { close = true }
    end
    if actionId == 'freecam' then
        session.freecam = true
        return { close = true }
    end

    local kind, argument, delta = actionId:match('^(%a+):([%w_]+):?(-?%d*)$')
    local handler = scalarActions[kind]
    if not handler then return end

    handler(argument, kind == 'step' and delta or context or {})
    refresh()
end

-- registerApp needs at least one view, so it starts with a placeholder that
-- open() replaces with the session's real navigation.
Kora.nui.registerApp({
    id = APP_ID,
    title = 'Custom Shop',
    description = 'Cosmetic vehicle customisation. No repairs or performance tuning.',
    icon = 'Palette',
    layout = 'standard',
    defaultView = 'paint',
    width = 400,
    height = 900,
    placement = 'right',
    footer = 'Press Escape to cancel and revert your previews',
    navigation = { { id = 'paint', label = 'Paint', icon = 'Palette', content = { blocks = { { type = 'empty', title = 'No vehicle selected' } } } } },
    onAction = onAction,
})

local function open(shopId)
    if active then return notify('A customisation session is already open.', 'warning') end
    local shop = Config.shops[shopId]
    if not shop then return end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicleIsUsable(vehicle) then return notify('Sit in the driver seat of your vehicle.', 'error') end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return notify('This vehicle is not networked.', 'error') end

    SetVehicleModKit(vehicle, 0)
    local original, err = Kora.vehicle.getProperties(vehicle)
    if not original then return notify(err or 'Could not read this vehicle.', 'error') end
    local session = {
        shopId = shopId,
        label = shop.label,
        vehicle = vehicle,
        original = original,
        pending = {},
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(vehicle) or false,
    }
    active = session
    FreezeEntityPosition(vehicle, true)

    CreateThread(function()
        refresh()
        Kora.nui.openApp(APP_ID, { viewId = 'paint' })

        -- The freecam button closes the shell on purpose: fly the camera, then
        -- reopen the shell with the previews untouched.
        while active == session and session.freecam do
            session.freecam = false
            runFreecam(session)
            if active ~= session then break end
            if not vehicleIsUsable(session.vehicle) then
                notify('You must remain in the driver seat.', 'error')
                break
            end
            refresh()
            Kora.nui.openApp(APP_ID, { viewId = session.viewId or 'paint' })
        end

        -- openApp returns however the shell closed (Escape, X, discard, a
        -- completed purchase). Anything not purchased rolls the previews back,
        -- and the camera always goes back to normal.
        if active == session then restore() end
        stopCamera()
    end)
end

local targetIds = {}
local function registerTargets()
    for _, id in pairs(targetIds) do exports.kora_target:removeZone(id) end
    targetIds = {}
    for shopId, shop in pairs(Config.shops) do
        targetIds[#targetIds + 1] = exports.kora_target:addBoxZone({
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
        Kora.blips.create(shop.coords, {
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
    if resource == 'kora_target' then registerTargets() end
end)
AddEventHandler('onClientResourceStop', function(resource)
    if resource == owner then
        restore()
        stopCamera()
    end
end)

exports('open', open)
RegisterCommand('getVehprop', function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicle or vehicle == 0 then
        print('No vehicle found')
        return
    end
    local props = Kora.vehicle.getProperties(vehicle)
    Kora.print.debug(props)
end)