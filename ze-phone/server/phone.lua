-- What the UI loads when it starts (one request, its queries run in parallel), settings, notes and nearby players.

-- Everything the home screen needs. The apps load their own data when they are opened.
Core.Rpc('boot', { rate = 1000 }, function(ctx)
    local cid = ctx.cid
    local q = DB.Parallel({
        { 'SELECT id, name, number, iban FROM player_contacts WHERE citizenid = ? ORDER BY name ASC', { cid } },
        { 'SELECT number FROM phone_blocked WHERE citizenid = ?', { cid } },
        { 'SELECT COUNT(*) AS c FROM player_mails WHERE citizenid = ? AND `read` = 0', { cid } },
        { 'SELECT COUNT(*) AS c FROM phone_invoices WHERE citizenid = ?', { cid } },
    })

    local contacts = {}
    for _, row in ipairs(q[1]) do
        contacts[#contacts + 1] = {
            id = row.id,
            name = row.name or '',
            number = row.number or '',
            iban = (row.iban and row.iban ~= '0') and row.iban or '',
            online = Core.OnlineByNumber(row.number) ~= nil,
        }
    end

    local blocked = {}
    for _, row in ipairs(q[2]) do blocked[#blocked + 1] = row.number end

    local chats = Msg.Summaries(cid)
    local unreadMessages = 0
    for _, chat in ipairs(chats) do unreadMessages = unreadMessages + chat.unread end

    local calls = Calls.History(cid)
    local missed = 0
    for _, call in ipairs(calls) do
        if call.direction == 'missed' and not call.seen then missed = missed + 1 end
    end

    local data = ctx.Player.PlayerData
    local meta = data.metadata or {}
    local settings = Core.GetSettings(data)

    return {
        settings = settings,
        contacts = contacts,
        blocked = blocked,
        chats = chats,
        calls = calls,
        adverts = Social.AdvertList(),
        unread = {
            messages = unreadMessages,
            mail = (q[3][1] and q[3][1].c) or 0,
            phone = missed,
            bank = (q[4][1] and q[4][1].c) or 0,
        },
        me = {
            name = ctx.name,
            first = ctx.first,
            last = ctx.last,
            number = ctx.number,
            account = data.charinfo and data.charinfo.account or '',
            citizenid = cid,
            serial = meta.phonedata and meta.phonedata.SerialNumber or '',
            picture = settings.profilepicture,
            mdt = Core.CanMDT(data),
        },
    }
end)

Core.Rpc('settings:save', { rate = 150 }, function(ctx, a)
    local settings = Core.SaveSettings(ctx, type(a.patch) == 'table' and a.patch or {})
    return { settings = settings }
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Notes
-- ---------------------------------------------------------------------------------------------------------------------

local MaxNotes = 100

Core.Rpc('notes:list', function(ctx)
    local rows = MySQL.query.await(
        'SELECT id, title, body, color, pinned, UNIX_TIMESTAMP(updated) AS updated FROM phone_notes WHERE citizenid = ? ORDER BY pinned DESC, updated DESC LIMIT ' .. MaxNotes,
        { ctx.cid }) or {}
    local notes = {}
    for _, row in ipairs(rows) do
        notes[#notes + 1] = {
            id = row.id,
            title = row.title or '',
            body = row.body or '',
            color = row.color,
            pinned = row.pinned == 1 or row.pinned == true,
            updated = tonumber(row.updated) or 0,
        }
    end
    return { notes = notes }
end)

Core.Rpc('notes:save', { rate = 250 }, function(ctx, a)
    local title = Core.Clean(a.title, 80)
    local body = Core.Clean(a.body, 4000)
    if title == '' and body == '' then return { error = 'The note is empty' } end
    local color = (type(a.color) == 'string' and a.color:find('^#%x%x%x%x%x%x$')) and a.color or nil
    local pinned = a.pinned and 1 or 0

    local id = Core.ToInt(a.id, 1)
    if id then
        local changed = MySQL.update.await(
            'UPDATE phone_notes SET title = ?, body = ?, color = ?, pinned = ?, updated = NOW() WHERE id = ? AND citizenid = ?',
            { title, body, color, pinned, id, ctx.cid })
        if not changed or changed == 0 then return { error = 'Note not found' } end
    else
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_notes WHERE citizenid = ?', { ctx.cid }) or 0
        if count >= MaxNotes then return { error = 'You have too many notes' } end
        id = MySQL.insert.await('INSERT INTO phone_notes (citizenid, title, body, color, pinned) VALUES (?, ?, ?, ?, ?)',
            { ctx.cid, title, body, color, pinned })
    end
    return { id = id }
end)

Core.Rpc('notes:delete', { rate = 250 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return { error = 'Note not found' } end
    MySQL.query.await('DELETE FROM phone_notes WHERE id = ? AND citizenid = ?', { id, ctx.cid })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Players near the caller (invoices, sharing a contact)
-- ---------------------------------------------------------------------------------------------------------------------

function Core.Distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if not pa or pa == 0 or not pb or pb == 0 then return nil end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end

Core.Rpc('players:nearby', { rate = 500 }, function(ctx, a)
    local radius = math.min(tonumber(a.radius) or 10.0, 30.0)
    local players = {}
    for src, me in pairs(Core.AllOnline()) do
        if src ~= ctx.src then
            local distance = Core.Distance(ctx.src, src)
            if distance and distance <= radius then
                players[#players + 1] = {
                    id = src,
                    name = Core.FullName(me.first, me.last),
                    picture = me.picture,
                    distance = math.floor(distance * 10) / 10,
                }
            end
        end
    end
    table.sort(players, function(x, y) return x.distance < y.distance end)
    return { players = players }
end)
