Config = Config or {}

-- ---------------------------------------------------------------------------------------------------------------------
-- General
-- ---------------------------------------------------------------------------------------------------------------------

Config.Debug = false

Config.OpenKey = 'M'               -- default key for /phone. Players can rebind it in the game's key bindings.
Config.AnswerKey = 'Y'             -- answers an incoming call while the phone is closed
Config.HangupKey = 'N'             -- hangs up / declines while the phone is closed
Config.Item = 'phone'              -- the item a player needs. false: no item needed.
Config.WalkWhileOpen = true        -- keep moving (and driving) with the phone open. Typing in a field pauses the keys.
Config.Accent = '#ff7a1a'          -- default accent colour of the phone UI. Players can pick their own in Settings.

-- Controls that are switched off while the phone is open (mouse look, weapons, melee, pause menu, ...).
Config.DisabledControls = { 1, 2, 3, 4, 5, 6, 14, 15, 16, 17, 24, 25, 37, 44, 45, 47, 58, 92, 99, 100, 114, 115, 140, 141, 142, 143, 157, 158, 159, 160, 161, 162, 163, 164, 165, 177, 199, 200, 202, 257, 263, 264, 322 }

-- ---------------------------------------------------------------------------------------------------------------------
-- Apps (order = order on the home screen; `dock = true` ones sit in the bottom bar)
--   requires: the app is hidden while that resource is not running
--   mdt:      only for the jobs in Config.MDT
--   jobs:     only for these job names
--   enabled:  false to remove an app
-- ---------------------------------------------------------------------------------------------------------------------

