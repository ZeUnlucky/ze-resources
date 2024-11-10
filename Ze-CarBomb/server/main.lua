local QBCore = exports['qb-core']:GetCoreObject()


QBCore.Functions.CreateUseableItem('carbomb', function(source, item)
    TriggerClientEvent('ze-carbomb:plantBomb', source) 
end)

RegisterServerEvent("ze-carbomb:removeBomb", function()
    local xPlayer = QBCore.Functions.GetPlayer(source)
    xPlayer.Functions.RemoveItem(Config.BombItem, 1)
end)