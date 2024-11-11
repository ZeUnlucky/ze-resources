local QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPedShooting(PlayerPedId()) then
            Citizen.Wait(50)
            RequestModel("w_pi_flaregun_shell")
            while not HasModelLoaded("w_pi_flaregun_shell") do
                Wait(500)                
            end
            local pCoords = GetEntityCoords(PlayerPedId())

            local created_object = CreateObjectNoOffset("w_pi_flaregun_shell", pCoords.x+math.random(-1,1), pCoords.y+math.random(-1,1), pCoords.z, true, 0, 1)
            PlaceObjectOnGroundProperly(created_object)
            SetEntityHeading(created_object, GetEntityHeading(PlayerPedId()))
            FreezeEntityPosition(created_object, true)
            SetModelAsNoLongerNeeded("w_pi_flaregun_shell")
            NetworkRegisterEntityAsNetworked(created_object)
            Wait(1)
            entID = NetworkGetNetworkIdFromEntity(created_object)
            Wait(1)
            TriggerServerEvent("ze-evidence:RegisterNewCasing", entID, GetSelectedPedWeapon(PlayerPedId()))
            
            Citizen.Wait(5000)
        end
    end
end)

RegisterNetEvent("ze-evidence:RegisterNewCasingClient")
AddEventHandler("ze-evidence:RegisterNewCasingClient", function(casingId, serial)
    exports['qb-target']:AddEntityZone("casings"..casingId, NetworkGetEntityFromNetworkId(casingId), {
        name = "casings"..casingId,
    }, {
        options = {
            {
                num = 1,
                type = "client",
                label = "Collect Casing",
                action = function()
                    TriggerServerEvent("ze-evidence:CollectCasing", casingId)
                end,
                drawDistance = 10.0, 
                drawColor = {255, 0, 0, 0}, 
                successDrawColor = {30, 144, 255, 255},
            }
        },
        distance = 3
    })
end)


RegisterNetEvent("ze-evidence:debug:SendEntityIdToAll")
AddEventHandler("ze-evidence:debug:SendEntityIdToAll", function(entity)
    print(NetworkGetEntityFromNetworkId(entity))
end)

RegisterNetEvent("ze-evidence:RemoveCasingMenu")
AddEventHandler("ze-evidence:RemoveCasingMenu", function(casingId)
    exports['qb-target']:RemoveZone("casings".. casingId)
end)
