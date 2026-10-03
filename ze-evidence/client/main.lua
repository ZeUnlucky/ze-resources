local QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
    exports['qb-target']:AddGlobalPlayer({
        options = {
          {
            icon = "fas fa-fingerprint",
            label = "Take Fingerprint",
            action = function(entity)
              TriggerServerEvent("ze-evidence:GetFingerprintFromPlayer", GetPlayerServerId(entity))
            end,
            canInteract = function(entity)
              return IsPedAPlayer(entity)
            end,
            job = { ["police"] = 0 },
            item = "pdfingerprinttape"
          }
        },
        distance = 2.5
      })

      for i, pos in ipairs(Config.LabLocations) do
        exports['qb-target']:AddCircleZone("forensicsLab"..i, pos, 3, {
            name = "forensicsLab"..i,
            debugPoly = false,
            useZ = true
          }, {
            options = {
              {

                event = "police:openArmory",
                icon = "fas fa-archive",
                label = "Open Armory",
                targeticon = "fas fa-gun",
                item = "police_badge",
                action = function(entity)
                  if IsPedAPlayer(entity) then return false end
                  TriggerEvent("police:openArmoryMenu", entity)
                end,
                canInteract = function(entity, distance, data)
                  return not IsPedAPlayer(entity)
                end,
                job = { ["police"] = 0, ["sheriff"] = 1 },
                gang = { ["thelostmc"] = 2 },
                citizenid = { ["JFD98238"] = true, ["HJS29340"] = true },
                drawDistance = 10.0,
                drawColor = {255, 255, 255, 255},
                successDrawColor = {0, 255, 0, 255}
              }
            },
            distance = 2.5
          })
      end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPedShooting(PlayerPedId()) then
            Citizen.Wait(50)
            print('[ze-evidence:debug] client: shot detected, requesting shell model')
            RequestModel(Config.ShellProp)
            while not HasModelLoaded(Config.ShellProp) do
                Wait(500)                
            end
            local pCoords = GetEntityCoords(PlayerPedId())

            local created_object = CreateObjectNoOffset(Config.ShellProp, pCoords.x+math.random(-1,1), pCoords.y+math.random(-1,1), pCoords.z, true, 0, 1)
            PlaceObjectOnGroundProperly(created_object)
            SetEntityHeading(created_object, GetEntityHeading(PlayerPedId()))
            FreezeEntityPosition(created_object, true)
            SetModelAsNoLongerNeeded(Config.ShellProp)
            NetworkRegisterEntityAsNetworked(created_object)
            Wait(1)
            local entID = NetworkGetNetworkIdFromEntity(created_object)
            Wait(1)
            print('[ze-evidence:debug] client: sending RegisterNewCasing, torso drawable=' .. GetPedDrawableVariation(PlayerPedId(), 3))
            TriggerServerEvent("ze-evidence:RegisterNewCasing", entID, GetSelectedPedWeapon(PlayerPedId()), GetEntityCoords(created_object), not Shared.ArmsWithoutGloves[GetEntityModel(PlayerPedId()) == `mp_m_freemode_01` and 'male' or 'female'][GetPedDrawableVariation(PlayerPedId(), 3)])
            Citizen.Wait(5000)
        end
    end
end)

AddEventHandler("entityDamaged", function (victim, culprit, weapon, dmg)
    if IsEntityAPed(victim) and culprit ~= nil and weapon ~= nil and PlayerPedId() == victim then
        if not IsPedAPlayer(victim) or IsEntityOnFire(victim) then return end
            Citizen.CreateThread(function()
            local velocity = WeaponVelocity[weapon]
            if velocity ~= nil and not IsPedInAnyVehicle(victim, false) then
                if velocity >= 1 then
                    local hash = GetHashKey("p_bloodsplat_s")
                    local entityCoords = GetEntityCoords(victim)
                    local splatterID = CreateObject(hash, entityCoords.x, entityCoords.y, entityCoords.z-1.25, true, false, false)
                    local _, currentRoll, currentYaw = GetEntityRotation(splatterID, 2)
                    Citizen.Wait(100)
                    TriggerServerEvent("ze-evidence:CreateBloodSplatter", victim, NetworkGetNetworkIdFromEntity(splatterID), -90.0 , currentRoll, currentYaw)
                end
            end
        end)
    end
end)

