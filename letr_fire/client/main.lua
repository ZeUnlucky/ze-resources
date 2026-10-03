local QBCore = exports['qb-core']:GetCoreObject()
local clientFires = {}
local myRope = -1
local dict = "core"
local particle = "water_cannon_jet"

RegisterNetEvent("letr_fire:StartFire")
AddEventHandler("letr_fire:StartFire", function(firePositions, shouldGround)
    for i, v in ipairs(firePositions) do
        local groundZ = v.z
        if shouldGround then
            success, groundZ = GetGroundZFor_3dCoord(v.x, v.y, v.z, true)
        end
        newV = vector3(v.x, v.y, groundZ)
        local fireID = StartScriptFire(newV, 25, false)
        clientFires[""..fireID] = newV
    end
    
    if QBCore.Functions.GetPlayerData().job.name == "fire" then
        SetNewWaypoint(firePositions[1].x, firePositions[1].y)
    end
end)

CreateThread(function()
    exports['qb-target']:AddTargetModel({"FIRETRUK"}, {
        options = {
            {
                num = 1,
                icon = "fas fa-fire-extinguisher",
                label = "Use Hose",
                canInteract = function(entity, distance, data)
                    return myRope == -1
                end,
                action = function(entity)
                    TriggerServerEvent("letr_fire:SyncRopesServer", NetworkGetNetworkIdFromEntity(entity))
                end,        
                job = { ["fire"] = 0 },
            }, 
            {
                num = 2,
                icon = "fas fa-fire-extinguisher",
                label = "Return Hose",
                canInteract = function(entity, distance, data)
                    return myRope ~= -1
                end,
                action = function(entity)
                    TriggerServerEvent("letr_fire:DeleteRopeServer", myRope)
                    myRope = -1
                end,        
                job = { ["fire"] = 0 },
            }
        },
        distance = 3.5
    })
end)

RegisterNetEvent("letr_fire:SyncRopesClient")
AddEventHandler("letr_fire:SyncRopesClient", function(firetruck, entityB)
    CreateThread(function()
        if not RopeAreTexturesLoaded() then
            RopeLoadTextures()
            while not RopeAreTexturesLoaded() do
                Wait(0)
            end
        end
    end)
    firetruck = NetworkGetEntityFromNetworkId(firetruck)
    entityB = NetworkGetEntityFromNetworkId(entityB)
    local posA = GetEntityCoords(firetruck)
    local posB = GetEntityCoords(entityB)

    local rope = AddRope(posA, 0, 0, 0, GetDistanceBetweenCoords(posB, posA, true), 1, 10.0, 0.0, 1.0, false, true, false, 1.0, false, 0)
    if not DoesRopeExist(rope) then
        cleanup_rope_textures()
        return
    end
    LoadRopeData(rope, "ropeFamily3")
    AttachEntitiesToRope(rope, firetruck, entityB, posA, posB, 50.0, 1, 1)
    
    if entityB == PlayerPedId() then
        myRope = rope
    end
end)

RegisterNetEvent("letr_fire:DeleteRopeClient")
AddEventHandler("letr_fire:DeleteRopeClient", function(rope)
    DeleteRope(rope)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        for k, v in pairs(clientFires) do
            clientFires[""..StartScriptFire(v, 25, false)] = v
        end

    end
end)

Citizen.CreateThread(function()
    RequestNamedPtfxAsset(dict)
    while not HasNamedPtfxAssetLoaded(dict) do
         Citizen.Wait(0)
    end
    local pressed = false
    local particleEffect = nil
    while true do
        Citizen.Wait(0)
        if (IsDisabledControlJustReleased(0, 24) or IsControlJustReleased(0, 24)) and pressed and myRope ~= nil then
            StopParticleFxLooped(particleEffect, 0)
            pressed = false
        elseif myRope ~= -1 and (IsControlJustPressed(0, 24) or IsDisabledControlPressed(0, 24)) and not pressed then
            pressed = true
            UseParticleFxAssetNextCall(dict)
            particleEffect = StartParticleFxLoopedOnEntity(particle, PlayerPedId(), 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 1.25, false, false, false)
        end

        if myRope ~= -1 then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 24, true)
            if pressed then
                DeleteHitFires(GetEntityCoords(PlayerPedId()), GetEntityForwardVector(PlayerPedId()))
                SetParticleFxLoopedOffsets(particleEffect, 0.0, 0.0, 0.0, GetGameplayCamRelativePitch(), 0.0, 0.0)--GetEntityHeading(PlayerPedId()))
            end
        end
    end
end)

function DeleteHitFires(startCoords, direction)
        local hitPos = startCoords + direction*2
        TriggerServerEvent("letr_fire:DeleteFireServer", hitPos)
end

RegisterNetEvent("letr_fire:DeleteFireClient")
AddEventHandler("letr_fire:DeleteFireClient", function(hitPos)
    local hit, firePos = GetClosestFirePos(hitPos)
    if GetDistanceBetweenCoords(firePos, hitPos, true) < 1.0 then
        if hit then
            for k, v in pairs(clientFires) do
                if GetDistanceBetweenCoords(firePos, v, true) < 0.25 then
                    RemoveScriptFire(tonumber(k))
                    clientFires[k] = nil
                    break
                end
            end
        end
    end
end)