# kora_customs

Public, self-service cosmetic vehicle customisation for the qbcore2 stack.
It is intentionally separate from `kora_mechanic`: no repairs, work orders,
employee job, servicing, or performance upgrades are included.

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

**Horn preview.** `Config.hornPreview` (`autoPlay`, `button`, `durationMs`):
the selected horn sounds briefly when changed, and the horn row has a
**Test horn** button. Set either to `false` to turn it off.

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
