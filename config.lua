Config = {}

Config.debug = false

Config.interaction = {
    distance = 4.0,
    checkoutDistance = 12.0,
    account = 'bank',
    reason = 'vehicle-customisation',
    requireSameBucket = true,
    -- Checkout refuses an order containing a field whose price in
    -- Config.prices is missing or 0, so a typo cannot make paint or window tint
    -- free. Set true only if some categories are meant to cost nothing.
    allowFreeFields = false,
}

Config.ui = {
    -- Use short action labels (Prev / Next / Pick) on option rows. Off by
    -- default; rows already wrap their buttons below the text when narrow.
    compactActions = false,

    -- Shop panel geometry (kora_lib app shell). 'standard' is at least 720 px
    -- wide, 'compact' at least 420 px. `placement` is 'right' or 'center'. The
    -- part camera uses these to keep the framed part out from under the panel
    -- (see Config.camera.avoidPanel).
    layout = 'standard',
    width = 720,
    height = 900,
    placement = 'right',

    -- Which side the panel opens on when `placement` is not 'center':
    -- 'right' (default) or 'left'. 'left' needs a kora_lib app shell that
    -- accepts placement = 'left'; on older builds the shop quietly keeps the
    -- right-hand panel (and its camera framing). The part camera frames the
    -- part on the opposite side of the screen either way.
    defaultSide = 'right',

    -- Let the player drag the panel by its header, clamped to the screen
    -- (double-click the header to reset), and remember where they left it
    -- (browser storage, so it is per player). Sent to the app shell as
    -- `draggable` / `rememberPosition`; needs a kora_lib build whose app shell
    -- supports them, older builds ignore both. A dragged panel can sit under
    -- the camera's offset framing: turn avoidPanel off if you prefer to drag.
    draggable = true,
    rememberPosition = true,

    -- Add a "Hide menu" button that closes the panel so the whole screen shows
    -- the vehicle; Enter / Backspace / Escape brings it back, previews intact.
    previewButton = true,

    -- Stop GTA's pause menu (Escape / P) opening over the shop. While Freecam
    -- or Hide menu is up the pause keys are disabled and Escape cancels like
    -- Backspace; after Escape ends a view or closes the panel they stay
    -- disabled until the key is released plus `pauseGuardMs` milliseconds.
    blockPauseMenu = true,
    pauseGuardMs = 250,
}

