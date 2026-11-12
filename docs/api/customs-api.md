---
title: "Client export"
sidebar_position: 2
---


# Client export

Kora Customs exposes one client export, `open`, that starts a shop session. Everything else (previewing fields, checkout, repair) happens inside the app shell this export opens, driven by the server callbacks documented below.

Namespace: `exports.kora_customs` · Source: `client/main.lua`

## How it works

A session is a single Lua table (`active`) tracking the vehicle, its pre-preview properties, the pending patch, and camera/horn state. Only one session can be open per client at a time; `open` refuses to start a second one.

## Functions

One client export.

### `exports.kora_customs:open(shopId)`

Opens a customisation session on the vehicle the player is currently driving, at the named shop. Normally called by the shop's own kora_target option, but exported so another resource (a different interaction, a menu) can open the same shop.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `shopId` | string | Required key into `Config.shops`. An unknown key is silently ignored (no session opens). |

**Returns**

- **No return value. Failure is reported to the player with a notification, not to the caller: "A customisation session is already open.", "Wait for the repair to finish.", "Sit in the driver seat of your vehicle.", or "This vehicle is not networked."**

**Example**

```lua
-- client: open a shop by its Config.shops key (e.g. from a different interaction)
exports.kora_customs:open('bennys')
```

**Representative console output**

```text
Freezes the vehicle, reads its current properties as the session baseline, and opens the kora_lib app shell on the Paint tab. Nothing is charged or saved until the player completes checkout inside the shop UI.
```

## Limits and related APIs

Client only. The export does not return whether the session actually opened; call it only from a context where the failure notifications shown to the player are an acceptable result (for example, your own target/menu option with its own `canInteract` guard).

## Behaviour details

`open(shopId)` requires a shop id that exists in `Config.shops`. It notifies the player and does nothing else if a session or repair is already running, or if the player is not in the driver seat of a networked vehicle. Checkout still enforces the server-side distance, ownership and bucket rules, so calling it away from a shop opens the panel but purchases are refused.

There are no server exports for other resources. (`fft_hooks_server.lua` registers `fftVersion` and `fftAction` only when FFT hooks are enabled, see [Development](../development.md).) The resource triggers no custom net events; the client and server talk through the callbacks listed in [Events and callbacks](../events.md).
