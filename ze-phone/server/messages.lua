-- Messages. The server owns the conversation: a client says "send this text to that number" and the server builds the
-- message, so nobody can forge what the other side said or rewrite a history.
--
-- Storage is the qb-phone table `phone_messages` (one row per character and conversation partner, the whole conversation
-- as JSON grouped by day), so existing chats keep working. Three columns are added next to it (last_ts, last_text,
-- unread, see db.lua) so the chat list never has to decode a conversation.
--
-- A message: { id, message, time, ts, sender (citizenid), type = 'message' | 'location' | 'picture', data, read }

Msg = {}

local locks = {}

-- two sends between the same people must not interleave their read-modify-write
local function withPair(a, b, fn)
    local key = a < b and (a .. ':' .. b) or (b .. ':' .. a)
    while locks[key] do Wait(5) end
    locks[key] = true
    local ok, err = pcall(fn)
    locks[key] = nil
    if not ok then error(err, 0) end
end

local function loadRow(cid, number)
    local row = MySQL.single.await('SELECT id, messages FROM phone_messages WHERE citizenid = ? AND number = ? LIMIT 1', { cid, number })
    if not row then return nil end
    local convo = json.decode(row.messages or '[]')
    if type(convo) ~= 'table' then convo = {} end
    return { id = row.id, convo = convo }
end

-- qb-phone's messages have no id: give them a stable negative one so they can be addressed
local function normalize(convo)
    for b, bucket in ipairs(convo) do
        if type(bucket.messages) ~= 'table' then bucket.messages = {} end
        for i, m in ipairs(bucket.messages) do
            if not m.id then m.id = -(b * 1000 + i) end
        end
    end
end

local function previewOf(m)
    if m.type == 'picture' then return 'Photo' end
    if m.type == 'location' then return 'Location' end
    local text = tostring(m.message or ''):gsub('%s+', ' ')
    return text:sub(1, 120)
end

local function lastOf(convo)
    for b = #convo, 1, -1 do
        local list = convo[b].messages
        if type(list) == 'table' and #list > 0 then return list[#list] end
    end
    return nil
end

local function trim(convo, max)
    local total = 0
    for _, bucket in ipairs(convo) do total = total + #bucket.messages end
    while total > max and convo[1] do
        local first = convo[1]
        if #first.messages > 0 then
            table.remove(first.messages, 1)
            total = total - 1
        end
        if #first.messages == 0 then table.remove(convo, 1) end
    end
end

local function view(m, myCid, day)
    return {
        id = m.id,
        mine = m.sender == myCid,
        type = m.type or 'message',
        text = m.message or '',
        data = type(m.data) == 'table' and m.data or {},
        time = m.time or '',
        ts = m.ts or 0,
        day = day,
        read = m.read ~= false,
    }
end

