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

-- { { id, name, interiorName, entrances = number of entrances, owner, ownerName, locked } }
-- `owner` is the citizenid ('' when nobody owns the house). The UI shows `ownerName` when there is one, else `owner`.
local function buildHouses()
    local names = Houses.OwnerNames()
    local list = {}
    for id, house in pairs(Config.Houses) do
        list[#list + 1] = {
            id = id,
            name = house.name,
            interiorName = house.interior.name,
            entrances = #house.entrances,
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

-- Add house. data = { name = string, interior = interior id, entrances = { { x, y, z, w }, ... } }
register('ze-interiors:menu:createHouse', NO_PERMISSION, function(_, data)
    if type(data) ~= 'table' then return { ok = false, error = 'Nothing was sent' } end

    local name = type(data.name) == 'string' and data.name:match('^%s*(.-)%s*$') or ''
    if name == '' or #name > 50 then return { ok = false, error = 'The name must be 1 to 50 characters' } end

    local interiorId = number(data.interior)
    local interior = interiorId and Config.Interiors[interiorId]
    if not interior then return { ok = false, error = 'That interior does not exist' } end

    -- the UI only lets the form through with one entrance per exit; the client is not trusted, so check again
    local sent = type(data.entrances) == 'table' and data.entrances or {}
    if #sent ~= #interior.exits then
        return { ok = false, error = ('%s has %d exits, so the house needs %d entrances'):format(interior.name, #interior.exits, #interior.exits) }
    end

    local entrances = {}
    for i, e in ipairs(sent) do
        local x, y, z = number(e.x), number(e.y), number(e.z)
        if not (x and y and z) then return { ok = false, error = ('Entrance %d has no valid coordinates'):format(i) } end
        entrances[i] = vector4(x + 0.0, y + 0.0, z + 0.0, (number(e.w) or 0.0) + 0.0)
    end

    local id, err = Houses.Create(name, interiorId, entrances)
    if not id then return { ok = false, error = err } end
    return { ok = true, message = ('House #%d "%s" created'):format(id, name) }
end)

-- Sell a house to a player. data = { house = house id, player = server id of the buyer }
register('ze-interiors:menu:sellHouse', NO_PERMISSION, function(_, data)
    if type(data) ~= 'table' then return { ok = false, error = 'Nothing was sent' } end

    local id = number(data.house)
    local house = id and Config.Houses[id]
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
    local house = id and Config.Houses[id]
    if not house then return { ok = false, error = 'That house does not exist' } end

    local name = house.name
    local ok, err = Houses.Delete(id)
    if not ok then return { ok = false, error = err } end
    return { ok = true, message = ('"%s" deleted'):format(name) }
end)
