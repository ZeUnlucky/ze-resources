-- House manager menu, server side: the command, the permission check and the callbacks behind the NUI.
-- The houses themselves are loaded, saved and synced in server/houses.lua. The UI contract is in README.md.
local QBCore = exports['qb-core']:GetCoreObject()

-- QBCore permission group that gets the command. The callbacks below write to the database, so they stay gated too.

QBCore.Commands.Add(Config.MenuCommand, 'Open the house manager', {}, false, function(source)
    if QBCore.Functions.GetPlayer(source).PlayerData.job.name == Config.Job then
        TriggerClientEvent('ze-interiors:menu:open', source)
    end
end)

-- Whoever may run the command may use the menu. This asks for the command's own ACE instead of QBCore's 'admin' one:
-- a player in group.admin (add_ace group.admin command allow) can run commands without being in qbcore.admin.
local function allowed(source)
    return IsPlayerAceAllowed(source, 'command.' .. Config.MenuCommand)
end

-- Registers a callback that only answers players who may use the menu. `denied` is what everyone else gets.
-- `fn(source, data)` returns the reply; if it errors the UI still gets an answer instead of waiting forever.
local function register(name, denied, fn)
    QBCore.Functions.CreateCallback(name, function(source, cb, data)
        if not allowed(source) then return cb(denied) end

        local ok, reply = pcall(fn, source, data)
        if not ok then
            print(('^1[ze-interiors]^7 %s failed: %s'):format(name, tostring(reply)))
            reply = { ok = false, error = 'Something went wrong on the server, see the console' }
        end
        cb(reply)
    end)
end

local NO_PERMISSION = { ok = false, error = 'No permission' }

-- A number the UI sent, or nil when it is missing, not a number, or not finite.
local function number(v)
    v = tonumber(v)
    if v and v == v and v ~= math.huge and v ~= -math.huge then return v end
    return nil
end

-- ---------------------------------------------------------------- data for the UI

