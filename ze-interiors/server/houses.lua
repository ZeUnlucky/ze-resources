Houses = {}

local loaded = false

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

    local entrances = {}
    local building, floor

    if row.building ~= nil then
        -- An apartment has no entrance of its own: its only entrance (exit 1) is the door of its building.
        building = Shared.Buildings[row.building]
        floor = tonumber(row.floor)
        if not building then
            warn(('apartment #%d "%s" is skipped: there is no building %s'):format(row.id, row.name, tostring(row.building)))
            return nil
        end
        if not floor or floor ~= math.floor(floor) or floor < 1 or floor > building.floors then
            warn(('apartment #%d "%s" is skipped: floor %s does not exist in "%s" (it has %d floors)'):format(
                row.id, row.name, tostring(row.floor), building.name, building.floors))
            return nil
        end
        entrances[1] = building.entrance
    else
        local list = json.decode(row.entrances or '')
        if type(list) ~= 'table' then list = {} end

        for i, e in ipairs(list) do
            local exit = tonumber(e.exit) or i
            if interior.exits[exit] then
                entrances[exit] = vector4(e.x + 0.0, e.y + 0.0, e.z + 0.0, (e.w or 0.0) + 0.0)
            else
                warn(('house #%d "%s": entrance for exit %s is ignored, "%s" has no such exit'):format(row.id, row.name, tostring(exit), interior.name))
            end
        end

        if not entrances[1] then
            warn(('house #%d "%s" is skipped: it has no entrance on exit 1'):format(row.id, row.name))
            return nil
        end
    end

    local keyholders = json.decode(row.keyholders or '')
    return {
        name = row.name,
        interior = interior,
        interiorId = row.interior,
        building = row.building,   -- nil for a normal house; building id and floor for an apartment
        floor = floor,
        entrances = entrances,
        owner = row.owner or '',
        keyholders = type(keyholders) == 'table' and keyholders or {},
        locked = row.locked == true or row.locked == 1,
    }
end

function Houses.Load()
    -- the apartments need the buildings, so those load first
    Buildings.Load()

    local rows = MySQL.query.await('SELECT id, name, interior, building, floor, entrances, owner, keyholders, locked FROM ze_houses') or {}
    Shared.Houses = {}
    for _, row in ipairs(rows) do
        local house = build(row)
        if house then Shared.Houses[row.id] = house end
    end
    loaded = true

    local count = 0
    for _ in pairs(Shared.Houses) do count = count + 1 end
    print(('^2[ze-interiors]^7 %d houses loaded'):format(count))
    Houses.SyncAll()
end

MySQL.ready(Houses.Load)

-- ---------------------------------------------------------------- clients

