-- The apps that talk to other resources (qb-crypto, qb-garages, qb-houses, qb-lapraces, qb-policejob). Each callback waits
-- for the other resource with a time limit (Phone.Await), so a resource that is missing or does not answer gives an
-- error in the app instead of a screen that never finishes.
--
-- Data shapes are the ones those resources already return; the UI reads them as they come.

local QBCore = exports['qb-core']:GetCoreObject()

local function trimPlate(plate)
    return (tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', ''):upper())
end

-- a table that came out of Lua as {} may be an object or a list on the other side: always give lists
local function toList(t)
    local list = {}
    if type(t) ~= 'table' then return list end
    for _, v in pairs(t) do list[#list + 1] = v end
    return list
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Mail: the stored button of a mail is run here (it is an event of another resource)
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('mail:button', function(data, cb)
    local res = Phone.RpcAwait('mail:button', { mailid = data and data.mailid })
    if type(res) == 'table' and res.event then
        TriggerEvent(res.event, res.data)
        return cb({ ok = true })
    end
    cb(res or { error = 'No answer from the server' })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Crypto (qb-crypto)
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('crypto:data', function(_, cb)
    local res = Phone.Await('qb-crypto:server:GetCryptoData', 6000, 'qbit')
    if type(res) ~= 'table' then return cb({ error = 'Crypto is not available' }) end
    cb({
        history = toList(res.History),
        worth = tonumber(res.Worth) or 0,
        portfolio = tonumber(res.Portfolio) or 0,
        walletId = res.WalletId or '',
    })
end)

local function cryptoResult(res)
    if type(res) ~= 'table' then return { error = res == 'notenough' and 'You do not have enough Qbits' or 'The order failed' } end
    return {
        ok = true,
        history = toList(res.History),
        worth = tonumber(res.Worth) or 0,
        portfolio = tonumber(res.Portfolio) or 0,
        walletId = res.WalletId or '',
    }
end

local function coinsOf(data)
    local coins = tonumber(data and data.coins)
    if not coins or coins <= 0 or coins > 1000000 then return nil end
    return coins
end

RegisterNUICallback('crypto:buy', function(data, cb)
    local coins = coinsOf(data)
    if not coins then return cb({ error = 'Enter an amount' }) end
    local res = Phone.Await('qb-crypto:server:BuyCrypto', 8000, { Coins = coins })
    if res == false or res == nil then return cb({ error = 'You do not have enough money' }) end
    cb(cryptoResult(res))
end)

RegisterNUICallback('crypto:sell', function(data, cb)
    local coins = coinsOf(data)
    if not coins then return cb({ error = 'Enter an amount' }) end
    local res = Phone.Await('qb-crypto:server:SellCrypto', 8000, { Coins = coins })
    if res == false or res == nil then return cb({ error = 'You do not have enough Qbits' }) end
    cb(cryptoResult(res))
end)

RegisterNUICallback('crypto:transfer', function(data, cb)
    local coins = coinsOf(data)
    local wallet = tostring(data and data.walletId or '')
    if not coins or wallet == '' then return cb({ error = 'Fill in both fields' }) end
    local res = Phone.Await('qb-crypto:server:TransferCrypto', 8000, { Coins = coins, WalletId = wallet })
    if res == 'notenough' then return cb({ error = 'You do not have enough Qbits' }) end
    if res == 'notvalid' or res == nil then return cb({ error = 'This wallet ID does not exist' }) end
    cb(cryptoResult(res))
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Vehicles (qb-garages)
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('vehicles:list', function(_, cb)
    local list = Phone.Await('qb-garages:server:GetPlayerVehicles', 8000)
    cb({ vehicles = toList(list) })
end)

RegisterNUICallback('vehicles:track', function(data, cb)
    local plate = trimPlate(data and data.plate)
    if plate == '' then return cb({ ok = false }) end
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and trimPlate(GetVehicleNumberPlateText(vehicle)) == plate then
            local at = GetEntityCoords(vehicle)
            SetNewWaypoint(at.x, at.y)
            Phone.Notify('Your vehicle has been marked', 'success')
            return cb({ ok = true })
        end
    end
    Phone.Notify('This vehicle cannot be located', 'error')
    cb({ ok = false })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Houses (qb-houses)
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('houses:list', function(_, cb)
    local houses = Phone.Await('qb-phone:server:GetPlayerHouses', 8000)
    local keys = Phone.Await('qb-phone:server:GetHouseKeys', 8000)
    cb({ houses = toList(houses), keys = toList(keys) })
end)

RegisterNUICallback('houses:removeKey', function(data, cb)
    local holder = data and data.holder
    if type(data) ~= 'table' or type(data.house) ~= 'string' or type(holder) ~= 'table' or not holder.citizenid then
        return cb({ error = 'Bad request' })
    end
    TriggerServerEvent('qb-houses:server:removeHouseKey', data.house, {
        citizenid = holder.citizenid,
        firstname = holder.firstname,
        lastname = holder.lastname,
    })
    cb({ ok = true })
end)

RegisterNUICallback('houses:transfer', function(data, cb)
    local cid = tostring(data and data.citizenid or '')
    local house = tostring(data and data.house or '')
    if cid == '' or house == '' then return cb({ error = 'Fill in the citizen ID' }) end
    local ok = Phone.Await('qb-phone:server:TransferCid', 6000, cid, { name = house })
    if ok then return cb({ ok = true }) end
    cb({ error = 'This is not a valid citizen ID' })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Racing (qb-lapraces)
-- ---------------------------------------------------------------------------------------------------------------------

local function race(name)
    local ok, result = pcall(function() return exports['qb-lapraces'][name](exports['qb-lapraces']) end)
    return ok and result or false
end

local function inRace() return race('IsInRace') end
local function inEditor() return race('IsInEditor') end

-- is the player close enough to the first checkpoint? If not, the GPS points there.
local function nearStart(raceId, joined)
    local data = Phone.Await('qb-lapraces:server:GetRacingData', 5000, raceId)
    local first = data and data.Checkpoints and data.Checkpoints[1] and data.Checkpoints[1].coords
    if not first then return false, 'This race is not available' end
    local at = GetEntityCoords(PlayerPedId())
    if #(at - vector3(first.x, first.y, first.z)) <= 115.0 then
        if joined then TriggerEvent('qb-lapraces:client:WaitingDistanceCheck') end
        return true
    end
    SetNewWaypoint(first.x, first.y)
    Phone.Notify("You're too far away from the race. GPS has been set to the race.", 'error', 5000)
    return false, "You're too far away from the race. GPS has been set to the race."
end

RegisterNUICallback('racing:list', function(_, cb)
    local races = Phone.Await('qb-lapraces:server:GetRaces', 6000)
    cb({ races = toList(races) })
end)

RegisterNUICallback('racing:join', function(data, cb)
    local entry = data and data.race
    if type(entry) ~= 'table' or not entry.RaceId then return cb({ error = 'This race is not available' }) end
    if inRace() then return cb({ error = "You're already in a race.." }) end
    local near, why = nearStart(entry.RaceId, true)
    if not near then return cb({ error = why }) end
    if inEditor() then return cb({ error = "You're in an editor.." }) end
    TriggerServerEvent('qb-lapraces:server:JoinRace', entry)
    cb({ ok = true })
end)

RegisterNUICallback('racing:leave', function(data, cb)
    if type(data) == 'table' and type(data.race) == 'table' then
        TriggerServerEvent('qb-lapraces:server:LeaveRace', data.race)
    end
    cb({ ok = true })
end)

RegisterNUICallback('racing:start', function(data, cb)
    local entry = data and data.race
    if type(entry) == 'table' and entry.RaceId then
        TriggerServerEvent('qb-lapraces:server:StartRace', entry.RaceId)
    end
    cb({ ok = true })
end)

-- the tracks that can be set up as a race
RegisterNUICallback('racing:tracks', function(_, cb)
    local listed = Phone.Await('qb-lapraces:server:GetListedRaces', 6000)
    local tracks = {}
    for _, track in pairs(listed or {}) do
        if type(track) == 'table' and not track.Started and not track.Waiting then
            tracks[#tracks + 1] = { RaceId = track.RaceId, RaceName = track.RaceName }
        end
    end
    table.sort(tracks, function(a, b) return tostring(a.RaceName) < tostring(b.RaceName) end)
    cb({ tracks = tracks })
end)

RegisterNUICallback('racing:track', function(data, cb)
    local track, creator = Phone.Await('qb-lapraces:server:GetTrackData', 6000, data and data.raceId)
    if type(track) ~= 'table' then return cb({ error = 'Track not found' }) end
    local info = creator and creator.charinfo or {}
    local records = type(track.Records) == 'table' and track.Records or {}
    cb({
        distance = track.Distance,
        creator = (tostring(info.firstname or '?'):sub(1, 1):upper() .. '. ' .. tostring(info.lastname or ''):sub(1, 8)),
        record = records.Holder and {
            time = records.Time,
            holder = tostring(records.Holder[1] or '?'):sub(1, 1):upper() .. '. ' .. tostring(records.Holder[2] or ''):sub(1, 8),
        } or nil,
    })
end)

RegisterNUICallback('racing:setup', function(data, cb)
    local raceId = data and data.raceId
    local laps = tonumber(data and data.laps)
    if not raceId then return cb({ error = 'You have not selected a track..' }) end
    if not laps or laps < 0 or laps > 99 then return cb({ error = 'Fill in an amount of laps..' }) end

    if Phone.Await('qb-lapraces:server:HasCreatedRace', 5000) then
        return cb({ error = 'You already have a race active..' })
    end
    local near, why = nearStart(raceId, false)
    if not near then return cb({ error = why }) end
    if not Phone.Await('qb-lapraces:server:CanRaceSetup', 5000) then
        return cb({ error = "Races can't be set up right now.." })
    end
    TriggerServerEvent('qb-lapraces:server:SetupRace', raceId, math.floor(laps))
    cb({ ok = true })
end)

RegisterNUICallback('racing:create', function(data, cb)
    local name = tostring(data and data.name or ''):gsub('[<>"\']', ''):sub(1, 40)
    if name == '' then return cb({ error = 'You have to enter a track name..' }) end

    local authorized, available = Phone.Await('qb-lapraces:server:IsAuthorizedToCreateRaces', 5000, name)
    if not authorized then return cb({ error = "You don't have rights to make race tracks.." }) end
    if inEditor() then return cb({ error = "You're already setting up a track.." }) end
    if inRace() then return cb({ error = "You're in a race.." }) end
    if not available then return cb({ error = 'This name is not available..' }) end

    TriggerServerEvent('qb-lapraces:server:CreateLapRace', name)
    cb({ ok = true })
end)

RegisterNUICallback('racing:leaderboards', function(_, cb)
    local races = Phone.Await('qb-lapraces:server:GetRacingLeaderboards', 6000)
    local list = {}
    for _, entry in pairs(races or {}) do
        if type(entry) == 'table' and type(entry.LastLeaderboard) == 'table' and #entry.LastLeaderboard > 0 then
            list[#list + 1] = { name = entry.RaceName, results = entry.LastLeaderboard }
        end
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    cb({ races = list })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- MDT: what needs this player's game (the closest car, flagged plates, houses and apartments)
-- ---------------------------------------------------------------------------------------------------------------------

local flaggedChecks = true   -- false after the first time qb-policejob did not answer

local function addFlags(vehicles)
    if GetResourceState('qb-policejob') ~= 'started' then return end
    for _, vehicle in ipairs(vehicles) do
        if not flaggedChecks then break end
        local flagged = Phone.Await('police:server:IsPlateFlagged', 2500, vehicle.plate)
        if flagged == nil then
            flaggedChecks = false
        else
            vehicle.flagged = flagged == true
        end
    end
end

RegisterNUICallback('mdt:vehicles', function(data, cb)
    local res = Phone.RpcAwait('mdt:vehicles', { q = data and data.q })
    if type(res) == 'table' and res.vehicles then
        flaggedChecks = true
        addFlags(res.vehicles)
    end
    cb(res or { error = 'No answer from the server' })
end)

RegisterNUICallback('mdt:scan', function(_, cb)
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if not vehicle or vehicle == 0 or (distance and distance > 12.0) then
        return cb({ error = 'No vehicle nearby' })
    end
    local plate = QBCore.Functions.GetPlate(vehicle)
    local res = Phone.RpcAwait('mdt:plate', { plate = plate })
    if type(res) == 'table' and res.vehicle then
        flaggedChecks = true
        addFlags({ res.vehicle })
    end
    cb(res or { error = 'No answer from the server' })
end)

RegisterNUICallback('mdt:houses', function(data, cb)
    local houses = Phone.Await('qb-phone:server:MeosGetPlayerHouses', 6000, data and data.q)
    cb({ houses = toList(houses) })
end)

RegisterNUICallback('mdt:apartment', function(data, cb)
    local kind = data and data.type
    local place = Apartments and Apartments.Locations and kind and Apartments.Locations[kind]
    if place and place.coords and place.coords.enter then
        SetNewWaypoint(place.coords.enter.x, place.coords.enter.y)
        Phone.Notify('GPS has been set!', 'success')
        return cb({ ok = true })
    end
    cb({ error = 'No location for this apartment' })
end)
