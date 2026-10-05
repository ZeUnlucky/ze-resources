-- The floors and apartments menu of a building: the callbacks behind the Apartments option at the building's entrance.
-- The client opens it with ze-interiors:lobby:getBuilding and every button goes through ze-interiors:lobby:act.
-- Nothing the client says is trusted: both check that the player stands at the building's door, and `act` checks that the
-- action is one the player may do right now. Other tenants' names and citizenids are never sent.
local QBCore = exports['qb-core']:GetCoreObject()

local DOOR_DISTANCE = 6.0   -- how close to the building's entrance the player has to be

-- Callback that never leaves the client waiting: an error in `fn` still answers.
local function register(name, fn)
    QBCore.Functions.CreateCallback(name, function(source, cb, data)
        local ok, reply = pcall(fn, source, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[ze-interiors]^7 %s failed: %s'):format(name, tostring(reply)))
            reply = { ok = false, error = 'Something went wrong, try again' }
        end
        cb(reply)
    end)
end

-- True when the player stands at the building's entrance outside (not inside a house).
local function atDoor(source, building)
    if GetPlayerRoutingBucket(source) ~= 0 then return false end
    local here = GetEntityCoords(GetPlayerPed(source))
    local e = building.entrance
    return #(here - vector3(e.x, e.y, e.z)) <= DOOR_DISTANCE
end

-- What this player may do with an apartment right now. Locked: unlock with a key, breach as police, pick it with a lockpick.
-- Unlocked: enter, and lock it with a key.
local function actionsFor(player, id, house)
    local actions = {}
    local hasKey = Houses.HasKey(id, player.PlayerData.citizenid)
    if house.locked then
        if hasKey then actions[#actions + 1] = 'unlock' end
        if player.PlayerData.job.name == 'police' then actions[#actions + 1] = 'breach' end
        if player.Functions.GetItemByName('lockpick') then actions[#actions + 1] = 'lockpick' end
    else
        actions[#actions + 1] = 'enter'
        if hasKey then actions[#actions + 1] = 'lock' end
    end
    return actions
end

-- yours / key / free (nobody owns it) / taken (someone else does)
local function statusFor(player, id, house)
    local citizenid = player.PlayerData.citizenid
    if house.owner == citizenid then return 'yours' end
    if Houses.HasKey(id, citizenid) then return 'key' end
    if house.owner == '' then return 'free' end
    return 'taken'
end

-- { id, name, floors = { { floor, apartments = { { id, name, status, locked, actions } } } } }
-- Every floor of the building is in the list, also the ones without apartments.
local function packBuilding(player, id)
    local building = Shared.Buildings[id]
    local floors = {}
    for f = 1, building.floors do floors[f] = { floor = f, apartments = {} } end

    for houseId, house in pairs(Shared.Houses) do
        if house.building == id and floors[house.floor] then
            local list = floors[house.floor].apartments
            list[#list + 1] = {
                id = houseId,
                name = house.name,
                status = statusFor(player, houseId, house),
                locked = house.locked,
                actions = actionsFor(player, houseId, house),
            }
        end
    end
    for _, floor in ipairs(floors) do
        table.sort(floor.apartments, function(a, b)
            local an, bn = a.name:lower(), b.name:lower()
            if an ~= bn then return an < bn end
            return a.id < b.id
        end)
    end

    return { id = id, name = building.name, floors = floors }
end

-- data = { building = building id }. Reply: { ok, building?, error? }
register('ze-interiors:lobby:getBuilding', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    local id = tonumber(data.building)
    local building = id and Shared.Buildings[id]
    if not player or not building then return { ok = false, error = 'That building does not exist' } end
    if not atDoor(source, building) then return { ok = false, error = 'You are too far from the building' } end
    return { ok = true, building = packBuilding(player, id) }
end)

-- data = { house = apartment id, action = enter | lock | unlock | breach | lockpick }. Reply: { ok, message?, error? }
register('ze-interiors:lobby:act', function(source, data)
    local player = QBCore.Functions.GetPlayer(source)
    local id = tonumber(data.house)
    local house = id and Shared.Houses[id]
    local building = house and house.building and Shared.Buildings[house.building]
    if not player or not building then return { ok = false, error = 'That apartment does not exist' } end
    if not atDoor(source, building) then return { ok = false, error = 'You are too far from the building' } end

    local action = data.action
    local allowed = false
    for _, a in ipairs(actionsFor(player, id, house)) do
        if a == action then allowed = true end
    end
    if not allowed then return { ok = false, error = 'You cannot do that' } end

    if action == 'enter' then
        local ok, err = Houses.Enter(source, id, 1)
        if not ok then return { ok = false, error = err or 'You cannot enter that apartment' } end
        return { ok = true }
    end

    local locked = action == 'lock'
    local ok, err = Houses.SetLocked(id, locked)
    if not ok then return { ok = false, error = err } end

    local messages = {
        lock = '%s is now locked',
        unlock = '%s is now unlocked',
        breach = 'You breached the door of %s',
        lockpick = 'You picked the lock of %s',
    }
    return { ok = true, message = messages[action]:format(house.name) }
end)
