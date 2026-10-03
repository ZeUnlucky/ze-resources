local QBCore = exports['qb-core']:GetCoreObject()
local infiAmmo = false
RegisterNetEvent("ze_toggleInfiAmmo")
AddEventHandler("ze_toggleInfiAmmo", function()
    infiAmmo = not infiAmmo
    if infiAmmo == true then
        ToggleInfiAmmo()
    end
end)

function ToggleInfiAmmo()
    Citizen.CreateThread(function()
        while infiAmmo do
            Citizen.Wait(0)
            local _p, wep = GetCurrentPedWeapon(PlayerPedId(), 1)
            SetAmmoInClip(PlayerPedId(), wep, 1000)
        end
    end)
end
