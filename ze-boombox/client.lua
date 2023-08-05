local QBCore = exports['qb-core']:GetCoreObject()
boomboxes = nil
local boomboxended = {} 
boombox = {
    ["boombox01"] = {
    ["model"] = "prop_boombox_01", ["bone"] = 28422, ["x"] = 0.2,["y"] = 0.0,["z"] = 0.0,["xR"] = -35.0,["yR"] = -100.0, ["zR"] = 0.0
}}


RegisterNetEvent('ze-boombox:placeBoombox')
AddEventHandler('ze-boombox:placeBoombox', function()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    local pos = GetEntityCoords(ped)
    local shouldPlace = true
    for _,v in ipairs(Config.NoMusicZones) do
        if GetDistanceBetweenCoords(pos, v, false) <= Config.NoMusicRadius then
            shouldPlace = false
            QBCore.Functions.Notify("Cant place here!", "error")
            TriggerServerEvent('ze-boombox:refundBoombox', 42)
            break
        end
    end
    if shouldPlace then
        local obj = CreateObject('prop_boombox_01', pos, true)
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityHeading(obj, GetEntityHeading(ped))
        print(obj)
        TriggerServerEvent("ze-boombox:updateIndexes", obj, pos)
        QBCore.Functions.Notify("Placed a boombox!", "success")
    end
end)

RegisterNetEvent('ze-boombox:playSong')
AddEventHandler('ze-boombox:playSong', function(name)
    if not name then return end
    xSound:setSoundDynamic(name, true)
	xSound:setVolumeMax(name, 0.3)
    xSound:destroyOnFinish(name, false)
    boomboxended[name] = false
    xSound:onPlayEnd(name, function()
        boomboxended[name] = true
    end)
end)

local function findByPos(pos) -- UC
    if boomboxes then
        for _, v in pairs(boomboxes) do
            if GetDistanceBetweenCoords(pos, v.Position.x, v.Position.y, v.Position.z, true) <= 2 then
                return v
            end
        end
    else
        return nil
    end
end

local function findByObject(obj) -- UC
    local pos = (GetEntityCoords(obj))
   return findByPos(pos)
end

RegisterNetEvent("ze-boombox:UpdateBoomboxes", function(booms)
    boomboxes = booms
end)

RegisterNetEvent("ze-boombox:setVolume", function(obj, vol)
    if obj.Playing then
        xSound:setVolumeMax(obj.ID, vol)
    end
end)

RegisterNetEvent("ze-boombox:setPosition", function(obj, pos)
    if not boomboxended[obj.ID] and obj.Playing then
        xSound:Position(obj.ID, pos)
    end
end)

