local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add("enterprop", "test", {}, false, function(source)
    SetEntityCoords(GetPlayerPed(source), Config.Interiors.Test.exits[1])
    SetEntityHeading(GetPlayerPed(source), Config.Interiors.Test.exits[1][4])
end)

QBCore.Commands.Add("exitprop", "test", {}, false, function(source)
    SetEntityCoords(GetPlayerPed(source), 82.0, 51.0, 73.0)
end)

RegisterServerEvent("ze-interiors:EnterInterior", function(id, entrance)
    SetEntityCoords(GetPlayerPed(source), Config.Houses[id].interior.exits[entrance])
    SetEntityHeading(GetPlayerPed(source), Config.Houses[id].interior.exits[entrance][4])
    SetPlayerRoutingBucket(source, id+5000)
    SetRoutingBucketPopulationEnabled(id+5000, false)
    TriggerClientEvent("ze-interiors:ChangeInterior", source, id)
end)

RegisterServerEvent("ze-interiors:ExitInterior", function(id, exit)
    SetEntityCoords(GetPlayerPed(source), Config.Houses[id].entrances[exit])
    SetEntityHeading(GetPlayerPed(source), Config.Houses[id].entrances[exit][4])
    SetPlayerRoutingBucket(source, 0)
    TriggerClientEvent("ze-interiors:ChangeInterior", source, 0)
end)

RegisterServerEvent("ze-interiors:OpenStash", function(id)
    local src = source
    if id > 0 then
        local stashID = "interiorStash"..id
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