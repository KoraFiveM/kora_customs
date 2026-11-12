---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Customs is a public, self-service cosmetic vehicle shop: paint, wheels, interior, lighting, plates, horns and extras, with live previews and server-authoritative checkout. It is deliberately not a mechanic job, repair system, performance tuner or garage — those stay in kora_mechanic / kora_garages. It also answers to the `qb-customs` and `kora_customs` export/resource names. Follow these steps in order.

## Install Kora Customs

1. **Add the folder** — Place the `kora_customs` folder in your resources directory (on the Kora recipe it is `resources/[kora]/kora_customs`). Keep the folder name unchanged: it is the export name scripts use as `exports.kora_customs:open(...)`.

2. **Install the dependencies** — The manifest declares `dependencies { 'kora_lib', 'kora_core', 'kora_target' }`. kora_lib supplies the app shell, callbacks, distance/world helpers and progress bars; kora_core supplies player data, money and vehicle ownership rows; kora_target supplies the shop's interaction zones.

3. **Start it after its dependencies** — Start Kora Customs after kora_lib, kora_core, kora_target and kora_sql, and after a real database driver is up.

   ```bash title="server.cfg"
   ensure kora_theme
   ensure kora_lib
   ensure kora_sql
   ensure kora_core
   ensure kora_target
   ensure kora_customs
   ```

4. **Make sure a real qb-customs is not also running** — `provide 'qb-customs'` lets other resources that only declare the retired `qb-customs` dependency start. The manifest comment is explicit that kora_customs does not reproduce qb-customs' purchase events; a real qb-customs resource must not run alongside this one.

## What the manifest sets up

- Shared scripts (both realms): `@kora_lib/init.lua`, then `config.lua`, `shared/catalog.lua` (the field rules, pricing, patch sanitising and merge logic — `Customs.*`), `shared/camera.lua` (part-camera framing math) and `shared/horn.lua` (horn preview duration lookup).
- Client: a single `client/main.lua` carrying the shop UI session, preview/rollback, part camera, horn preview, self-repair flow and target/blip registration.
- Server: `@kora_sql/init.lua` then `server/main.lua`. `@kora_sql/init.lua` is loaded as a **server script**, not a shared script — kora_customs itself issues no direct SQL (persistence goes through `exports.kora_core:saveVehicleProperties`), so only the server realm needs the `Kora.sql` namespace installed.
- No `config.lua` of its own is declared `shared_script` twice; it is a single shared script read by both client and server (the server reads `Config.interaction`, `Config.prices`, `Config.selfRepair`, `Config.factoryLook`, `Config.shops`).

## Configure shops and prices

Everything location- and money-related lives in `config.lua`.

- `Config.shops` — one entry per shop: `label`, `coords`, `size`, `rotation` (a kora_target box zone) and `bucket` (the routing bucket the shop and its customers must share).
- `Config.prices` — per-category prices (`primaryPaint`, `secondaryPaint`, `customPrimary`, `customSecondary`, `pearlescent`, `wheelPaint`, `windowTint`, `body`, `wheels`, `interior`, `lighting`, `extra`, `plate`), plus `paint` / `customPaint` fallbacks for any key left unset. A changed field whose resolved price is 0 or missing is refused by checkout unless `Config.interaction.allowFreeFields = true`.
- `Config.selfRepair` — optional paid self-service repair when no `mechanicJobs` player is on duty.
- `Config.factoryLook` — whether a first-ever customisation session stores the vehicle's pre-preview look as its baseline when its ownership row has none yet.

## If it does not start or nothing can be targeted

- Check the console for a missing `kora_lib`, `kora_core` or `kora_target` dependency.
- If the shop opens with no vehicle selected, you were not recognised as sitting in the driver seat of a usable vehicle — `exports.kora_customs:open` and the target option both refuse this.
- Run `test/run.sh` after changing the cosmetic field rules or prices (`shared/catalog.lua`, exercised by `test/catalog.lua`).

## Dependencies at a glance

Declared in `fxmanifest.lua`:

| Resource | Used for |
| --- | --- |
| `kora_lib` | Shared init, `Kora.nui` app shell, notifications, blips, callbacks, distance and world checks |
| `kora_core` | Owned vehicle rows (`getByPlate`), player data (`getPlayerData`), money (`removeMoney`, `addMoney`), `saveVehicleProperties`, on-duty counts (`getDutyCount`), `logEvent` |
| `kora_target` | Box zones with the "Customise vehicle" and "Repair vehicle" options |

`server_scripts` also loads `@kora_sql/init.lua`, but `kora_sql` is not in the `dependencies` list and the server code does not query SQL itself.

Related resources (not required): `kora_garages` and `kora_dealership` interact with the stored look, see [Factory look](./configuration.md#factory-look). The manifest also declares `qa_feature 'tests/*.feature'` for `kora_qa`.

## Compatibility notes

- The draggable panel, `placement = 'left'` and hold-to-test horn buttons need a `kora_lib` app shell that supports them. Older shells ignore the fields.
- `Config.targetAllowInVehicle` needs a `kora_target` that honours `allowInVehicle`; older builds ignore it, which blocks targeting while seated.
- In `kora_garages` keep `Config.TrustClientCosmetics = false` so an unpaid preview is not saved when parking.
