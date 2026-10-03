local QBCore = exports['qb-core']:GetCoreObject()


QBCore.Commands.Add("zemama", "Yo mama", {}, false, function(source)
    TriggerClientEvent("ZeMama-DoIt", source)
end, 'user')