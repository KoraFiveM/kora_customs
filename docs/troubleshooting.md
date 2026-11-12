---
title: Troubleshooting
sidebar_position: 8
---

# Troubleshooting

## No "Customise vehicle" option

The player must be in the driver seat of a vehicle. Seated targeting needs `Config.targetAllowInVehicle = true` and a `kora_target` that supports `allowInVehicle`; hold the target key (ALT by default).

## Checkout is refused

Typical server messages: `this is not your vehicle`, `this vehicle is not owned`, `vehicle ownership state is invalid` (the row `state` must be `out`), `vehicle model does not match its ownership record`, `too far from the custom shop` or `vehicle is not at the custom shop` (see `checkoutDistance`), `custom shop is not in your world` (routing bucket), `customisation price changed; review the new quote`, `custom shop pricing is invalid` (a changed field has no price), `no changes selected`.

## A field is refused as unpriced

Add the matching key to `Config.prices` (see [Configuration](./configuration.md#prices)), or set `Config.interaction.allowFreeFields = true` if free fields are intended.

## The car shows an unpaid look after leaving

Keep `Config.previewGuard` enabled and `kora_garages` `Config.TrustClientCosmetics = false`.

## The repair option is missing

It is hidden when `Config.selfRepair.enabled` is false or when a player with one of `mechanicJobs` is on duty. The server refuses during the cooldown.

## The horn preview is silent or cut short

Use `method = 'input'`. Horn length rules match English names only; adjust `durations` or `byIndex`. Hold to test needs a `kora_lib` shell with hold actions.

## The panel cannot be dragged or placed left

The `kora_lib` app shell is older than the draggable build; update `kora_lib`.
