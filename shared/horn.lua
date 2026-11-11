Customs = Customs or {}

local function whole(value)
    value = tonumber(value)
    return value and value >= 0 and math.floor(value) or nil
end

local function matches(name, match)
    if type(match) == 'string' then return match ~= '' and name:find(match:lower(), 1, true) ~= nil end
    if type(match) ~= 'table' then return false end
    for _, entry in ipairs(match) do
        if matches(name, entry) then return true end
    end
    return false
end

-- How long one preview of horn mod `index` (displayed as `name`) sounds:
-- settings.byIndex[index], then the first settings.durations rule whose
-- `match` is part of the name (case-insensitive), then settings.durationMs.
function Customs.hornDuration(settings, index, name)
    settings = type(settings) == 'table' and settings or {}
    local fallback = whole(settings.durationMs) or 1500

    local byIndex = type(settings.byIndex) == 'table' and settings.byIndex or nil
    local exact = byIndex and whole(byIndex[index] or byIndex[tostring(index)])
    if exact then return exact end

    name = type(name) == 'string' and name:lower() or ''
    if name ~= '' and type(settings.durations) == 'table' then
        for _, rule in ipairs(settings.durations) do
            local ms = type(rule) == 'table' and whole(rule.ms)
            if ms and matches(name, rule.match) then return ms end
        end
    end
    return fallback
end
