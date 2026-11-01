Customs = Customs or {}

Customs.modFields = {
    { field = 'modSpoilers', slot = 0, label = 'Spoiler', price = 'body' },
    { field = 'modFrontBumper', slot = 1, label = 'Front bumper', price = 'body' },
    { field = 'modRearBumper', slot = 2, label = 'Rear bumper', price = 'body' },
    { field = 'modSideSkirt', slot = 3, label = 'Side skirts', price = 'body' },
    { field = 'modExhaust', slot = 4, label = 'Exhaust', price = 'body' },
    { field = 'modFrame', slot = 5, label = 'Frame', price = 'body' },
    { field = 'modGrille', slot = 6, label = 'Grille', price = 'body' },
    { field = 'modHood', slot = 7, label = 'Hood', price = 'body' },
    { field = 'modFender', slot = 8, label = 'Left fender', price = 'body' },
    { field = 'modRightFender', slot = 9, label = 'Right fender', price = 'body' },
    { field = 'modRoof', slot = 10, label = 'Roof', price = 'body' },
    { field = 'modHorns', slot = 14, label = 'Horn', price = 'interior' },
    { field = 'modFrontWheels', slot = 23, label = 'Front wheels', price = 'wheels' },
    { field = 'modBackWheels', slot = 24, label = 'Rear wheels', price = 'wheels' },
    { field = 'modPlateHolder', slot = 25, label = 'Plate holder', price = 'plate' },
    { field = 'modVanityPlate', slot = 26, label = 'Vanity plate', price = 'plate' },
    { field = 'modTrimA', slot = 27, label = 'Trim design', price = 'interior' },
    { field = 'modOrnaments', slot = 28, label = 'Ornaments', price = 'interior' },
    { field = 'modDashboard', slot = 29, label = 'Dashboard', price = 'interior' },
    { field = 'modDial', slot = 30, label = 'Dials', price = 'interior' },
    { field = 'modDoorSpeaker', slot = 31, label = 'Door speakers', price = 'interior' },
    { field = 'modSeats', slot = 32, label = 'Seats', price = 'interior' },
    { field = 'modSteeringWheel', slot = 33, label = 'Steering wheel', price = 'interior' },
    { field = 'modShifterLeavers', slot = 34, label = 'Shifter', price = 'interior' },
    { field = 'modAPlate', slot = 35, label = 'Plaques', price = 'interior' },
    { field = 'modSpeakers', slot = 36, label = 'Speakers', price = 'interior' },
    { field = 'modTrunk', slot = 37, label = 'Trunk', price = 'interior' },
    { field = 'modHydrolic', slot = 38, label = 'Hydraulics appearance', price = 'body' },
    { field = 'modEngineBlock', slot = 39, label = 'Engine block appearance', price = 'body' },
    { field = 'modAirFilter', slot = 40, label = 'Air filter appearance', price = 'body' },
    { field = 'modStruts', slot = 41, label = 'Struts', price = 'body' },
    { field = 'modArchCover', slot = 42, label = 'Arch covers', price = 'body' },
    { field = 'modAerials', slot = 43, label = 'Aerials', price = 'body' },
    { field = 'modTrimB', slot = 44, label = 'Secondary trim', price = 'interior' },
    { field = 'modTank', slot = 45, label = 'Tank', price = 'body' },
    { field = 'modWindows', slot = 46, label = 'Window accessories', price = 'body' },
    { field = 'modLivery', slot = 48, label = 'Livery', price = 'body' },
}

local rules = {
    color1 = { kind = 'color', price = 'paint' },
    color2 = { kind = 'color', price = 'paint' },
    pearlescentColor = { kind = 'integer', min = 0, max = 255, price = 'paint' },
    wheelColor = { kind = 'integer', min = 0, max = 255, price = 'paint' },
    dashboardColor = { kind = 'integer', min = 0, max = 255, price = 'interior' },
    interiorColor = { kind = 'integer', min = 0, max = 255, price = 'interior' },
    wheels = { kind = 'integer', min = 0, max = 13, price = 'wheels' },
    windowTint = { kind = 'integer', min = -1, max = 6, price = 'paint' },
    plateIndex = { kind = 'integer', min = 0, max = 5, price = 'plate' },
    neonEnabled = { kind = 'booleanArray', count = 4, price = 'lighting' },
    neonColor = { kind = 'rgb', price = 'lighting' },
    tyreSmokeColor = { kind = 'rgb', price = 'lighting' },
    modSmokeEnabled = { kind = 'boolean', price = 'lighting' },
    modXenon = { kind = 'boolean', price = 'lighting' },
    xenonColor = { kind = 'xenon', price = 'lighting' },
    extras = { kind = 'extras', price = 'extra' },
    modCustomTiresF = { kind = 'boolean', price = 'wheels' },
    modCustomTiresR = { kind = 'boolean', price = 'wheels' },
}

