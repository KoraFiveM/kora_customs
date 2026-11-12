---
title: Exports and commands
sidebar_position: 4
---

# Exports and commands

## Client export

```lua
exports.kora_customs:open('bennys')
```

`open(shopId)` opens the shop panel for the vehicle the player is driving. The id must exist in `Config.shops`. It notifies the player and does nothing else if a session or repair is already running, or if the player is not in the driver seat of a networked vehicle; an unknown shop id is ignored silently. Checkout still enforces the server-side distance, ownership and bucket rules, so calling it away from a shop opens the panel but purchases are refused.

There are no server exports for other resources. (`fft_hooks_server.lua` registers `fftVersion` and `fftAction` only when FFT hooks are enabled, see [Development](./development.md).)

## Commands

| Command | Condition | Description |
| --- | --- | --- |
| `getVehprop` | only registered when `Config.debug` is `true` | Prints the properties of the vehicle the player is in. |
| `+kora_customs_horn` / `-kora_customs_horn` | always registered; the key mapping exists only when `Config.hornPreview.holdKey` is set | Holds the test horn while the shop is open and `holdToTest` is on. |

## Permissions

No ACE permissions or job checks are used. The only job reference is `Config.selfRepair.mechanicJobs`, used to count on-duty mechanics.