Config.Apps = {
    { id = 'phone',      dock = true },
    { id = 'messages',   dock = true },
    { id = 'camera',     dock = true },
    { id = 'settings',   dock = true },
    { id = 'twitter' },
    { id = 'mail' },
    { id = 'bank' },
    { id = 'crypto',     requires = 'qb-crypto' },
    { id = 'vehicles',   requires = 'qb-garages' },
    { id = 'houses',     requires = 'qb-houses' },
    { id = 'racing',     requires = 'qb-lapraces' },
    { id = 'services' },
    { id = 'ads' },
    { id = 'gallery' },
    { id = 'maps' },
    { id = 'notes' },
    { id = 'clock' },
    { id = 'calculator' },
    { id = 'mdt',        mdt = true },
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Phone calls
-- ---------------------------------------------------------------------------------------------------------------------

Config.Calls = {
    RingTime = 25,                 -- seconds before an unanswered call counts as missed
    History = 60,                  -- calls kept per character
    Voice = 'pma-voice',           -- 'pma-voice' or 'none'
}

-- Ringtones and message tones are GTA frontend sounds (no sound files needed): id, label, sound set, sound name.
Config.Ringtones = {
    { id = 'default',  label = 'Classic',  set = 'Phone_SoundSet_Default',  name = 'Remote_Ring' },
    { id = 'michael',  label = 'Michael',  set = 'Phone_SoundSet_Michael',  name = 'Remote_Ring' },
    { id = 'franklin', label = 'Franklin', set = 'Phone_SoundSet_Franklin', name = 'Remote_Ring' },
    { id = 'trevor',   label = 'Trevor',   set = 'Phone_SoundSet_Trevor',   name = 'Remote_Ring' },
}

Config.TextTones = {
    { id = 'default',  label = 'Classic',  set = 'Phone_SoundSet_Default',  name = 'Text_Arrive_Tone' },
    { id = 'michael',  label = 'Michael',  set = 'Phone_SoundSet_Michael',  name = 'Text_Arrive_Tone' },
    { id = 'franklin', label = 'Franklin', set = 'Phone_SoundSet_Franklin', name = 'Text_Arrive_Tone' },
    { id = 'trevor',   label = 'Trevor',   set = 'Phone_SoundSet_Trevor',   name = 'Text_Arrive_Tone' },
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Messages, Twitter, adverts
-- ---------------------------------------------------------------------------------------------------------------------

Config.Messages = {
    MaxLength = 500,               -- characters in one message
    MaxPerChat = 400,              -- older messages of a conversation are dropped beyond this
}

Config.Twitter = {
    Hours = 12,                    -- how many hours of tweets are loaded
    Max = 60,                      -- tweets in the feed
    MaxLength = 280,
    Cooldown = 10,                 -- seconds between two tweets of one player
}

Config.Adverts = {
    Price = 0,                     -- charged from the bank for an advert (0: free)
    Cooldown = 60,                 -- seconds between two adverts of one player
    DurationMinutes = 30,          -- an advert disappears after this long (0: stays until deleted)
    MaxLength = 300,
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Bank and invoices
-- ---------------------------------------------------------------------------------------------------------------------

Config.Bank = {
    MaxTransfer = 1000000,         -- most money one transfer can move
    History = 40,                  -- transfers kept per character
}

Config.Billing = {
    Jobs = { police = true, ambulance = true, mechanic = true },   -- jobs that can send invoices (the /bill command and the Bank app)
    Commissions = { mechanic = 0.10 },                             -- share of a paid invoice the sender gets (0.10 = 10%)
    MaxAmount = 100000,
}

-- ---------------------------------------------------------------------------------------------------------------------
-- MDT (the police app) and the Services directory
-- ---------------------------------------------------------------------------------------------------------------------

Config.MDT = {
    Jobs = { 'police' },           -- job names that get the app...
    Types = { 'leo' },             -- ...and job types
    RequireDuty = true,
    AlertHistory = 40,
}

-- The Services app lists players of these jobs who are on duty. icon names are from html/js/icons.js.
Config.Services = {
    RequireDuty = true,
    List = {
        { job = 'police',     label = 'Police',       icon = 'shield', color = '#4a8cff' },
        { job = 'ambulance',  label = 'Ambulance',    icon = 'cross',  color = '#ff5d7a' },
        { job = 'mechanic',   label = 'Mechanics',    icon = 'wrench', color = '#34d399' },
        { job = 'taxi',       label = 'Taxi',         icon = 'car',    color = '#ffc14d' },
        { job = 'lawyer',     label = 'Lawyers',      icon = 'scale',  color = '#4dc3ff' },
        { job = 'realestate', label = 'Real estate',  icon = 'home',   color = '#c084fc' },
    },
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Camera (the provider and its keys are in config.server.lua)
-- ---------------------------------------------------------------------------------------------------------------------

Config.Camera = {
    Encoding = 'jpg',              -- 'jpg' or 'png'
    Quality = 0.85,
    MaxPhotos = 200,               -- photos kept per character
}

-- ---------------------------------------------------------------------------------------------------------------------
-- Personalisation
-- ---------------------------------------------------------------------------------------------------------------------

-- Wallpapers are CSS backgrounds. `id` is what gets saved, so do not change ids that players may already use.
Config.Wallpapers = {
    { id = 'ember',    label = 'Ember',    css = 'radial-gradient(120% 70% at 85% 0%, rgba(255,122,26,.62), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(255,182,46,.30), transparent 65%), linear-gradient(165deg, #2a1c14, #0d0a09 70%)' },
    { id = 'dusk',     label = 'Dusk',     css = 'radial-gradient(110% 70% at 15% 0%, rgba(167,139,250,.55), transparent 62%), radial-gradient(100% 70% at 100% 100%, rgba(255,122,26,.40), transparent 60%), linear-gradient(170deg, #1d1530, #0b0912 75%)' },
    { id = 'midnight', label = 'Midnight', css = 'radial-gradient(110% 70% at 80% 0%, rgba(56,189,248,.45), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(99,102,241,.35), transparent 65%), linear-gradient(170deg, #0f1a2e, #070a12 75%)' },
    { id = 'forest',   label = 'Forest',   css = 'radial-gradient(110% 70% at 20% 0%, rgba(52,211,153,.42), transparent 60%), radial-gradient(90% 60% at 100% 100%, rgba(163,230,53,.25), transparent 65%), linear-gradient(170deg, #0e1f1a, #070d0b 75%)' },
    { id = 'rose',     label = 'Rose',     css = 'radial-gradient(110% 70% at 85% 0%, rgba(244,114,182,.50), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(255,93,122,.32), transparent 65%), linear-gradient(170deg, #2a1420, #0e080b 75%)' },
    { id = 'aurora',   label = 'Aurora',   css = 'radial-gradient(90% 55% at 10% 15%, rgba(45,212,191,.45), transparent 60%), radial-gradient(90% 60% at 95% 55%, rgba(167,139,250,.40), transparent 62%), linear-gradient(175deg, #0c1a22, #08080f 80%)' },
    { id = 'sunrise',  label = 'Sunrise',  css = 'linear-gradient(180deg, rgba(255,182,46,.65) 0%, rgba(255,93,122,.55) 38%, rgba(72,34,76,.85) 70%, #120a14 100%)' },
    { id = 'graphite', label = 'Graphite', css = 'radial-gradient(100% 60% at 50% 0%, rgba(255,240,225,.12), transparent 62%), linear-gradient(170deg, #26221f, #0c0b0a 80%)' },
}

Config.Accents = { '#ff7a1a', '#ffb62e', '#ff5d7a', '#f472b6', '#a78bfa', '#38bdf8', '#2dd4bf', '#34d399', '#a3e635' }

-- ---------------------------------------------------------------------------------------------------------------------
-- Maps app: places that can be set as a GPS waypoint. { label, category, x, y } (approximate points, edit freely)
-- ---------------------------------------------------------------------------------------------------------------------

Config.Places = {
    { 'Legion Square',               'City',     195.2,  -933.8 },
    { 'City Hall',                   'City',    -544.8,  -204.4 },
    { 'Maze Bank Tower',             'City',     -75.0,  -818.0 },
    { 'Mirror Park',                 'City',    1060.0,  -724.0 },
    { 'Del Perro Pier',              'Leisure', -1850.0, -1231.0 },
    { 'Vespucci Beach',              'Leisure', -1203.0, -1561.0 },
    { 'Vinewood Sign',               'Leisure',  711.0,  1198.0 },
    { 'Observatory',                 'Leisure', -427.0,  1112.0 },
    { 'Mission Row Police Station',  'Services', 441.8,  -981.9 },
    { 'Pillbox Medical Center',      'Services', 311.0,  -592.0 },
    { 'Sandy Shores Sheriff',        'Services', 1853.0,  3689.0 },
    { 'Paleto Bay Sheriff',          'Services', -448.0,  6008.0 },
    { 'Premium Deluxe Motorsport',   'Shops',    -56.0, -1097.0 },
    { "Benny's Motor Works",         'Shops',   -205.7, -1307.0 },
    { 'Pacific Standard Bank',       'Shops',    235.0,   216.0 },
    { 'Los Santos International',    'Travel',  -1037.0, -2737.0 },
}
