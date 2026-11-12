---
title: Events and callbacks
sidebar_position: 5
---

# Events and callbacks

The resource triggers no custom net events. Client and server talk through `Kora.callback` callbacks. They are internal; other resources should not call them.

## Server callbacks

| Callback | Arguments | Rate limit | Behaviour |
| --- | --- | --- | --- |
| `kora_customs:quote` | `shopId`, `netId`, `patch` | 8 per 10 s | Validates and returns `true, { price, plate }` or `false, reason`. |
| `kora_customs:purchase` | `shopId`, `netId`, `patch`, `quotedPrice`, `mods` | 4 per 10 s | Validates, charges, saves, returns `true, { price, plate }`. The `mods` argument is ignored. |
| `kora_customs:factoryLook` | `shopId`, `netId`, `properties` | 4 per 10 s | Stores the factory look baseline, see [Configuration](./configuration.md#factory-look). Returns `true, { stored = bool }`. |
| `kora_customs:repairStart` | `shopId`, `netId` | 4 per 10 s | Checks a repair and opens a ticket. Returns `true, { price, durationMs }`. |
| `kora_customs:repairFinish` | none | 4 per 10 s | Consumes the ticket, re-checks, charges, sets the cooldown. Returns `true, { price }`. |

## Checkout validation

For quote and purchase the server, in order:

1. Resolves the shop: known id, player ped exists, routing bucket equals the shop bucket (if `requireSameBucket`), player within `checkoutDistance`.
2. Resolves the vehicle from `netId`: a vehicle entity, the player is the driver, within distance, same bucket, and located at the shop.
3. Checks ownership: a row exists for the plate (`kora_core:getByPlate`), `citizenid` matches, `state` is `out`, and the entity model matches the row's model.
4. Sanitises the patch against the allow-list in `shared/catalog.lua` (unsupported field or bad value is refused, at most 64 fields), drops fields equal to the stored value, and refuses an empty result.
5. Prices from `Config.prices`; refuses a zero total or, unless `allowFreeFields`, any unpriced field.
6. On purchase: the quoted price must equal the server price, and only one purchase per plate may run (lock).

Then it removes the money, merges the validated fields into the stored properties, calls `saveVehicleProperties`, and logs `vehicle-customisation`. If saving fails the money is refunded (`vehicle-customisation-refund`). If the process errors after charging, a refund is attempted.

## Self-service repair

`repairStart` requires `Config.selfRepair.enabled`, a valid shop and driver vehicle at the shop, no on-duty mechanic (when `onlyWhenNoMechanics`) and no active cooldown, then stores a single ticket per player. `repairFinish` requires the elapsed time to be at least the duration minus 1 s and at most the duration plus 60 s, re-runs all checks, charges `price` (if above 0), sets the cooldown and logs `vehicle-self-repair`. The client then fixes engine, body and fuel tank. The repair does not require vehicle ownership.

## Events listened

| Event | Side | Use |
| --- | --- | --- |
| `playerDropped` | server | Clears the player's repair ticket. |
| `onClientResourceStart` | client | Re-registers target zones when `kora_target` starts. |
| `onClientResourceStop` | client | On this resource stopping, stops horn and camera and restores the vehicle preview. |

## Logging

`kora_core:logEvent` entries: `vehicle-customisation` (plate, shop, price, fields) and `vehicle-self-repair` (shop, price).
