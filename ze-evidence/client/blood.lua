AddEventHandler("entityDamaged", function (victim, culprit, weapon, dmg)
    if IsEntityAPed(victim) and culprit ~= nil and weapon ~= nil and PlayerPedId() == victim then
        if not IsPedAPlayer(victim) or IsEntityOnFire(victim) then return end
            Citizen.CreateThread(function()
            local velocity = Shared.WeaponVelocity[weapon]
            if velocity ~= nil and not IsPedInAnyVehicle(victim, false) then
                if velocity >= 1 then
                    local hash = GetHashKey("p_bloodsplat_s")
                    local entityCoords = GetEntityCoords(victim)
                    local splatterID = CreateObject(hash, entityCoords.x, entityCoords.y, entityCoords.z-1.25, true, false, false)
                    local _, currentRoll, currentYaw = GetEntityRotation(splatterID, 2)
                    Citizen.Wait(100)
                    TriggerServerEvent("ze-evidence:CreateBloodSplatter", victim, NetworkGetNetworkIdFromEntity(splatterID), -90.0 , currentRoll, currentYaw)
                end
            end
        end)
    end
end)

RegisterNetEvent("ze-evidence:CreateSplatterMenu", function(splatter, DNA, newPitch, currentRoll, currentYaw)
    local splatterID = NetworkGetEntityFromNetworkId(splatter)
    SetEntityRotation(splatterID, newPitch, currentRoll, currentYaw, 2, true)
    exports['qb-target']:AddEntityZone("blood_splatter_"..splatterID, splatterID, {
        name = "blood_splatter_"..splatterID
    }, {
        options = {
            {
                num = 1,
                icon = "fas fa-droplet",
                label = "Collect Blood",
                action = function(entity)
                    TriggerServerEvent("ze-evidence:CollectSplatter", splatter, DNA, true)
                end,                        
                drawDistance = 10.0,
                drawColor = {200, 0, 0, 255},
                job = "police"
            },
            {
                num = 2,
                icon = "fas fa-toilet-paper",
                label = "Clean Blood",
                action = function(entity)
                    TriggerServerEvent("ze-evidence:CollectSplatter", splatter, DNA, false)
                end,                        
                drawDistance = 10.0,
                drawColor = {200, 0, 0, 255}
            }
        },
        distance = 3.0
    })
end)


RegisterNetEvent("ze-evidence:DeleteSplatterMenu", function(splatter)
    local splatterID = NetworkGetEntityFromNetworkId(splatter)
    DeleteEntity(splatterID)
    exports['qb-target']:RemoveZone("blood_splatter_"..splatterID)
end)
