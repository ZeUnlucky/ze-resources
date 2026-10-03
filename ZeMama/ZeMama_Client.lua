local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent("ZeMama-DoIt")
AddEventHandler("ZeMama-DoIt", function()
    local pos = GetEntityCoords(PlayerPedId())
    RequestModel("u_f_o_carol")
    while not HasModelLoaded("u_f_o_carol") do
        Citizen.Wait(100)
    end
    local Mama = CreatePed(1, "u_f_o_carol", pos.x, pos.y, pos.z + 10, 0.0, true)
    QBCore.Functions.Notify("Watch out!", "error")
end, 'user')