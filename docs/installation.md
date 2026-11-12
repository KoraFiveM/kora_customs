---
title: Installation
sidebar_position: 2
---

# Installation

## Dependencies

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| `kora_lib` | Shared init, `Kora.nui` app shell, notifications, blips, callbacks, distance and world checks |
| `kora_core` | Owned vehicle rows (`getByPlate`), player data (`getPlayerData`), money (`removeMoney`, `addMoney`), `saveVehicleProperties`, on-duty counts (`getDutyCount`), `logEvent` |
| `kora_target` | Box zones with the "Customise vehicle" and "Repair vehicle" options |

`server_scripts` also loads `@kora_sql/init.lua`, but `kora_sql` is not in the `dependencies` list and the server code does not query SQL itself.

Related resources (not required): `kora_garages` and `kora_dealership` interact with the stored look, see [Factory look](./configuration.md#factory-look). The manifest also declares `qa_feature 'tests/*.feature'` for `kora_qa`.

## Steps

1. Place the resource in the resources folder and ensure it after `kora_lib`, `kora_core` and `kora_target`.
2. Edit `config.lua` (shops, prices, camera, UI).
3. Do not run a real `qb-customs`; this resource provides that name.

## Compatibility notes

- The draggable panel, `placement = 'left'` and hold-to-test horn buttons need a `kora_lib` app shell that supports them. Older shells ignore the fields.
- `Config.targetAllowInVehicle` needs a `kora_target` that honours `allowInVehicle`; older builds ignore it, which blocks targeting while seated.
- In `kora_garages` keep `Config.TrustClientCosmetics = false` so an unpaid preview is not saved when parking.
