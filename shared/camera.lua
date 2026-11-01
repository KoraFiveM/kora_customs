Customs = Customs or {}

local function number(value, fallback)
    value = tonumber(value)
    return value ~= nil and value or fallback
end

-- Resolves the framing preset for a vehicle field, then the shop tab, then the
-- configured default. Returns the preset name and its definition, or nil when
-- the part camera is off or nothing usable is configured.
function Customs.cameraPreset(field, viewId, camera)
    if type(camera) ~= 'table' or camera.focusParts == false then return nil end
    local presets = type(camera.presets) == 'table' and camera.presets or {}
    local candidates = {
        type(camera.fields) == 'table' and field and camera.fields[field] or nil,
        type(camera.views) == 'table' and viewId and camera.views[viewId] or nil,
        camera.default,
    }
    for index = 1, 3 do
        local name = candidates[index]
        if name ~= nil and type(presets[name]) == 'table' then return name, presets[name] end
    end
    return nil
end

-- Long vehicles get a proportionally larger framing distance (1.0 at 4.5 m).
function Customs.cameraDistanceScale(length)
    length = number(length, 4.5)
    return math.max(0.6, math.min(2.0, length / 4.5))
end

-- The preset's fallback point in vehicle-local space, derived from the model's
-- bounding box (min/max as {x, y, z}) for vehicles that lack the bone.
function Customs.cameraFallbackPoint(preset, minimum, maximum)
    local fraction = type(preset.fallback) == 'table' and preset.fallback or {}
    local out = {}
    for axis = 1, 3 do
        local low, high = number(minimum[axis], -1), number(maximum[axis], 1)
        out[axis] = (low + high) / 2 + number(fraction[axis], 0.0) * (high - low) / 2
    end
    return out
end

-- Vehicle-local camera position for a local target point: `distance` metres
-- along the preset's `dir`, scaled by `scale`.
function Customs.cameraPosition(preset, target, scale)
    local dir = type(preset.dir) == 'table' and preset.dir or {}
    local x, y, z = number(dir[1], 0.0), number(dir[2], 1.0), number(dir[3], 0.0)
    local magnitude = math.sqrt(x * x + y * y + z * z)
    if magnitude == 0 then x, y, z, magnitude = 0.0, 1.0, 0.0, 1.0 end
    local distance = number(preset.distance, 4.0) * number(scale, 1.0)
    return {
        target[1] + x / magnitude * distance,
        target[2] + y / magnitude * distance,
        target[3] + z / magnitude * distance,
    }
end
