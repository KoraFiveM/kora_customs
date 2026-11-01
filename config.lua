Config = {}

Config.debug = false

Config.interaction = {
    distance = 4.0,
    checkoutDistance = 12.0,
    account = 'bank',
    reason = 'vehicle-customisation',
    requireSameBucket = true,
}

Config.ui = {
    -- Use short action labels (Prev / Next / Pick) on option rows. Off by
    -- default; rows already wrap their buttons below the text when narrow.
    compactActions = false,
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
-- `fields` maps a vehicle field to a preset, `views` maps a shop tab to a
-- preset, and `default` is used for anything not listed (paint, body, ...).
Config.camera = {
    focusParts = true,
    interpMs = 800,
    fov = 45.0,
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
        -- `eye` places the camera inside the cabin (passenger seat, head height)
        -- looking at the steering wheel / dashboard.
        interior = { bone = 'steeringwheel', fallback = { -0.35, 0.3, 0.2 }, fov = 65.0, eye = { bone = 'seat_pside_f', fallback = { 0.35, 0.0, 0.0 }, offset = { 0.0, -0.1, 0.45 } } },
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
--   autoPlay    sound the selected horn briefly whenever it changes
--   button      add a "Test horn" button to the horn row
--   durationMs  how long the horn sounds
Config.hornPreview = {
    autoPlay = true,
    button = true,
    durationMs = 1200,
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
-- previewed. Extras are charged individually.
Config.prices = {
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
