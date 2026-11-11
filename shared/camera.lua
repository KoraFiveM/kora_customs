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

-- Presets with an `eye` table put the camera at a point inside the vehicle
-- instead of orbiting the target: `eye.bone` / `eye.fallback` locate the point
-- (same fallback fraction as `fallback`) and `eye.offset` {x, y, z} metres is
-- added in vehicle-local space. Returns nil for orbiting presets.
function Customs.cameraEye(preset, point)
    if type(preset.eye) ~= 'table' then return nil end
    local offset = type(preset.eye.offset) == 'table' and preset.eye.offset or {}
    return {
        point[1] + number(offset[1], 0.0),
        point[2] + number(offset[2], 0.0),
        point[3] + number(offset[3], 0.0),
    }
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

-- The framed point itself: the bone (or fallback) point plus the preset's
-- optional `offset` {x, y, z} metres in vehicle-local space. Lets a preset aim
-- at e.g. the centre console rather than the steering wheel bone.
function Customs.cameraTarget(preset, point)
    local offset = type(preset.offset) == 'table' and preset.offset or {}
    return {
        point[1] + number(offset[1], 0.0),
        point[2] + number(offset[2], 0.0),
        point[3] + number(offset[3], 0.0),
    }
end

-- Width in pixels of the shop panel. kora_lib clamps the app shell to
-- 720..1600 px (standard layout) or 420..1600 px (compact layout).
function Customs.panelWidth(ui)
    ui = type(ui) == 'table' and ui or {}
    local minimum = ui.layout == 'compact' and 420 or 720
    return math.min(math.max(number(ui.width, minimum), minimum), 1600)
end

-- Signed fraction of the screen width (-0.45..0.45) by which the framed point
-- should sit left (+) of the screen centre so it lands in the free area beside
-- a right-hand panel, or right (-) of it beside a left-hand panel
-- (`ui.defaultSide = 'left'`). 0 when the panel is centred, `camera.avoidPanel`
-- is false, or the preset opts out with `avoidPanel = false`.
-- `camera.screenShift` is added as a manual tweak (fraction of the screen
-- width, positive moves the view left, negative moves it right).
function Customs.panelShift(camera, ui, preset, screenWidth)
    camera = type(camera) == 'table' and camera or {}
    ui = type(ui) == 'table' and ui or {}
    local shift = number(camera.screenShift, 0.0)
    local automatic = camera.avoidPanel ~= false and not (type(preset) == 'table' and preset.avoidPanel == false)
    if automatic and ui.placement ~= 'center' then
        local width = math.max(1, number(screenWidth, 1920))
        local covered = Customs.panelWidth(ui) + number(camera.panelMargin, 16)
        local amount = math.min(covered, width) / width / 2
        shift = shift + (ui.defaultSide == 'left' and -amount or amount)
    end
    return math.max(-0.45, math.min(0.45, shift))
end

-- World-space point to aim the camera at so that `look` appears `shift`
-- (fraction of the screen width) left of the screen centre, or right of it when
-- `shift` is negative. The view direction is turned right (left) about the
-- vertical axis; pitch is unchanged. `fov` is the vertical field of view in
-- degrees and `aspect` is width / height.
function Customs.cameraAim(eye, look, shift, fov, aspect)
    local dx, dy, dz = look[1] - eye[1], look[2] - eye[2], look[3] - eye[3]
    shift = number(shift, 0.0)
    if shift == 0 or math.sqrt(dx * dx + dy * dy) < 1e-4 then return { look[1], look[2], look[3] } end
    local halfWidth = math.tan(math.rad(number(fov, 45.0)) / 2) * number(aspect, 16 / 9)
    local angle = math.atan(2 * shift * halfWidth)
    local sin, cos = math.sin(angle), math.cos(angle)
    return { eye[1] + dx * cos + dy * sin, eye[2] - dx * sin + dy * cos, eye[3] + dz }
end