-- The plain table that goes to the clients (and nil for a house that does not exist, which tells them to drop it).
function Houses.Pack(id)
    local house = Shared.Houses[id]
    if not house then return nil end
    local entrances = {}
    for exit, e in pairs(house.entrances) do
        entrances[#entrances + 1] = { exit = exit, x = e.x, y = e.y, z = e.z, w = e.w }
    end
    table.sort(entrances, function(a, b) return a.exit < b.exit end)
    -- the keyholders go along so the door of a house can show Lock / Unlock to them too
    return { id = id, name = house.name, interior = house.interiorId, building = house.building, floor = house.floor, entrances = entrances, owner = house.owner, keyholders = house.keyholders, locked = house.locked }
end

-- True when the citizen owns the house or holds a key to it.
function Houses.HasKey(id, citizenid)
    local house = Shared.Houses[id]
    if not house then return false end
    if house.owner == citizenid then return true end
    for _, holder in ipairs(house.keyholders) do
        if holder == citizenid then return true end
    end
    return false
end

function Houses.SyncAll(target)
    local list = {}
    for id in pairs(Shared.Houses) do list[#list + 1] = Houses.Pack(id) end
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

-- `entrances` is { [exit number] = vector4 }: exit 1 has to be there, the others are optional (the caller checks that).
-- An apartment is created with a building id and a floor instead of entrances (pass nil for `entrances`): its only entrance
-- is the door of the building. The callers check that the building exists and that the floor is one of its floors.
function Houses.Create(name, interiorId, entrances, building, floor)
    local ok, id
    if building then
        entrances = { [1] = Shared.Buildings[building].entrance }
        ok, id = pcall(MySQL.insert.await, 'INSERT INTO ze_houses (name, interior, building, floor, entrances, owner, keyholders, locked) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { name, interiorId, building, floor, '[]', '', '[]', 0 })
    else
        local plain = {}
        for exit, e in pairs(entrances) do plain[#plain + 1] = { exit = exit, x = e.x, y = e.y, z = e.z, w = e.w } end
        table.sort(plain, function(a, b) return a.exit < b.exit end)
        ok, id = pcall(MySQL.insert.await, 'INSERT INTO ze_houses (name, interior, entrances, owner, keyholders, locked) VALUES (?, ?, ?, ?, ?, ?)',
            { name, interiorId, json.encode(plain), '', '[]', 0 })
    end
    if not ok or not id then return false, 'The database did not save the house' end

    Shared.Houses[id] = {
        name = name,
        interior = Config.Interiors[interiorId],
        interiorId = interiorId,
        building = building,
        floor = floor,
        entrances = entrances,
        owner = '',
        keyholders = {},
        locked = false,
    }
    Houses.Sync(id)
    return id
end

-- Changes the name and the entrances of a house; the interior, owner, keys and lock stay as they are.
-- `entrances` is { [exit number] = vector4 } like in Houses.Create and replaces the old set (an exit left out loses its entrance).
-- An apartment has no entrances to change: pass its building and floor instead (nil for `entrances`), and the name, building
-- and floor are saved.
function Houses.Update(id, name, entrances, building, floor)
    local house = Shared.Houses[id]
    if not house then return false, 'That house does not exist' end

    if house.building then
        local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET name = ?, building = ?, floor = ? WHERE id = ?', { name, building, floor, id })
        if not ok then return false, 'The database did not save the changes' end

        house.name = name
        house.building = building
        house.floor = floor
        house.entrances = { [1] = Shared.Buildings[building].entrance }
        Houses.Sync(id)
        return true
    end

    local plain = {}
    for exit, e in pairs(entrances) do plain[#plain + 1] = { exit = exit, x = e.x, y = e.y, z = e.z, w = e.w } end
    table.sort(plain, function(a, b) return a.exit < b.exit end)

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET name = ?, entrances = ? WHERE id = ?', { name, json.encode(plain), id })
    if not ok then return false, 'The database did not save the changes' end

    house.name = name
    house.entrances = entrances
    Houses.Sync(id)
    return true
end

-- A new owner starts without the previous owner's keyholders.
function Houses.SetOwner(id, citizenid)
    local house = Shared.Houses[id]
    if not house then return false, 'That house does not exist' end

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET owner = ?, keyholders = ? WHERE id = ?', { citizenid, '[]', id })
    if not ok then return false, 'The database did not save the sale' end

    house.owner = citizenid
    house.keyholders = {}
    Houses.Sync(id)
    return true
end

-- Gives a citizen a key: the keyholders column is saved first, the server and the clients only change when it worked.
function Houses.AddKeyholder(id, citizenid)
    local house = Shared.Houses[id]
    if not house then return false, 'That house does not exist' end
    if Houses.HasKey(id, citizenid) then return false, 'That player already has a key' end

    local keyholders = { table.unpack(house.keyholders) }
    keyholders[#keyholders + 1] = citizenid

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET keyholders = ? WHERE id = ?', { json.encode(keyholders), id })
    if not ok then return false, 'The database did not save the key' end

    house.keyholders = keyholders
    Houses.Sync(id)
    return true
end

-- Takes a key back. citizenid = nil takes every key (this is also how an offline friend's key is revoked).
-- Returns the number of keys removed.
function Houses.RemoveKeyholders(id, citizenid)
    local house = Shared.Houses[id]
    if not house then return false, 'That house does not exist' end

    local keyholders = {}
    for _, holder in ipairs(house.keyholders) do
        if citizenid and holder ~= citizenid then keyholders[#keyholders + 1] = holder end
    end
    local removed = #house.keyholders - #keyholders
    if removed == 0 then return false, citizenid and 'That player has no key' or 'Nobody has a key to that house' end

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET keyholders = ? WHERE id = ?', { json.encode(keyholders), id })
    if not ok then return false, 'The database did not save the change' end

    house.keyholders = keyholders
    Houses.Sync(id)
    return removed
end

function Houses.SetLocked(id, locked)
    local house = Shared.Houses[id]
    if not house then return false, 'That house does not exist' end

    local ok = pcall(MySQL.update.await, 'UPDATE ze_houses SET locked = ? WHERE id = ?', { locked and 1 or 0, id })
    if not ok then return false, 'The database did not save the lock' end

    house.locked = locked
    Houses.Sync(id)
    return true
end

-- Removes the house, puts anyone still inside back on its first entrance and empties its stash.
function Houses.Delete(id)
    local house = Shared.Houses[id]
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

    Shared.Houses[id] = nil
    Houses.Sync(id)

    -- the stash goes with the house; an inventory resource that does not have these exports is not a reason to fail the delete
    pcall(function() exports['qb-inventory']:ClearStash(Houses.StashId(id)) end)
    pcall(function() exports['qb-inventory']:RemoveInventory(Houses.StashId(id)) end)
    return true
end

-- citizenid -> "First Last" for every owner and keyholder, one query. Offline characters are read from the players table.
function Houses.OwnerNames()
    local owners, seen = {}, {}
    local function add(citizenid)
        if citizenid ~= '' and not seen[citizenid] then
            seen[citizenid] = true
            owners[#owners + 1] = citizenid
        end
    end
    for _, house in pairs(Shared.Houses) do
        add(house.owner)
        for _, holder in ipairs(house.keyholders) do add(holder) end
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
