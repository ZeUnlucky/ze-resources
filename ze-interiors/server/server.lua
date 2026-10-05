local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add("enterprop", "test", {}, false, function(source)
    SetEntityCoords(GetPlayerPed(source), Config.Interiors.Test.exits[1])
    SetEntityHeading(GetPlayerPed(source), Config.Interiors.Test.exits[1][4])
end)

QBCore.Commands.Add("exitprop", "test", {}, false, function(source)
    SetEntityCoords(GetPlayerPed(source), 82.0, 51.0, 73.0)
end)

RegisterServerEvent("ze-interiors:EnterInterior", function(id, entrance)
    local house = Config.Houses[id]
    -- the house can be gone (deleted while the client still had its door) or the entrance number can be wrong
    if not house or not house.interior.exits[entrance] then return end

    if house.locked then
        QBCore.Functions.Notify(source, "Can't enter, house is locked!", "error", 5000)
    else
        SetEntityCoords(GetPlayerPed(source), house.interior.exits[entrance])
        SetEntityHeading(GetPlayerPed(source), house.interior.exits[entrance][4])
        SetPlayerRoutingBucket(source, Houses.Bucket(id))
        SetRoutingBucketPopulationEnabled(Houses.Bucket(id), false)
        TriggerClientEvent("ze-interiors:ChangeInterior", source, id)
    end
end)

RegisterServerEvent("ze-interiors:ExitInterior", function(id, exit)
    local house = Config.Houses[id]
    if not house or not house.entrances[exit] then return end

    SetEntityCoords(GetPlayerPed(source), house.entrances[exit])
    SetEntityHeading(GetPlayerPed(source), house.entrances[exit][4])
    SetPlayerRoutingBucket(source, 0)
    TriggerClientEvent("ze-interiors:ChangeInterior", source, 0)
end)

RegisterServerEvent("ze-interiors:OpenStash", function(id)
    local src = source
    if Config.Houses[id] then
        local stashID = Houses.StashId(id)
        if not exports['qb-inventory']:GetInventory(stashID) then
            exports['qb-inventory']:CreateInventory(stashID, {
                label = "House Stash",
                maxweight = 100000,
                slots = 50
            })
        end
        exports['qb-inventory']:OpenInventory(src, stashID)
    end
end)

RegisterServerEvent("ze-interiors:ToggleLock", function(id)
    local src = source -- the database call yields, and `source` is not reliable after that
    local house = Config.Houses[id]
    if house then
        local ok, err = Houses.SetLocked(id, not house.locked)
        if ok then
            QBCore.Functions.Notify(src, "House is now " .. (house.locked and "locked" or "unlocked"), "success", 5000)
        else
            QBCore.Functions.Notify(src, err, "error", 5000)
        end
    end
end)