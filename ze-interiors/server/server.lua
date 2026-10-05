local QBCore = exports['qb-core']:GetCoreObject()

-- Puts a player inside a house (or apartment) through one of its entrances. Returns true, or false and a text for the player
-- (false without a text when the house or the entrance does not exist).
function Houses.Enter(src, id, entrance)
    local house = Shared.Houses[id]
    if not house or not house.interior.exits[entrance] then return false end

    if house.locked then return false, "Can't enter, house is locked!" end

    SetEntityCoords(GetPlayerPed(src), house.interior.exits[entrance])
    SetEntityHeading(GetPlayerPed(src), house.interior.exits[entrance][4])
    SetPlayerRoutingBucket(src, Houses.Bucket(id))
    SetRoutingBucketPopulationEnabled(Houses.Bucket(id), false)
    TriggerClientEvent("ze-interiors:ChangeInterior", src, id)
    return true
end

RegisterServerEvent("ze-interiors:EnterInterior", function(id, entrance)
    local src = source
    local ok, err = Houses.Enter(src, id, entrance)
    if not ok and err then QBCore.Functions.Notify(src, err, "error", 5000) end
end)

RegisterServerEvent("ze-interiors:ExitInterior", function(id, exit)
    local house = Shared.Houses[id]
    if not house or not house.entrances[exit] then return end

    SetEntityCoords(GetPlayerPed(source), house.entrances[exit])
    SetEntityHeading(GetPlayerPed(source), house.entrances[exit][4])
    SetPlayerRoutingBucket(source, 0)
    TriggerClientEvent("ze-interiors:ChangeInterior", source, 0)
end)

RegisterServerEvent("ze-interiors:OpenStash", function(id)
    local src = source
    if Shared.Houses[id] then
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
    local src = source 
    local house = Shared.Houses[id]
    if house then
        local ok, err = Houses.SetLocked(id, not house.locked)
        if ok then
            QBCore.Functions.Notify(src, "House is now " .. (house.locked and "locked" or "unlocked"), "success", 5000)
        else
            QBCore.Functions.Notify(src, err, "error", 5000)
        end
    end
end)

RegisterServerEvent("ze-interiors:UnlockForcefully", function(id)
    local src = source 
    local house = Shared.Houses[id]
    if house then
        local ok, err = Houses.SetLocked(id, false)
        if ok then
            QBCore.Functions.Notify(src, "House is now breached!", "success", 5000)
        else
            QBCore.Functions.Notify(src, err, "error", 5000)
        end
    end
end)