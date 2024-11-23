local QBCore = exports['qb-core']:GetCoreObject()

SpeedCameras = {}

QBCore.Functions.CreateUseableItem("speedcamera", function(source, item)
    local pos = GetEntityCoords(GetPlayerPed(source))
    local model = GetHashKey("prop_roadpole_01a")
    local entity = CreateObject(model, pos.x, pos.y, pos.z-1, true)
    FreezeEntityPosition(entity, true)

    exports['qb-inventory']:RemoveItem(source, item.name, 1, item.slot, 'ze-speedcamera:UsedSpeedCamera')

    table.insert(SpeedCameras, pos)
    TriggerClientEvent("ze-speedcamera:UpdateAllClients", -1, pos)
end)