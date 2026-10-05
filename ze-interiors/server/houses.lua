-- ze_houses: loads the houses from the database into Config.Houses and keeps the database, the server and every client in step.
-- Config.Houses[id] = { name, interior (the Config.Interiors entry), interiorId, entrances = { vector4 }, owner (citizenid or ''),
--                       keyholders = { citizenid }, locked }
-- The Houses.* functions below are the only place that writes to ze_houses. They return false (and an error text) on a database failure.
Houses = {}

local loaded = false

-- Routing bucket a house lives in. The stash is "interiorStash" .. id.
function Houses.Bucket(id)
    return id + 5000
end

function Houses.StashId(id)
    return 'interiorStash' .. id
end

-- ---------------------------------------------------------------- loading

local function warn(text)
    print(('^3[ze-interiors]^7 %s'):format(text))
end

local function build(row)
    local interior = Config.Interiors[row.interior]
    if not interior then
        warn(('house #%d "%s" is skipped: there is no interior %s in Config.Interiors'):format(row.id, row.name, tostring(row.interior)))
        return nil
    end

    local list = json.decode(row.entrances or '')
    if type(list) ~= 'table' or #list ~= #interior.exits then
        warn(('house #%d "%s" is skipped: its interior has %d exits but the house has %d entrances'):format(
            row.id, row.name, #interior.exits, type(list) == 'table' and #list or 0))
        return nil
    end

    local entrances = {}
    for i, e in ipairs(list) do
        entrances[i] = vector4(e.x + 0.0, e.y + 0.0, e.z + 0.0, (e.w or 0.0) + 0.0)
    end

    local keyholders = json.decode(row.keyholders or '')
    return {
        name = row.name,
        interior = interior,
        interiorId = row.interior,
        entrances = entrances,
        owner = row.owner or '',
        keyholders = type(keyholders) == 'table' and keyholders or {},
        locked = row.locked == true or row.locked == 1,
    }
end

function Houses.Load()
    local rows = MySQL.query.await('SELECT id, name, interior, entrances, owner, keyholders, locked FROM ze_houses') or {}
    Config.Houses = {}
    for _, row in ipairs(rows) do
        local house = build(row)
        if house then Config.Houses[row.id] = house end
    end
    loaded = true

    local count = 0
    for _ in pairs(Config.Houses) do count = count + 1 end
    print(('^2[ze-interiors]^7 %d houses loaded'):format(count))
    Houses.SyncAll()
end

MySQL.ready(Houses.Load)

-- ---------------------------------------------------------------- clients

-- The plain table that goes to the clients (and nil for a house that does not exist, which tells them to drop it).
function Houses.Pack(id)
    local house = Config.Houses[id]
    if not house then return nil end
    local entrances = {}
    for i, e in ipairs(house.entrances) do
        entrances[i] = { x = e.x, y = e.y, z = e.z, w = e.w }
    end
    return { id = id, name = house.name, interior = house.interiorId, entrances = entrances, owner = house.owner, locked = house.locked }
end

function Houses.SyncAll(target)
    local list = {}
    for id in pairs(Config.Houses) do list[#list + 1] = Houses.Pack(id) end
    TriggerClientEvent('ze-interiors:SyncHouses', target or -1, list)
end

function Houses.Sync(id)
    TriggerClientEvent('ze-interiors:SyncHouse', -1, id, Houses.Pack(id))
end

-- A client asks for the houses when it starts. Wait for the database if it is not read yet.
RegisterNetEvent('ze-interiors:RequestHouses', function()
    local src = source
    while not loaded do Wait(200) end
    Houses.SyncAll(src)
end)

-- ---------------------------------------------------------------- changes

-- `entrances` is a list of vector4 with one entry per exit of the interior (the caller checks that).
function Houses.Create(name, interiorId, entrances)
    local plain = {}
    for i, e in ipairs(entrances) do plain[i] = { x = e.x, y = e.y, z = e.z, w = e.w } end

    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO ze_houses (name, interior, entrances, owner, keyholders, locked) VALUES (?, ?, ?, ?, ?, ?)',
        { name, interiorId, json.encode(plain), '', '[]', 0 })
    if not ok or not id then return false, 'The database did not save the house' end

    Config.Houses[id] = {
        name = name,
        interior = Config.Interiors[interiorId],
        interiorId = interiorId,
        entrances = entrances,
        owner = '',
        keyholders = {},
        locked = false,
    }
    Houses.Sync(id)
    return id
end

-- A new owner starts without the previous owner's keyholders.
function Houses.SetOwner(id, citizenid)
    local house = Config.Houses[id]
    if not house then return false, 'That house does not exist' end

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET owner = ?, keyholders = ? WHERE id = ?', { citizenid, '[]', id })
    if not ok then return false, 'The database did not save the sale' end

    house.owner = citizenid
    house.keyholders = {}
    Houses.Sync(id)
    return true
end

function Houses.SetLocked(id, locked)
    local house = Config.Houses[id]
    if not house then return false, 'That house does not exist' end

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET locked = ? WHERE id = ?', { locked and 1 or 0, id })
    if not ok then return false, 'The database did not save the lock' end

    house.locked = locked
    Houses.Sync(id)
    return true
end

-- Removes the house, puts anyone still inside back on its first entrance and empties its stash.
function Houses.Delete(id)
    local house = Config.Houses[id]
    if not house then return false, 'That house does not exist' end

    local ok = pcall(MySQL.update.await, 'DELETE FROM ze_houses WHERE id = ?', { id })
    if not ok then return false, 'The database did not delete the house' end

    local bucket = Houses.Bucket(id)
    local door = house.entrances[1]
    for _, player in ipairs(GetPlayers()) do
        local src = tonumber(player)
        if GetPlayerRoutingBucket(src) == bucket then
            local ped = GetPlayerPed(src)
            SetEntityCoords(ped, door.x, door.y, door.z)
            SetEntityHeading(ped, door.w)
            SetPlayerRoutingBucket(src, 0)
            TriggerClientEvent('ze-interiors:ChangeInterior', src, 0)
        end
    end

    Config.Houses[id] = nil
    Houses.Sync(id)

    -- the stash goes with the house; an inventory resource that does not have these exports is not a reason to fail the delete
    pcall(function() exports['qb-inventory']:ClearStash(Houses.StashId(id)) end)
    pcall(function() exports['qb-inventory']:RemoveInventory(Houses.StashId(id)) end)
    return true
end

-- citizenid -> "First Last" for every owner, one query. Owners that are offline are read from the players table.
function Houses.OwnerNames()
    local owners, seen = {}, {}
    for _, house in pairs(Config.Houses) do
        if house.owner ~= '' and not seen[house.owner] then
            seen[house.owner] = true
            owners[#owners + 1] = house.owner
        end
    end

    local names = {}
    if #owners == 0 then return names end

    local ok, rows = pcall(MySQL.query.await, 'SELECT citizenid, charinfo FROM players WHERE citizenid IN (?)', { owners })
    if ok and rows then
        for _, row in ipairs(rows) do
            local info = json.decode(row.charinfo or '')
            if type(info) == 'table' then
                names[row.citizenid] = ('%s %s'):format(info.firstname or '', info.lastname or '')
            end
        end
    end
    return names
end
