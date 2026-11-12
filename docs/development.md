---
title: Development
sidebar_position: 9
---

# Development

## Tests

Pure logic lives in `shared/` and is covered offline by plain Lua scripts in `test/`. Run them all with:

```sh
./test/run.sh
```

It runs `catalog.lua`, `camera.lua`, `hornconfig.lua`, `pauseconfig.lua`, `previewguard.lua`, `server.lua` and `selfrepair.lua`. Run it after changing the cosmetic contract, prices, camera or repair logic.

`tests/checklist-vehicles.feature` holds Gherkin scenarios for `kora_qa` (declared with `qa_feature` in the manifest).

## Layout

`config.lua`, `shared/catalog.lua` (allow-list, pricing, diff, merge), `shared/camera.lua`, `shared/horn.lua`, `client/main.lua` (shop UI, preview, camera, targets, repair), `server/main.lua` (callbacks), `fft_hooks_server.lua`.

## FFT hooks

`fft_hooks_server.lua` does nothing unless the convar `fft_kora_hooks` is `true`. When enabled it exports `fftVersion` and `fftAction`; `fftAction` accepts calls only from the `fft` resource for a player with an FFT session state, and supports the single action `resetRepairCooldown`, which clears that player's own repair cooldown through `Customs._fftResetRepair`.
