Config = {}

-- General ------------------------------------------------------------------

Config.OpenMenu = 'I'             -- default key for the settings menu (players can rebind it in FiveM settings)
Config.UseMPH = true              -- true = MPH and feet, false = KPH and metres
Config.Accent = '#5eead4'         -- UI accent colour (matches ze-inventory)
Config.Currency = { locale = 'en-US', code = 'USD' } -- used to format the money display (Intl.NumberFormat)

Config.SpeedMax = { mph = 180, kph = 300 } -- speed that fills the gauge completely
Config.VoiceRanges = { 1.5, 3.0, 6.0 }     -- pma-voice proximity ranges, shortest first (drives the 3 voice pips)

-- Any resource that exports GetFuel(vehicle) works here (qb-fuel provides 'LegacyFuel').
Config.FuelResource = 'LegacyFuel'
Config.LowFuelLevel = 20          -- percent
Config.LowFuelRepeat = 60000      -- ms between low fuel alerts

-- Refresh rate (ms) of the vitals/vehicle loop. "Optimized" is what players get by default,
-- "Synced" is the menu's performance toggle turned off.
Config.Tick = {
    footOptimized = 500,
    footSynced = 100,
    vehOptimized = 100,
    vehSynced = 50,
}

Config.CinematicBar = 0.1         -- height of each black bar in cinematic mode (fraction of the screen)

-- Minimap frame -------------------------------------------------------------
-- The NUI frame is drawn around the minimap. All values are in vh (1% of screen height).
-- If the frame does not line up on your screen, tune these (also make sure the GTA safezone is
-- on its default: Settings > Display > Restore Defaults).
Config.MapFrame = {
    square = { left = 2.5, bottom = 6.0, width = 29.0, height = 18.5 },
    circle = { left = 3.7, bottom = 7.0, width = 27.3, height = 22.9 },
}

-- Defaults for every player-facing setting. Players change these in the menu; they are stored
-- per player in the client's resource KVP. "auto*" means "hide while there is nothing to report".
Config.Defaults = {
    -- status
    autoHealth = true,         -- hide health at 100%
    autoArmor = true,          -- hide armor at 0
    autoHunger = true,         -- hide hunger at 100%
    autoThirst = true,         -- hide thirst at 100%
    autoStress = true,         -- hide stress at 0
    autoStamina = true,        -- hide stamina / oxygen at 100%
    -- vehicle
    autoEngine = true,         -- hide engine health above 95%
    autoNitro = true,          -- hide nitrous when the tank is empty
    optimized = true,          -- slower refresh rate, easier on low end machines
    -- map
    mapShape = 'square',       -- 'square' | 'circle'
    mapFrame = true,           -- draw the frame around the minimap
    hideMap = false,           -- never show the minimap
    minimapOnFoot = false,     -- show the minimap on foot (it always shows in vehicles)
    -- compass
    compassShow = true,
    compassOnFoot = false,
    compassFollowCam = true,   -- heading follows the camera instead of the character
    compassOptimized = true,
    streetNames = true,
    compassPointer = true,
    compassDegrees = true,
    -- sounds and alerts
    soundMenu = true,
    soundToggle = true,
    soundReset = true,
    notifyMap = true,
    notifyFuel = true,
    notifyCinematic = true,
    -- state
    cinematic = false,
}

-- Stress -------------------------------------------------------------------

Config.DisableStress = false      -- true removes stress completely for everyone
Config.StressChance = 0.1         -- chance (0-1) of gaining stress per shot
Config.MinimumStress = 50         -- stress level where the screen starts to blur
Config.MinimumSpeedUnbuckled = 50 -- going over this speed unbuckled causes stress
Config.MinimumSpeed = 100         -- going over this speed buckled causes stress

Config.WhitelistedWeaponArmed = { -- weapons that do NOT show the "armed" chip
    -- miscellaneous
    [`weapon_petrolcan`] = true,
    [`weapon_hazardcan`] = true,
    [`weapon_fireextinguisher`] = true,
    -- melee
    [`weapon_dagger`] = true,
    [`weapon_bat`] = true,
    [`weapon_bottle`] = true,
    [`weapon_crowbar`] = true,
    [`weapon_flashlight`] = true,
    [`weapon_golfclub`] = true,
    [`weapon_hammer`] = true,
    [`weapon_hatchet`] = true,
    [`weapon_knuckle`] = true,
    [`weapon_knife`] = true,
    [`weapon_machete`] = true,
    [`weapon_switchblade`] = true,
    [`weapon_nightstick`] = true,
    [`weapon_wrench`] = true,
    [`weapon_battleaxe`] = true,
    [`weapon_poolcue`] = true,
    [`weapon_briefcase`] = true,
    [`weapon_briefcase_02`] = true,
    [`weapon_garbagebag`] = true,
    [`weapon_handcuffs`] = true,
    [`weapon_bread`] = true,
    [`weapon_stone_hatchet`] = true,
    -- throwables
    [`weapon_grenade`] = true,
    [`weapon_bzgas`] = true,
    [`weapon_molotov`] = true,
    [`weapon_stickybomb`] = true,
    [`weapon_proxmine`] = true,
    [`weapon_snowball`] = true,
    [`weapon_pipebomb`] = true,
    [`weapon_ball`] = true,
    [`weapon_smokegrenade`] = true,
    [`weapon_flare`] = true,
}

Config.WhitelistedWeaponStress = { -- weapons that do NOT cause stress when fired
    [`weapon_petrolcan`] = true,
    [`weapon_hazardcan`] = true,
    [`weapon_fireextinguisher`] = true,
}

Config.VehClassStress = { -- vehicle classes that cause stress when speeding
    ['0'] = true,         -- Compacts
    ['1'] = true,         -- Sedans
    ['2'] = true,         -- SUVs
    ['3'] = true,         -- Coupes
    ['4'] = true,         -- Muscle
    ['5'] = true,         -- Sports Classics
    ['6'] = true,         -- Sports
    ['7'] = true,         -- Super
    ['8'] = true,         -- Motorcycles
    ['9'] = true,         -- Off Road
    ['10'] = true,        -- Industrial
    ['11'] = true,        -- Utility
    ['12'] = true,        -- Vans
    ['13'] = false,       -- Cycles
    ['14'] = false,       -- Boats
    ['15'] = false,       -- Helicopters
    ['16'] = false,       -- Planes
    ['18'] = false,       -- Emergency
    ['19'] = false,       -- Military
    ['20'] = false,       -- Commercial
    ['21'] = false,       -- Trains
}

Config.WhitelistedVehicles = { -- vehicles that never cause stress by speeding
    --[`adder`] = true
}

Config.WhitelistedJobs = {     -- jobs / job types that never gain stress
    ['leo'] = true,
    ['ambulance'] = true,
}

-- Screen blur while stressed. `intensity` is how long (ms) the blur is held.
Config.Intensity = {
    blur = {
        { min = 50, max = 60, intensity = 1500 },
        { min = 60, max = 70, intensity = 2000 },
        { min = 70, max = 80, intensity = 2500 },
        { min = 80, max = 90, intensity = 2700 },
        { min = 90, max = 100, intensity = 3000 },
    },
}

-- How often (ms, rolled between the two values) the stress effect repeats.
Config.EffectInterval = {
    { min = 50, max = 60, timeout = { 50000, 60000 } },
    { min = 60, max = 70, timeout = { 40000, 50000 } },
    { min = 70, max = 80, timeout = { 30000, 40000 } },
    { min = 80, max = 90, timeout = { 20000, 30000 } },
    { min = 90, max = 100, timeout = { 15000, 20000 } },
}
