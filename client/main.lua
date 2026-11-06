local owner = GetCurrentResourceName()
local APP_ID = 'qbcustoms:shop'
local active
local repairing = false -- a self-service repair (Config.selfRepair) is running

local wheelTypes = {
    'Sport', 'Muscle', 'Lowrider', 'SUV', 'Offroad', 'Tuner', 'Bike',
    'High End', "Benny's Original", "Benny's Bespoke", 'Open Wheel', 'Street', 'Track',
}
-- Window tint -1 .. 6: -1 is the model's own glass, then the game's tints in
-- SET_VEHICLE_WINDOW_TINT order (0 none, 1 pure black ... 4 stock, 5 limo, 6 green).
local tintNames = { 'Factory', 'None', 'Pure Black', 'Dark Smoke', 'Light Smoke', 'Stock', 'Limo', 'Green' }
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

local function notify(message, kind)
    Kora.notify.send({ title = 'Custom Shop', message = message, type = kind or 'info' })
end

local function dollars(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

-- Natives only: this runs every frame in the freecam/hidden loops and every
-- 250 ms in the session guard, so it must not be an export round trip
-- (Kora.vehicle.isDriver is the same check behind one).
local function vehicleIsUsable(vehicle)
    return type(vehicle) == 'number' and vehicle > 0 and DoesEntityExist(vehicle)
        and IsEntityAVehicle(vehicle) and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
end

local function withinDistance(a, b, limit)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz <= limit * limit
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
    local original = indexedValue(active.original.extras, id) == true
    active.pending.extras = active.pending.extras or {}
    -- Not `enabled ~= original and enabled or nil`: that idiom yields nil when
    -- enabled is false, silently dropping "turn this extra off" from the order.
    if enabled == original then active.pending.extras[tostring(id)] = nil
    else active.pending.extras[tostring(id)] = enabled end
    if next(active.pending.extras) == nil then active.pending.extras = nil end
end

-- The number the vehicle currently shows for a field: the pending preview if
-- there is one, otherwise what it already had.
local function currentNumber(field, fallback)
    local value = active.pending[field]
    if type(value) ~= 'number' then value = active.original[field] end
    if type(value) ~= 'number' then value = fallback end
    return value
end

local function hornOption(name, default)
    local value = tonumber(Config.hornPreview and Config.hornPreview[name])
    return value and math.floor(value) or default
end

-- The game only lets a horn sound briefly, like a tap, while a player is in
-- the driver seat: StartVehicleHorn and SetHornPermanentlyOnTime both ignore
-- their duration then. The shop keeps the player in that seat, so a preview
-- is sounded another way (Config.hornPreview.method):
--   input  the player's own vehicle: started once, then the horn key held for
--          the preview, as if the player held it (the driver's horn stays on
--          while its key is down)
--   proxy  a hidden local copy of the vehicle, the same horn fitted, nobody in
--          it. Testers heard nothing from it, so it is no longer the default
-- Each preview starts once and is cut when the next one starts, so it never
-- loops or overlaps.
local hornToken, hornProxy = 0, nil
local HORN_SLOT, HORN_CONTROL = 14, 86

local function hornMode()
    local mode = Config.hornPreview and Config.hornPreview.mode
    return GetHashKey(type(mode) == 'string' and mode ~= '' and mode or 'HELDDOWN')
end

local function hornMethod()
    return Config.hornPreview and Config.hornPreview.method == 'proxy' and 'proxy' or 'input'
end

local function removeHornProxy(proxy)
    if proxy == hornProxy then hornProxy = nil end
    if not proxy or not DoesEntityExist(proxy) then return end
    -- deleting the vehicle silences its horn straight away
    if not Kora.entities.remove(proxy) and DoesEntityExist(proxy) then DeleteEntity(proxy) end
end

-- Silences a sounding preview and cancels one about to start. Safe at any time.
local function stopHorn()
    hornToken = hornToken + 1
    removeHornProxy(hornProxy)
end

-- Kora.entities vehicles are local: no other player sees or hears this one,
-- and it is deleted if the resource stops.
local function createHornProxy(vehicle, horn)
    local proxy = Kora.entities.create(GetEntityModel(vehicle), GetEntityCoords(vehicle), {
        heading = GetEntityHeading(vehicle), freeze = true, invincible = true,
    })
    if not proxy then return nil end
    SetEntityCollision(proxy, false, false)
    -- alpha, not SetEntityVisible: it stays a live, audible vehicle
    SetEntityAlpha(proxy, 0, false)
    SetVehicleModKit(proxy, 0)
    if horn >= 0 then SetVehicleMod(proxy, HORN_SLOT, horn, false) end
    return proxy
end

local function soundOnProxy(token, vehicle, horn, duration)
    local proxy = createHornProxy(vehicle, horn)
    if not proxy then return end
    -- a newer press or a stop while it spawned or settled wins
    if token ~= hornToken then return removeHornProxy(proxy) end
    hornProxy = proxy
    Wait(0) -- one frame for the new vehicle's audio to be set up
    if token ~= hornToken or not DoesEntityExist(proxy) then return removeHornProxy(proxy) end
    StartVehicleHorn(proxy, duration, hornMode(), false)
    SetTimeout(duration + 250, function() removeHornProxy(proxy) end)
end

-- Runs only while one preview sounds, and ends with it. The horn is started
-- once straight away so it is heard even where the held key is not; the held
-- key then keeps it going for the whole preview.
local function holdHornKey(token, vehicle, duration)
    local untilAt = GetGameTimer() + duration
    StartVehicleHorn(vehicle, duration, hornMode(), false)
    CreateThread(function()
        while token == hornToken and GetGameTimer() < untilAt do
            SetControlNormal(0, HORN_CONTROL, 1.0)
            Wait(0)
        end
    end)
end

-- Config.hornPreview length of the horn fitted to the vehicle (durationMs /
-- durations / byIndex).
local function hornLength(vehicle)
    local horn = GetVehicleMod(vehicle, HORN_SLOT)
    return math.max(100, Customs.hornDuration(Config.hornPreview, horn,
        horn >= 0 and localizedModName(vehicle, HORN_SLOT, horn) or nil))
end

-- Sounds the horn fitted to the vehicle once, from the start, for its
-- Config.hornPreview length (or `duration`). The short delay lets a running
-- preview stop first and a horn mod fitted this frame take effect.
local function playHorn(duration)
    local vehicle = active and active.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then return end
    stopHorn()
    local token = hornToken
    SetTimeout(math.max(0, hornOption('startDelayMs', 150)), function()
        if token ~= hornToken or not active or active.vehicle ~= vehicle or not DoesEntityExist(vehicle) then return end
        local horn = GetVehicleMod(vehicle, HORN_SLOT)
        duration = duration and math.max(100, duration) or hornLength(vehicle)
        if hornMethod() == 'input' then return holdHornKey(token, vehicle, duration) end
        soundOnProxy(token, vehicle, horn, duration)
    end)
end

-- The Test horn button: plays the horn once; pressing it again restarts it.
local function testHorn()
    playHorn()
end

-- Hold to test (Config.hornPreview.holdToTest): one continuous horn from press
-- to release, capped at maxHoldMs. It is started once, never re-triggered, so
-- it does not stutter; release, closing the menu or leaving stops it. With
-- clickPlaysFull a release before the horn's normal preview length lets it
-- play that long: a click (released within ~0.1 s, before the horn has even
-- started) still plays the whole horn once.
local holdFullUntil -- game time a click's horn may play until
local function holdHorn(held)
    if not held then
        local remaining = holdFullUntil and holdFullUntil - GetGameTimer() or 0
        holdFullUntil = nil
        if remaining <= 0 then return stopHorn() end
        local token = hornToken
        -- one deferred stop of this same horn; a newer press or a stop wins
        SetTimeout(remaining, function()
            if token == hornToken then stopHorn() end
        end)
        return
    end
    holdFullUntil = nil
    playHorn(math.max(500, hornOption('maxHoldMs', 15000)))
    local vehicle = active and active.vehicle
    if Config.hornPreview.clickPlaysFull ~= false and vehicle and DoesEntityExist(vehicle) then
        holdFullUntil = GetGameTimer() + math.max(0, hornOption('startDelayMs', 150)) + hornLength(vehicle)
    end
end

-- Paint and glass are put back with direct natives as well as through
-- Kora.vehicle.setProperties. A preview left on the entity is exactly what the
-- garage would later save for free, so this is the part that must not fail
-- silently (a failed network-control request, a tint value the native ignores).
local function readAppearance(vehicle)
    local primary, secondary = GetVehicleColours(vehicle)
    local pearl, wheel = GetVehicleExtraColours(vehicle)
    local snapshot = {
        primary = primary, secondary = secondary, pearl = pearl, wheel = wheel,
        tint = GetVehicleWindowTint(vehicle),
    }
    if GetIsVehiclePrimaryColourCustom(vehicle) then
        local red, green, blue = GetVehicleCustomPrimaryColour(vehicle)
        snapshot.customPrimary = { red, green, blue }
    end
    if GetIsVehicleSecondaryColourCustom(vehicle) then
        local red, green, blue = GetVehicleCustomSecondaryColour(vehicle)
        snapshot.customSecondary = { red, green, blue }
    end
    return snapshot
end

local function sameRgb(left, right)
    if left == nil or right == nil then return left == right end
    return left[1] == right[1] and left[2] == right[2] and left[3] == right[3]
end

local function appearanceMatches(vehicle, wanted)
    local now = readAppearance(vehicle)
    -- A stock tint of -1 can only be re-applied as "none" (0) on some builds.
    local tintOk = now.tint == wanted.tint or (wanted.tint < 0 and now.tint <= 0)
    return tintOk and now.primary == wanted.primary and now.secondary == wanted.secondary
        and now.pearl == wanted.pearl and now.wheel == wanted.wheel
        and sameRgb(now.customPrimary, wanted.customPrimary)
        and sameRgb(now.customSecondary, wanted.customSecondary)
end

-- Tint -1 is the model's own glass. Set over a tint, the game takes the -1
-- (and reads it back) yet leaves the tinted glass on the car, even right after
-- a 0 in the same frame, so -1 is never set: factory glass is applied as 0
-- (none), the same clear glass, which Customs.showsValue counts as factory.
local function applyTint(vehicle, tint)
    SetVehicleWindowTint(vehicle, tint < 0 and 0 or tint)
end

local function applyAppearance(vehicle, wanted)
    ClearVehicleCustomPrimaryColour(vehicle)
    ClearVehicleCustomSecondaryColour(vehicle)
    SetVehicleColours(vehicle, wanted.primary, wanted.secondary)
    if wanted.customPrimary then SetVehicleCustomPrimaryColour(vehicle, table.unpack(wanted.customPrimary)) end
    if wanted.customSecondary then SetVehicleCustomSecondaryColour(vehicle, table.unpack(wanted.customSecondary)) end
    SetVehicleExtraColours(vehicle, wanted.pearl, wanted.wheel)
    applyTint(vehicle, wanted.tint)
end

local function revertAppearance(vehicle, wanted)
    applyAppearance(vehicle, wanted)
    if not appearanceMatches(vehicle, wanted) then applyAppearance(vehicle, wanted) end
    if Config.debug and not appearanceMatches(vehicle, wanted) then
        print('kora_customs: could not restore the original paint / window tint')
    end
end

local function preview(field, value)
    if not active or not vehicleIsUsable(active.vehicle) then return end
    local props = { [field] = value }
    -- Changing the palette colours can reset the pearlescent / wheel colours
    -- on the entity; pin them to what the preview is meant to show.
    if field == 'color1' or field == 'color2' then
        props.pearlescentColor = currentNumber('pearlescentColor', 0)
        props.wheelColor = currentNumber('wheelColor', 0)
        -- the game may have moved them too: put back and re-checked with the paint
        active.touched.pearlescentColor, active.touched.wheelColor = true, true
    end
    active.touched[field] = true
    local ok, err = Kora.vehicle.setProperties(active.vehicle, props)
    if not ok then return notify(err or 'Could not preview that option.', 'error') end
    -- -1 ("Factory") over a tint: clear the glass first (see applyTint)
    if field == 'windowTint' and value < 0 then applyTint(active.vehicle, value) end
    active.shown[field] = value
    setPending(field, value)
    if field == 'modHorns' and Config.hornPreview and Config.hornPreview.autoPlay then playHorn() end
end

-- Preview guard (Config.previewGuard). A preview left on the car is what the
-- next session reads as the car's look before any preview, so it could be
-- stored as its factory look (Config.factoryLook) without being paid for.
local unpaidPreviews = {} -- [plate] = Customs.rememberUnpaid entry, this client only

local function guardSettings()
    return type(Config.previewGuard) == 'table' and Config.previewGuard or {}
end

-- Applies `patch` (field = value) to the car; tint through applyTint.
local function applyPatch(vehicle, patch)
    if next(patch) == nil then return end
    pcall(Kora.vehicle.setProperties, vehicle, patch, { timeout = 2000 })
    if type(patch.windowTint) == 'number' then applyTint(vehicle, patch.windowTint) end
end

-- Reads the car again a moment after a revert and puts back any previewed
-- field the game did not take; a few tries, one timer at a time, and none
-- once the order was paid or a new session is open on the car.
local function recheckRevert(session, attempt)
    local settings = guardSettings()
    local delay = math.floor(tonumber(settings.recheckMs) or 500)
    if delay <= 0 or attempt > math.floor(tonumber(settings.attempts) or 3) then return end
    SetTimeout(delay, function()
        local vehicle = session.vehicle
        if session.paid or not DoesEntityExist(vehicle) or (active and active.vehicle == vehicle) then return end
        local current = Kora.vehicle.getProperties(vehicle)
        local patch = Customs.previewDrift(current, session.original, session.touched)
        if next(patch) == nil then return end
        if Config.debug then Kora.print.debug('kora_customs: a preview stayed on the vehicle after the revert; putting it back') end
        applyPatch(vehicle, patch)
        recheckRevert(session, attempt + 1)
    end)
end

-- Opening on a car that still shows a preview an earlier session did not sell
-- (the revert did not take, or the client stopped mid-session): put those
-- fields back before the car is read. Fields showing anything else are left.
local function putBackUnpaid(vehicle, plate)
    local entry = plate and unpaidPreviews[plate]
    if not entry then return end
    unpaidPreviews[plate] = nil
    if guardSettings().reapplyOnOpen == false then return end
    local patch = Customs.stuckPreviews(Kora.vehicle.getProperties(vehicle), entry)
    if next(patch) == nil then return end
    if Config.debug then Kora.print.debug('kora_customs: unpaid previews were still on the vehicle; put back') end
    applyPatch(vehicle, patch)
end

-- Puts the vehicle back as it was when the shop opened. Every way out of a
-- session that is not a completed purchase ends here: Escape, X, Discard,
-- leaving the seat or the zone, dying, a failed checkout, resource stop.
local function restore()
    if not active then return end
    stopHorn()
    local session = active
    active = nil
    if session.plate then
        unpaidPreviews[session.plate] = Customs.rememberUnpaid(unpaidPreviews[session.plate], session.original, session.shown)
    end
    local vehicle = session.vehicle
    if not DoesEntityExist(vehicle) then return end

    local ok, applied = pcall(Kora.vehicle.setProperties, vehicle, session.original, { timeout = 2000 })
    if not ok or not applied then
        -- The full snapshot was refused (control, a stale value): fall back to
        -- just the fields this session previewed.
        local patch = {}
        for field in pairs(session.touched) do patch[field] = session.original[field] end
        if next(patch) then pcall(Kora.vehicle.setProperties, vehicle, patch, { timeout = 2000 }) end
    end
    if session.appearance then revertAppearance(vehicle, session.appearance) end
    FreezeEntityPosition(vehicle, session.wasFrozen)
    if next(session.touched) then recheckRevert(session, 1) end
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

    local compact = Config.ui and Config.ui.compactActions
    active.specs[field] = { minimum = minimum, last = last, current = current }
    local actions = {
        { id = ('step:%s:-1'):format(field), label = compact and 'Prev' or 'Previous', icon = 'ChevronLeft', variant = 'outline' },
        { id = ('step:%s:1'):format(field), label = 'Next', icon = 'ChevronRight', variant = 'outline' },
        { id = 'set:' .. field, label = compact and 'Pick' or 'Choose', icon = 'List', variant = 'ghost', fields = { chooser } },
    }
    if field == 'modHorns' and Config.hornPreview and Config.hornPreview.button then
        -- holdToTest: a press-and-hold button (kora_lib `hold` action); older
        -- kora_lib builds show it as a normal button that plays the horn once.
        local hold = Config.hornPreview.holdToTest == true
        actions[#actions + 1] = {
            id = 'horn:modHorns', label = hold and 'Hold to test horn' or 'Test horn', icon = 'Music2', variant = 'ghost',
            hold = hold or nil,
        }
    end
    return {
        id = field,
        label = label,
        description = ('%s · %s once%s'):format(valueName, dollars(Customs.unitPrice(field)), changed and ' · changed' or ''),
        tone = changed and 'primary' or nil,
        actions = actions,
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
        description = ('%s once%s'):format(dollars(Customs.unitPrice(field)), changed and ' · changed' or ''),
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

    local changed = type(active.pending[field]) == 'table'
    return {
        id = 'rgb_' .. field,
        label = label,
        description = ('%s once%s'):format(dollars(Customs.unitPrice(field, { r = 0, g = 0, b = 0 })), changed and ' · changed' or ''),
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
        description = ('%s each%s'):format(dollars(Customs.unitPrice('extras')), changed and ' · changed' or ''),
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
        if definition.price == sectionName then
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
    local headerActions = { { id = 'freecam', label = 'Freecam', icon = 'Camera', variant = 'outline' } }
    if not Config.ui or Config.ui.previewButton ~= false then
        headerActions[#headerActions + 1] = { id = 'hide', label = 'Hide menu', icon = 'ScanSearch', variant = 'outline' }
    end
    headerActions[#headerActions + 1] = { id = 'checkout', label = 'Purchase changes', icon = 'CreditCard', variant = 'primary' }
    headerActions[#headerActions + 1] = {
        id = 'discard',
        label = 'Discard changes',
        icon = 'X',
        variant = 'outline',
        confirm = amount > 0 and 'Discard every previewed change and close?' or nil,
    }

    local function view(id, label, icon, blocks)
        return {
            id = id,
            label = label,
            icon = icon,
            content = {
                title = label,
                description = amount > 0 and ('Pending total: %s'):format(dollars(amount))
                    or 'Nothing selected yet. Each option shows its price; you pay at Purchase changes.',
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

-- Flying is Kora.freecam. The shell holds NUI focus, so the button closes it, then
-- waits for Enter (keep the view) or Escape / Backspace (back to the previous
-- view) and reopens it. The camera handle stays live while the shell is open
-- and is stopped when the whole session ends.
local viewHandle
local helpText = 'WASD move  |  Q/E down/up  |  Shift fast  |  Mouse look  |  Enter save view  |  Esc / Backspace cancel'
-- vehicle inputs that would fire while flying (E is the horn in a vehicle)
local blockedControls = { 23, 71, 72, 75, 76, 86 }

local function stopCamera()
    if viewHandle then
        viewHandle.stop()
        viewHandle = nil
    end
end

-- Part camera (Config.camera): a scripted camera that glides to frame the part
-- being changed. Freecam has priority: while it is active the part camera is
-- stopped and not restarted.
local partCam, partCamName
local cabinView

-- The cabin helpers only act while the camera is inside the vehicle. They do
-- not change the entity (SetEntityLocallyInvisible lasts a single frame), so
-- stopping the view is all it takes to put everything back.
local function stopCabinView()
    cabinView = nil
end

local function clearScreenEffects()
    if type(TriggerScreenblurFadeOut) == 'function' then TriggerScreenblurFadeOut(0.0) end
    if type(GetTimecycleModifierIndex) == 'function' and GetTimecycleModifierIndex() ~= -1 then
        ClearTimecycleModifier()
    end
end

local function startCabinView(vehicle, eye)
    local settings = Config.camera.cabin
    if type(settings) ~= 'table' then return end
    local view = { vehicle = vehicle }
    cabinView = view
    if settings.clearScreenEffects ~= false then clearScreenEffects() end

    local light = type(settings.fillLight) == 'table' and settings.fillLight.enabled ~= false and settings.fillLight or nil
    if settings.hidePed == false and not light then return end
    CreateThread(function()
        local seats = math.max(1, GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)))
        while cabinView == view and DoesEntityExist(vehicle) do
            if settings.hidePed ~= false then
                for seat = -1, seats - 2 do
                    local ped = GetPedInVehicleSeat(vehicle, seat)
                    if ped and ped ~= 0 then SetEntityLocallyInvisible(ped) end
                end
            end
            if light then
                DrawLightWithRange(eye.x, eye.y, eye.z, 255, 244, 229,
                    (tonumber(light.range) or 3.5) + 0.0, (tonumber(light.intensity) or 1.0) + 0.0)
            end
            Wait(0)
        end
    end)
end

local function stopPartCamera()
    stopCabinView()
    local cam = partCam
    partCam, partCamName = nil, nil
    if not cam then return end
    RenderScriptCams(false, false, 0, true, false)
    if DoesCamExist(cam) then DestroyCam(cam, false) end
end

local function bonePoint(vehicle, bone, fallback)
    if bone and type(GetEntityBoneIndexByName) == 'function' then
        local index = GetEntityBoneIndexByName(vehicle, bone)
        if index and index ~= -1 then
            local world = GetWorldPositionOfEntityBone(vehicle, index)
            local localPoint = GetOffsetFromEntityGivenWorldCoords(vehicle, world.x, world.y, world.z)
            return { localPoint.x, localPoint.y, localPoint.z }
        end
    end
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    return Customs.cameraFallbackPoint({ fallback = fallback }, { minimum.x, minimum.y, minimum.z }, { maximum.x, maximum.y, maximum.z })
end

local function focusPart(field, viewId)
    local settings = Config.camera
    if not active or not vehicleIsUsable(active.vehicle) then return end
    if viewHandle and viewHandle.isActive() then return end
    local name, preset = Customs.cameraPreset(field, viewId, settings)
    if not name or name == partCamName then return end

    local vehicle = active.vehicle
    local target = Customs.cameraTarget(preset, bonePoint(vehicle, preset.bone, preset.fallback))
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local position
    if type(preset.eye) == 'table' then
        position = Customs.cameraEye(preset, bonePoint(vehicle, preset.eye.bone, preset.eye.fallback))
    else
        position = Customs.cameraPosition(preset, target, Customs.cameraDistanceScale(maximum.y - minimum.y))
    end
    local eye = GetOffsetFromEntityInWorldCoords(vehicle, position[1], position[2], position[3])
    local look = GetOffsetFromEntityInWorldCoords(vehicle, target[1], target[2], target[3])

    -- Turn the view so the part lands in the free screen area beside the panel.
    local fov = tonumber(preset.fov) or tonumber(settings.fov) or 45.0
    local screenWidth, screenHeight = GetActiveScreenResolution()
    local shift = Customs.panelShift(settings, Config.ui, preset, screenWidth)
    local aim = Customs.cameraAim({ eye.x, eye.y, eye.z }, { look.x, look.y, look.z }, shift, fov,
        screenHeight and screenHeight > 0 and screenWidth / screenHeight or 16 / 9)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, eye.x, eye.y, eye.z)
    PointCamAtCoord(cam, aim[1], aim[2], aim[3])
    SetCamFov(cam, fov)

    local previous = partCam
    local duration = math.max(0, math.floor(tonumber(settings.interpMs) or 800))
    if not previous then
        -- start from the gameplay view so the first move glides too
        previous = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        local from, rotation = GetGameplayCamCoord(), GetGameplayCamRot(2)
        SetCamCoord(previous, from.x, from.y, from.z)
        SetCamRot(previous, rotation.x, rotation.y, rotation.z, 2)
        SetCamFov(previous, GetGameplayCamFov())
        SetCamActive(previous, true)
        RenderScriptCams(true, false, 0, true, false)
    end
    partCam, partCamName = cam, name
    if preset.cabin then startCabinView(vehicle, eye) else stopCabinView() end
    SetCamActiveWithInterp(cam, previous, duration, 1, 1)
    SetTimeout(duration + 100, function()
        if DoesCamExist(previous) then DestroyCam(previous, false) end
    end)
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

-- GTA's pause menu sits on Escape (200) and P (199). Escape is also a cancel
-- key here (177 is Backspace / Escape / right mouse), so without this one press
-- both cancels and opens the pause map under the reopened shop.
local function pauseBlocked()
    return not Config.ui or Config.ui.blockPauseMenu ~= false
end

local function blockPause()
    DisableControlAction(0, 199, true)
    DisableControlAction(0, 200, true)
end

-- The key that ended a view, or that closed the shell (the shell closes on
-- key-down and hands focus back), is still held when the game sees it again.
-- Keep the pause controls off until it is released plus Config.ui.pauseGuardMs,
-- and shut the pause menu if it got in anyway. Bounded: at most ~2 s.
local function swallowPause()
    if not pauseBlocked() then return end
    local margin = math.max(0, tonumber(Config.ui and Config.ui.pauseGuardMs) or 250)
    local started, releasedAt = GetGameTimer(), nil
    while true do
        blockPause()
        if IsPauseMenuActive() then SetFrontendActive(false) end
        local now = GetGameTimer()
        if IsDisabledControlPressed(0, 200) or IsDisabledControlPressed(0, 199) then
            releasedAt = nil
        elseif not releasedAt then
            releasedAt = now
        end
        if (releasedAt and now - releasedAt >= margin) or now - started >= margin + 2000 then return end
        Wait(0)
    end
end

-- Blocks until Enter, Backspace or Escape. Backspace / Escape go back to the view
-- the camera had when this run began, or to the normal camera if it had none.
local function runFreecam(session)
    local existing = viewHandle and viewHandle.isActive()
    local before = existing and poseOf(viewHandle) or nil
    stopPartCamera()
    local handle = existing and viewHandle or startView()
    if not handle then return end

    Wait(150) -- let the shell release NUI focus first

    local blockingPause = pauseBlocked()
    while handle.isActive() and vehicleIsUsable(session.vehicle) do
        Wait(0)
        for _, control in ipairs(blockedControls) do DisableControlAction(0, control, true) end
        if blockingPause then blockPause() end

        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName(helpText)
        EndTextCommandDisplayHelp(0, false, false, -1)

        if pressed(191) then return end         -- Enter
        if pressed(177) or pressed(200) then    -- Backspace / Escape
            stopCamera()
            if before then startView(before) end
            -- wait for the key to come up before the shell takes focus again
            return swallowPause()
        end
    end
end

-- "Hide menu": the shell closes so nothing covers the view, the part camera
-- stays, and Enter / Backspace / Escape brings the menu back. Previews are kept.
local function runHidden(session)
    Wait(150) -- let the shell release NUI focus first
    local blockingPause = pauseBlocked()
    while active == session and vehicleIsUsable(session.vehicle) do
        Wait(0)
        if blockingPause then blockPause() end

        BeginTextCommandDisplayHelp('STRING')
        AddTextComponentSubstringPlayerName('Enter / Backspace / Escape  show the menu again')
        EndTextCommandDisplayHelp(0, false, false, -1)

        if pressed(191) then return end
        if pressed(177) or pressed(200) then return swallowPause() end
    end
end

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
    active.touched.extras = true
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
    stopHorn()
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

        -- paid: no revert re-check may undo it, and no earlier preview is
        -- put back over it
        session.paid = true
        if session.plate then unpaidPreviews[session.plate] = nil end
        if active == session then
            active = nil
            FreezeEntityPosition(session.vehicle, session.wasFrozen)
            closeShell()
        elseif DoesEntityExist(session.vehicle) then
            -- Escape closed the shell while the order was in flight, so the
            -- previews were rolled back; the order is paid and saved, so show it.
            pcall(Kora.vehicle.setProperties, session.vehicle, session.pending, { timeout = 2000 })
        end
        notify(('Customisation saved for %s (%s).'):format(result.plate, dollars(result.price)), 'success')
    end)
end

local scalarActions = { step = stepField, set = setField, toggle = toggleField, extra = toggleExtra, color = pickColor, horn = testHorn }

local function onAction(actionId, context)
    -- press / release of a hold button; kora_lib ignores what a hold returns
    if type(context) == 'table' and (context.hold == 'start' or context.hold == 'end') then
        if actionId == 'horn:modHorns' then
            holdHorn(context.hold == 'start' and active ~= nil and not active.busy and vehicleIsUsable(active.vehicle))
        end
        return
    end

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
    if actionId == 'hide' then
        session.hidden = true
        return { close = true }
    end

    local kind, argument, delta = actionId:match('^(%a+):([%w_]+):?(-?%d*)$')
    local handler = scalarActions[kind]
    if not handler then return end

    handler(argument, kind == 'step' and delta or context or {})
    focusPart(kind == 'extra' and 'extras' or argument, session.viewId)
    refresh()
end

-- registerApp needs at least one view, so it starts with a placeholder that
-- open() replaces with the session's real navigation.
local function panelPlacement()
    if Config.ui and Config.ui.placement == 'center' then return 'center' end
    return Config.ui and Config.ui.defaultSide == 'left' and 'left' or 'right'
end

local appDefinition = {
    id = APP_ID,
    title = 'Custom Shop',
    description = 'Cosmetic vehicle customisation. No repairs or performance tuning.',
    icon = 'Palette',
    layout = Config.ui and Config.ui.layout == 'compact' and 'compact' or 'standard',
    defaultView = 'paint',
    width = Customs.panelWidth(Config.ui),
    height = tonumber(Config.ui and Config.ui.height) or 900,
    placement = panelPlacement(),
    -- Read by app shells that support a movable panel; ignored by older ones.
    draggable = not Config.ui or Config.ui.draggable ~= false,
    rememberPosition = not Config.ui or Config.ui.rememberPosition ~= false,
    positionKey = APP_ID,
    footer = 'Press Escape to cancel and revert your previews',
    navigation = { { id = 'paint', label = 'Paint', icon = 'Palette', content = { blocks = { { type = 'empty', title = 'No vehicle selected' } } } } },
    onAction = onAction,
}

local registered, registerErr = pcall(Kora.nui.registerApp, appDefinition)
if not registered and appDefinition.placement == 'left' then
    -- This kora_lib build has no left-hand panel: keep the right-hand one, and
    -- tell the camera so it frames the part on the free side.
    Config.ui.defaultSide = 'right'
    appDefinition.placement = 'right'
    registered, registerErr = pcall(Kora.nui.registerApp, appDefinition)
end
if not registered then error(registerErr, 0) end

local function open(shopId)
    if active then return notify('A customisation session is already open.', 'warning') end
    if repairing then return notify('Wait for the repair to finish.', 'warning') end
    local shop = Config.shops[shopId]
    if not shop then return end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicleIsUsable(vehicle) then return notify('Sit in the driver seat of your vehicle.', 'error') end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return notify('This vehicle is not networked.', 'error') end

    SetVehicleModKit(vehicle, 0)
    local plate = Kora.vehicle.plate(vehicle) or nil
    putBackUnpaid(vehicle, plate)
    local original, err = Kora.vehicle.getProperties(vehicle)
    if not original then return notify(err or 'Could not read this vehicle.', 'error') end
    local session = {
        shopId = shopId,
        label = shop.label,
        vehicle = vehicle,
        plate = plate,
        original = original,
        pending = {},
        touched = {},
        shown = {}, -- last previewed value per field (Config.previewGuard)
        appearance = readAppearance(vehicle),
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(vehicle) or false,
    }
    active = session
    FreezeEntityPosition(vehicle, true)

    -- Config.factoryLook: the look read above, before any preview, becomes the
    -- stored baseline of a car that has none yet; the server decides if it is.
    if type(Config.factoryLook) == 'table' and Config.factoryLook.enabled == true then
        CreateThread(function()
            local taken, result = Kora.callback.trigger('kora_customs:factoryLook', shopId, netId, original)
            if Config.debug and not taken then Kora.print.debug(('factory look not stored: %s'):format(tostring(result))) end
        end)
    end

    CreateThread(function()
        local ok, err = pcall(function()
            refresh()
            focusPart(nil, 'paint')
            Kora.nui.openApp(APP_ID, { viewId = 'paint' })

            -- Freecam and Hide menu close the shell on purpose: look around,
            -- then reopen the shell with the previews untouched.
            while active == session and (session.freecam or session.hidden) do
                local flying = session.freecam
                session.freecam, session.hidden = false, false
                if flying then runFreecam(session) else runHidden(session) end
                if active ~= session then break end
                if not vehicleIsUsable(session.vehicle) then
                    notify('You must remain in the driver seat.', 'error')
                    break
                end
                refresh()
                Kora.nui.openApp(APP_ID, { viewId = session.viewId or 'paint' })
            end
        end)

        -- openApp returns however the shell closed (Escape, X, discard, a
        -- completed purchase). Anything not purchased rolls the previews back,
        -- and the camera always goes back to normal, even if the code above
        -- raised an error. An Escape that closed the shell must not also open
        -- the pause menu once the game has input again.
        swallowPause()
        if active == session then pcall(restore) end
        stopCamera()
        stopPartCamera()
        if not ok then
            closeShell()
            Kora.print.error(('kora_customs session failed: %s'):format(tostring(err)))
        end
    end)

    -- While the shell is open nothing else notices the player being moved,
    -- killed or kicked from the seat, or the vehicle being removed. Without
    -- this the preview would stay on the vehicle, and a garage would later
    -- store that look for free.
    CreateThread(function()
        local limit = tonumber(Config.interaction.checkoutDistance) or 12.0
        while active == session do
            Wait(250)
            if active ~= session then return end
            -- a checkout in flight finishes (or aborts) itself
            if not session.busy then
                local reason
                if not vehicleIsUsable(session.vehicle) then
                    reason = 'You must remain in the driver seat.'
                elseif IsEntityDead(PlayerPedId()) then
                    reason = 'Customisation cancelled; previews were reverted.'
                elseif not withinDistance(GetEntityCoords(session.vehicle), shop.coords, limit) then
                    reason = 'You left the custom shop; previews were reverted.'
                end
                if reason then
                    restore()
                    closeShell()
                    return notify(reason, 'error')
                end
            end
        end
    end)
end

-- Self-service repair (Config.selfRepair). The server re-checks the shop,
-- seat, distance, on-duty mechanics and cooldown, and charges; this side only
-- asks, shows the progress bar and fixes the vehicle once it is paid for.
local function repairSettings()
    local settings = Config.selfRepair
    return type(settings) == 'table' and settings.enabled == true and settings or nil
end

-- Only hides the option: kora_core replicates on-duty counts to every client.
local function mechanicsOnDuty(settings)
    if settings.onlyWhenNoMechanics == false then return false end
    local counts = GlobalState.OnDuty
    if type(counts) ~= 'table' then return false end
    return Customs.mechanicsOnDuty(settings.mechanicJobs, function(job) return counts[job] end) > 0
end

local function needsRepair(vehicle)
    return GetVehicleEngineHealth(vehicle) < 1000.0 or GetVehicleBodyHealth(vehicle) < 1000.0
        or GetVehiclePetrolTankHealth(vehicle) < 1000.0
end

local function fixVehicle(vehicle)
    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleUndriveable(vehicle, false)
end

local function repairVehicle(shopId)
    local settings = repairSettings()
    if not settings or repairing then return end
    if active then return notify('Close the custom shop first.', 'warning') end
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if not vehicleIsUsable(vehicle) then return notify('Sit in the driver seat of your vehicle.', 'error') end
    if not needsRepair(vehicle) then return notify('This vehicle does not need a repair.', 'info') end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return notify('This vehicle is not networked.', 'error') end

    repairing = true
    CreateThread(function()
        local ok, err = pcall(function()
            local confirmation = Kora.nui.openAlert({
                title = 'Repair vehicle',
                message = ('Repair the engine and bodywork for %s?'):format(dollars(math.max(0, tonumber(settings.price) or 0))),
                confirmLabel = 'Repair',
            })
            if not confirmation or not confirmation.confirmed then return end

            local started, ticket = Kora.callback.trigger('kora_customs:repairStart', shopId, netId)
            if not started then return notify(ticket or 'You cannot repair your vehicle here right now.', 'error') end

            local completed = Kora.progressbar.start({
                label = 'Repairing vehicle...',
                duration = ticket.durationMs,
                canCancel = true,
                disable = { car = true, combat = true },
            })
            if not completed then return notify('Repair cancelled.', 'error') end
            if not vehicleIsUsable(vehicle) then return notify('You must remain in the driver seat.', 'error') end
            if not Kora.vehicle.requestControl(vehicle, 2000) then
                return notify('Could not get control of the vehicle. Try again.', 'error')
            end

            local paid, result = Kora.callback.trigger('kora_customs:repairFinish')
            if not paid then return notify(result or 'The repair failed.', 'error') end
            fixVehicle(vehicle)
            notify(('Vehicle repaired for %s.'):format(dollars(result.price)), 'success')
        end)
        repairing = false
        if not ok then Kora.print.error(('kora_customs repair failed: %s'):format(tostring(err))) end
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
                Customs.allowInVehicle({
                    label = ('Customise vehicle at %s'):format(shop.label),
                    icon = 'palette',
                    canInteract = function()
                        return vehicleIsUsable(GetVehiclePedIsIn(PlayerPedId(), false))
                    end,
                    onSelect = function() open(shopId) end,
                }, Config.targetAllowInVehicle),
                repairSettings() and Customs.allowInVehicle({
                    label = ('Repair vehicle (%s)'):format(dollars(math.max(0, tonumber(Config.selfRepair.price) or 0))),
                    icon = 'wrench',
                    canInteract = function()
                        local settings = repairSettings()
                        return settings ~= nil and not active and not repairing and not mechanicsOnDuty(settings)
                            and vehicleIsUsable(GetVehiclePedIsIn(PlayerPedId(), false))
                    end,
                    onSelect = function() repairVehicle(shopId) end,
                }, Config.targetAllowInVehicle) or nil,
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
                    { kind = 'wrappedText', value = repairSettings()
                        and 'Cosmetic vehicle customisation. Self-service repairs when no mechanic is on duty.'
                        or 'Cosmetic vehicle customisation. No repairs or performance tuning.' },
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
        pcall(stopHorn)
        pcall(restore)
        stopCamera()
        stopPartCamera()
    end
end)

-- Hold-to-test key (Config.hornPreview.holdKey): the same continuous horn as
-- the hold button while the key is held. The game only sees keys while the
-- panel is hidden (Hide menu), so it is an extra to the button. Without
-- holdToTest a release must not cut a Next / Test horn preview short.
RegisterCommand('+kora_customs_horn', function()
    if active and Config.hornPreview and Config.hornPreview.holdToTest then holdHorn(true) end
end, false)
RegisterCommand('-kora_customs_horn', function()
    if Config.hornPreview and Config.hornPreview.holdToTest then holdHorn(false) end
end, false)
if Config.hornPreview and Config.hornPreview.holdKey then
    RegisterKeyMapping('+kora_customs_horn', 'Customs: hold to test horn', 'keyboard', Config.hornPreview.holdKey)
end

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