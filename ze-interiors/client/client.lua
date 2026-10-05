local QBCore = exports['qb-core']:GetCoreObject()

currentInterior = 0

-- Config.Houses is filled by the server (server/houses.lua) with ze-interiors:SyncHouses / SyncHouse.
-- houseZones[id] = names of the qb-target zones of that house, so they can be removed when it changes.
local houseZones = {}

local function removeHouseZones(id)
    for _, name in ipairs(houseZones[id] or {}) do
        exports['qb-target']:RemoveZone(name)
    end
    houseZones[id] = nil
end

-- Map blips are local to each client, so a blip only exists for the player who owns the house (keyholders do not get one).
-- houseBlips[id] = blip handle; it sits on the first entrance.
local houseBlips = {}

local function removeHouseBlip(id)
    if houseBlips[id] then
        RemoveBlip(houseBlips[id])
        houseBlips[id] = nil
    end
end

local function addHouseBlip(id)
    removeHouseBlip(id)

    local house = Config.Houses[id]
    if not house or house.owner == '' or house.owner ~= QBCore.Functions.GetPlayerData().citizenid then return end

    local door = house.entrances[1]
    local blip = AddBlipForCoord(door.x, door.y, door.z)
    SetBlipSprite(blip, 40)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(house.name)
    EndTextCommandSetBlipName(blip)
    houseBlips[id] = blip
end

-- Rebuilds every blip: for when the character changes (loaded or logged out) and the owner of each house has to be compared again.
local function refreshHouseBlips()
    for id in pairs(houseBlips) do
        removeHouseBlip(id)
    end
    for id in pairs(Config.Houses) do
        addHouseBlip(id)
    end
end

RegisterNetEvent("QBCore:Client:OnPlayerLoaded", refreshHouseBlips)
RegisterNetEvent("QBCore:Client:OnPlayerUnload", function()
    for id in pairs(houseBlips) do
        removeHouseBlip(id)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(houseBlips) do
        removeHouseBlip(id)
    end
end)

-- The owner and anyone they gave a key to (/givekeys).
local function hasKey(house)
    local citizenid = QBCore.Functions.GetPlayerData().citizenid
    if house.owner == citizenid then return true end
    for _, holder in ipairs(house.keyholders) do
        if holder == citizenid then return true end
    end
    return false
end

local function addHouseZones(id)
    local v = Config.Houses[id]
    if not v then return end

    houseZones[id] = {}
    for entranceNum, entrance in ipairs(v.entrances) do
        local zoneName = id.."entrance"..entranceNum
        exports['qb-target']:AddCircleZone(zoneName, entrance, 2, {
            name = zoneName,
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
                },
                {
                    icon = "fas fa-lock",
                    label = "Lock Doors",
                    canInteract = function()
                        local house = Config.Houses[id]
                        return house ~= nil and not house.locked and hasKey(house)
                    end,
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:ToggleLock", id)
                    end,
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-lock-open",
                    label = "Unlock Doors",
                    canInteract = function()
                        local house = Config.Houses[id]
                        return house ~= nil and house.locked and hasKey(house)
                    end,
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:ToggleLock", id)
                    end,
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-unlock",
                    label = "Breach Door",
                    canInteract = function()
                        local house = Config.Houses[id]
                        return house ~= nil and house.locked
                    end,
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:UnlockForcefully", id)
                    end,
                    job = { ["police"] = 0 },
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-unlock",
                    label = "Lockpick Door",
                    canInteract = function()
                        local house = Config.Houses[id]
                        return house ~= nil and house.locked
                    end,
                    action = function(entity)
                        TriggerServerEvent("ze-interiors:UnlockForcefully", id)
                    end,
                    item = "lockpick",
                    drawDistance = 5.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                }
            },
            distance = 2.5
          })
        houseZones[id][#houseZones[id] + 1] = zoneName
    end
end

-- One house as the server packs it (Houses.Pack): the entrances come as { x, y, z, w } and become vector4 again.
local function setHouse(data)
    local entrances = {}
    for i, e in ipairs(data.entrances) do
        entrances[i] = vector4(e.x + 0.0, e.y + 0.0, e.z + 0.0, e.w + 0.0)
    end

    Config.Houses[data.id] = {
        name = data.name,
        interior = Config.Interiors[data.interior],
        interiorId = data.interior,
        entrances = entrances,
        owner = data.owner,
        keyholders = data.keyholders or {},
        locked = data.locked
    }
    addHouseZones(data.id)
    addHouseBlip(data.id)
end

-- Every house, on start. Replaces what the client had.
RegisterNetEvent("ze-interiors:SyncHouses", function(list)
    for id in pairs(houseZones) do
        removeHouseZones(id)
    end
    for id in pairs(houseBlips) do
        removeHouseBlip(id)
    end
    Config.Houses = {}
    for _, data in ipairs(list) do
        setHouse(data)
    end
end)

-- One house that was created, sold, locked, unlocked or deleted (data is nil when it is gone).
RegisterNetEvent("ze-interiors:SyncHouse", function(id, data)
    removeHouseZones(id)
    removeHouseBlip(id)
    Config.Houses[id] = nil
    if data then setHouse(data) end
end)

Citizen.CreateThread(function()
    TriggerServerEvent("ze-interiors:RequestHouses")

    for id, v in ipairs(Config.Interiors) do
        for exitNum, exit in ipairs(v.exits) do
            exports['qb-target']:AddCircleZone(id.."exit"..exitNum, exit, 2, {
                name = id.."exit"..exitNum,
                useZ = true
              }, {
                options = {
                    {
                        icon = "fas fa-door-open",
                        label = "Exit House",
                        action = function(entity)
                            TriggerServerEvent("ze-interiors:ExitInterior", currentInterior, exitNum)
                        end,
                        drawDistance = 5.0,
                        drawColor = {255, 255, 255, 255},
                        successDrawColor = {0, 255, 0, 255}
                    },
                   
                    {
                        icon = "fas fa-lock",
                        label = "Lock Doors",
                        canInteract = function()
                            local house = Config.Houses[currentInterior]
                            return house ~= nil and not house.locked
                        end,
                        action = function(entity)
                            TriggerServerEvent("ze-interiors:ToggleLock", currentInterior)
                        end,
                        drawDistance = 5.0,
                        drawColor = {255, 255, 255, 255},
                        successDrawColor = {0, 255, 0, 255}
                    },
                    {
                        icon = "fas fa-lock-open",
                        label = "Unlock Doors",
                        canInteract = function()
                            local house = Config.Houses[currentInterior]
                            return house ~= nil and house.locked
                        end,
                        action = function(entity)
                            TriggerServerEvent("ze-interiors:ToggleLock", currentInterior)
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
