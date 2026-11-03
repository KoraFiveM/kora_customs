# kora_customs

Public, self-service cosmetic vehicle customisation for the qbcore2 stack.
It is intentionally separate from `kora_mechanic`: no work orders, employee
job, servicing, or performance upgrades are included. The only repair is the
optional paid self-service fallback for when no mechanic is on duty
(`Config.selfRepair`, below).

## Features

- Live previews with complete rollback on cancel, failed payment, or resource stop.
- Three configurable public shops with target interactions and map markers.
- Standard body modifications, liveries, wheels, paint, custom RGB paint,
  interior colours, tint, plates, horns, xenon, neon, tyre smoke, and extras.
- Server-authoritative ownership, driver-seat, entity, plate, model, location,
  routing-bucket, field allow-list, and price validation.
- Cosmetic persistence through `qbcore:saveVehicleProperties`; the resource
  never writes `player_vehicles` directly.
- `provide 'qb-customs'` for dependency compatibility. A real `qb-customs`
  resource must not run alongside this one.

Configure locations and prices in `config.lua`. Players target a shop while
sitting in the driver seat of an owned vehicle. Side-scroll menu values to
preview them, then choose **Purchase changes**. The bank account is used by
default. Set `Config.ui.compactActions = true` for short Prev/Next/Pick button labels.

**Part camera.** With `Config.camera.focusParts = true` (default), choosing an
option glides a scripted camera to the part being changed (wheels, bumpers,
exhaust, spoiler, hood, roof, interior, plate, lights; paint/body show a 3/4
overview). `Config.camera.fields` maps vehicle fields and `Config.camera.views`
maps shop tabs to entries in `Config.camera.presets` (bone, fallback point,
direction, distance, fov), so servers can tune any framing. The camera uses
vehicle bones with a model-size fallback, is restored on close, and is stopped
while **Freecam** is active. Set `focusParts = false` for the normal camera.
Presets with an `eye = { bone, fallback, offset }` table put the camera inside
the cabin (the Interior tab does); window tint uses the `sideWindow` preset.

**Keeping the part clear of the panel.** The shop panel covers the right of the
screen, so the camera is turned to put the framed part in the free area beside
it (`Config.camera.avoidPanel`, `panelMargin`, `screenShift`; the panel width
comes from `Config.ui.width` / `layout`). Presets can opt out with
`avoidPanel = false` and add an aim `offset`. The Interior view sits between and
behind the front seats and looks at the middle of the dashboard; while it is
active (`Config.camera.cabin`) the player is hidden for the local client, a
white fill light lights the cabin, and a leftover screen blur / timecycle is
cleared. The **Hide menu** button (`Config.ui.previewButton`) closes the panel
so the whole screen shows the vehicle; Enter, Backspace or Escape brings it back.

**Escape and the pause menu.** In **Freecam** Escape cancels exactly like
Backspace (back to the previous view, then the panel reopens). With
`Config.ui.blockPauseMenu = true` (default) GTA's pause menu (Escape / P) is
disabled while Freecam or Hide menu is up, and after Escape ends a view or
closes the panel it stays disabled until the key is released plus
`Config.ui.pauseGuardMs` (default 250 ms), so the map never opens behind the shop.

**Movable panel.** `Config.ui.draggable` and `Config.ui.rememberPosition` are
sent to the kora_lib app shell as `draggable` / `rememberPosition` (with
`positionKey`). A shell that supports them lets the player drag the panel by its
header, clamped to the screen, remember the position per player and reset it with
a double-click on the header; older shells ignore the fields. The shell must be a
kora_lib build that includes the draggable app shell (`draggable`,
`rememberPosition`, `positionKey` in `Kora.nui.registerApp`). `Config.ui.defaultSide`
(`'right'` default, `'left'`) picks the side the panel opens on and the camera frames
the part on the opposite side; `'left'` needs a shell that accepts
`placement = 'left'`, otherwise the shop keeps the right-hand panel.

**Previews are never saved.** Previews exist only on the vehicle entity; the
server persists only what checkout validates and charges. Every way out that is
not a completed purchase (Escape, X, Discard changes, a failed or refused
checkout, leaving the seat or the shop, dying, the vehicle disappearing,
resource stop) puts the original properties back, including paint, pearlescent,
custom RGB and window tint, and checks that paint and tint really came back.
Checkout prices every changed field on the server and refuses a field whose
price is missing or 0 unless `Config.interaction.allowFreeFields = true`.
The client price is only compared with the server's; the charge happens before
anything is saved, and an order that cannot be paid is never persisted. If
Escape closes the panel while a paid order is still being processed, the paid
look is applied back to the vehicle.

Parking the vehicle is the other place a look can be saved: kora_garages stores
the properties the client reads off the vehicle. Keep its
`Config.TrustClientCosmetics = false` so paint, tint and every other cosmetic
field comes from the stored (paid) row instead of an unpaid preview.

**Horn preview.** `Config.hornPreview`: the selected horn sounds once when it
changes, and the horn row has a **Test horn** button that plays it again from the
start; a new press cuts the running preview first, so previews never overlap.
GTA only taps a horn while a player sits in the driver seat (`StartVehicleHorn`
ignores its duration then), and the shop keeps the player there, so the preview
does not sound the player's own vehicle. With `method = 'proxy'` (default) it
sounds from a hidden, local copy of the vehicle with the same horn fitted and
nobody in it, which only this player hears; `method = 'input'` holds the horn
key for the preview instead. The length comes from `byIndex[horn index]`, then
the first `durations` rule whose `match` text is in the horn's name (musical
horns 5 s, loop horns one 6 s pass), then `durationMs` (1.5 s, plain horns).
The rules match the English names; translate them for other game languages.
`holdToTest` (off by default) also sounds the horn while `holdKey` is held, up
to `maxHoldMs`; the game only sees that key while the panel is hidden. Set
autoPlay/button to `false` to turn them off.

**Self-service repair.** `Config.selfRepair` (enabled by default) adds a
**Repair vehicle** target option at every shop for the driver. With
`onlyWhenNoMechanics` it only shows, and the server only accepts it, while no
player with one of `mechanicJobs` is on duty (kora_core's on-duty counts). The
player confirms the `price`, waits through a `durationMs` progress bar, and the
server then re-checks the shop, driver seat, distance, routing bucket, mechanics
and the per-character `cooldownSeconds` before charging `account`; the engine,
body and fuel tank are then fixed. Set `enabled = false` to keep the shop purely
cosmetic.

**Who can use the shop.** There is no job check: the shop is a public,
self-service cosmetic shop. Access is decided by the location (a `Config.shops`
entry, the player must be at it), sitting in the driver seat, and the vehicle
being owned by that player; checkout re-verifies all of this on the server.

Performance fields (`modEngine`, `modBrakes`, `modTransmission`,
`modSuspension`, `modArmor`, and `modTurbo`) and vehicle condition/fuel are not
accepted by the server.

## API

Client:

```lua
exports.kora_customs:open('bennys')
```

The id must exist in `Config.shops`; checkout still enforces its server-side
distance and routing-bucket policy.

## Test

```sh
./test/run.sh
```
