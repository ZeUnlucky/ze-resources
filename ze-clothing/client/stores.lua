if ZE_DISABLED then return end

-- Where the menu can be opened: map blips, and either qb-target boxes or PolyZones with an [E] prompt
-- (Config.UseTarget, the same switch as qb-clothing).

local QBCore = exports['qb-core']:GetCoreObject()

local zoneName = nil      -- 'clothing' | 'barber' | 'surgeon' | 'outfit', or the index of a locker room
local inZone = false
local storesLoaded = false

local function playerData()
    return QBCore.Functions.GetPlayerData() or {}
end

local function roomGrade(room)
    local data = playerData()
    local owner = room.isGang and data.gang or data.job
    return owner and owner.grade and owner.grade.level or 0
end

-- ---------------------------------------------------------------------------------------------------------------
-- Blips
-- ---------------------------------------------------------------------------------------------------------------

local BLIPS = {
    clothing = { sprite = 366, colour = 47, label = 'store.clothing' },
    barber = { sprite = 71, colour = 0, label = 'store.barber' },
    surgeon = { sprite = 71, colour = 0, label = 'store.surgeon' },
}

CreateThread(function()
    for _, store in pairs(Config.Stores) do
        local b = BLIPS[store.shopType]
        if b then
            local blip = AddBlipForCoord(store.coords)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.colour)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(Lang:t(b.label))
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ---------------------------------------------------------------------------------------------------------------
-- qb-target
-- ---------------------------------------------------------------------------------------------------------------

local TARGET_SHOPS = {
    barber = { icon = 'fas fa-chair-office', label = 'store.barber' },
    clothing = { icon = 'fas fa-clothes-hanger', label = 'store.clothing' },
    surgeon = { icon = 'fas fa-scalpel', label = 'store.surgeon' },
}

local function loadTargets()
    for k, v in pairs(Config.Stores) do
        local t = TARGET_SHOPS[v.shopType]
        if t then
            local kind = v.shopType
            exports['qb-target']:AddBoxZone(kind .. k, v.coords, v.length, v.width, {
                name = kind .. k,
                debugPoly = false,
                minZ = v.coords.z - 1,
                maxZ = v.coords.z + 1,
            }, {
                options = {
                    {
                        type = 'client',
                        action = function() ZeClothing.Open(kind, nil) end,
                        icon = t.icon,
                        label = Lang:t(t.label),
                    },
                },
                distance = 3,
            })
        end
    end

    for k, room in pairs(Config.ClothingRooms) do
        if room.isGang or not QBCore.Shared.QBJobsStatus then
            local option = {
                type = 'client',
                action = function()
                    ZeClothing.OpenRoom(roomGrade(room), Config.Outfits[room.requiredJob], room.cameraLocation)
                end,
                icon = 'fas fa-sign-in-alt',
                label = Lang:t('menu.clothing'),
            }
            if room.isGang then option.gang = room.requiredJob else option.job = room.requiredJob end

            exports['qb-target']:AddBoxZone('clothing_' .. room.requiredJob .. k, room.coords, room.length, room.width, {
                name = 'clothing_' .. room.requiredJob .. k,
                debugPoly = false,
                minZ = room.coords.z - 2,
                maxZ = room.coords.z + 2,
            }, {
                options = { option },
                distance = 3,
            })
        end
    end

    for k, v in pairs(Config.OutfitChangers) do
        exports['qb-target']:AddBoxZone('OutfitChangers_' .. k, v.coords, v.length, v.width, {
            name = 'OutfitChangers_' .. k,
            debugPoly = false,
            minZ = v.coords.z - 1,
            maxZ = v.coords.z + 1,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'qb-clothing:client:openOutfitMenu',
                    icon = 'fas fa-sign-in-alt',
                    label = Lang:t('store.outfitchanger'),
                },
            },
            distance = 3,
        })
    end
end

-- ---------------------------------------------------------------------------------------------------------------
-- PolyZone
-- ---------------------------------------------------------------------------------------------------------------

local PROMPTS = {
    surgeon = 'store.surgeon',
    clothing = 'store.clothing',
    barber = 'store.barber',
    outfit = 'store.outfitchanger',
}

local function newBox(v, name)
    return BoxZone:Create(v.coords, v.length, v.width, {
        name = name,
        minZ = v.coords.z - 2,
        maxZ = v.coords.z + 2,
        debugPoly = false,
    })
end

local function loadZones()
    local zones, roomZones = {}, {}
    for _, v in pairs(Config.Stores) do
        zones[#zones + 1] = newBox(v, v.shopType)
    end
    for _, v in pairs(Config.OutfitChangers) do
        zones[#zones + 1] = newBox(v, v.shopType)
    end
    for k, v in pairs(Config.ClothingRooms) do
        roomZones[#roomZones + 1] = newBox(v, 'ClothingRooms_' .. k)
    end

    local shops = ComboZone:Create(zones, { name = 'clothingCombo', debugPoly = false })
    shops:onPlayerInOut(function(isPointInside, _, zone)
        if isPointInside then
            zoneName = zone.name
            inZone = true
            exports['qb-core']:DrawText('[E] - ' .. Lang:t(PROMPTS[zoneName] or 'store.clothing'), 'left')
        else
            inZone = false
            exports['qb-core']:HideText()
        end
    end)

    local rooms = ComboZone:Create(roomZones, { name = 'clothingRoomsCombo', debugPoly = false })
    rooms:onPlayerInOut(function(isPointInside, _, zone)
        if isPointInside then
            local zoneID = tonumber(QBCore.Shared.SplitStr(zone.name, '_')[2])
            local room = Config.ClothingRooms[zoneID]
            local data = playerData()
            local job = room.isGang and (data.gang and data.gang.name) or (not QBCore.Shared.QBJobsStatus and data.job and data.job.name)
            if job == room.requiredJob then
                zoneName = zoneID
                inZone = true
                exports['qb-core']:DrawText('[E] - ' .. Lang:t('store.room'), 'left')
            end
        else
            inZone = false
            exports['qb-core']:HideText()
        end
    end)

    CreateThread(function()
        while true do
            local sleep = 1000
            if inZone then
                sleep = 5
                if IsControlJustReleased(0, 38) then
                    if type(zoneName) == 'number' then
                        local room = Config.ClothingRooms[zoneName]
                        ZeClothing.OpenRoom(roomGrade(room), Config.Outfits[room.requiredJob], room.cameraLocation)
                    elseif zoneName == 'outfit' then
                        ZeClothing.OpenOutfits(nil)
                    elseif zoneName == 'surgeon' or zoneName == 'clothing' or zoneName == 'barber' then
                        ZeClothing.Open(zoneName, nil)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

-- Called when the player has loaded (and when this resource is restarted while they are in).
function ZeClothing.LoadStores()
    if storesLoaded then return end
    storesLoaded = true
    CreateThread(function()
        if Config.UseTarget then loadTargets() else loadZones() end
    end)
end