-- Part camera: while the shop is open, selecting an option moves a scripted
-- camera to frame the part being changed. Set focusParts = false to keep the
-- normal camera. Freecam always takes priority while it is active.
--   interpMs  glide time between framings (milliseconds)
--   fov       default field of view
-- Each preset frames one point on the vehicle:
--   bone      vehicle bone to aim at (falls back to `fallback` when missing)
--   fallback  {x, y, z} point as a fraction (-1..1) of the model's half size
--             from its centre; x = right, y = front, z = up
--   dir       {x, y, z} direction from that point to the camera, vehicle-local
--   distance  metres from the point (scaled for long/short vehicles)
--   fov       optional per-preset field of view
--   eye       optional {bone, fallback, offset}: put the camera inside the
--             vehicle at that point (+ offset metres, vehicle-local) instead of
--             `distance` metres out along `dir`
--   offset    optional {x, y, z} metres (vehicle-local) added to the aimed point
--   avoidPanel  set false to keep this preset centred on screen
--   cabin     true for in-cabin views: applies Config.camera.cabin
-- `fields` maps a vehicle field to a preset, `views` maps a shop tab to a
-- preset, and `default` is used for anything not listed (paint, body, ...).
Config.camera = {
    focusParts = true,
    interpMs = 800,
    fov = 45.0,

    -- The shop panel covers the right of the screen. With avoidPanel the view
    -- is turned so the framed part lands in the free area to its left, using
    -- the panel width from Config.ui.
    --   avoidPanel   true to shift framing clear of the panel
    --   panelMargin  pixels of gap between the panel and the screen edge
    --   screenShift  extra shift as a fraction of the screen width (+ = move
    --                the part further left, - towards the panel); 0 = none
    avoidPanel = true,
    panelMargin = 16,
    screenShift = 0.0,

    -- In-cabin views (presets with cabin = true):
    --   hidePed             hide the player (and passengers) for the local
    --                       client only, so the dashboard is not blocked.
    --                       Nothing is changed on the entity; it reverts by
    --                       itself the moment the camera leaves the cabin
    --   fillLight           a white light at the camera so the dashboard is lit
    --                       even in a dark bay (enabled, range m, intensity)
    --   clearScreenEffects  drop a screen blur / timecycle modifier left over
    --                       from another resource while the cabin view is up
    cabin = {
        hidePed = true,
        fillLight = { enabled = true, range = 3.5, intensity = 1.0 },
        clearScreenEffects = true,
    },
    default = 'overview',
    presets = {
        overview = { fallback = { 0.0, 0.0, 0.2 }, dir = { -0.8, 1.0, 0.35 }, distance = 6.5 },
        wheelFront = { bone = 'wheel_lf', fallback = { -1.0, 0.6, -0.6 }, dir = { -1.0, 0.0, 0.12 }, distance = 2.6, fov = 40.0 },
        wheelRear = { bone = 'wheel_lr', fallback = { -1.0, -0.6, -0.6 }, dir = { -1.0, 0.0, 0.12 }, distance = 2.6, fov = 40.0 },
        front = { bone = 'bumper_f', fallback = { 0.0, 1.0, -0.3 }, dir = { -0.3, 1.0, 0.2 }, distance = 4.0 },
        rear = { bone = 'bumper_r', fallback = { 0.0, -1.0, -0.3 }, dir = { 0.3, -1.0, 0.2 }, distance = 4.0 },
        exhaust = { bone = 'exhaust', fallback = { 0.0, -1.0, -0.6 }, dir = { 0.3, -1.0, 0.2 }, distance = 3.0 },
        spoiler = { bone = 'boot', fallback = { 0.0, -0.9, 0.6 }, dir = { 0.5, -1.0, 0.45 }, distance = 4.5 },
        hood = { bone = 'bonnet', fallback = { 0.0, 0.7, 0.4 }, dir = { -0.4, 1.0, 0.8 }, distance = 4.5 },
        roof = { fallback = { 0.0, 0.0, 1.0 }, dir = { 0.0, -0.3, 1.0 }, distance = 5.5 },
        -- Cabin view: the camera sits between and just behind the front seats
        -- at head height and looks forward at the centre of the dashboard (the
        -- steering wheel bone shifted to the middle of the cabin), so the whole
        -- dash, centre console and trim are in view.
        interior = {
            cabin = true, fov = 65.0,
            bone = 'steeringwheel', fallback = { -0.35, 0.3, 0.2 }, offset = { 0.35, 0.2, -0.1 },
            eye = { bone = 'seat_pside_f', fallback = { 0.35, 0.0, 0.0 }, offset = { -0.35, -0.4, 0.5 } },
        },
        sideWindow = { bone = 'window_lf', fallback = { -1.0, 0.1, 0.35 }, dir = { -1.0, 0.1, 0.15 }, distance = 3.0, fov = 40.0 },
        plate = { bone = 'numberplate', fallback = { 0.0, -1.0, -0.3 }, dir = { 0.0, -1.0, 0.1 }, distance = 2.2, fov = 40.0 },
        lights = { bone = 'headlight_l', fallback = { -0.6, 1.0, 0.0 }, dir = { -0.5, 1.0, 0.15 }, distance = 3.5 },
        underglow = { fallback = { 0.0, 0.0, -0.8 }, dir = { -0.9, 0.6, 0.12 }, distance = 5.0 },
    },
    fields = {
        wheels = 'wheelFront', wheelColor = 'wheelFront', modFrontWheels = 'wheelFront', modCustomTiresF = 'wheelFront',
        modBackWheels = 'wheelRear', modCustomTiresR = 'wheelRear',
        modFrontBumper = 'front', modGrille = 'front', modHydrolic = 'front', modStruts = 'hood',
        modRearBumper = 'rear', modExhaust = 'exhaust', modSpoilers = 'spoiler', modTrunk = 'spoiler',
        modHood = 'hood', modEngineBlock = 'hood', modAirFilter = 'hood',
        modRoof = 'roof', modAerials = 'roof',
        dashboardColor = 'interior', interiorColor = 'interior', modTrimA = 'interior', modTrimB = 'interior',
        modOrnaments = 'interior', modDashboard = 'interior', modDial = 'interior', modDoorSpeaker = 'interior',
        modSeats = 'interior', modSteeringWheel = 'interior', modShifterLeavers = 'interior', modAPlate = 'interior',
        modSpeakers = 'interior', modHorns = 'interior',
        modPlateHolder = 'plate', modVanityPlate = 'plate', plateIndex = 'plate',
        windowTint = 'sideWindow',
        modXenon = 'lights', xenonColor = 'lights',
        neonEnabled = 'underglow', neonColor = 'underglow',
        modSmokeEnabled = 'wheelRear', tyreSmokeColor = 'wheelRear',
    },
    views = {
        paint = 'overview', body = 'overview', wheels = 'wheelFront', interior = 'interior',
        lighting = 'lights', plate = 'plate', extras = 'overview', review = 'overview',
    },
}

