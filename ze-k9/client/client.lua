local QBCore = exports['qb-core']:GetCoreObject()

local myDog = nil
local command = "Stay"

function SummonDog()
    if myDog then
        DeleteEntity(myDog)
        myDog = nil
        return
    end

    RequestModel(Config.K9Model)
    while not HasModelLoaded(Config.K9Model) do
        Wait(500)                
    end

    myDog = CreatePed(0, Config.K9Model, GetEntityCoords(PlayerPedId()), 0, true, false)

    while not DoesEntityExist(myDog) do 
        Wait(10) 
    end

    NetworkRequestControlOfEntity(myDog)
    AddRelationshipGroup("ZE_K9")
    local k9Group = GetHashKey("ZE_K9")
    local playerGroup = GetHashKey("PLAYER")
    SetRelationshipBetweenGroups(0, k9Group, playerGroup)
    SetRelationshipBetweenGroups(0, playerGroup, k9Group)
    SetPedRelationshipGroupHash(myDog, k9Group)

    SetBlockingOfNonTemporaryEvents(myDog, true)
    SetPedFleeAttributes(myDog, 0, false)
    SetPedCombatAbility(myDog, 0)
    SetPedCombatAttributes(myDog, 5, false)
    SetPedCombatAttributes(myDog, 46, false)
    SetPedCombatAttributes(myDog, 17, false)
    ChangeCommand("Follow")
    Citizen.CreateThread(function()
        while myDog do
            Citizen.Wait(0)
            SetEntityInvincible(myDog, true)
            SetPedAsEnemy(myDog, false)
            if IsPedInAnyVehicle(PlayerPedId(), true) and command ~= "Follow" then
                ChangeCommand("Follow")
            end
        end
    end)
   

    exports['qb-target']:AddTargetEntity(myDog,
    {
        options = {
            {
                num = 1,
                label = "Stay",
                action = function()
                    ChangeCommand("Stay")
                end,
                canInteract = function(entity)
                    return myDog == entity
                end,
                drawDistance = 10.0, 
                drawColor = {255, 165, 0, 0}, 
                successDrawColor = {30, 144, 255, 255},
            },
            {
                num = 2,
                label = "Follow",
                action = function()
                    ChangeCommand("Follow")
                end,
                canInteract = function(entity)
                    return myDog == entity
                end,
                drawDistance = 10.0, 
                drawColor = {255, 165, 0, 0}, 
                successDrawColor = {30, 144, 255, 255},
            }
        },
        distance = 5.0
    })
end


Citizen.CreateThread(function()
    exports['qb-target']:AddGlobalVehicle({
        options = {
          {
            icon = "fas fa-dog",
            label = "Sniff Car",
            action = function(entity)
              ChangeCommand("SniffCar", entity)
            end,
            canInteract = function(entity)
              return myDog
            end,
            job = { ["police"] = 0 }
          }
        },
        distance = 3.0
      })
end)


function ChangeCommand(cmd, args)
    if CommandToAction[cmd] ~= nil then
        command = cmd
        pcall(CommandToAction[cmd], args)
    end
end

function Stay()
    ClearPedTasks(myDog)
end

function FollowPlayer()
    Citizen.CreateThread(function()
        local lastSpeed = nil
        while DoesEntityExist(myDog) and command == "Follow" do
            if not NetworkHasControlOfEntity(myDog) then
                NetworkRequestControlOfEntity(myDog)
            end

            local playerPed = PlayerPedId()
            local dist = #(GetEntityCoords(myDog) - GetEntityCoords(playerPed))

            local speed = 1.0
            if dist > 15.0 then
                speed = 3.0
            elseif dist > 6.0 then
                speed = 2.0
            end

            local stalled = dist > 4.0 and GetEntitySpeed(myDog) < 0.1
            if speed ~= lastSpeed or stalled then
                TaskFollowToOffsetOfEntity(myDog, playerPed, 0.0, -1.0, 0.0, speed, -1, 2.0, true)
                SetPedKeepTask(myDog, true)
                lastSpeed = speed
            end
            Citizen.Wait(250)
        end
    end)
end

local isBarking = false

function BarkDog(duration)
    if isBarking or not myDog or not DoesEntityExist(myDog) then return end
    isBarking = true

    Citizen.CreateThread(function()
        local dict = "creatures@rottweiler@amb@world_dog_barking@idle_a"
        RequestAnimDict(dict)
        local timeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
            Citizen.Wait(10)
        end

        if not NetworkHasControlOfEntity(myDog) then
            NetworkRequestControlOfEntity(myDog)
        end
        ClearPedTasks(myDog)
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(myDog, dict, "idle_a", 8.0, -8.0, duration, 1, 0, false, false, false)
        end

        local endTime = GetGameTimer() + duration
        while GetGameTimer() < endTime and DoesEntityExist(myDog) do
            PlayAnimalVocalization(myDog, 3, "bark")
            Citizen.Wait(900)
        end

        if DoesEntityExist(myDog) then
            StopAnimTask(myDog, dict, "idle_a", 1.0)
            -- resume following if that was the active command
            if command == "Follow" then
                FollowPlayer()
            end
        end
        RemoveAnimDict(dict)
        isBarking = false
    end)
end

function SniffCar(veh)
    Citizen.CreateThread(function()
        if not NetworkHasControlOfEntity(myDog) then
            NetworkRequestControlOfEntity(myDog)
        end

        TaskGoToEntity(myDog,  veh, -1, 2.0, 2.0, 1073741824, 0)
        SetPedKeepTask(myDog, true)
        
        Citizen.Wait(3000)

        QBCore.Functions.TriggerCallback('ze-k9:CheckForContrabandInInventory', function(found)
            if found then
                BarkDog(5000)
                QBCore.Functions.Notify("Contraband has been alerted by the dog in the glovebox!", "success", 10000)
            else
                QBCore.Functions.Notify("Contraband has not been alerted by the dog in the glovebox!", "error", 10000)
            end
        end, "glovebox-"..GetVehicleNumberPlateText(veh))
        Citizen.Wait(500)
        QBCore.Functions.TriggerCallback('ze-k9:CheckForContrabandInInventory', function(found2)
            if found2 then
                BarkDog(5000)
                QBCore.Functions.Notify("Contraband has been alerted by the dog in the trunk!", "success", 10000)
            else
                QBCore.Functions.Notify("Contraband has not been alerted by the dog in the trunk!", "error", 10000)
            end
        end, "trunk-"..GetVehicleNumberPlateText(veh))
        ChangeCommand("Follow")
    end)
end

RegisterNetEvent("ze-k9:OpenMenu", function()
    local options =  {
        { 
            header = "K9 Menu", 
            icon = "fas fa-dog", 
            isMenuHeader = true,
            disabled = true,
        },
        { 
            header = "Spawn K9", 
            txt = "Spawn or despawn your K9",
            action = function()
                SummonDog()
            end
        }
    }

    if myDog then
        table.insert(options,    { 
            header = "Stay", 
            txt = "Stay at place.",
            action = function()
                ChangeCommand("Stay")
            end
        })

        table.insert(options,   { 
            header = "Follow Me", 
            txt = "Follow the player.",
            action = function()
                ChangeCommand("Follow")
            end
        })
    end
       
    exports['qb-menu']:openMenu(options, false, false)
end)

CommandToAction = {
    ["Stay"] = Stay,
    ["Follow"] = FollowPlayer,
    ["SniffCar"] = SniffCar,
    ["SniffArea"] = SniffArea
}