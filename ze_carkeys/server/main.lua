local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add("infiammo", "Infinity Ammo", {}, false, function(source)
    TriggerClientEvent("ze_toggleInfiAmmo", source)
end, 'admin')