for _, definition in ipairs(Customs.modFields) do
    rules[definition.field] = { kind = 'integer', min = -1, max = 200, price = definition.price }
end

Customs.rules = rules

local function integer(value, min, max)
    local number = tonumber(value)
    if not number or number % 1 ~= 0 or number < min or number > max then return nil end
    return number
end

local function rgb(value)
    if type(value) ~= 'table' then return nil end
    local red = integer(value.r or value[1] or value['1'], 0, 255)
    local green = integer(value.g or value[2] or value['2'], 0, 255)
    local blue = integer(value.b or value[3] or value['3'], 0, 255)
    if not red or not green or not blue then return nil end
    return { r = red, g = green, b = blue }
end

local function sanitizeValue(rule, value)
    if rule.kind == 'integer' then return integer(value, rule.min, rule.max) end
    if rule.kind == 'boolean' then
        if type(value) ~= 'boolean' then return nil end
        return value
    end
    if rule.kind == 'rgb' then return rgb(value) end
    if rule.kind == 'color' then
        if type(value) == 'table' then return rgb(value) end
        return integer(value, 0, 255)
    end
    if rule.kind == 'xenon' then
        if type(value) == 'table' then return rgb(value) end
        return integer(value, -1, 12)
    end
    if rule.kind == 'booleanArray' then
        if type(value) ~= 'table' then return nil end
        local out = {}
        for index = 1, rule.count do
            if type(value[index]) ~= 'boolean' then return nil end
            out[index] = value[index]
        end
        return out
    end
    if rule.kind == 'extras' then
        if type(value) ~= 'table' then return nil end
        local out, count = {}, 0
        for key, enabled in pairs(value) do
            local id = integer(key, 0, 20)
            if not id or type(enabled) ~= 'boolean' then return nil end
            count = count + 1
            if count > 21 then return nil end
            out[tostring(id)] = enabled
        end
        return next(out) and out or nil
    end
end

---@param patch any
---@return table|nil patch
---@return string|nil error
function Customs.sanitizePatch(patch)
    if type(patch) ~= 'table' then return nil, 'invalid customisation' end
    local out, count = {}, 0
    for field, value in pairs(patch) do
        count = count + 1
        if count > 64 or type(field) ~= 'string' then return nil, 'invalid customisation' end
        local rule = rules[field]
        if not rule then return nil, ('unsupported customisation: %s'):format(field) end
        local sanitized = sanitizeValue(rule, value)
        if sanitized == nil then return nil, ('invalid value for %s'):format(field) end
        out[field] = sanitized
    end
    if next(out) == nil then return nil, 'no changes selected' end
    return out
end

function Customs.equal(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= 'table' then return left == right end
    for key, value in pairs(left) do if not Customs.equal(value, right[key]) then return false end end
    for key in pairs(right) do if left[key] == nil then return false end end
    return true
end

---@param patch table
---@param existing table
---@return table
function Customs.changedPatch(patch, existing)
    local changed = {}
    for field, value in pairs(patch) do
        if field == 'extras' then
            local extras, current = {}, type(existing.extras) == 'table' and existing.extras or {}
            for id, enabled in pairs(value) do
                local old = current[id]
                if old == nil then old = current[tonumber(id)] end
                if old ~= enabled then extras[id] = enabled end
            end
            if next(extras) then changed.extras = extras end
        elseif not Customs.equal(value, existing[field]) then
            changed[field] = value
        end
    end
    return changed
end

---@param patch table
---@return integer
function Customs.price(patch)
    local total = 0
    for field, value in pairs(patch) do
        local rule = rules[field]
        local amount = math.max(0, math.floor(tonumber(Config.prices[rule.price]) or 0))
        if field == 'extras' then
            local count = 0
            for _ in pairs(value) do count = count + 1 end
            total = total + amount * count
        elseif (field == 'color1' or field == 'color2') and type(value) == 'table' then
            total = total + math.max(0, math.floor(tonumber(Config.prices.customPaint) or amount))
        else
            total = total + amount
        end
    end
    return total
end

-- Changed fields the configured prices would let through for nothing (a
-- missing or zero price). Checked per field, because a free field riding along
-- in an order that has other paid fields would never trip the total-is-zero check.
---@param patch table
---@return string[] fields
function Customs.unpriced(patch)
    local free = {}
    for field, value in pairs(patch) do
        if Customs.price({ [field] = value }) <= 0 then free[#free + 1] = field end
    end
    table.sort(free)
    return free
end

local function clone(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = clone(child) end
    return copy
end

---@param existing table
---@param patch table
---@return table
function Customs.merge(existing, patch)
    local merged = clone(type(existing) == 'table' and existing or {})
    for field, value in pairs(patch) do
        if field == 'extras' then
            merged.extras = clone(type(merged.extras) == 'table' and merged.extras or {})
            for id, enabled in pairs(value) do merged.extras[tostring(id)] = enabled end
        else
            merged[field] = clone(value)
        end
    end
    return merged
end
