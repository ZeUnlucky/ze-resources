Config = {}
Config.Job = "ambulance"
Config.UseBloodType = true

Config.HealthChangeOnBloodWork = 50

Config.EmptyBloodBagItemName = "emptybloodbag"
Config.FullBloodBagItemName = "fullbloodbag"

Config.BloodChart = {
    ["A+"] = {"A+", "A-", "O+", "O-"},
    ["O+"] = {"O+", "O-"},
    ["B+"] = {"B+", "B-", "O+", "O-"},
    ["AB+"] = {"A+", "A-", "O+", "O-", "AB+", "AB-", "B+", "B-"},
    ["A-"] = {"A-", "O-"},
    ["O-"] = {"O-"},
    ["B-"] = {"B-", "O-"},
    ["AB-"] = {"AB-", "A-", "B-", "O-"}
}

