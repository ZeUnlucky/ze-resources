-- The Services directory (who is on duty) and the MDT (people, vehicles, plates). The MDT checks the caller's job on every
-- request: qb-phone let any client ask for any citizen's data.

local QBCore = exports['qb-core']:GetCoreObject()

-- ---------------------------------------------------------------------------------------------------------------------
-- Services
-- ---------------------------------------------------------------------------------------------------------------------

Core.Rpc('services:list', { rate = 1500 }, function(ctx)
    local groups = {}
    for _, svc in ipairs(Config.Services.List) do
        local members = {}
        local sources = QBCore.Functions.GetPlayersByJob(svc.job, Config.Services.RequireDuty)
        for _, src in ipairs(sources or {}) do
            local me = Core.Online(src)
            if me and src ~= ctx.src then
                members[#members + 1] = { name = Core.FullName(me.first, me.last), number = me.number, picture = me.picture }
            end
        end
        table.sort(members, function(a, b) return a.name < b.name end)
        groups[#groups + 1] = { job = svc.job, label = svc.label, icon = svc.icon, color = svc.color, members = members }
    end
    return { groups = groups }
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- MDT
-- ---------------------------------------------------------------------------------------------------------------------

local function allowed(ctx)
    return Core.CanMDT(ctx.Player.PlayerData)
end

local function likeEscape(text)
    return (text:gsub('[%%_\\]', '\\%0'))
end

-- JSON_EXTRACT comes back as text on MariaDB and already decoded on MySQL
local function parse(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' or raw == 'null' then return nil end
    return json.decode(raw)
end

Core.Rpc('mdt:people', { rate = 800 }, function(ctx, a)
    if not allowed(ctx) then return { error = 'You do not have access to this' } end
    local q = Core.Clean(tostring(a.q or ''), 40)
    if #q < 2 then return { error = 'Type at least two characters' } end

    local params = { q }
    local parts = {}
    local n = 0
    for token in q:gmatch('%S+') do
        n = n + 1
        if n > 4 then break end
        local like = '%' .. likeEscape(token) .. '%'
        parts[#parts + 1] = "(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) LIKE ?)"
        params[#params + 1] = like
        params[#params + 1] = like
        params[#params + 1] = like
    end

    local rows = MySQL.query.await(
        "SELECT citizenid, charinfo, JSON_EXTRACT(metadata, '$.licences') AS licences, JSON_EXTRACT(metadata, '$.criminalrecord') AS record, " ..
        "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.fingerprint')) AS fingerprint FROM players WHERE citizenid = ? OR (" ..
        table.concat(parts, ' AND ') .. ') LIMIT 25', params) or {}

    if #rows == 0 then return { people = {} } end

    local cids = {}
    for _, row in ipairs(rows) do cids[#cids + 1] = row.citizenid end
    local homes = {}
    local apartments = MySQL.query.await('SELECT citizenid, label, type FROM apartments WHERE citizenid IN (' .. DB.Marks(#cids) .. ')', cids) or {}
    for _, apt in ipairs(apartments) do homes[apt.citizenid] = { label = apt.label, type = apt.type } end

    local people = {}
    for _, row in ipairs(rows) do
        local info = json.decode(row.charinfo or '{}') or {}
        local licences = parse(row.licences) or {}
        local record = parse(row.record) or {}
        people[#people + 1] = {
            citizenid = row.citizenid,
            firstname = info.firstname or '',
            lastname = info.lastname or '',
            birthdate = info.birthdate or '',
            phone = info.phone and tostring(info.phone) or '',
            nationality = info.nationality or '',
            gender = tonumber(info.gender) or 0,
            driver = licences.driver == true,
            weapon = licences.weapon == true,
            business = licences.business == true,
            record = record.hasRecord == true,
            fingerprint = row.fingerprint or '',
            apartment = homes[row.citizenid],
        }
    end
    return { people = people }
end)

local function vehicleLabel(model)
    local info = QBCore.Shared.Vehicles and QBCore.Shared.Vehicles[model]
    if not info then return 'Unknown vehicle' end
    if info.brand and info.brand ~= '' then return info.brand .. ' ' .. info.name end
    return info.name
end

Core.Rpc('mdt:person', { rate = 600 }, function(ctx, a)
    if not allowed(ctx) then return { error = 'You do not have access to this' } end
    local cid = Core.Clean(tostring(a.citizenid or ''), 50)
    if cid == '' then return { error = 'Person not found' } end
    local rows = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ? LIMIT 40', { cid }) or {}
    local vehicles = {}
    for _, row in ipairs(rows) do
        vehicles[#vehicles + 1] = { plate = row.plate, label = vehicleLabel(row.vehicle) }
    end
    return { vehicles = vehicles }
end)

-- Plates of cars that belong to nobody in the database get an owner anyway, the same one every time (so a stolen NPC car
-- keeps its owner between two scans, and across restarts).
local NpcOwners = {
    'Bailey Sykes', 'Aroush Goodwin', 'Tom Warren', 'Abdallah Friedman', 'Lavinia Powell', 'Andrew Delarosa', 'Skye Cardenas',
    'Amelia-Mae Walter', 'Elisha Cote', 'Janice Rhodes', 'Justin Harris', 'Montel Graves', 'Benjamin Zavala', 'Mia Willis',
    'Jacques Schmitt', 'Mert Simmonds', 'Rickie Browne', 'Deacon Stanley', 'Daisy Fraser', 'Kitty Walters', 'Jareth Fernandez',
    'Meredith Calhoun', 'Teagan Mckay', 'Kurt Bain', 'Burt Kain', 'Joanna Huff', 'Carrie-Ann Pineda', 'Gracie-Mai Mcghee',
    'Robyn Boone', 'Aliya William', 'Rohit West', 'Skylar Archer', 'Jake Kumar',
}

local function npcOwner(plate)
    local hash = 7
    for i = 1, #plate do hash = (hash * 31 + plate:byte(i)) % 1000003 end
    return NpcOwners[(hash % #NpcOwners) + 1]
end

local function searchVehicles(q)
    local rows = MySQL.query.await(
        'SELECT v.plate, v.vehicle, v.citizenid, p.charinfo FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid ' ..
        'WHERE v.plate LIKE ? OR v.citizenid = ? LIMIT 25', { '%' .. likeEscape(q) .. '%', q }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        local info = json.decode(row.charinfo or '{}') or {}
        list[#list + 1] = {
            plate = row.plate,
            label = vehicleLabel(row.vehicle),
            owner = Core.FullName(info.firstname, info.lastname),
            citizenid = row.citizenid,
        }
    end
    return list
end

Core.Rpc('mdt:vehicles', { rate = 800 }, function(ctx, a)
    if not allowed(ctx) then return { error = 'You do not have access to this' } end
    local q = Core.Clean(tostring(a.q or ''), 20)
    if #q < 2 then return { error = 'Type at least two characters' } end
    local list = searchVehicles(q)
    if #list == 0 and #q >= 5 then
        -- a plate that is not registered to a player
        list[1] = { plate = q:upper(), label = 'Unknown vehicle', owner = npcOwner(q:upper()), npc = true }
    end
    return { vehicles = list }
end)

-- a plate scanned from the closest vehicle
Core.Rpc('mdt:plate', { rate = 800 }, function(ctx, a)
    if not allowed(ctx) then return { error = 'You do not have access to this' } end
    local plate = Core.Clean(tostring(a.plate or ''), 12)
    if plate == '' then return { error = 'No vehicle nearby' } end

    local row = MySQL.query.await(
        'SELECT v.plate, v.vehicle, v.citizenid, p.charinfo FROM player_vehicles v LEFT JOIN players p ON p.citizenid = v.citizenid WHERE v.plate = ? LIMIT 1', { plate }) or {}
    row = row[1]
    if row then
        local info = json.decode(row.charinfo or '{}') or {}
        return { vehicle = { plate = row.plate, label = vehicleLabel(row.vehicle), owner = Core.FullName(info.firstname, info.lastname), citizenid = row.citizenid } }
    end
    return { vehicle = { plate = plate:upper(), label = 'Unknown vehicle', owner = npcOwner(plate:upper()), npc = true } }
end)
