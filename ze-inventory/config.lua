Config = {}

-- Names and defaults match qb-inventory so existing habits and docs still apply.
Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

Config.Debug = false -- true prints every move to the server console (who, from where to where, what)

Config.MaxWeight = 120000 -- grams
Config.MaxSlots = 40

Config.StashSize = {
    maxweight = 2000000,
    slots = 100,
}

Config.DropSize = {
    maxweight = 1000000,
    slots = 50,
}

Config.Keybinds = {
    Open = 'TAB',
    Hotbar = 'Z',
}

Config.HotbarSlots = 5         -- player slots 1..N are the quick slots (keys 1..N use them)
Config.GiveDistance = 3.0      -- how close the nearest player must be to receive an item
Config.StashSaveInterval = 5   -- minutes between saves of stashes that changed

Config.CleanupDropTime = 15    -- minutes before an untouched drop disappears
Config.CleanupDropInterval = 1 -- minutes between cleanup passes

Config.ItemDropObject = `bkr_prop_duffel_bag_01a`
Config.ItemDropObjectBone = 28422
Config.ItemDropObjectOffset = {
    vector3(0.260000, 0.040000, 0.000000),
    vector3(90.000000, 0.000000, -78.989998),
}

Config.VendingObjects = {
    'prop_vend_soda_01',
    'prop_vend_soda_02',
    'prop_vend_water_01',
    'prop_vend_coffe_01',
}

Config.VendingItems = {
    { name = 'kurkakola',    price = 4, amount = 50 },
    { name = 'water_bottle', price = 4, amount = 50 },
}

-- Sent to the UI on open. Everything is optional; see UI.md for what each does.
Config.UI = {
    accent = nil,                  -- e.g. '#ff7a1a'. nil keeps the UI's default accent colour
    currency = '$',
    closeKeys = { 'Escape', 'Tab' },
    hotbarMs = 3500,               -- how long the quick-slot bar stays up after using a slot
}

-- Trunk and glovebox sizes by vehicle class (GetVehicleClass). A size of 0 means "no storage".
Config.VehicleStorage = {
    default = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 35, trunkWeight = 60000 },
    [0]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 30, trunkWeight = 38000 },  -- Compacts
    [1]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 40, trunkWeight = 50000 },  -- Sedans
    [2]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 50, trunkWeight = 75000 },  -- SUVs
    [3]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 35, trunkWeight = 42000 },  -- Coupes
    [4]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 30, trunkWeight = 38000 },  -- Muscle
    [5]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 25, trunkWeight = 30000 },  -- Sports Classics
    [6]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 25, trunkWeight = 30000 },  -- Sports
    [7]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 25, trunkWeight = 30000 },  -- Super
    [8]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 15, trunkWeight = 15000 },  -- Motorcycles
    [9]  = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 35, trunkWeight = 60000 },  -- Off-road
    [12] = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 35, trunkWeight = 120000 }, -- Vans
    [13] = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 0,  trunkWeight = 0 },      -- Cycles
    [14] = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 50, trunkWeight = 120000 }, -- Boats
    [15] = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 50, trunkWeight = 120000 }, -- Helicopters
    [16] = { gloveboxSlots = 5, gloveboxWeight = 10000, trunkSlots = 50, trunkWeight = 120000 }, -- Planes
    [17] = { gloveboxSlots = 0, gloveboxWeight = 0,     trunkSlots = 0,  trunkWeight = 0 },      -- Service
    [18] = { gloveboxSlots = 4, gloveboxWeight = 10000, trunkSlots = 12, trunkWeight = 150000 }, -- Emergency
    [19] = { gloveboxSlots = 0, gloveboxWeight = 0,     trunkSlots = 0,  trunkWeight = 0 },      -- Military
    [20] = { gloveboxSlots = 0, gloveboxWeight = 0,     trunkSlots = 0,  trunkWeight = 0 },      -- Commercial
    [21] = { gloveboxSlots = 0, gloveboxWeight = 0,     trunkSlots = 0,  trunkWeight = 0 },      -- Trains
    [22] = { gloveboxSlots = 0, gloveboxWeight = 0,     trunkSlots = 0,  trunkWeight = 0 },      -- Open wheel
}

-- Vehicles whose trunk is at the front (engine in the back).
Config.BackEngineVehicles = {
    [`ninef`] = true, [`adder`] = true, [`vagner`] = true, [`t20`] = true, [`infernus`] = true,
    [`zentorno`] = true, [`reaper`] = true, [`comet2`] = true, [`comet3`] = true, [`jester`] = true,
    [`jester2`] = true, [`cheetah`] = true, [`cheetah2`] = true, [`prototipo`] = true, [`turismor`] = true,
    [`pfister811`] = true, [`ardent`] = true, [`nero`] = true, [`nero2`] = true, [`tempesta`] = true,
    [`vacca`] = true, [`bullet`] = true, [`osiris`] = true, [`entityxf`] = true, [`turismo2`] = true,
    [`fmj`] = true, [`re7b`] = true, [`tyrus`] = true, [`italigtb`] = true, [`italirsx`] = true,
    [`penetrator`] = true, [`monroe`] = true, [`ninef2`] = true, [`stingergt`] = true, [`surfer`] = true,
    [`surfer2`] = true, [`gp1`] = true, [`autarch`] = true, [`tyrant`] = true,
}
