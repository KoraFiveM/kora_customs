# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_customs — Vehicles

  @kora_customs @checklist @checklist:kora_customs:shop-blips @cat:vehicles @manual
  Scenario: Three shop blips
    """
    Checklist test: Check the map for Benny's (-211,-1324), La Mesa Customs (731,-1088) and Route 68 Customs (1174,2640).
    """
    When I manually: open the map
    Then I confirm: a blip is shown for Benny's near (-211, -1324)
    And I confirm: a blip is shown for La Mesa Customs near (731, -1088)
    And I confirm: a blip is shown for Route 68 Customs near (1174, 2640)

  @kora_customs @checklist @checklist:kora_customs:open-shop-target @cat:vehicles
  Scenario: Open shop from driver seat
    """
    Checklist test: Drive an owned car into a shop zone, hold the target key (ALT) and pick 'Customise vehicle'; panel opens on the right.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: drive an owned car into a shop zone
    And I manually: hold the target key (ALT) and look at the shop
    And I select the "Customise vehicle" target option
    Then the "kora_customs:shop" app opens
    And I confirm: the customisation panel is shown on the right of the screen

  @kora_customs @checklist @checklist:kora_customs:not-owned-denied @cat:vehicles @manual
  Scenario: Owned vehicle and driver seat required
    """
    Checklist test: Try the shop in a non-owned vehicle or as passenger; option is missing or checkout is refused.
    """
    When I manually: go to a shop zone in a non-owned vehicle and hold the target key (ALT)
    Then I confirm: the 'Customise vehicle' option is missing or checkout is refused
    When I manually: repeat as a passenger in an owned vehicle
    Then I confirm: the 'Customise vehicle' option is missing or checkout is refused

  @kora_customs @checklist @checklist:kora_customs:live-preview @cat:vehicles @manual
  Scenario: Live preview of options
    """
    Checklist test: Use Previous/Next/Choose on a mod (spoiler, bumper, wheels); the change shows on the car instantly.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: use Previous, Next and Choose on a mod such as spoiler, bumper or wheels
    Then I confirm: the change shows on the car instantly

  @kora_customs @checklist @checklist:kora_customs:paint-colours @cat:vehicles @manual
  Scenario: Paint, pearlescent, wheel paint
    """
    Checklist test: Paint tab: change primary, secondary, pearlescent and wheel colours; custom RGB uses a colour picker.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: open the Paint tab and change the primary, secondary, pearlescent and wheel colours
    Then I confirm: each colour change shows on the car
    When I manually: choose custom RGB paint
    Then I confirm: a colour picker is used for custom RGB

  @kora_customs @checklist @checklist:kora_customs:window-tint-neon-xenon @cat:vehicles @manual
  Scenario: Tint, neon, xenon, tyre smoke
    """
    Checklist test: Toggle neon/xenon, set window tint and tyre smoke colour; previews apply and prices are listed.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: toggle neon and xenon, set window tint and set the tyre smoke colour
    Then I confirm: the previews apply to the car
    And I confirm: prices are listed for the options

  @kora_customs @checklist @checklist:kora_customs:plate-liveries-extras @cat:vehicles @manual
  Scenario: Plate index, liveries, extras
    """
    Checklist test: Change plate style, livery and toggle vehicle extras (Turn on/off).
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: change the plate style, the livery and toggle vehicle extras (Turn on/off)
    Then I confirm: each change shows on the car

  @kora_customs @checklist @checklist:kora_customs:interior-colours @cat:vehicles @manual
  Scenario: Interior colours
    """
    Checklist test: Interior tab changes dashboard/trim colour; camera moves inside the cabin and player is hidden.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: open the Interior tab and change the dashboard/trim colour
    Then I confirm: the dashboard/trim colour changes
    And I confirm: the camera moves inside the cabin
    And I confirm: my player is hidden

  @kora_customs @checklist @checklist:kora_customs:part-camera @cat:vehicles @manual
  Scenario: Camera focuses on changed part
    """
    Checklist test: Pick a wheel, spoiler or hood option; camera glides to that part and stays clear of the panel; restored on close.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: pick a wheel, spoiler or hood option
    Then I confirm: the camera glides to that part and stays clear of the panel
    When I manually: close the panel
    Then I confirm: the camera is restored to normal

  @kora_customs @checklist @checklist:kora_customs:freecam @cat:vehicles
  Scenario: Freecam button
    """
    Checklist test: Click Freecam to orbit the car; Escape/Backspace returns to previous view and reopens the panel (pause menu stays blocked).
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: click Freecam and orbit the car
    And I press the "ESCAPE" key
    Then I confirm: the view returns to the previous view and the panel reopens
    And I confirm: the pause menu does not open
    When I manually: click Freecam again and press Backspace
    Then I confirm: the view returns to the previous view and the panel reopens

  @kora_customs @checklist @checklist:kora_customs:hide-menu @cat:vehicles @manual
  Scenario: Hide menu button
    """
    Checklist test: Click Hide menu to see the full car; Enter, Backspace or Escape brings the panel back.
    """
    When I manually: open the customisation panel in an owned vehicle at a shop
    And I manually: click Hide menu
    Then I confirm: the full car is visible without the panel
    When I manually: press Enter
    Then I confirm: the panel comes back
    When I manually: click Hide menu and press Backspace
    Then I confirm: the panel comes back
    When I manually: click Hide menu and press Escape
    Then I confirm: the panel comes back

  @kora_customs @checklist @checklist:kora_customs:horn-preview @cat:vehicles
  Scenario: Horn test
    """
    Checklist test: Horns row: Test horn plays the fitted horn once from a local copy; changing horn plays it; new click restarts it.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: open the custom shop and go to the Horns row
    And I manually: click Test horn
    Then I confirm: the fitted horn plays once
    When I manually: change the horn selection
    Then I confirm: the newly selected horn plays
    When I manually: click Test horn again while it is still playing
    Then I confirm: the horn sound restarts from the beginning

  @kora_customs @checklist @checklist:kora_customs:pending-total @cat:vehicles
  Scenario: Pending changes and price summary
    """
    Checklist test: Summary view lists each change with its price and a pending total; prices per field match config.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: target the shop and choose Customise vehicle
    And I manually: preview several changes
    And I manually: open the summary view
    Then I confirm: the summary lists each change with its price
    And I confirm: the summary shows a pending total equal to the sum of the prices
    And I confirm: each price matches the per-field price in the config

  @kora_customs @checklist @checklist:kora_customs:purchase-changes @cat:vehicles
  Scenario: Purchase changes
    """
    Checklist test: Click Purchase changes; bank charged the total, look persists, park/respawn the car and confirm cosmetics stay.
    """
    Given I am in the driver seat of a "test_car"
    And my bank balance is at least 10000
    When I manually: target the shop and choose Customise vehicle
    And I manually: preview some changes
    And I manually: click Purchase changes
    Then I should see a notification containing "Customisation saved for"
    And I confirm: my bank was charged the pending total
    And I confirm: the vehicle keeps the purchased look
    When I manually: park the car and respawn it from the garage
    Then I confirm: the cosmetics stay applied

  @kora_customs @checklist @checklist:kora_customs:insufficient-funds @cat:vehicles
  Scenario: Checkout with insufficient funds
    """
    Checklist test: Try purchasing with too little bank balance; refused with error and the car reverts to its original look.
    """
    Given I am in the driver seat of a "test_car"
    And my bank balance is 0
    When I manually: target the shop and choose Customise vehicle
    And I manually: preview some paid changes
    And I manually: click Purchase changes
    Then I should see a notification containing "Purchase failed."
    And I should see an error notification
    And my bank balance should be 0
    And I confirm: the car reverts to its original look

  @kora_customs @checklist @checklist:kora_customs:discard-rollback @cat:vehicles
  Scenario: Discard, escape or leaving rolls back
    """
    Checklist test: Preview changes then Discard, close with X/Escape, exit the seat or die; original paint, wheels and tint are restored.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: target the shop, choose Customise vehicle and preview changes to paint, wheels and tint
    And I manually: click Discard
    Then I confirm: the original paint, wheels and tint are restored
    When I manually: preview the changes again and close the shop with X
    Then I confirm: the original paint, wheels and tint are restored
    When I manually: preview the changes again
    And I press the "ESCAPE" key
    Then I confirm: the original paint, wheels and tint are restored
    When I manually: preview the changes again
    And I get out of the vehicle
    Then I confirm: the original paint, wheels and tint are restored
    When I manually: get back in the driver seat, preview the changes again and die
    Then I confirm: the original paint, wheels and tint are restored

  @kora_customs @checklist @checklist:kora_customs:performance-mods-excluded @cat:vehicles
  Scenario: No performance upgrades
    """
    Checklist test: Confirm the shop offers no engine, brakes, transmission, suspension, armor or turbo options.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: target the shop, choose Customise vehicle and browse every tab
    Then I confirm: the shop offers no engine, brakes, transmission, suspension, armor or turbo options

  @kora_customs @checklist @checklist:kora_customs:self-repair @cat:vehicles
  Scenario: Repair vehicle (no mechanic on duty)
    """
    Checklist test: With no mechanic on duty, target 'Repair vehicle ($750)', confirm, 10s bar; engine/body/fuel fixed and bank charged.
    """
    Given I am in the driver seat of a "test_car"
    And my bank balance is at least 1000
    When I manually: make sure no mechanic is on duty and damage the vehicle engine and body
    And I manually: target the shop and choose Repair vehicle ($750)
    And I manually: confirm the repair
    Then a progress bar should run
    And I confirm: the progress bar runs for about 10 seconds
    When I wait 10 seconds
    Then I confirm: engine, body and fuel are fixed
    And I should see a notification containing "Vehicle repaired for"
    And my bank balance should have changed by -750

  @kora_customs @checklist @checklist:kora_customs:self-repair-cooldown @cat:vehicles
  Scenario: Repair blocked with mechanic or cooldown
    """
    Checklist test: With a mechanic on duty the option is hidden/refused; a second repair within 120s is refused.
    """
    Given I am in the driver seat of a "test_car"
    And my bank balance is at least 2000
    When I manually: ask a second player to go on duty as mechanic
    And I manually: target the shop and look for Repair vehicle
    Then I confirm: the Repair vehicle option is hidden or the repair is refused
    When I manually: ask the mechanic to go off duty
    And I manually: target the shop, choose Repair vehicle and confirm, then wait for the repair to finish
    And I manually: try to repair the vehicle again within 120 seconds
    Then I confirm: the second repair is refused

  @kora_customs @checklist @checklist:kora_customs:factory-look @cat:vehicles
  Scenario: Factory look saved on first open
    """
    Checklist test: Open the shop with a freshly bought dealership car; its current colours are stored as baseline without charge.
    """
    Given I am in the driver seat of a "test_car"
    When I manually: use a freshly bought dealership car and open the custom shop
    Then I confirm: the current colours are stored as the baseline
    And I confirm: I was not charged anything

  @kora_customs @checklist @checklist:kora_customs:export-open @cat:vehicles
  Scenario: exports.kora_customs:open
    """
    Checklist test: From another client script call exports.kora_customs:open('bennys') in a vehicle; shop opens (server still checks location).
    """
    Given I am in the driver seat of a "test_car"
    When I manually: drive to a custom shop location (Benny's) in my vehicle
    And I select the "Customise vehicle" target option
    Then the "kora_customs:shop" app opens
    And I confirm: the shop opens only when the server location check passes (at the shop it opens; away from a shop it is refused)

  @kora_customs @checklist @checklist:kora_customs:getvehprop-command @cat:vehicles
  Scenario: /getVehprop debug command
    """
    Checklist test: Sit in a vehicle and run /getVehprop; vehicle properties print to the debug console.
    """
    Given I am in the driver seat of a "test_car"
    When I run the command "/getVehprop"
    And the F8 console should show "model"
