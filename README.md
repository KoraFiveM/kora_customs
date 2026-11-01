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
