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

-- Preview guard: what a revert must apply again, and which unpaid previews a
-- later session finds still on the car.
assert(Customs.showsValue('windowTint', 0, -1) and Customs.showsValue('windowTint', -1, -1),
    'factory tint (-1) reads back as -1 or as none (0)')
assert(not Customs.showsValue('windowTint', 5, -1) and not Customs.showsValue('windowTint', 0, 1), 'a real tint is a difference')
assert(Customs.showsValue('color1', { r = 1, g = 2, b = 3 }, { r = 1, g = 2, b = 3 }) and not Customs.showsValue('color2', 4, 5),
    'other fields compare by value')

local before = { color1 = 5, color2 = 7, pearlescentColor = 3, windowTint = -1, neonColor = { r = 1, g = 1, b = 1 } }
local drift = Customs.previewDrift({ color1 = 5, color2 = 12, pearlescentColor = 3, windowTint = 0, neonColor = { r = 9, g = 1, b = 1 } },
    before, { color2 = true, windowTint = true, neonColor = true, pearlescentColor = true })
equal(drift.color2, 7, 'a secondary preview that stayed is put back')
equal(drift.windowTint, nil, 'tint none over factory is not a drift')
equal(drift.neonColor.r, 1, 'RGB previews are put back')
equal(drift.pearlescentColor, nil, 'a field that was put back is left alone')
equal(drift.color1, nil, 'fields the session did not preview are not touched')
drift.neonColor.r = 99
equal(before.neonColor.r, 1, 'the patch is a copy')
equal(next(Customs.previewDrift(nil, before, { color2 = true })), nil, 'no snapshot, no patch')
equal(Customs.previewDrift({ windowTint = 5 }, before, { windowTint = true }).windowTint, -1, 'a stuck tint is put back to factory')

local entry = Customs.rememberUnpaid(nil, before, { windowTint = 5, color2 = 40 })
equal(entry.original.windowTint, -1, 'the value before the preview is kept')
equal(entry.preview.windowTint, 5, 'the last preview is kept')
entry = Customs.rememberUnpaid(entry, { windowTint = 5, color2 = 7, pearlescentColor = 3 }, { windowTint = 4, pearlescentColor = 9 })
equal(entry.original.windowTint, -1, 'a later session that opened on the stuck preview keeps the first original')
equal(entry.preview.windowTint, 4, 'and the latest preview')
equal(entry.original.pearlescentColor, 3, 'new fields join the entry')
equal(Customs.rememberUnpaid(nil, before, {}), nil, 'nothing previewed, nothing remembered')
equal(Customs.rememberUnpaid(nil, before, { modEngine = 2 }), nil, 'a field the snapshot lacks is not remembered')

local stuck = Customs.stuckPreviews({ windowTint = 4, color2 = 7, pearlescentColor = 11 }, entry)
equal(stuck.windowTint, -1, 'a tint preview still on the car is put back')
equal(stuck.color2, nil, 'a field already back is left alone')
equal(stuck.pearlescentColor, nil, 'a field showing something else (bought, changed elsewhere) is left alone')
equal(next(Customs.stuckPreviews({ windowTint = 0 }, { original = { windowTint = -1 }, preview = { windowTint = 0 } })), nil,
    'a none-tint preview over factory glass is not undone (it looks the same)')
equal(next(Customs.stuckPreviews({ windowTint = 4 }, nil)), nil, 'no entry, no patch')

-- Window tint row: -1 .. 6 in SET_VEHICLE_WINDOW_TINT order, every tint reachable.
local client = assert(io.open('client/main.lua')):read('a')
local names = assert(client:match("local tintNames = (%b{})"), 'tint names exist')
local count = 0
for _ in names:gmatch("'[^']+'") do count = count + 1 end
equal(count, Customs.rules.windowTint.max - Customs.rules.windowTint.min + 1, 'one tint name per value -1 .. 6')
assert(names:find("'None', 'Pure Black', 'Dark Smoke', 'Light Smoke', 'Stock', 'Limo', 'Green'", 1, true),
    'names follow the native order: 0 none, 1 pure black ... 6 green')

print('qbcustoms catalog: ok')