local function flatten(convo, myCid)
    local out = {}
    for _, bucket in ipairs(convo) do
        for _, m in ipairs(bucket.messages or {}) do
            out[#out + 1] = view(m, myCid, bucket.date)
        end
    end
    return out
end

-- adds `msg` to the row (or creates it) and refreshes the chat list columns
local function appendTo(row, cid, number, msg, incoming)
    local convo = row and row.convo or {}
    normalize(convo)
    local day = os.date('%Y-%m-%d')
    local bucket = convo[#convo]
    if not bucket or bucket.date ~= day then
        bucket = { date = day, messages = {} }
        convo[#convo + 1] = bucket
    end
    bucket.messages[#bucket.messages + 1] = msg
    trim(convo, Config.Messages.MaxPerChat)

    local preview = (msg.sender == cid and '>' or '<') .. previewOf(msg)
    local encoded = json.encode(convo)
    if row then
        MySQL.update.await('UPDATE phone_messages SET messages = ?, last_ts = ?, last_text = ?, unread = unread + ? WHERE id = ?',
            { encoded, msg.ts * 1000, preview, incoming and 1 or 0, row.id })
    else
        MySQL.insert.await('INSERT INTO phone_messages (citizenid, number, messages, last_ts, last_text, unread) VALUES (?, ?, ?, ?, ?, ?)',
            { cid, number, encoded, msg.ts * 1000, preview, incoming and 1 or 0 })
    end
end

-- marks what `fromCid` sent as read in one row; returns the ids it changed
local function markRead(row, fromCid)
    local ids = {}
    for _, bucket in ipairs(row.convo) do
        for _, m in ipairs(bucket.messages or {}) do
            if m.sender == fromCid and m.read == false then
                m.read = true
                ids[#ids + 1] = m.id
            end
        end
    end
    return ids
end

-- ---------------------------------------------------------------------------------------------------------------------
-- The chat list
-- ---------------------------------------------------------------------------------------------------------------------

function Msg.Summaries(cid)
    local rows = MySQL.query.await('SELECT id, number, last_ts, last_text, unread FROM phone_messages WHERE citizenid = ? ORDER BY id DESC LIMIT 120', { cid }) or {}
    local chats, numbers = {}, {}

    for _, row in ipairs(rows) do
        local lastTs, lastText, unread = row.last_ts, row.last_text, row.unread or 0

        if lastTs == nil then
            -- an old qb-phone conversation: read it once and keep the result in the columns
            local raw = MySQL.scalar.await('SELECT messages FROM phone_messages WHERE id = ?', { row.id })
            local convo = json.decode(raw or '[]')
            if type(convo) ~= 'table' then convo = {} end
            normalize(convo)
            local last = lastOf(convo)
            lastTs = last and (last.ts and last.ts * 1000 or 0) or 0
            lastText = last and ((last.sender == cid and '>' or '<') .. previewOf(last)) or ''
            MySQL.update.await('UPDATE phone_messages SET last_ts = ?, last_text = ? WHERE id = ?', { lastTs, lastText, row.id })
        end

        lastText = lastText or ''
        chats[#chats + 1] = {
            number = row.number,
            mine = lastText:sub(1, 1) == '>',
            text = lastText:sub(2),
            lastTs = tonumber(lastTs) or 0,
            unread = tonumber(unread) or 0,
            rowId = row.id,
        }
        numbers[#numbers + 1] = row.number
    end

    local profiles = Core.Profiles(numbers)
    for _, chat in ipairs(chats) do
        local p = profiles[chat.number]
        chat.picture = p and p.picture or nil
    end

    table.sort(chats, function(a, b)
        if a.lastTs ~= b.lastTs then return a.lastTs > b.lastTs end
        return a.rowId > b.rowId
    end)
    return chats
end

Core.Rpc('messages:list', { rate = 500 }, function(ctx)
    return { chats = Msg.Summaries(ctx.cid) }
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- One conversation
-- ---------------------------------------------------------------------------------------------------------------------

local function otherParty(number)
    if not Core.IsNumber(number) then return nil end
    return Core.CidByNumber(number)
end

-- tells the sender of the messages that they were read
local function pushRead(theirCid, myNumber, ids)
    if #ids == 0 then return end
    Core.PushCid(theirCid, 'messagesRead', { number = myNumber, ids = ids })
end

local function openConversation(ctx, number)
    local theirCid = otherParty(number)
    local result
    withPair(ctx.cid, theirCid or ctx.cid, function()
        local row = loadRow(ctx.cid, number)
        if not row then
            result = { messages = {}, exists = theirCid ~= nil }
            return
        end
        normalize(row.convo)
        local ids = markRead(row, theirCid)
        MySQL.update.await('UPDATE phone_messages SET messages = ?, unread = 0 WHERE id = ?', { json.encode(row.convo), row.id })
        if theirCid and #ids > 0 then
            local theirs = loadRow(theirCid, ctx.number)
            if theirs then
                normalize(theirs.convo)
                markRead(theirs, theirCid)
                MySQL.update.await('UPDATE phone_messages SET messages = ? WHERE id = ?', { json.encode(theirs.convo), theirs.id })
            end
            pushRead(theirCid, ctx.number, ids)
        end
        local flat = flatten(row.convo, ctx.cid)
        -- the chat can be long: send the last 250
        if #flat > 250 then
            local cut = {}
            for i = #flat - 249, #flat do cut[#cut + 1] = flat[i] end
            flat = cut
        end
        result = { messages = flat, exists = theirCid ~= nil }
    end)
    return result
end

Core.Rpc('messages:open', { rate = 300 }, function(ctx, a)
    local number = Core.Digits(a.number)
    if not Core.IsNumber(number) then return { error = 'That is not a valid phone number' } end
    return openConversation(ctx, number)
end)

-- the chat is open and a new message arrived: mark it read without sending the whole chat again
Core.Rpc('messages:read', { rate = 200 }, function(ctx, a)
    local number = Core.Digits(a.number)
    local theirCid = otherParty(number)
    if not theirCid then return end
    withPair(ctx.cid, theirCid, function()
        local row = loadRow(ctx.cid, number)
        if not row then return end
        normalize(row.convo)
        local ids = markRead(row, theirCid)
        MySQL.update.await('UPDATE phone_messages SET messages = ?, unread = 0 WHERE id = ?', { json.encode(row.convo), row.id })
        if #ids > 0 then
            local theirs = loadRow(theirCid, ctx.number)
            if theirs then
                normalize(theirs.convo)
                markRead(theirs, theirCid)
                MySQL.update.await('UPDATE phone_messages SET messages = ? WHERE id = ?', { json.encode(theirs.convo), theirs.id })
            end
            pushRead(theirCid, ctx.number, ids)
        end
    end)
end)

Core.Rpc('messages:send', { rate = 350 }, function(ctx, a)
    local number = Core.Digits(a.number)
    if not Core.IsNumber(number) then return { error = 'That is not a valid phone number' } end
    if number == ctx.number then return { error = 'You cannot message yourself' } end

    local settings = Core.GetSettings(ctx.Player.PlayerData)
    if settings.airplane then return { error = 'Airplane mode is on' } end
    if not Core.HasPhone(ctx.src) then return { error = 'You do not have a phone' } end

    local kind = a.type
    local text, data = '', {}
    if kind == 'location' then
        local ped = GetPlayerPed(ctx.src)
        local at = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
        if not at then return { error = 'Your location is not available' } end
        text = 'Shared location'
        data = { x = math.floor(at.x * 10) / 10, y = math.floor(at.y * 10) / 10 }
    elseif kind == 'picture' then
        local url = Core.SafeUrl(a.url, 500)
        if not url then return { error = 'That photo cannot be sent' } end
        text = 'Photo'
        data = { url = url }
    else
        kind = 'message'
        text = Core.Clean(a.text, Config.Messages.MaxLength)
        if text == '' then return { error = 'The message is empty' } end
    end

    local theirCid = Core.CidByNumber(number)
    if not theirCid then return { error = 'This number does not exist' } end

    local ts = os.time()
    local msg = {
        id = ts * 1000 + math.random(0, 999),
        message = text,
        time = os.date('%H:%M'),
        ts = ts,
        sender = ctx.cid,
        type = kind,
        data = data,
        read = false,
    }

    withPair(ctx.cid, theirCid, function()
        appendTo(loadRow(ctx.cid, number), ctx.cid, number, msg, false)

        if not Blocked.Has(theirCid, ctx.number) then
            appendTo(loadRow(theirCid, ctx.number), theirCid, ctx.number, msg, true)

            local on = Core.OnlineByCid(theirCid)
            if on then
                Core.Push(on.src, 'message', { number = ctx.number, message = view(msg, theirCid, os.date('%Y-%m-%d')) })
            end
        end
    end)

    return { message = view(msg, ctx.cid, os.date('%Y-%m-%d')) }
end)

Core.Rpc('messages:delete', { rate = 200 }, function(ctx, a)
    local number = Core.Digits(a.number)
    local id = tonumber(a.id)
    if not Core.IsNumber(number) or not id then return { error = 'Message not found' } end
    local row = loadRow(ctx.cid, number)
    if not row then return end
    normalize(row.convo)
    for b = #row.convo, 1, -1 do
        local list = row.convo[b].messages
        for i = #list, 1, -1 do
            if list[i].id == id then table.remove(list, i) end
        end
        if #list == 0 then table.remove(row.convo, b) end
    end
    local last = lastOf(row.convo)
    MySQL.update.await('UPDATE phone_messages SET messages = ?, last_ts = ?, last_text = ? WHERE id = ?', {
        json.encode(row.convo),
        last and ((last.ts or 0) * 1000) or 0,
        last and ((last.sender == ctx.cid and '>' or '<') .. previewOf(last)) or '',
        row.id,
    })
end)

Core.Rpc('messages:clear', { rate = 300 }, function(ctx, a)
    local number = Core.Digits(a.number)
    if not Core.IsNumber(number) then return end
    MySQL.query.await('DELETE FROM phone_messages WHERE citizenid = ? AND number = ?', { ctx.cid, number })
end)
