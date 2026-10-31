Config = {}

Config.debug = false

Config.interaction = {
    distance = 4.0,
    checkoutDistance = 12.0,
    account = 'bank',
    reason = 'vehicle-customisation',
    requireSameBucket = true,
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
