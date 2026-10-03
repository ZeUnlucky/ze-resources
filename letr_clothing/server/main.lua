local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add("zshirt", "Change shirt", {{name="shirt", help = "shirt to put on"}}, true, function(source, args)
    SetPedComponentVariation(GetPlayerPed(source), 8, tonumber(table.remove(args, 1)), 0, 0)
end)