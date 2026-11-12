---
title: "How to use"
sidebar_position: 3
---


# How to use

A player targets a shop zone while sitting in the driver seat of an owned vehicle, previews changes live on their own vehicle entity, then confirms a server-priced purchase. The client never decides what gets charged or saved — it only shows previews and asks.

## The player-facing flow

1. **Target the shop** — Hold the kora_target key at a `Config.shops` zone while in the driver seat. `Config.targetAllowInVehicle` (default true) keeps the option visible even though kora_target normally hides everything while seated.

2. **Session opens** — `open(shopId)` reads the vehicle's current properties as the session's "original" snapshot, freezes the vehicle in place, and opens the kora_lib app shell on the Paint tab. Every side effect (field previews, camera, horn) only exists on this client until checkout.

3. **Preview options** — Stepping, toggling or colour-picking a field previews it immediately on the vehicle (`Kora.vehicle.setProperties`-style) and records it in the session's pending patch. The part camera (`Config.camera`) glides to frame whatever was just changed.

4. **Purchase changes** — Choosing "Purchase changes" quotes the pending patch (`kora_customs:quote`), shows a confirmation dialog with the server-returned price, and only then sends `kora_customs:purchase` with the same patch and the quoted price.

5. **Anything else reverts** — Escape, the X button, "Discard changes", leaving the driver seat or the shop radius, dying, the vehicle disappearing, or the resource stopping all restore the vehicle to its pre-session properties. `Config.previewGuard` re-checks shortly after a revert and `reapplyOnOpen` catches a preview that survived to the next session.

## Checkout: what the server re-validates

The manifest comment is explicit that this resource does not reproduce qb-customs' client-trusting purchase events. Every purchase re-derives its own facts; nothing the client reports is persisted as-is.

```lua title="server/main.lua" {8}
-- server/main.lua (abridged): every purchase is re-derived from scratch
Kora.callback.register('kora_customs:purchase', function(src, shopId, netId, requestedPatch, quotedPrice, mods)
    local prepared, prepareErr = prepare(src, shopId, netId, requestedPatch)
    if not prepared then return false, prepareErr end
    local row, patch, price = prepared.row, prepared.patch, prepared.price
    if tonumber(quotedPrice) ~= price then
        return false, 'customisation price changed; review the new quote'
    end
    -- ...charge, merge, persist, log (see "Checkout: what the server re-validates")...
end, { rateLimit = { max = 4, window = 10000 } })
```

