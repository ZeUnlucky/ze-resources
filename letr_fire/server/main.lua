local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add("setfire", "Set a fire at your location", {}, false, function(source, args) 
    local fire = Config.fires[math.random(#Config.fires)]

    local players = QBCore.Functions.GetQBPlayers()
    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'fire' then       
            TriggerClientEvent('QBCore:Notify', v.PlayerData.source, fire.label)
        end
    end
    local firePositions = {}
    local distance = fire.distance

    for i = 1, fire.amount do
        table.insert(firePositions, vector3(fire.position.x + math.random(-distance.x, distance.x),fire.position.y + math.random(-distance.y, distance.y),fire.position.z + math.random(-distance.z, distance.z)))
    end
    TriggerClientEvent("letr_fire:StartFire", -1, firePositions, fire.shouldGround)
end, 'admin')

RegisterNetEvent("letr_fire:DeleteFireServer")
AddEventHandler("letr_fire:DeleteFireServer", function(hitPos)
    TriggerClientEvent("letr_fire:DeleteFireClient", -1, hitPos)
end)

RegisterNetEvent("letr_fire:SyncRopesServer")
AddEventHandler("letr_fire:SyncRopesServer", function(firetruck)
    TriggerClientEvent("letr_fire:SyncRopesClient", -1, firetruck, NetworkGetNetworkIdFromEntity(GetPlayerPed(source)))
end)

RegisterNetEvent("letr_fire:DeleteRopeServer")
AddEventHandler("letr_fire:DeleteRopeServer", function(rope)
    TriggerClientEvent("letr_fire:DeleteRopeClient", -1, rope)
end)