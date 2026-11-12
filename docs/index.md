---
title: kora_customs
sidebar_position: 1
---

# kora_customs

`kora_customs` is a public, self-service cosmetic vehicle shop for Kora servers. A player drives an owned vehicle into one of the configured shop zones, targets the shop from the driver seat, previews cosmetic changes live in a `kora_lib` NUI app and pays at checkout. It is deliberately not a mechanic job: performance upgrades, work orders and servicing are out of scope. The only repair is the optional paid self-service fallback (`Config.selfRepair`) that works while no mechanic is on duty.

Current version: see `version` in `fxmanifest.lua`.

## Features

- **Three shops** - `Config.shops` defines Benny's, La Mesa Customs and Route 68 Customs, each with a `kora_target` box zone and an optional map blip.
- **Cosmetic catalogue** - body mods (spoilers, bumpers, skirts, exhaust, hood, roof and so on), liveries, wheels and wheel type, primary and secondary paint (palette or custom RGB), pearlescent, wheel colour, interior and dashboard colours, interior trim mods, horn, window tint, plate style and plate holders, xenon, neon, tyre smoke and vehicle extras. See [UI](./ui.md).
- **Live preview with rollback** - previews exist only on the vehicle entity and are reverted on every exit that is not a completed purchase.
- **Part camera, Freecam, Hide menu** - a scripted camera frames the part being changed. See [UI](./ui.md).
- **Horn preview** - automatic playback and a test button (optionally hold to test).
- **Server-authoritative checkout** - the server re-resolves the shop, player, vehicle, ownership row, field allow-list and price. See [Events and callbacks](./events.md).
- **Factory look baseline** - stores the car's original look once when the car has none stored. See [Configuration](./configuration.md#factory-look).
- **Self-service repair** - optional paid repair when no mechanic is on duty.
- **qb-customs compatibility** - the manifest uses `provide 'qb-customs'`. A real `qb-customs` must not run alongside this resource.

Access has no job check. Access is decided by being at a shop, sitting in the driver seat and owning the vehicle.

## Pages

- [Installation](./installation.md) - dependencies, installation, compatibility.
- [Configuration](./configuration.md) - every `Config` table and option, and the price table.
- [Exports and commands](./api.md) - the `open` export and the commands.
- [Events and callbacks](./events.md) - server callbacks and the events the resource uses.
- [Database](./database.md) - how vehicle data is read and written.
- [UI](./ui.md) - the shop panel, tabs, camera, preview rules.
- [Troubleshooting](./troubleshooting.md) - common problems and their causes.
- [Development](./development.md) - tests, kora_qa features, FFT hooks.
