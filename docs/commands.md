---
title: Commands
sidebar_position: 4
---

# Commands

| Command | Condition | Description |
| --- | --- | --- |
| `getVehprop` | only registered when `Config.debug` is `true` | Prints the properties of the vehicle the player is in. |
| `+kora_customs_horn` / `-kora_customs_horn` | always registered; the key mapping exists only when `Config.hornPreview.holdKey` is set | Holds the test horn while the shop is open and `holdToTest` is on. |

## Permissions

No ACE permissions or job checks are used. The only job reference is `Config.selfRepair.mechanicJobs`, used to count on-duty mechanics.

The shop itself is opened from the target option or the `open` export, see the [client export](./api/customs-api.md).
