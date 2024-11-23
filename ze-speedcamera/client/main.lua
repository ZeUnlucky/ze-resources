local QBCore = exports['qb-core']:GetCoreObject()

SpeedCameras = {}

RegisterNetEvent("ze-speedcamera:UpdateAllClients")
AddEventHandler("ze-speedcamera:UpdateAllClients", function(pos)
    table.insert(SpeedCameras, pos)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        for i, v in ipairs(SpeedCameras) do
            if GetDistanceBetweenCoords(v, GetEntityCoords(PlayerPedId()), false) < 10 then
                if IsPedInAnyVehicle(PlayerPedId(), false) then
                    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
                    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then
                        if GetEntitySpeed(veh) > 40 then
                            QBCore.Functions.Notify("Caught in HDMI", "error", 5000)
                        else
                            QBCore.Functions.Notify("next tiem", "success", 5000)
                        end
                    end
                end
            end
        end
    end
end)