-- { { id, name, exits = number of exits } }
local function buildInteriors()
    local list = {}
    for id, interior in pairs(Config.Interiors) do
        list[#list + 1] = { id = id, name = interior.name, exits = #interior.exits }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- { { id, name, interior = interior id, interiorName, entrances = number of entrances, entranceList = { {exit, x, y, z, w} },
--     exits = number of exits of its interior, owner, ownerName, locked, keyholders = { {citizenid, name} } } }
-- `owner` is the citizenid ('' when nobody owns the house). The UI shows `ownerName` when there is one, else `owner`.
local function buildHouses()
    local names = Houses.OwnerNames()
    local list = {}
    for id, house in pairs(Shared.Houses) do
        local entranceList = {}
        for exit, e in pairs(house.entrances) do
            entranceList[#entranceList + 1] = { exit = exit, x = e.x, y = e.y, z = e.z, w = e.w }
        end
        table.sort(entranceList, function(a, b) return a.exit < b.exit end)
        local keyholders = {}
        for _, holder in ipairs(house.keyholders) do
            keyholders[#keyholders + 1] = { citizenid = holder, name = names[holder] }
        end
        list[#list + 1] = {
            id = id,
            name = house.name,
            keyholders = keyholders,
            interior = house.interiorId,
            interiorName = house.interior.name,
            entrances = #entranceList,
            entranceList = entranceList,   -- the coordinates, for the edit form
            exits = #house.interior.exits,
            owner = house.owner,
            ownerName = names[house.owner],
            locked = house.locked,
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- Called when the menu opens and again after every change. Answers nothing without permission.
register('ze-interiors:menu:getData', nil, function()
    return { interiors = buildInteriors(), houses = buildHouses() }
end)

-- Shows the buyer's name under the Player ID field. data = { id = server id }
register('ze-interiors:menu:lookupPlayer', NO_PERMISSION, function(_, data)
    local id = type(data) == 'table' and number(data.id) or nil
    local player = id and QBCore.Functions.GetPlayer(id) or nil
    if not player then return { ok = false, error = 'No player with that ID is online' } end
    local info = player.PlayerData.charinfo
    return { ok = true, name = ('%s %s'):format(info.firstname, info.lastname), citizenid = player.PlayerData.citizenid }
end)

-- ---------------------------------------------------------------- actions
-- Every reply is { ok = true, message? } or { ok = false, error = 'text shown to the admin' }.
-- On ok the UI reloads the lists through ze-interiors:menu:getData, so there is nothing else to send back.

-- The name from the UI, trimmed, or nil and an error text.
local function parseName(value)
    local name = type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
    if name == '' or #name > 50 then return nil, 'The name must be 1 to 50 characters' end
    return name
end

-- The entrances from the UI as { [exit] = vector4 }, or nil and an error text.
-- The client is not trusted: exit 1 has to be there, every exit at most once, and only exits the interior has.
local function parseEntrances(interior, sent)
    sent = type(sent) == 'table' and sent or {}
    local entrances = {}
    for _, e in ipairs(sent) do
        local exit = type(e) == 'table' and number(e.exit) or nil
        if not exit or exit ~= math.floor(exit) or not interior.exits[exit] then
            return nil, ('%s has %d exits, an entrance points at one it does not have'):format(interior.name, #interior.exits)
        end
        if entrances[exit] then return nil, ('Entrance %d was sent twice'):format(exit) end

        local x, y, z = number(e.x), number(e.y), number(e.z)
        if not (x and y and z) then return nil, ('Entrance %d has no valid coordinates'):format(exit) end
        entrances[exit] = vector4(x + 0.0, y + 0.0, z + 0.0, (number(e.w) or 0.0) + 0.0)
    end
    if not entrances[1] then return nil, 'Entrance 1 is required' end
    return entrances
end

-- Add house. data = { name = string, interior = interior id, entrances = { { exit, x, y, z, w }, ... } }
-- `exit` is the exit of the interior the entrance leads to. Exit 1 is required, every other exit is optional (just leave it out).
register('ze-interiors:menu:createHouse', NO_PERMISSION, function(_, data)
    if type(data) ~= 'table' then return { ok = false, error = 'Nothing was sent' } end

    local name, nameErr = parseName(data.name)
    if not name then return { ok = false, error = nameErr } end

    local interiorId = number(data.interior)
    local interior = interiorId and Config.Interiors[interiorId]
    if not interior then return { ok = false, error = 'That interior does not exist' } end

    local entrances, err = parseEntrances(interior, data.entrances)
    if not entrances then return { ok = false, error = err } end

    local id, createErr = Houses.Create(name, interiorId, entrances)
    if not id then return { ok = false, error = createErr } end
    return { ok = true, message = ('House #%d "%s" created'):format(id, name) }
end)

-- Edit house. data = { house = house id, name = string, entrances = { { exit, x, y, z, w }, ... } }
-- Same rules for the entrances as createHouse. The interior, owner, keys and lock are not changed: the interior stays because
-- people can be standing inside it. The entrances sent replace the old ones, so an exit that is left out loses its entrance.
register('ze-interiors:menu:updateHouse', NO_PERMISSION, function(_, data)
    if type(data) ~= 'table' then return { ok = false, error = 'Nothing was sent' } end

    local id = number(data.house)
    local house = id and Shared.Houses[id]
    if not house then return { ok = false, error = 'That house does not exist' } end

    local name, nameErr = parseName(data.name)
    if not name then return { ok = false, error = nameErr } end

    local entrances, err = parseEntrances(house.interior, data.entrances)
    if not entrances then return { ok = false, error = err } end

    local ok, updateErr = Houses.Update(id, name, entrances)
    if not ok then return { ok = false, error = updateErr } end
    return { ok = true, message = ('"%s" saved'):format(name) }
end)

-- ---------------------------------------------------------------- access (owner, keys, lock)
-- These are used by the edit form and save straight away, each one on its own. The reply is { ok, error?, message? } like the rest.

-- The house and the online player a request is about: house, player, citizenid, or nil and an error reply.
local function houseAndPlayer(data, needPlayer)
    if type(data) ~= 'table' then return nil, { ok = false, error = 'Nothing was sent' } end

    local id = number(data.house)
    local house = id and Shared.Houses[id]
    if not house then return nil, { ok = false, error = 'That house does not exist' } end
    if not needPlayer then return id, house end

    local source = number(data.player)
    local player = source and QBCore.Functions.GetPlayer(source)
    if not player then return nil, { ok = false, error = 'No player with that ID is online' } end
    return id, house, source, player
end

-- Lock or unlock. data = { house, locked = bool }
register('ze-interiors:menu:setLocked', NO_PERMISSION, function(_, data)
    local id, house = houseAndPlayer(data, false)
    if not id then return house end

    local locked = data.locked == true
    local ok, err = Houses.SetLocked(id, locked)
    if not ok then return { ok = false, error = err } end
    return { ok = true, message = ('%s is now %s'):format(house.name, locked and 'locked' or 'unlocked') }
end)

-- Make an online player the owner. data = { house, player = server id }. The previous owner's keys are cleared (Houses.SetOwner).
register('ze-interiors:menu:setOwner', NO_PERMISSION, function(_, data)
    local id, house, source, player = houseAndPlayer(data, true)
    if not id then return house end

    local citizenid = player.PlayerData.citizenid
    if house.owner == citizenid then return { ok = false, error = 'That player already owns this house' } end

    local ok, err = Houses.SetOwner(id, citizenid)
    if not ok then return { ok = false, error = err } end

    local info = player.PlayerData.charinfo
    TriggerClientEvent('QBCore:Notify', source, ('You are now the owner of %s'):format(house.name), 'success', 7000)
    return { ok = true, message = ('%s %s is now the owner'):format(info.firstname, info.lastname) }
end)

-- Take the house back from its owner (it goes back to "for sale"). data = { house }. Clears the keys too.
register('ze-interiors:menu:removeOwner', NO_PERMISSION, function(_, data)
    local id, house = houseAndPlayer(data, false)
    if not id then return house end
    if house.owner == '' then return { ok = false, error = 'Nobody owns this house' } end

    local ok, err = Houses.SetOwner(id, '')
    if not ok then return { ok = false, error = err } end
    return { ok = true, message = 'The owner was removed' }
end)

-- Give an online player a key. data = { house, player = server id }
register('ze-interiors:menu:addKey', NO_PERMISSION, function(_, data)
    local id, house, _, player = houseAndPlayer(data, true)
    if not id then return house end

    local ok, err = Houses.AddKeyholder(id, player.PlayerData.citizenid)
    if not ok then return { ok = false, error = err } end

    local info = player.PlayerData.charinfo
    return { ok = true, message = ('%s %s got a key'):format(info.firstname, info.lastname) }
end)

-- Take a key back. data = { house, citizenid } (a citizenid, so keys of offline players can go too)
register('ze-interiors:menu:removeKey', NO_PERMISSION, function(_, data)
    local id, reply = houseAndPlayer(data, false)
    if not id then return reply end

    local citizenid = type(data.citizenid) == 'string' and data.citizenid or nil
    if not citizenid or citizenid == '' then return { ok = false, error = 'No key was chosen' } end

    local removed, err = Houses.RemoveKeyholders(id, citizenid)
    if not removed then return { ok = false, error = err } end
    return { ok = true, message = 'Key removed' }
end)

-- Sell a house to a player. data = { house = house id, player = server id of the buyer }
register('ze-interiors:menu:sellHouse', NO_PERMISSION, function(_, data)
    if type(data) ~= 'table' then return { ok = false, error = 'Nothing was sent' } end

    local id = number(data.house)
    local house = id and Shared.Houses[id]
    if not house then return { ok = false, error = 'That house does not exist' } end

    local buyerSource = number(data.player)
    local buyer = buyerSource and QBCore.Functions.GetPlayer(buyerSource)
    if not buyer then return { ok = false, error = 'No player with that ID is online' } end

    local citizenid = buyer.PlayerData.citizenid
    if house.owner == citizenid then return { ok = false, error = 'That player already owns this house' } end

    local ok, err = Houses.SetOwner(id, citizenid)
    if not ok then return { ok = false, error = err } end

    local info = buyer.PlayerData.charinfo
    TriggerClientEvent('QBCore:Notify', buyerSource, ('You are now the owner of %s'):format(house.name), 'success', 7000)
    return { ok = true, message = ('%s sold to %s %s'):format(house.name, info.firstname, info.lastname) }
end)

-- Delete a house. data = { house = house id }
register('ze-interiors:menu:deleteHouse', NO_PERMISSION, function(_, data)
    local id = type(data) == 'table' and number(data.house) or nil
    local house = id and Shared.Houses[id]
    if not house then return { ok = false, error = 'That house does not exist' } end

    local name = house.name
    local ok, err = Houses.Delete(id)
    if not ok then return { ok = false, error = err } end
    return { ok = true, message = ('"%s" deleted'):format(name) }
end)