exports['qb-target']:AddTargetModel("prop_boombox_01", {
    options = {
        {
            num = 1,
            action = function(entity)
                local dialog = exports['qb-input']:ShowInput({
                    header = "Music ID",
                    submitText = "Submit",
                    inputs = {
                        {
                            text = "YouTube Song ID", -- text you want to be displayed as a place holder
                            name = "YTID", -- name of the input should be unique otherwise it might override
                            type = "text", -- type of the input
                            isRequired = true, -- Optional [accepted values: true | false] but will submit the form if no value is inputted
                        }
                    }
                })
                if dialog ~= nil then
                    local ID = dialog["YTID"]
                    TriggerServerEvent('ze-boombox:playSong', ID, findByObject(entity))
                end
            end,
            icon = "fas fa-play",
            label = "Play song",
        },
        {
            num = 2,
            action = function(entity)
                TriggerServerEvent("ze-boombox:stopSong", findByObject(entity))
            end,
            icon = "fas fa-stop",
            label = "Stop Song",
        },
        {
            num = 3,
            action = function(entity)
                local dialog = exports['qb-input']:ShowInput({
                    header = "Volume amount",
                    submitText = "Submit",
                    inputs = {
                        {
                            text = "Volume", -- text you want to be displayed as a place holder
                            name = "YTVL", -- name of the input should be unique otherwise it might override
                            type = "number", -- type of the input
                            isRequired = true, -- Optional [accepted values: true | false] but will submit the form if no value is inputted
                        }
                    }
                })
                if dialog ~= nil then
                    local Vol = tonumber(dialog["YTVL"])
                    TriggerServerEvent("ze-boombox:changeVolume", findByObject(entity), Vol)
                end
            end,
            icon = "fas fa-volume-up",
            label = "Change Volume",
        },
        {
            num = 4,
            action = function(entity)
                local pos = GetEntityCoords(entity)
                SetEntityAsMissionEntity(entity)
                DeleteObject(entity)
                if not DoesEntityExist(entity) then
                    TriggerServerEvent("ze-boombox:pickupBoombox", findByPos(pos))
                    QBCore.Functions.Notify('Picked up the boombox!', 'success', 5000)
                else
                    QBCore.Functions.Notify('Can\'t pick up other\'s boomboxes!', 'error', 5000)
                end
            end,
            icon = "fas fa-hand-holding",
            label = "Pickup Boombox",
        },
        {
            num = 5,
            action = function(entity)
                local carried = true
                local bb = findByObject(entity)
                SetEntityAsMissionEntity(entity)
                DeleteObject(entity)
                if not DoesEntityExist(entity) then
                    Citizen.CreateThread(function()
                        local item = 'boombox01'
                        local attachModel = GetHashKey(boombox[item]["model"])
                        SetCurrentPedWeapon(PlayerPedId(), 0xA2719263)
                        local bone = GetPedBoneIndex(PlayerPedId(), boombox[item]["bone"])
                        RequestModel(attachModel)
                        while not HasModelLoaded(attachModel) do
                            Citizen.Wait(100)
                        end
                        attachedPropPerm = CreateObject(attachModel, 1.0, 1.0, 1.0, 1, 1, 0)
                        AttachEntityToEntity(attachedPropPerm, PlayerPedId(), bone, boombox[item]["x"], boombox[item]["y"], boombox[item]["z"], boombox[item]["xR"], boombox[item]["yR"], boombox[item]["zR"], 1, 1, 0, 0, 2, 1)
                        APPbone = bone
                        APPx = x
                        APPy = y
                        APPz = z
                        APPxR = xR
                        APPyR = yR
                        APPzR = zR
                        QBCore.Functions.Notify('Press '..Config.BoomboxButtonLabel..' to release the boombox', 'success', 5000)
                        local shouldBlockPlayWhileMoving = true
                        if bb and bb.Playing then
                            local pCount = 0
                            local players = {}
                            for i = 0, 2048 do
                                if NetworkIsPlayerActive(i) then
                                    table.insert(players, i)
                                end
                            end
                            local real_players = {}
                            for _,value in ipairs(players) do
                                local playerId = GetPlayerServerId(value)
                                local ignore = false
                                for _,subvalue in ipairs(real_players) do
                                    if playerId == subvalue then
                                        ignore = true
                                        break
                                    end
                                end
                                if ignore == false then
                                    table.insert(real_players, playerId)
                                    pCount = pCount + 1
                                end
                            end
                            if pCount > Config.MaxPlayersForMusicWhileTransfer then
                                QBCore.Functions.Notify('Sorry but the server is too busy to handle dynamic music position,<br>Music has been stopped.', 'info', 5000)
                                TriggerServerEvent("ze-boombox:stopSong", findByObject(entity))
                            else
                                shouldBlockPlayWhileMoving = false
                                local limitnet = 0
                                while carried do
                                    Citizen.Wait(1)
                                    limitnet = limitnet + 1
                                    local shouldNet = false
                                    if limitnet == Config.NetEventsLimitInMiliseconds then
                                        shouldNet = true
                                        limitnet = 0
                                    end
                                    local forceDrop = false
                                    local pos = GetEntityCoords(PlayerPedId())
                                    for _,v in ipairs(Config.NoMusicZones) do
                                        if GetDistanceBetweenCoords(pos, v, false) <= Config.NoMusicRadius then
                                            forceDrop = true
                                            break
                                        end
                                    end
                                    if IsControlJustReleased(0, Config.BoomboxButtonControlKey) or forceDrop then
                                        carried = false
                                        if forceDrop then
                                            if DoesEntityExist(attachedPropPerm) then
                                                DeleteEntity(attachedPropPerm)
                                            end
                                            TriggerServerEvent("ze-boombox:pickupBoombox", findByPos(pos))
                                            QBCore.Functions.Notify("Boombox returned, restricted area!", "error", 5000)
                                        else
                                            local obj = CreateObject('prop_boombox_01', pos, true)
                                            PlaceObjectOnGroundProperly(obj)
                                            FreezeEntityPosition(obj, true)
                                            if DoesEntityExist(attachedPropPerm) then
                                                DeleteEntity(attachedPropPerm)
                                            end
                                            SetEntityHeading(obj, GetEntityHeading(PlayerPedId()))
                                            TriggerServerEvent("ze-boombox:changePosition", bb, pos, obj)
                                            QBCore.Functions.Notify('You\'ve set the boombox down!', 'success', 5000)
                                        end
                                    else
                                        if shouldNet then TriggerServerEvent("ze-boombox:changePosition", bb, pos, nil) end
                                    end
                                end
                            end
                        end
                        if shouldBlockPlayWhileMoving then -- this will only ru when the server is busy or when the boombox isnt playing
                            while carried do
                                Citizen.Wait(1)
                                local forceDrop = false
                                local pos = GetEntityCoords(PlayerPedId())
                                for _,v in ipairs(Config.NoMusicZones) do
                                    if GetDistanceBetweenCoords(pos, v, false) <= Config.NoMusicRadius then
                                        forceDrop = true
                                        break
                                    end
                                end
                                if IsControlJustReleased(0, Config.BoomboxButtonControlKey) or forceDrop then
                                    carried = false
                                    if forceDrop then
                                        if DoesEntityExist(attachedPropPerm) then
                                            DeleteEntity(attachedPropPerm)
                                        end
                                        TriggerServerEvent("ze-boombox:pickupBoombox", findByPos(pos))
                                        QBCore.Functions.Notify("Boombox returned, restricted area!", "error", 5000)
                                    else
                                        local obj = CreateObject('prop_boombox_01', pos, true)
                                        PlaceObjectOnGroundProperly(obj)
                                        FreezeEntityPosition(obj, true)
                                        if DoesEntityExist(attachedPropPerm) then
                                            DeleteEntity(attachedPropPerm)
                                        end
                                        SetEntityHeading(obj, GetEntityHeading(PlayerPedId()))
                                        TriggerServerEvent("ze-boombox:changePosition", bb, pos, obj)
                                        QBCore.Functions.Notify('You\'ve set the boombox down!', 'success', 5000)
                                    end
                                end
                            end
                        end
                    end)
                else
                    QBCore.Functions.Notify('Can\'t pick up other\'s boomboxes!', 'error', 5000)
                end
            end,
            icon = "fas fa-luggage-cart",
            label = "Transfer Boombox",
        }
    },
    distance = 2.5
})
Citizen.CreateThread(function() -- UNOPTIMAL
    while true do
        Citizen.Wait(500)
        local coords = GetEntityCoords(PlayerPedId())
        local closestDistance = -1
        local object = GetClosestObjectOfType(coords, 20.0, GetHashKey('prop_boombox_01'), false, false, false)
        if DoesEntityExist(object) then
            local objCoords = GetEntityCoords(object)
            local distance  = GetDistanceBetweenCoords(coords, objCoords, true)
            if closestDistance == -1 or closestDistance > distance then
                closestDistance = distance
                closestEntity = object
            end
        end
        if closestDistance ~= -1 and closestDistance <= 3.0 then
            if lastEntity ~= closestEntity then
                closestEntity = object
                lastEntity = closestEntity
            end
        else
            if lastEntity then
                lastEntity = nil
            end
        end
    end
end)
