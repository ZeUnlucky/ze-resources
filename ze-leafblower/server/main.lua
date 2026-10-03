local QBCore = exports['qb-core']:GetCoreObject()


RegisterServerEvent("ze-leafblower:BlowPerson")
AddEventHandler("ze-leafblower:BlowPerson", function(target, x, y)
    local targetPed = GetPlayerPed(target)
    SetPedToRagdoll(targetPed, 10000, 5000, 0, 0,0,0)
    Citizen.CreateThread(function()
        ApplyForceToEntity(targetPed, 2, x*Config.Force, y*Config.Force, GetEntityCoords(targetPed).z*5, 0, 0, 0, 0, false, true, true, false, true)
    end)
    TriggerClientEvent("ze-leafblower:SyncRagdolls", -1, target, x*Config.Force, y*Config.Force, GetEntityCoords(targetPed).z*5)
end)

RegisterServerEvent("ze-leafblower:SyncParticlesSV")
AddEventHandler("ze-leafblower:SyncParticlesSV", function(ent)
    TriggerClientEvent("ze-leafblower:SyncParticles", -1, ent)
end)
