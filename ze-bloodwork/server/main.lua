local QBCore = exports['qb-core']:GetCoreObject()


RegisterNetEvent("ze-bloodwork:Server:FinishedBloodwork", function(targetSrc)
    local Target = QBCore.Functions.GetPlayer(targetSrc)
    if Target then
        GivePlayerFullBloodbag(source, Target.PlayerData.metadata.bloodtype)
    end
end)

QBCore.Commands.Add('takeblood', 'Take my own blood! (DEBUG!)', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player.PlayerData.job.name == Config.Job then
        if exports['qb-inventory']:HasItem(source, Config.EmptyBloodBagItemName, 1) then
            GivePlayerFullBloodbag(source, Player.PlayerData.metadata["bloodtype"])
            TriggerClientEvent("ze-bloodwork:client:ChangeHealth", source, -Config.HealthChangeOnBloodWork)
        else
            QBCore.Functions.Notify(source, 'You don\'t have the required item!', 'error')
        end
    else
        QBCore.Functions.Notify(source, 'You don\'t have the required job!', 'error')
    end
end)

QBCore.Commands.Add('giveblood', 'Give nearby player blood', {{ name = 'id', help = 'Player ID' },  { name = 'bloodtype', help = 'The blood type to give' }}, false, function(source, args)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local target = QBCore.Functions.GetPlayer(tonumber(args[1]))
    if not target then return TriggerClientEvent('QBCore:Notify', src, "Couldn't find this player!", 'error') end

    local targetCoords = GetEntityCoords( GetPlayerPed(tonumber(args[1])))
    local bloodType = args[2]
    if #(playerCoords - targetCoords) > 5 then return TriggerClientEvent('QBCore:Notify', src, "You are too far!", 'error') end

    if Player.PlayerData.job.name == Config.Job then
        local foundItem = nil
        for i, v in pairs(Player.Functions.GetItemsByName(Config.FullBloodBagItemName)) do
            if v.info.Bloodtype == bloodType then
                foundItem = v
                break
            end
        end
        if foundItem then
            RemoveBloodBagWithType(target, foundItem.info.Bloodtype)
            TriggerClientEvent("ze-bloodwork:client:DoGetBloodProgbar", target.PlayerData.source, has_value(Config.BloodChart[target.PlayerData.metadata["bloodtype"]], foundItem.info.Bloodtype) and Config.HealthChangeOnBloodWork or -Config.HealthChangeOnBloodWork)
            if target ~= Player then
                TriggerClientEvent("ze-bloodwork:client:DoGiveBloodProgbar", Player.PlayerData.source)
            end
        else
            QBCore.Functions.Notify(source, 'You don\'t have the required item with the right bloodtype!', 'error')
        end
    else
        QBCore.Functions.Notify(source, 'You don\'t have the required job!', 'error')
    end
end)


function GivePlayerFullBloodbag(player, bloodtype)
    info = {
        Bloodtype = bloodtype
    }
    exports['qb-inventory']:AddItem(player, Config.FullBloodBagItemName , 1, false, info, 'ze-bloodworks:giveItem')
    exports['qb-inventory']:RemoveItem(player, Config.EmptyBloodBagItemName, 1)
end

function RemoveBloodBagWithType(target, bloodType)
    for _, v in pairs(target.PlayerData.items) do
        if v then
            if v.name == Config.FullBloodBagItemName and v.info.Bloodtype == bloodType then
                target.Functions.RemoveItem(v.name, 1, v.slot)
                break
            end
        end
    end
end

function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end