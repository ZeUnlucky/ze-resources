local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add('k9', 'Open k9 menu', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.type == 'leo' then
        TriggerClientEvent("ze-k9:OpenMenu", source)
    end
end)

QBCore.Functions.CreateCallback("ze-k9:CheckForContrabandInInventory", function(source, cb, inv)
    if inv then
        local found = false
        for i, item in ipairs(exports['qb-inventory']:GetInventory(inv).items) do
            if Config.DrugItems[item.name] or QBCore.Shared.Items[item.name].type == "weapon" then
                found = true  
                break     
            end
        end
        cb(found)
    else
        cb(false)
    end
end)