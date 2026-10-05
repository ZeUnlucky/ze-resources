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

Config.Houses = {
    [1] = {
        name = "Test house",
        interior = Config.Interiors[1],
        entrances = {
            vector4(92.67, 49.22, 73.5, 73.0),
            vector4(104.5, 57.1, 73.57, 353.5)
        },
        owner = "",
        keyholders = {},
        locked = false
    }
}