
-- CODE --


local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {}

Citizen.CreateThread(function()
        Citizen.CreateThread(function()
           while QBCore == nil do
                QBCore = exports['qb-core']:GetCoreObject()
                Citizen.Wait(30)
           end
        end)
        while QBCore.Functions.GetPlayerData().job == nil do
            Citizen.Wait(10)
        end
        PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('ze-carbomb:plantBomb', function()
    local veh, dis = QBCore.Functions.GetClosestVehicle(GetEntityCoords(PlayerPedId()))
    if dis <= 5.0 then
        QBCore.Functions.Progressbar('PlantBomb', 'Planting Bomb..', 7500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
        }, 
        {
            animDict = "amb@medic@standing@kneel@idle_a",
            anim = "idle_a",
            flags = 0,
            task = nil,
        }, {}, {}, function()
            local pos = GetEntityCoords(veh)
            local pPos = GetEntityCoords(PlayerPedId())
            if GetDistanceBetweenCoords(pos, pPos, true)
            PlantTime(5, veh)
            TriggerServerEvent("ze-carbomb:removeBomb")
        end)
    end
end)


function CreateCarBombMenu()
    exports['qb-target']:AddGlobalVehicle({
        options = {
            {
                num = 1,
                action = function(entity)
                    local time = Input("Time", "Time in seconds")
                    QBCore.Functions.Progressbar('PlantBomb', 'Planting Bomb..', 7500, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                    }, 
                    {
                        animDict = "amb@medic@standing@kneel@idle_a",
                        anim = "idle_a",
                        flags = 0,
                        task = nil,
                    }, {}, {}, function()
                        TriggerServerEvent("ze-carbomb:removeBomb")
                        PlantTime(time, entity)
                    end)
                       
                end,
                label = "Plant By Time",
                icon = 'fas fa-clock',
                item = 'carbomb'
            },
            {
                num = 2,
                action = function(entity)
                    local distance = Input("Distance", "Distance in meters")
                    QBCore.Functions.Progressbar('PlantBomb', 'Planting Bomb..', 7500, false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true
                        }, 
                        {
                            animDict = "amb@medic@standing@kneel@idle_a",
                            anim = "idle_a",
                            flags = 0,
                            task = nil,
                        }, {}, {}, function()
                            TriggerServerEvent("ze-carbomb:removeBomb")
                            PlantDistance(GetEntityCoords(entity), distance, entity)
                        end)
                end,
                label = "Plant By Distance",
                icon = 'fas fa-road',
                item = 'carbomb'
            }, 
            {
                num = 3,
                action = function(entity)
                    local speed = Input("Speed", "Speed in KM/H")
                    QBCore.Functions.Progressbar('PlantBomb', 'Planting Bomb..', 7500, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                    }, 
                    {
                        animDict = "amb@medic@standing@kneel@idle_a",
                        anim = "idle_a",
                        flags = 0,
                        task = nil,
                    }, {}, {}, function()
                        TriggerServerEvent("ze-carbomb:removeBomb")
                        PlantSpeed(speed, entity)
                    end)
                end,
                label = "Plant By Speed",
                icon = 'fas fa-car',
                item = 'carbomb'
            },                   
            {
                num = 4,
                action = function(entity)
                    QBCore.Functions.Progressbar('PlantBomb', 'Planting Bomb..', 7500, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true
                    }, 
                    {
                        animDict = "amb@medic@standing@kneel@idle_a",
                        anim = "idle_a",
                        flags = 0,
                        task = nil,
                    }, {}, {}, function()
                        TriggerServerEvent("ze-carbomb:removeBomb")
                        PlantEntry(entity)
                    end)     
                end,
                label = "Plant By Entry",
                icon = 'fas fa-door-closed',
                item = 'carbomb'
            }
           
        },
        distance = 2.5
    })
end

Citizen.CreateThread(function()
    
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) 
        local veh, dis = QBCore.Functions.GetClosestVehicle(GetEntityCoords(PlayerPedId()))
        CreateCarBombMenu()
    end
end)

function PlantTime(time, veh)
    Citizen.CreateThread(function()
        Citizen.Wait(time*1000)
        AddExplosion(GetEntityCoords(veh), 2, 2.0, true, false, 4, false)
    end)
end

function PlantDistance(pos, distance, veh)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(100)
            if GetDistanceBetweenCoords(pos, GetEntityCoords(veh), true) >= tonumber(distance) then
                AddExplosion(GetEntityCoords(veh), 2, 2.0, true, false, 4, false)
                break
            end
        end
    end)
end

function PlantSpeed(speed, veh)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(100)
            if tonumber(GetEntitySpeed(veh)) * 3.6 >= tonumber(speed) then
                AddExplosion(GetEntityCoords(veh), 2, 2.0, true, false, 4, false)
                break
            end
        end
    end)
end

function PlantEntry(veh)
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(100)
            if GetPedInVehicleSeat(veh, -1) ~= 0 then
                AddExplosion(GetEntityCoords(veh), 2, 2.0, true, false, 4, false)
                break
            end
        end
    end)
end

function Input(type, head)
    local dialog = exports['qb-input']:ShowInput({
        header = head,
        submitText = "Submit",
        inputs = {
            {
                text = type, -- text you want to be displayed as a place holder
                name = type, -- name of the input should be unique otherwise it might override
                type = "number", -- type of the input
                isRequired = true, -- Optional [accepted values: true | false] but will submit the form if no value is inputted
            }
        }
    })
    return dialog[type]
end



