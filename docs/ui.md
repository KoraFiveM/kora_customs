---
title: UI
sidebar_position: 7
---

# UI

The shop is a `kora_lib` NUI app with id `kora_customs:shop` and title "Custom Shop", opened from the "Customise vehicle at (shop name)" target option while driving an owned vehicle. Tabs: Paint, Body, Wheels, Interior, Lighting, Plate and glass, Extras and Review. Rows offer Previous, Next and Choose (Prev, Next, Pick with `compactActions`), toggles for neon, xenon and extras, and a colour picker for custom RGB.

Header actions: **Freecam**, **Hide menu** (with `previewButton`), **Purchase changes**, and **Discard changes**.

## Camera

With `Config.camera.focusParts` a scripted camera glides to the part being changed using `Config.camera.fields` and `views`. The camera is restored on close and stopped while Freecam is active. The Interior view sits inside the cabin, hides the local player ped and adds a fill light (`Config.camera.cabin`). With `avoidPanel` the framing is shifted away from the panel.

## Escape and pause menu

In Freecam, Escape cancels like Backspace. With `Config.ui.blockPauseMenu` the pause menu is disabled while Freecam or Hide menu is up and until `pauseGuardMs` after the key is released.

## Previews are never saved

Escape, X, Discard, a failed or refused checkout, leaving the seat or the shop, dying, the vehicle vanishing or the resource stopping all restore the original properties (including paint, pearlescent, custom RGB and window tint) and verify paint and tint came back. Factory window glass (-1) is restored as tint 0. If Escape closes the panel while a paid order is processing, the paid look is applied back to the vehicle. See `Config.previewGuard`.

The vehicle is frozen while the shop is open and the original frozen state is restored afterwards.

## Horn

The selected horn plays on change (`autoPlay`) and the horn row has a Test horn button (Hold to test horn with `holdToTest`). See [Configuration](./configuration.md#horn-preview).

## Self-service repair

The "Repair vehicle" target option shows the price, a progress bar "Repairing vehicle..." runs for `durationMs`, then the server finishes the repair.
