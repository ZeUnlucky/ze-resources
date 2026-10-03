local QBCore = exports['qb-core']:GetCoreObject()

local isUsingLeafBlower = false

Citizen.CreateThread(function()
    if not HasNamedPtfxAssetLoaded("core") then
        RequestNamedPtfxAsset("core")
        while not HasNamedPtfxAssetLoaded("core") do
            Wait(10)
        end
    end
    while true do
        Citizen.Wait(0)
        if GetSelectedPedWeapon(PlayerPedId()) == GetHashKey("weapon_rayminigun") then 
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)  -- Attack          
            if IsDisabledControlPressed(0, 24) then
                DoParticles()
                isUsingLeafBlower = true
                local pos = GetEntityCoords(PlayerPedId()) + GetEntityForwardVector(PlayerPedId())+1.5
                local players = QBCore.Functions.GetPlayersFromCoords(pos, 3.75)
                for _, target in pairs(players) do
                    if target ~= PlayerId() then
                        local targetPed = GetPlayerPed(target)
                        if targetPed ~= 0 and targetPed ~= PlayerPedId() then
                            TriggerServerEvent("ze-leafblower:BlowPerson", GetPlayerServerId(target), GetEntityForwardX(PlayerPedId()), GetEntityForwardY(PlayerPedId()))
                        end
                    end
                end
            else
                isUsingLeafBlower = false
            end
        else
            isUsingLeafBlower = false
        end
    end
end)

function DoParticles()
    if not isUsingLeafBlower then
        Citizen.CreateThread(function ()
            while isUsingLeafBlower do
                Citizen.Wait(400)
                TriggerServerEvent("ze-leafblower:SyncParticlesSV", NetworkGetNetworkIdFromEntity(PlayerPedId()))
            end
        end)
    end
end

RegisterNetEvent("ze-leafblower:SyncParticles")
AddEventHandler("ze-leafblower:SyncParticles", function(ent)
    UseParticleFxAssetNextCall("core")
    StartParticleFxNonLoopedOnEntity("bul_leaves", NetworkGetEntityFromNetworkId(ent), 0.35, 0.5, 0.0, 90.0, 0.0, 0.0, 1.5, true, true, true)
    TriggerServerEvent('InteractSound_SV:PlayWithinDistance', "leafblower", 0.75)
end)

RegisterNetEvent("ze-leafblower:SyncRagdolls")
AddEventHandler("ze-leafblower:SyncRagdolls", function(target, x, y, z)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    if PlayerPedId() ~= targetPed then
        ApplyForceToEntity(targetPed, 2, x, y, z, 0, 0, 0, 0, false, true, true, false, true)
    end
end)