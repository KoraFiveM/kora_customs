Config = {
    prices = {
        paint = 350, customPaint = 600, body = 500, wheels = 750,
        interior = 350, lighting = 300, extra = 100, plate = 250,
    },
}

dofile('shared/catalog.lua')

local function equal(actual, expected, message)
    assert(actual == expected, ('%s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
end

local patch = assert(Customs.sanitizePatch({
    color1 = { r = 12, g = 34, b = 56 },
    modSpoilers = 2,
    extras = { [1] = true, ['2'] = false },
}))
equal(patch.color1.r, 12, 'RGB is normalized')
equal(patch.extras['1'], true, 'numeric extra id is normalized')
equal(Customs.price(patch), 600 + 500 + 200, 'authoritative price')

local invalid, invalidErr = Customs.sanitizePatch({ modEngine = 3 })
equal(invalid, nil, 'performance upgrade is rejected')
assert(invalidErr:find('unsupported', 1, true), 'performance rejection is explained')

invalid = Customs.sanitizePatch({ color1 = { r = 256, g = 0, b = 0 } })
equal(invalid, nil, 'invalid RGB is rejected')

local existing = { color1 = 5, extras = { ['1'] = false, ['2'] = false }, modSpoilers = 1 }
local changed = Customs.changedPatch({ color1 = 5, extras = { ['1'] = true, ['2'] = false }, modSpoilers = 2 }, existing)
equal(changed.color1, nil, 'unchanged paint is free')
equal(changed.extras['1'], true, 'changed extra remains')
equal(changed.extras['2'], nil, 'unchanged extra is removed')
equal(Customs.price(changed), 100 + 500, 'only changed fields are charged')

local merged = Customs.merge(existing, changed)
equal(merged.modSpoilers, 2, 'body modification merges')
equal(merged.extras['1'], true, 'changed extra merges')
equal(merged.extras['2'], false, 'unmentioned extra is preserved')
equal(existing.modSpoilers, 1, 'merge does not mutate existing properties')

print('qbcustoms catalog: ok')