-- Horn preview: the horn option is hard to judge by name alone.
--   autoPlay      sound the selected horn whenever it changes (Previous/Next/Choose)
--   button        add a test button to the horn row (see holdToTest)
--   method        how the preview is sounded. The game only gives a horn a short
--                 tap while a player sits in the driver seat (StartVehicleHorn
--                 ignores its duration then), and the shop keeps the player there:
--                 'proxy'  a hidden, local copy of the vehicle with the same horn
--                          fitted and nobody in it sounds the horn for the full
--                          time; only this player hears it
--                 'input'  holds the horn key (control 86) for the preview, as if
--                          the player held it; the whole server hears it
--   durationMs    how long a horn sounds when no rule below names it (plain horns:
--                 truck, cop, clown, air horns, the scale notes)
--   durations     { match = text or list, ms = length }: the first rule whose text
--                 is part of the horn's displayed name (any case) sets its length.
--                 A loop horn repeats for as long as it sounds, so its length is
--                 one pass through the tune. Translate `match` for other languages
--   byIndex       [horn mod index] = ms, checked before `durations`
--   startDelayMs  pause before sounding, so a previous preview is cut cleanly
--                 and a horn fitted the same moment is the one heard
--   mode          StartVehicleHorn mode: 'HELDDOWN' (held horn) or 'NORMAL'
--   holdToTest    true: the button is "Hold to test horn": the horn sounds
--                 continuously from press to release (mouse, Enter or Space), up
--                 to maxHoldMs, with no repeats. Needs a kora_lib app shell with
--                 hold actions; older ones play it once per click instead.
--                 false: "Test horn" plays the horn once per click for its
--                 durationMs / durations length
--   maxHoldMs     cap on a held horn; it always stops on release, when the menu
--                 closes, the player leaves the vehicle or the resource stops
--   holdKey       optional RegisterKeyMapping key that also holds the horn
--                 (players can rebind it); the game only sees it while the panel
--                 is hidden (Hide menu). false = no key mapping
Config.hornPreview = {
    autoPlay = true,
    button = true,
    method = 'proxy',
    durationMs = 1500,
    durations = {
        { match = 'loop', ms = 6000 },
        { match = { 'musical', 'classical', 'jazz', 'star spangled', 'trombone', 'festive', 'halloween',
            'spooky', 'funeral', 'san andreas', 'liberty city' }, ms = 5000 },
    },
    byIndex = {},
    startDelayMs = 150,
    mode = 'HELDDOWN',
    holdToTest = true,
    maxHoldMs = 15000,
    holdKey = false,
}

-- Self-service repair at the shop zones, for when no mechanic is around.
-- Drivers get a "Repair vehicle" target option that fixes the engine, body and
-- fuel tank for `price`, after a `durationMs` progress bar. The server checks
-- the shop, the vehicle (driver seat, distance, routing bucket), the on-duty
-- mechanic count, the cooldown and the payment; the client only applies it.
--   enabled             offer the option at all
--   onlyWhenNoMechanics hide/refuse it while any `mechanicJobs` player is on duty
--   mechanicJobs        job names counted as mechanics (kora_core on-duty counts)
--   price               cost of one repair; 0 = free
--   account             money account charged
--   durationMs          progress bar length
--   cooldownSeconds     per character, between completed repairs
Config.selfRepair = {
    enabled = true,
    onlyWhenNoMechanics = true,
    mechanicJobs = { 'mechanic' },
    price = 750,
    account = 'bank',
    durationMs = 10000,
    cooldownSeconds = 120,
}

Config.blip = {
    enabled = true,
    sprite = 72,
    color = 5,
    scale = 0.75,
    shortRange = true,
    category = 'Other',
}

Config.shops = {
    bennys = {
        label = "Benny's Original Motor Works",
        coords = vector3(-211.55, -1324.55, 30.89),
        size = vector3(8.0, 8.0, 4.0),
        rotation = 0.0,
        bucket = 0,
    },
    laMesa = {
        label = 'La Mesa Customs',
        coords = vector3(731.68, -1088.78, 22.17),
        size = vector3(8.0, 8.0, 4.0),
        rotation = 0.0,
        bucket = 0,
    },
    route68 = {
        label = 'Route 68 Customs',
        coords = vector3(1174.76, 2640.15, 37.75),
        size = vector3(8.0, 8.0, 4.0),
        rotation = 0.0,
        bucket = 0,
    },
}

-- A field is charged once per checkout, regardless of how many variants were
-- previewed. Extras are charged individually. The server prices every order
-- from this table; checkout refuses a changed field whose price is 0 or missing
-- (see Config.interaction.allowFreeFields).
--   primaryPaint / secondaryPaint  a palette colour on the primary / secondary paint
--   customPrimary / customSecondary  a custom RGB primary / secondary paint
--   pearlescent, wheelPaint        pearlescent and wheel colour
--   windowTint                     window tint (Plate & glass tab)
--   paint / customPaint            fallbacks for any paint key above left out
--                                  (older configs only had these two)
Config.prices = {
    primaryPaint = 350,
    secondaryPaint = 300,
    customPrimary = 600,
    customSecondary = 500,
    pearlescent = 300,
    wheelPaint = 250,
    windowTint = 350,
    paint = 350,
    customPaint = 600,
    body = 500,
    wheels = 750,
    interior = 350,
    lighting = 300,
    extra = 100,
    plate = 250,
}

Config.palette = {
    min = 0,
    max = 160,
}

if Kora and Kora.config and Kora.config.adopt then Config = Kora.config.adopt(Config) end
