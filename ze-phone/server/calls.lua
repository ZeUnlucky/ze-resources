-- Phone calls. The server holds the state of every call (qb-phone left it to the two clients, which got stuck when
-- somebody disconnected and shared voice channels between unrelated calls). One call = one id = one voice channel.
--
-- Client -> server: callback 'ze-phone:server:call', events 'ze-phone:server:answer' and 'ze-phone:server:hangup'
-- Server -> client: 'ze-phone:client:incoming', 'ze-phone:client:callState', 'ze-phone:client:callEnded'

local QBCore = exports['qb-core']:GetCoreObject()

Calls = {}

local active = {}       -- [id] = call
local inCall = {}       -- [src] = id
local nextId = 0

-- a call: { id, caller, callee (sources), callerCid, calleeCid, callerNumber, calleeNumber, anonymous, state, silent, blocked, answeredAt }

local function logCall(cid, number, direction, duration, anonymous)
    MySQL.insert('INSERT INTO phone_calls (citizenid, number, direction, duration, anonymous, seen) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, number, direction, duration or 0, anonymous and 1 or 0, direction == 'missed' and 0 or 1 })
    MySQL.query('DELETE FROM phone_calls WHERE citizenid = ? AND id NOT IN (SELECT id FROM (SELECT id FROM phone_calls WHERE citizenid = ? ORDER BY id DESC LIMIT ?) AS keep)',
        { cid, cid, Config.Calls.History })
end

function Calls.History(cid)
    local rows = MySQL.query.await(
        'SELECT id, number, direction, duration, anonymous, seen, UNIX_TIMESTAMP(created) AS ts FROM phone_calls WHERE citizenid = ? ORDER BY id DESC LIMIT ?',
        { cid, Config.Calls.History }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            number = row.number,
            direction = row.direction,
            duration = row.duration or 0,
            anonymous = row.anonymous == 1 or row.anonymous == true,
            seen = row.seen == 1 or row.seen == true,
            ts = (tonumber(row.ts) or 0) * 1000,
        }
    end
    return list
end

-- reason: 'hangup', 'declined', 'cancelled', 'missed', 'dropped'. `by` is the source that ended it (nil: nobody, e.g. a timeout).
local function finish(id, reason, by)
    local c = active[id]
    if not c then return end
    active[id] = nil
    if inCall[c.caller] == id then inCall[c.caller] = nil end
    if inCall[c.callee] == id then inCall[c.callee] = nil end

    local now = os.time()
    local duration = c.answeredAt and (now - c.answeredAt) or 0
    local callerAnon = c.anonymous

    local callerLog = { number = c.calleeNumber, direction = 'outgoing', duration = duration, anonymous = false, ts = now * 1000 }
    local calleeLog = {
        number = (not callerAnon) and c.callerNumber or nil,
        direction = c.answeredAt and 'incoming' or 'missed',
        duration = duration,
        anonymous = callerAnon,
        ts = now * 1000,
    }

    logCall(c.callerCid, callerLog.number, callerLog.direction, duration, false)
    if not c.blocked then
        logCall(c.calleeCid, calleeLog.number, calleeLog.direction, duration, callerAnon)
    end

    TriggerClientEvent('ze-phone:client:callEnded', c.caller, {
        id = id, reason = reason, duration = duration, by = (by == c.caller) and 'you' or (by and 'them' or 'nobody'), log = callerLog,
    })
    if not c.silent then
        TriggerClientEvent('ze-phone:client:callEnded', c.callee, {
            id = id, reason = reason, duration = duration, by = (by == c.callee) and 'you' or (by and 'them' or 'nobody'), log = calleeLog,
        })
    elseif not c.blocked then
        -- a call on do not disturb: no ring, but the missed call is in the list
        Core.Push(c.callee, 'callLogged', { log = calleeLog })
    end
end

Core.OnDrop = function(src)
    local id = inCall[src]
    if id then finish(id, 'dropped', src) end
end

QBCore.Functions.CreateCallback('ze-phone:server:call', function(src, cb, number, anonymous)
    local me = Core.Online(src)
    if not me then return cb({ error = 'Not logged in' }) end
    if not Core.RateOk(src, 'call', 1500) then return cb({ error = 'Slow down a little' }) end

    number = Core.Digits(number)
    if not Core.IsNumber(number) then return cb({ error = 'That is not a valid phone number' }) end
    if number == me.number then return cb({ error = 'You cannot call yourself' }) end
    if inCall[src] then return cb({ error = 'You are already in a call' }) end

    local Player = Core.Player(src)
    if not Player then return cb({ error = 'Not logged in' }) end
    local mine = Core.GetSettings(Player.PlayerData)
    if mine.airplane then return cb({ error = 'Airplane mode is on' }) end
    if not Core.HasPhone(src) then return cb({ error = 'You do not have a phone' }) end

    local target = Core.OnlineByNumber(number)
    if not target or not Core.HasPhone(target.src) then
        return cb({ error = 'This number is not available', code = 'unavailable' })
    end
    if inCall[target.src] then
        return cb({ error = 'This person is busy', code = 'busy' })
    end

    local TargetPlayer = Core.Player(target.src)
    if not TargetPlayer then return cb({ error = 'This number is not available', code = 'unavailable' }) end
    local theirs = Core.GetSettings(TargetPlayer.PlayerData)
    if theirs.airplane then
        return cb({ error = 'This number is not available', code = 'unavailable' })
    end

    local blocked = Blocked.Has(target.cid, me.number)
    local silent = blocked or theirs.dnd

    nextId = nextId + 1
    local id = nextId
    anonymous = anonymous == true

    active[id] = {
        id = id,
        caller = src,
        callee = target.src,
        callerCid = me.cid,
        calleeCid = target.cid,
        callerNumber = me.number,
        calleeNumber = number,
        anonymous = anonymous,
        state = 'ringing',
        silent = silent,
        blocked = blocked,
    }
    inCall[src] = id
    if not silent then inCall[target.src] = id end

    if not silent then
        TriggerClientEvent('ze-phone:client:incoming', target.src, {
            id = id,
            number = (not anonymous) and me.number or nil,
            anonymous = anonymous,
            picture = (not anonymous) and me.picture or nil,
        })
    end

    SetTimeout(Config.Calls.RingTime * 1000, function()
        local c = active[id]
        if c and c.state == 'ringing' then finish(id, 'missed', nil) end
    end)

    cb({ ok = true, id = id })
end)

RegisterNetEvent('ze-phone:server:answer', function()
    local src = source
    local id = inCall[src]
    local c = id and active[id]
    if not c or c.callee ~= src or c.state ~= 'ringing' or c.silent then return end

    c.state = 'active'
    c.answeredAt = os.time()
    local info = { id = id, since = c.answeredAt }
    TriggerClientEvent('ze-phone:client:callState', c.caller, 'active', info)
    TriggerClientEvent('ze-phone:client:callState', c.callee, 'active', info)
end)

RegisterNetEvent('ze-phone:server:hangup', function()
    local src = source
    local id = inCall[src]
    local c = id and active[id]
    if not c then return end

    local reason = 'hangup'
    if c.state == 'ringing' then
        reason = (c.caller == src) and 'cancelled' or 'declined'
    end
    finish(id, reason, src)
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Call list
-- ---------------------------------------------------------------------------------------------------------------------

Core.Rpc('calls:seen', { rate = 500 }, function(ctx)
    MySQL.update.await('UPDATE phone_calls SET seen = 1 WHERE citizenid = ? AND seen = 0', { ctx.cid })
end)

Core.Rpc('calls:delete', { rate = 200 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return end
    MySQL.query.await('DELETE FROM phone_calls WHERE id = ? AND citizenid = ?', { id, ctx.cid })
end)

Core.Rpc('calls:clear', { rate = 1000 }, function(ctx)
    MySQL.query.await('DELETE FROM phone_calls WHERE citizenid = ?', { ctx.cid })
end)

Core.Rpc('calls:list', { rate = 500 }, function(ctx)
    return { calls = Calls.History(ctx.cid) }
end)
