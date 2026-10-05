-- Contacts, blocked numbers and sharing your own contact card with someone nearby.

local MaxContacts = 300
local MaxBlocked = 100

local function cleanContact(a)
    local name = Core.Clean(a.name, 50)
    local number = Core.Digits(a.number)
    local iban = Core.Clean(a.iban, 50)
    if name == '' then return nil, 'Give the contact a name' end
    if not Core.IsNumber(number) then return nil, 'That is not a valid phone number' end
    return { name = name, number = number, iban = iban ~= '' and iban or '0' }
end

local function publicContact(id, c)
    return {
        id = id,
        name = c.name,
        number = c.number,
        iban = c.iban ~= '0' and c.iban or '',
        online = Core.OnlineByNumber(c.number) ~= nil,
    }
end

Core.Rpc('contacts:add', { rate = 250 }, function(ctx, a)
    local c, err = cleanContact(a)
    if not c then return { error = err } end
    if c.number == ctx.number then return { error = 'That is your own number' } end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_contacts WHERE citizenid = ?', { ctx.cid }) or 0
    if count >= MaxContacts then return { error = 'Your contact list is full' } end

    local existing = MySQL.scalar.await('SELECT id FROM player_contacts WHERE citizenid = ? AND number = ? LIMIT 1', { ctx.cid, c.number })
    if existing then return { error = 'That number is already in your contacts' } end

    local id = MySQL.insert.await('INSERT INTO player_contacts (citizenid, name, number, iban) VALUES (?, ?, ?, ?)',
        { ctx.cid, c.name, c.number, c.iban })
    return { contact = publicContact(id, c) }
end)

Core.Rpc('contacts:edit', { rate = 250 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return { error = 'Contact not found' } end
    local c, err = cleanContact(a)
    if not c then return { error = err } end

    local clash = MySQL.scalar.await('SELECT id FROM player_contacts WHERE citizenid = ? AND number = ? AND id <> ? LIMIT 1', { ctx.cid, c.number, id })
    if clash then return { error = 'That number is already in your contacts' } end

    local changed = MySQL.update.await('UPDATE player_contacts SET name = ?, number = ?, iban = ? WHERE id = ? AND citizenid = ?',
        { c.name, c.number, c.iban, id, ctx.cid })
    if not changed or changed == 0 then return { error = 'Contact not found' } end
    return { contact = publicContact(id, c) }
end)

Core.Rpc('contacts:delete', { rate = 250 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return { error = 'Contact not found' } end
    MySQL.query.await('DELETE FROM player_contacts WHERE id = ? AND citizenid = ?', { id, ctx.cid })
end)

Core.Rpc('contacts:block', { rate = 250 }, function(ctx, a)
    local number = Core.Digits(a.number)
    if not Core.IsNumber(number) then return { error = 'That is not a valid phone number' } end
    if a.on then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM phone_blocked WHERE citizenid = ?', { ctx.cid }) or 0
        if count >= MaxBlocked then return { error = 'Your block list is full' } end
        MySQL.query.await('INSERT IGNORE INTO phone_blocked (citizenid, number) VALUES (?, ?)', { ctx.cid, number })
    else
        MySQL.query.await('DELETE FROM phone_blocked WHERE citizenid = ? AND number = ?', { ctx.cid, number })
    end
    Blocked.Drop(ctx.cid)
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Blocked numbers as the others need them: has `cid` blocked `number`? (cached, dropped when the list changes)
-- ---------------------------------------------------------------------------------------------------------------------

Blocked = {}
local blockedCache = {}   -- [cid] = { [number] = true }

function Blocked.Has(cid, number)
    local set = blockedCache[cid]
    if not set then
        set = {}
        local rows = MySQL.query.await('SELECT number FROM phone_blocked WHERE citizenid = ?', { cid }) or {}
        for _, row in ipairs(rows) do set[row.number] = true end
        blockedCache[cid] = set
    end
    return set[number] == true
end

function Blocked.Drop(cid)
    blockedCache[cid] = nil
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Sharing your contact card
-- ---------------------------------------------------------------------------------------------------------------------

local function shareWith(fromSrc, toSrc)
    local from, to = Core.Online(fromSrc), Core.Online(toSrc)
    if not from or not to or fromSrc == toSrc then return false, 'Nobody there' end
    local distance = Core.Distance(fromSrc, toSrc)
    if not distance or distance > 6.0 then return false, 'They are too far away' end
    if not Core.HasPhone(toSrc) then return false, 'They have no phone' end

    Core.Push(toSrc, 'contactShared', {
        name = Core.FullName(from.first, from.last),
        number = from.number,
        iban = from.account or '',
    })
    return true
end

Core.Rpc('contacts:share', { rate = 1500 }, function(ctx, a)
    local target = Core.ToInt(a.id, 1)
    if not target then return { error = 'Nobody there' } end
    local ok, err = shareWith(ctx.src, target)
    if not ok then return { error = err } end
end)

-- qb-radialmenu's "give contact details" asks the player's client for the nearest player and sends the id here
RegisterNetEvent('qb-phone:server:GiveContactDetails', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end
    local ok, err = shareWith(src, targetId)
    if not ok then Core.Notify(src, err, 'error') end
end)
