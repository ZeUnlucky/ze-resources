Config = {}

Config.Interiors = {
    [1] = {
        name = "Test",
        exits = {
            vector4(266.25, -1007.6, -101.0, 0.0),
            vector4(261.25, -994.5, -99.0, 0.0)
        },
        stash = vector3(265.9, -999.5, -99.0),
        clothes = vector3(259.75, -1004.0, -99.0)
    }
}

-- The houses live in the ze_houses table (ze_houses.sql). The server fills this in at start (server/houses.lua) and syncs it to the clients.
-- Config.Houses[id] = { name, interior, interiorId, entrances = { vector4 }, owner (citizenid or ""), keyholders = {}, locked }
Config.Houses = {}

Config.MenuCommand = "housemenu"
Config.Job = "realestate"