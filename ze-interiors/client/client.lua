local QBCore = exports['qb-core']:GetCoreObject()

currentInterior = 0

Citizen.CreateThread(function()
    for id, v in ipairs(Config.Houses) do
        for entranceNum, entrance in ipairs(v.entrances) do
            exports['qb-target']:AddCircleZone(id.."entrance"..entranceNum, entrance, 2, {
                name = id.."entrance"..entranceNum,
                useZ = true
              }, {
                options = {
                  {
                    icon = "fas fa-door-" .. (v.locked and "close" or "open"),
                    label = "Enter House",
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:EnterInterior", id, entranceNum)
                    end,
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                  }
                },
                distance = 2.5
              })
        end
    end

    for id, v in ipairs(Config.Interiors) do
        for exitNum, exit in ipairs(v.exits) do
            exports['qb-target']:AddCircleZone(id.."exit"..exitNum, exit, 2, {
                name = id.."exit"..exitNum,
                useZ = true
              }, {
                options = {
                  {
                    icon = "fas fa-door-" .. (v.locked and "close" or "open"),
                    label = "Exit House",
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:ExitInterior", currentInterior, exitNum)
                    end,
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                  }
                },
                distance = 2.5
            })
        end
        exports['qb-target']:AddCircleZone(id.."stash", v.stash, 1, {
            name = id.."stash",
            useZ = true
          }, {
            options = {
              {
                icon = "fas fa-toolbox",
                label = "Open Stash",
                action = function(entity)
                    TriggerServerEvent("ze-interiors:OpenStash", currentInterior)
                end,
                drawDistance = 5.0,
                drawColor = {255, 255, 255, 255},
                successDrawColor = {0, 255, 0, 255}
              }
            },
            distance = 2.0
        })

        exports['qb-target']:AddCircleZone(id.."clothes", v.clothes, 1, {
            name = id.."clothes",
            useZ = true
          }, {
            options = {
              {
                icon = "fas fa-dresser",
                label = "Open Clothing",
                action = function(entity)

                end,
                drawDistance = 5.0,
                drawColor = {255, 255, 255, 255},
                successDrawColor = {0, 255, 0, 255}
              }
            },
            distance = 2.0
        })
    end
end)

RegisterNetEvent("ze-interiors:ChangeInterior", function(interior)
    currentInterior = interior
end)