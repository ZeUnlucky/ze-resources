-- Keys: the owner of a house hands a key to a friend with /givekeys and takes it back with /takekeys.
-- They are commands, not part of the house manager menu.
--   /givekeys [player id] [house id]
--   /takekeys [player id | all] [house id]
-- The house id is optional. Without it the house is the one the owner is standing in or at the door of, or their only house.
-- The friend is saved in the keyholders column (Houses.AddKeyholder / RemoveKeyholders) and can lock and unlock the doors like the owner.
local QBCore = exports['qb-core']:GetCoreObject()

local GIVE_DISTANCE = 5.0   -- how close the friend has to stand to the owner
local DOOR_DISTANCE = 5.0   -- how close the owner has to be to an entrance for it to pick the house

local function notify(source, text, kind)
    TriggerClientEvent('QBCore:Notify', source, text, kind or 'primary', 5000)
end

-- The owner's house when no id was typed: the one they are inside, else the closest entrance of one of theirs, else their only house.
local function findHouse(source, citizenid)
    local inside = GetPlayerRoutingBucket(source) - 5000
    local house = Config.Houses[inside]
    if house and house.owner == citizenid then return inside end

    local here = GetEntityCoords(GetPlayerPed(source))
    local owned, ownedCount = nil, 0
    local nearest, nearestDistance = nil, DOOR_DISTANCE
    for id, h in pairs(Config.Houses) do
        if h.owner == citizenid then
            owned, ownedCount = id, ownedCount + 1
            for _, entrance in ipairs(h.entrances) do
                local distance = #(here - vector3(entrance.x, entrance.y, entrance.z))
                if distance <= nearestDistance then nearest, nearestDistance = id, distance end
            end
        end
    end

    if nearest then return nearest end
    if ownedCount == 1 then return owned end
    return nil, ownedCount
end

-- The house a command is about: the typed id, else findHouse. Tells the owner why when there is none and returns nil.
-- The owner check is on the server, so a typed id cannot be used on someone else's house.
local function resolveHouse(source, citizenid, typed)
    local id = tonumber(typed)
    if id then
        local house = Config.Houses[id]
        if not house then return notify(source, 'That house does not exist', 'error') end
        if house.owner ~= citizenid then return notify(source, 'You do not own that house', 'error') end
        return id
    end

    local found, ownedCount = findHouse(source, citizenid)
    if found then return found end
    if ownedCount and ownedCount > 1 then
        return notify(source, 'You own several houses: stand at one of them or add its id to the command', 'error')
    end
    return notify(source, 'You do not own a house', 'error')
end

QBCore.Commands.Add(Config.GiveKeyCmd, 'Give a friend a key to your house', {
    { name = 'id', help = 'Server ID of the player next to you' },
    { name = 'house', help = 'House id (only needed when you own several houses and are not at one of them)' },
}, false, function(source, args)
    local owner = QBCore.Functions.GetPlayer(source)
    if not owner then return end
    local citizenid = owner.PlayerData.citizenid

    local targetSource = tonumber(args[1])
    if not targetSource then return notify(source, 'Use /' .. COMMAND .. ' [player id]', 'error') end
    if targetSource == source then return notify(source, 'You already have the keys to your own house', 'error') end

    local target = QBCore.Functions.GetPlayer(targetSource)
    if not target then return notify(source, 'No player with that ID is online', 'error') end

    local id = resolveHouse(source, citizenid, args[2])
    if not id then return end
    local house = Config.Houses[id]

    -- handing over a key is done in person
    local near = GetEntityCoords(GetPlayerPed(source))
    local far = GetEntityCoords(GetPlayerPed(targetSource))
    if GetPlayerRoutingBucket(source) ~= GetPlayerRoutingBucket(targetSource) or #(near - far) > GIVE_DISTANCE then
        return notify(source, 'That player is too far away', 'error')
    end

    local ok, err = Houses.AddKeyholder(id, target.PlayerData.citizenid)
    if not ok then return notify(source, err, 'error') end

    local info = target.PlayerData.charinfo
    notify(source, ('You gave %s %s a key to %s'):format(info.firstname, info.lastname, house.name), 'success')
    notify(targetSource, ('You got a key to %s'):format(house.name), 'success')
end)

-- /takekeys [player id | all] [house id]: takes one friend's key back (the friend has to be online, but not nearby),
-- or every key of the house with "all", which is also how the key of a friend who is offline is revoked.
QBCore.Commands.Add(Config.TakeKeyCmd, 'Take back a key to your house', {
    { name = 'id', help = 'Server ID of the player, or "all" for every key' },
    { name = 'house', help = 'House id (only needed when you own several houses and are not at one of them)' },
}, false, function(source, args)
    local owner = QBCore.Functions.GetPlayer(source)
    if not owner then return end

    local who = args[1] and args[1]:lower()
    if not who then return notify(source, 'Use /' .. Config.TakeKeyCmd .. ' [player id | all]', 'error') end

    local targetSource, target
    if who ~= 'all' then
        targetSource = tonumber(who)
        target = targetSource and QBCore.Functions.GetPlayer(targetSource)
        if not target then return notify(source, 'No player with that ID is online (use "all" to take every key)', 'error') end
    end

    local id = resolveHouse(source, owner.PlayerData.citizenid, args[2])
    if not id then return end
    local house = Config.Houses[id]

    local removed, err = Houses.RemoveKeyholders(id, target and target.PlayerData.citizenid)
    if not removed then return notify(source, err, 'error') end

    if target then
        local info = target.PlayerData.charinfo
        notify(source, ('You took the key to %s from %s %s'):format(house.name, info.firstname, info.lastname), 'success')
        notify(targetSource, ('Your key to %s was taken back'):format(house.name), 'error')
    else
        notify(source, ('You took back %d key(s) to %s'):format(removed, house.name), 'success')
    end
end)
