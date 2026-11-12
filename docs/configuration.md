---
title: Configuration
sidebar_position: 3
---

# Configuration

All options are in `config.lua`. The table is passed through `Kora.config.adopt` when available.

## General

| Option | Default | Description |
| --- | --- | --- |
| `Config.debug` | `false` | Debug prints, target zone debug and the `getVehprop` command. |
| `Config.targetAllowInVehicle` | `true` | Sets `allowInVehicle` on the shop target options so they work from the driver seat. |

## Interaction

`Config.interaction`:

| Option | Default | Description |
| --- | --- | --- |
| `distance` | `4.0` | Target interaction distance. |
| `checkoutDistance` | `12.0` | Server-side maximum distance of the player and of the vehicle from the shop `coords`. |
| `account` | `'bank'` | Account charged for customisations. |
| `reason` | `'vehicle-customisation'` | Money reason string for the checkout charge (the refund and repair reasons are fixed in the code). |
| `requireSameBucket` | `true` | Player and vehicle must be in the shop's routing bucket. |
| `allowFreeFields` | `false` | When false, an order containing a changed field priced 0 or missing is refused. |

## Shops

`Config.shops` is a table keyed by shop id. Each entry has `label`, `coords` (vector3), `size` (vector3 box), `rotation` and `bucket` (routing bucket). Default ids: `bennys`, `laMesa`, `route68`. The id is what `exports.kora_customs:open` takes. `Config.blip` controls the map blips: `enabled`, `sprite`, `color`, `scale`, `shortRange`, `category`.

## Prices

`Config.prices` is the only price source; the server prices every changed field from it.

| Key | Applies to |
| --- | --- |
| `primaryPaint`, `secondaryPaint` | Palette colour on primary or secondary paint. |
| `customPrimary`, `customSecondary` | Custom RGB primary or secondary paint. |
| `pearlescent`, `wheelPaint`, `windowTint` | Pearlescent, wheel colour, window tint. |
| `paint`, `customPaint` | Fallbacks when a paint key above is missing. |
| `body` | Body mods, liveries, hydraulics, engine block, air filter, struts, arch covers, aerials, tank, window accessories (see `Customs.modFields` in `shared/catalog.lua`). |
| `wheels` | Front/rear wheels, wheel type, custom tyres. |
| `interior` | Dashboard and interior colours, trim, ornaments, dials, speakers, seats, steering wheel, shifter, plaques, trunk, horn. |
| `lighting` | Xenon, xenon colour, neon, neon colour, tyre smoke and its colour. |
| `plate` | Plate style, plate holder, vanity plate. |
| `extra` | Per vehicle extra toggled (charged individually). |

A field is charged once per checkout however many variants were previewed. `Config.palette` (`min` 0, `max` 160) bounds the palette colour list in the UI; the server accepts palette values 0 to 255.

Performance fields (`modEngine`, `modBrakes`, `modTransmission`, `modSuspension`, `modArmor`, `modTurbo`) and condition or fuel are not in the allow-list and are rejected.

## UI

`Config.ui`: `compactActions`, `layout` (`standard` or `compact`), `width`, `height`, `placement`, `defaultSide` (`right` or `left`), `draggable`, `rememberPosition`, `previewButton` (Hide menu), `blockPauseMenu`, `pauseGuardMs`. See [UI](./ui.md).

## Camera

`Config.camera`: `focusParts`, `interpMs`, `fov`, `avoidPanel`, `panelMargin`, `screenShift`, `cabin` (`hidePed`, `fillLight`, `clearScreenEffects`), `default`, `presets` (bone, fallback, dir, distance, fov, eye, offset, avoidPanel, cabin), `fields` (vehicle field to preset) and `views` (tab to preset). The comments in `config.lua` describe each key.

## Horn preview

`Config.hornPreview`: `autoPlay`, `button`, `method` (`input` or `proxy`), `durationMs`, `durations` (rules with `match` text and `ms`), `byIndex`, `startDelayMs`, `mode` (`HELDDOWN` or `NORMAL`), `holdToTest`, `clickPlaysFull`, `maxHoldMs`, `holdKey`.

Length is taken from `byIndex`, then the first `durations` rule whose `match` text appears in the horn name (English names), then `durationMs`. With `holdKey` set (and `holdToTest`), a key mapping `+kora_customs_horn` is registered.

## Factory look

`Config.factoryLook`: `enabled` (default `true`) and `fillMissing` (default `true`). When the shop opens on the player's own car whose stored row has no look, the client sends the properties it read before any preview and the server stores the shop's cosmetic fields once per plate while the resource runs. This one snapshot is client-supplied: a modified client could store a look it did not pay for, once. Turn `enabled` off if that matters more.

## Preview guard

`Config.previewGuard`: `recheckMs` (500), `attempts` (3), `reapplyOnOpen` (true). After a revert the car is re-read and fields still differing are put back; with `reapplyOnOpen` a stuck unpaid preview is reverted when the shop next opens.

## Self-service repair

`Config.selfRepair`: `enabled` (true), `onlyWhenNoMechanics` (true), `mechanicJobs` (`{ 'mechanic' }`), `price` (750, 0 is free), `account` (`'bank'`), `durationMs` (10000, minimum 1000 on the server), `cooldownSeconds` (120, per character). See [Events and callbacks](./events.md#self-service-repair).
