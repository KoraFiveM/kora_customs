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

for _, field in ipairs({ 'modXenon', 'modSmokeEnabled', 'modCustomTiresF', 'modCustomTiresR' }) do
    for _, enabled in ipairs({ false, true }) do
        local input = { [field] = enabled }
        local selected = assert(Customs.sanitizePatch(input))
        equal(selected[field], enabled, 'boolean value is preserved')
        local current = { [field] = not enabled, color1 = 5 }
        local changes = Customs.changedPatch(selected, current)
        equal(changes[field], enabled, 'changed boolean is retained')
        equal(Customs.price(changes), Config.prices[Customs.rules[field].price], 'boolean change has its normal price')
        local result = Customs.merge(current, changes)
        equal(result[field], enabled, 'boolean change merges')
        equal(result.color1, 5, 'unselected property is preserved')
        equal(current[field], not enabled, 'merge preserves the original properties')
        equal(input[field], enabled, 'sanitizer preserves its input')
        equal(next(Customs.changedPatch(selected, result)), nil, 'unchanged boolean is free')
    end
    for _, value in ipairs({ 0, 1, 'false', 'true', {} }) do
        equal(Customs.sanitizePatch({ [field] = value }), nil, 'non-boolean value is rejected')
    end
end

-- Every paint / glass field is priced, including custom RGB and pearlescent.
for _, changes in ipairs({
    { windowTint = 3 }, { pearlescentColor = 12 }, { color1 = { r = 1, g = 2, b = 3 } },
    { color2 = 7 }, { color1 = 4, color2 = { r = 9, g = 8, b = 7 }, pearlescentColor = 1, windowTint = 0 },
}) do
    local selected = assert(Customs.sanitizePatch(changes))
    assert(Customs.price(Customs.changedPatch(selected, {})) > 0, 'paint and tint changes are charged')
    equal(#Customs.unpriced(selected), 0, 'configured fields are all priced')
end
equal(Customs.price({ windowTint = 3, pearlescentColor = 12, color1 = { r = 1, g = 2, b = 3 } }), 350 + 350 + 600,
    'tint, pearlescent and custom RGB are each charged')

local savedPaint = Config.prices.paint
Config.prices.paint = 0
local free = Customs.unpriced({ windowTint = 2, modSpoilers = 1, color1 = 3 })
equal(table.concat(free, ','), 'color1,windowTint', 'zero-priced fields are reported, paid ones are not')
Config.prices.paint = nil
equal(#Customs.unpriced({ windowTint = 2 }), 1, 'a missing price counts as free')
Config.prices.paint = savedPaint

-- Paint has a price per category; a key left out falls back to paint / customPaint.
Config.prices.primaryPaint, Config.prices.secondaryPaint = 400, 300
Config.prices.customPrimary, Config.prices.customSecondary = 700, 550
Config.prices.pearlescent, Config.prices.wheelPaint, Config.prices.windowTint = 250, 200, 150
equal(Customs.unitPrice('color1', 3), 400, 'primary palette paint')
equal(Customs.unitPrice('color2', 3), 300, 'secondary palette paint')
equal(Customs.unitPrice('color1', { r = 1, g = 2, b = 3 }), 700, 'custom primary RGB')
equal(Customs.unitPrice('color2', { r = 1, g = 2, b = 3 }), 550, 'custom secondary RGB')
equal(Customs.price({ pearlescentColor = 1, wheelColor = 2, windowTint = 3 }), 250 + 200 + 150, 'pearlescent, wheel paint and tint')
equal(Customs.price({ color1 = 1, color2 = { r = 1, g = 1, b = 1 } }), 400 + 550, 'each paint side is charged separately')
Config.prices.secondaryPaint, Config.prices.customSecondary, Config.prices.windowTint = nil, nil, nil
equal(Customs.unitPrice('color2', 3), Config.prices.paint, 'a missing paint key falls back to paint')
equal(Customs.unitPrice('color2', { r = 1, g = 1, b = 1 }), Config.prices.customPaint, 'a missing custom key falls back to customPaint')
equal(Customs.unitPrice('windowTint', 1), Config.prices.paint, 'tint falls back to paint')
equal(Customs.unitPrice('extras'), Config.prices.extra, 'extras keep their price')
equal(Customs.unitPrice('modSpoilers', 1), Config.prices.body, 'mods keep their category price')

print('qbcustoms catalog: ok')