- Shop: `shopId` must be a configured `Config.shops` key; the player's ped must exist, be in the shop's routing bucket (unless `Config.interaction.requireSameBucket = false`), and within `Config.interaction.checkoutDistance` (default 12 m) of the shop coords.
- Vehicle: the network id is resolved through `Kora.world.resolveNetworkEntity` with `requireDriver = true`, the same bucket requirement and the same max distance, and the resolved vehicle must itself be within range of the shop.
- Ownership: the vehicle's plate is read directly off the entity (never trusted from the client), looked up with `exports.kora_core:getByPlate`, and the row's `citizenid` must match the calling player's, with `state == 'out'`. If the model can be checked, the entity's live model must match the row's stored model.
- Patch: the requested patch is re-sanitised field-by-field against `Customs.rules` (type, range, and known-field checks — see Catalog below), then reduced to only the fields that actually differ from the row's stored `mods`. An unknown field, an out-of-range value, or a patch that changes nothing is refused.
- Price: computed from `Config.prices` for the *re-sanitised, re-diffed* patch, never from a client-supplied number. The client's quoted price is only compared against this: a mismatch (because the server state moved between quote and purchase) refuses with "customisation price changed; review the new quote". A patch containing a field with no configured price is refused unless `Config.interaction.allowFreeFields = true`.
- Concurrency: a per-plate lock (`purchasing[plate]`) rejects a second purchase, factory-look store or repair while one is already in flight for that plate.
- Charge-then-persist: `exports.kora_core:removeMoney` runs first; only on success is `saveVehicleProperties` called with the existing stored mods merged with the validated patch (`Customs.merge`). If persistence fails, the charge is refunded (`addMoney`, `..., true` for a tax-free refund) before the error is returned. The whole sequence runs in a `pcall`; an uncaught error still refunds a charge that was not yet confirmed as saved.
- The optional sixth argument to `kora_customs:purchase` (the client's full `Kora.vehicle.getProperties` snapshot) is accepted for compatibility but is not what gets persisted — only the server-validated `patch` reaches `Customs.merge` and the database.

## Catalog: field rules, pricing and diffing (shared/catalog.lua)

`Customs.rules` is the single source of truth for every cosmetic field this shop will touch, shared by the client (building the UI and previews) and the server (sanitising and pricing). Each rule has a `kind` (`integer`, `boolean`, `rgb`, `color`, `xenon`, `booleanArray`, `extras`) with its own bounds, plus a `price` key into `Config.prices` and an optional `fallback` / `custom` key.

- `Customs.sanitizePatch(patch)` — rejects anything that is not a plain table of known fields with in-range values (max 64 fields per call); returns `nil, reason` on any violation.
- `Customs.changedPatch(patch, existing)` — reduces a sanitised patch to only the fields whose value differs from `existing` (the row's stored `mods`); `extras` is diffed per extra id.
- `Customs.price(patch)` / `Customs.unitPrice(field, value)` — sums `Config.prices[rule.price]` (or `rule.fallback`) per changed field; `extras` is priced per enabled/disabled id.
- `Customs.unpriced(patch)` — the changed fields whose resolved price is 0 or missing, used to refuse free-riding fields unless `Config.interaction.allowFreeFields` is set.
- `Customs.merge(existing, patch)` — deep-clones `existing` and applies the patch on top (`extras` merged key-by-key) to produce the properties blob that gets persisted.
- `Customs.lookOf(properties)` / `Customs.hasLook(stored)` / `Customs.missingLook(stored, look)` — extract only the shop's cosmetic fields from a full property snapshot, used by the factory-look feature (never performance mods, plate, fuel or condition).

## Preview rollback and the factory look

- Preview guard (`Config.previewGuard`): after any non-purchase exit, the client restores the original properties, then re-reads the vehicle `recheckMs` later (default 500 ms) and reapplies any field that still shows the preview, up to `attempts` times (default 3). `reapplyOnOpen` remembers fields previewed in a session that ended unpaid and, if the vehicle still shows one of them the next time a session opens on it, restores the earlier value before the new session's "original" snapshot is taken.
- Factory look (`Config.factoryLook`, enabled by default): if a vehicle's ownership row has no stored look yet, the client sends the properties it read *before any preview* when the session opens; the server (`kora_customs:factoryLook` callback) revalidates shop/vehicle/ownership/model exactly like checkout, keeps only the shop's cosmetic fields, and stores them once per plate for the life of the resource — at no charge. `fillMissing` (default on) also backfills cosmetic fields a partially-stored row lacks. The server trusts the client for this one snapshot because previews exist only client-side; this is a deliberate, narrow trust boundary (a modified client could store an unpaid look once per plate this way).

## Self-service repair

`Config.selfRepair` adds a "Repair vehicle" (enabled by default; set `enabled = false` to turn it off) target option at every shop, for the driver, when `onlyWhenNoMechanics` is set and no player with one of `mechanicJobs` is on duty (kora_core's on-duty counts).

1. **Start** — Client confirms the price, then calls the `kora_customs:repairStart` callback, which re-checks the shop, vehicle, on-duty mechanics and the per-character cooldown, and opens a single-use ticket keyed by `src`.

2. **Progress bar** — The client runs a cancellable progress bar for `ticket.durationMs`; nothing is charged or fixed yet.

3. **Finish** — The client calls `kora_customs:repairFinish`. The server checks the ticket's elapsed time against its recorded duration (rejecting both "too fast" and "took far too long"), re-runs every start-time check, then charges `Config.selfRepair.account` (or `Config.interaction.account`) and sets the cooldown. Only then does the client fix the engine, body and fuel tank (`SetVehicleFixed`, health set to 1000, `SetVehicleUndriveable(false)`).

## Part camera and horn preview

- `Config.camera` (shared/camera.lua): while a session is open, selecting an option glides a scripted camera to frame the part being changed, resolved per vehicle field (`Config.camera.fields`) then per shop tab (`Config.camera.views`) then a `default` preset. `avoidPanel` shifts the framing so the part lands clear of the shop panel; presets with an `eye` table put the camera inside the cabin (used by the Interior tab). Set `Config.camera.focusParts = false` for the plain FreeCam/normal camera instead.
- `Config.hornPreview` (shared/horn.lua): the fitted horn sounds automatically when it changes (`autoPlay`) and a "Test horn" / "Hold to test horn" button (`holdToTest`) plays it again. `Customs.hornDuration(settings, index, name)` picks the preview length: `byIndex[index]` first, then the first `durations` rule whose `match` text is part of the horn's displayed name, then `durationMs`. `method = 'input'` (default) sounds the horn on the player's own vehicle by holding the horn control, so nearby players hear it; `method = 'proxy'` sounds a hidden local copy instead.

## Security notes for integrators

- There is no job check anywhere in this resource: it is a public shop gated only by location, driver seat and vehicle ownership. If you need a job-restricted customisation flow, build it as a separate resource rather than editing this one's access checks.
- Never trust the client's reported price, patch, or full property snapshot for anything that gets persisted or charged — only `kora_customs:quote` / `kora_customs:purchase`'s own server-side `prepare()` result is authoritative, and the checkout code re-derives it from the vehicle entity and the ownership row on every call.
- Performance fields (`modEngine`, `modBrakes`, `modTransmission`, `modSuspension`, `modArmor`, `modTurbo`) and vehicle condition/fuel are not in `Customs.rules` at all, so the sanitiser rejects them outright — they can never reach this resource's checkout.
