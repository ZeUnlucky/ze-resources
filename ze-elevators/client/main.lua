QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
    for _, p in pairs(Config.Elevators) do
        for i, v in ipairs(p["Floors"]) do
            exports['qb-target']:AddBoxZone("ze-elevator1" .. i.. p.Name, v.Button, 0.75, 0.75, {
                name = "ze-elevator1" .. i..p.Name,
                -- debugPoly = true,
                heading = v["h"],
                minZ = v.Button.z-1,
                maxZ = v.Button.z+1,
            }, {
                options = {
                    {
                        type = "client",
                        action = function(entity)
                            if IsPedAPlayer(entity) then return false end
                            TriggerEvent("ze-elevators:OpenElevatorMenu", i, p)
                        end,
                        icon = "fa fa-clipboard",
                        label = "Use Elevator",
                    }
                },
                distance = 1.0
            })
        end
    end
end)

RegisterNetEvent("ze-elevators:OpenElevatorMenu", function(floorNum, elevator)
    
    local ElevatorMenu = {
        {
            header = elevator.Name,
            icon = "fa-solid fa-bars",
            isMenuHeader = true, -- Set to true to make a nonclickable title
        },
    }
    local curFloor = false
    for i, v in ipairs(elevator.Floors) do
        curFloor = floorNum == i
        table.insert(ElevatorMenu, {
            header = v.Label,
            txt = v.Description,
            icon = "fa-solid fa-house",
            isMenuHeader = curFloor,
            params = {
                event = 'ze-elevators:ChooseFloor',
                args = {
                    floorChosen = elevator.Floors[i].Destination
                }
            }
        })
    end
    table.insert(ElevatorMenu, {
        header = "Close",
        icon = "fa-solid fa-angle-left",
    })
    exports['qb-menu']:openMenu(ElevatorMenu)
end) 

RegisterNetEvent("ze-elevators:ChooseFloor", function(destination)
    local dest = destination.floorChosen
    print(dest)
    local player = PlayerPedId()
    --local pos = GetEntityCoords(player)
    QBCore.Functions.Progressbar('elevators', 'Taking the elevator', 1500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
        }, {
            animDict = "gestures@f@standing@casual",
            anim = "gesture_point",
            flags = 0,
            task = nil,
        }, {}, {}, function()
            DoScreenFadeOut(1000)
            Citizen.Wait(1000)
            print(dest)
            SetEntityCoords(player, dest, true, false, false, false)
            DoScreenFadeIn(1000)
        end, function()
            -- This code runs if the progress bar gets cancelled
    end)
end)

function table_to_string(tbl)
    local result = "{"
    for k, v in pairs(tbl) do
        -- Check the key type (ignore any numerical keys - assume its an array)
        if type(k) == "string" then
            result = result.."[\""..k.."\"]".."="
        end

        -- Check the value type
        if type(v) == "table" then
            result = result..table_to_string(v)
        elseif type(v) == "boolean" then
            result = result..tostring(v)
        else
            result = result.."\""..v.."\""
        end
        result = result..","
    end
    -- Remove leading commas from the result
    if result ~= "" then
        result = result:sub(1, result:len()-1)
    end
    return result.."}"
end