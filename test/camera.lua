vector3 = function(x, y, z) return { x = x, y = y, z = z } end
Config = nil
dofile('config.lua')
dofile('shared/catalog.lua')
dofile('shared/camera.lua')

local function equal(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
end

local camera = Config.camera
equal(camera.focusParts, true, 'part camera is on by default')

local function preset(field, view) return (Customs.cameraPreset(field, view, camera)) end

equal(preset('wheels', 'wheels'), 'wheelFront', 'wheel category frames the front wheel')
equal(preset('modFrontWheels', 'wheels'), 'wheelFront', 'front wheel design')
equal(preset('modBackWheels', 'wheels'), 'wheelRear', 'rear wheel design')
equal(camera.presets.wheelFront.bone, 'wheel_lf', 'front wheel preset uses wheel_lf')
equal(preset('modFrontBumper', 'body'), 'front', 'front bumper')
equal(preset('modRearBumper', 'body'), 'rear', 'rear bumper')
equal(preset('modExhaust', 'body'), 'exhaust', 'exhaust')
equal(preset('modSpoilers', 'body'), 'spoiler', 'spoiler')
equal(preset('modHood', 'body'), 'hood', 'hood')
equal(preset('modRoof', 'body'), 'roof', 'roof')
equal(preset('modSeats', 'interior'), 'interior', 'interior part')
equal(preset('plateIndex', 'plate'), 'plate', 'plate')
equal(preset('modXenon', 'lighting'), 'lights', 'headlights')
equal(preset('color1', 'paint'), 'overview', 'paint falls to the overview')
equal(preset('modLivery', 'body'), 'overview', 'unmapped body mod falls to the overview')
equal(preset(nil, 'wheels'), 'wheelFront', 'a tab with no field uses the tab mapping')
equal(preset('unknownField', 'unknownTab'), 'overview', 'unknown input uses the default')

for field, name in pairs(camera.fields) do
    assert(camera.presets[name], ('field %s maps to missing preset %s'):format(field, name))
end
for view, name in pairs(camera.views) do
    assert(camera.presets[name], ('view %s maps to missing preset %s'):format(view, name))
end
for _, definition in ipairs(Customs.modFields) do
    assert(Customs.cameraPreset(definition.field, nil, camera), definition.field .. ' resolves to a preset')
end

local off = { focusParts = false, default = camera.default, presets = camera.presets, fields = camera.fields, views = camera.views }
equal(Customs.cameraPreset('wheels', 'wheels', off), nil, 'no preset when focusParts is false')
equal(Customs.cameraPreset('wheels', 'wheels', nil), nil, 'no preset without config')
equal(Customs.cameraPreset('wheels', 'wheels', { presets = {} }), nil, 'no preset when nothing is configured')

local tuned = { presets = { custom = { dir = { 0, 1, 0 } }, other = {} }, fields = { wheels = 'custom', modRoof = 'missing' }, default = 'other' }
equal(Customs.cameraPreset('wheels', nil, tuned), 'custom', 'server-tuned mapping is honoured')
equal(Customs.cameraPreset('modRoof', nil, tuned), 'other', 'a mapping to a missing preset falls back to the default')

equal(Customs.cameraDistanceScale(4.5), 1.0, 'reference length is unscaled')
equal(Customs.cameraDistanceScale(100), 2.0, 'scale is capped')
equal(Customs.cameraDistanceScale(0.1), 0.6, 'scale has a floor')
equal(Customs.cameraDistanceScale(nil), 1.0, 'missing length is unscaled')

local point = Customs.cameraFallbackPoint({ fallback = { -1, 1, 0 } }, { -1, -2, -0.5 }, { 1, 2, 0.5 })
equal(point[1], -1.0, 'fallback x is the left edge')
equal(point[2], 2.0, 'fallback y is the front edge')
equal(point[3], 0.0, 'fallback z is the centre')
local centred = Customs.cameraFallbackPoint({}, { 0, 0, 0 }, { 2, 4, 2 })
equal(centred[2], 2.0, 'no fallback means the model centre')

local position = Customs.cameraPosition({ dir = { -1, 0, 0 }, distance = 2.5 }, { 1, 1, 1 }, 2)
equal(position[1], -4.0, 'camera sits 5 m out along dir (x)')
equal(position[2], 1.0, 'camera keeps y')
equal(position[3], 1.0, 'camera keeps z')
local diagonal = Customs.cameraPosition({ dir = { 3, 4, 0 }, distance = 10 }, { 0, 0, 0 })
equal(diagonal[1], 6.0, 'dir is normalised (x)')
equal(diagonal[2], 8.0, 'dir is normalised (y)')
local degenerate = Customs.cameraPosition({ dir = { 0, 0, 0 }, distance = 3 }, { 0, 0, 0 })
equal(degenerate[2], 3.0, 'zero dir falls back to the front')

print('kora_customs camera: ok')
