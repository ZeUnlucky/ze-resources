local QBCore = exports['qb-core']:GetCoreObject()

SpawnedPets = {}

QBCore.Commands.Add("pet", "Summon a pet", {{name="type", help = "Which pet type to spawn (dog/cat)"}, {name="name", help = "The pet's name"}}, true, function(source, args)
    local type = Config.Types[table.remove(args, 1)]
    if not type then
        return print("Wrong type chosen")
    end
    local name = table.concat(args, " ")
    TriggerClientEvent("ze_pets:SpawnPet", source, type, name)
end, 'admin')

QBCore.Commands.Add("spawnobject", "Summon an object", {{name="type", help = "Which object to spawn"}}, true, function(source, args)
    TriggerClientEvent("ze_pets:SpawnObject", source, args[1])
end, 'admin')

QBCore.Functions.CreateCallback('ze_pets:GetAllPets', function(source, cb)
    cb(SpawnedPets)
end)

