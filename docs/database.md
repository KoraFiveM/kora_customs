---
title: Database
sidebar_position: 8
---

# Database

The resource creates no tables and runs no SQL of its own. All vehicle data goes through `kora_core`:

| Call | Use |
| --- | --- |
| `getByPlate(plate)` | Reads the owned vehicle row. The fields used are `plate`, `citizenid`, `state`, `model` and `mods`. |
| `saveVehicleProperties(plate, properties)` | Persists the stored properties after a purchase or factory look. |

The stored `mods` table is merged with the validated cosmetic fields; a complete client-supplied property blob is never persisted. The one exception in trust is the [factory look](./configuration.md#factory-look) snapshot, which is filtered to the shop's cosmetic fields. Extras are stored under string keys.

The server keeps in-memory state only: the per-plate purchase lock, the set of plates whose factory look was already handled (reset on resource restart), repair tickets and repair cooldowns.