RegisterNetEvent("ze-evidence:RegisterNewCasingClient")
AddEventHandler("ze-evidence:RegisterNewCasingClient", function(casingId, serial)
    exports['qb-target']:AddEntityZone("casing"..casingId, NetworkGetEntityFromNetworkId(casingId), {
        name = "casing"..casingId,
    }, {
        options = {
            {
                num = 1,
                type = "client",
                label = "Collect Casing",
                action = function()
                    TriggerServerEvent("ze-evidence:CollectCasing", casingId)
                end,
                drawDistance = 10.0, 
                drawColor = {255, 0, 0, 0}, 
                successDrawColor = {30, 144, 255, 255},
            }
        },
        distance = 5.0
    })
end)


RegisterNetEvent("ze-evidence:RemoveCasingMenu")
AddEventHandler("ze-evidence:RemoveCasingMenu", function(casingId)
    exports['qb-target']:RemoveZone("casing".. casingId)
end)


RegisterNetEvent("ze-evidence:CreateSplatterMenu")
AddEventHandler("ze-evidence:CreateSplatterMenu", function(splatter, DNA, newPitch, currentRoll, currentYaw)
    Citizen.CreateThread(function()
        local splatterID = NetworkGetEntityFromNetworkId(splatter)
        SetEntityRotation(splatterID, newPitch, currentRoll, currentYaw, 2, true)
        exports['qb-target']:AddEntityZone("blood_splatter_"..splatterID, splatterID, {
            name = "blood_splatter_"..splatterID
        }, {
            options = {
                {
                    num = 1,
                    icon = "fas fa-droplet",
                    label = "Collect Blood",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:CollectSplatter", splatter, DNA, true)
                    end,                        
                    drawDistance = 10.0,
                    drawColor = {200, 0, 0, 255},
                    job = "police"
                },
                {
                    num = 2,
                    icon = "fas fa-toilet-paper",
                    label = "Clean Blood",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:CollectSplatter", splatter, DNA, false)
                    end,                        
                    drawDistance = 10.0,
                    drawColor = {200, 0, 0, 255}
                }
            },
            distance = 3.0
        })
    end)
end)

RegisterNetEvent("ze-evidence:DeleteSplatterMenu", function(splatter)
    local splatterID = NetworkGetEntityFromNetworkId(splatter)
    DeleteEntity(splatterID)
    exports['qb-target']:RemoveZone("blood_splatter_"..splatterID)
end)

RegisterNetEvent("ze-evidence:PlayerJoined", function(Splatters, Casings)
    Citizen.CreateThread(function()
        for i, v in ipairs(Splatters) do
            local hash = GetHashKey("p_bloodsplat_s")
            local splatterID = CreateObject(hash, v.position, false)
            FreezeEntityPosition(splatterID, true)
            Citizen.Wait(100)
            exports['qb-target']:AddEntityZone("blood_splatter_"..v.id, splatterID, {
                name = "blood_splatter_"..v.id
            }, {
                options = {
                    {
                        num = 1,
                        icon = "fas fa-droplet",
                        label = "Collect Blood",
                        action = function(entity)
                            TriggerServerEvent("ze-evidence:CollectSplatter", v.id, v.DNA, true)
                        end,                        
                        drawDistance = 10.0,
                        drawColor = {200, 0, 0, 255},
                        job = "police"
                    },
                    {
                        num = 2,
                        icon = "fas fa-toilet-paper",
                        label = "Clean Blood",
                        action = function(entity)
                            TriggerServerEvent("ze-evidence:CollectSplatter", v.id, v.DNA, false)
                        end,                        
                        drawDistance = 10.0,
                        drawColor = {200, 0, 0, 255}
                    }
                },
                distance = 3.0
            })
        end

        RequestModel(Config.ShellProp)
        while not HasModelLoaded(Config.ShellProp) do
            Wait(500)
        end
        for k, v in pairs(Casings) do
            local created_casing = CreateObjectNoOffset(Config.ShellProp, v.position, false)
            FreezeEntityPosition(created_casing, true)
            exports['qb-target']:AddEntityZone("casing".. v.id, created_casing, {
                name = "casing"..v.id,
            }, {
                options = {
                    {
                        num = 1,
                        type = "client",
                        label = "Collect Casing",
                        action = function()
                            TriggerServerEvent("ze-evidence:CollectCasing", v.id)
                            DeleteEntity(created_casing)
                        end,
                        drawDistance = 10.0, 
                        drawColor = {255, 0, 0, 0}, 
                        successDrawColor = {30, 144, 255, 255},
                    }
                },
                distance = 5.0
            })
        end
        SetModelAsNoLongerNeeded(Config.ShellProp)
    end)
end)


