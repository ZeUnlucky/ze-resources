-- Mail. Other resources send mail through `exports['qb-phone']:sendNewMailToOffline(citizenid, mailData)` or the
-- 'qb-phone:server:sendNewMail' event (see compat.lua); both end up in Mail.Send.
--
-- mailData: { sender, subject, message (a little HTML is fine), button = { buttonEvent, buttonData } }

Mail = {}

-- sender and subject are varchar(50) in the table
function Mail.Send(cid, data)
    if type(cid) ~= 'string' or type(data) ~= 'table' then return false end

    local sender = Core.Clean(tostring(data.sender or 'Unknown'), 50)
    local subject = Core.Clean(tostring(data.subject or ''), 50)
    local message = Core.Clean(tostring(data.message or ''), 4000)

    -- a mail without an event gets no button (qb-phone stored `{}` for those and then showed a button that did nothing)
    local button = nil
    if type(data.button) == 'table' and type(data.button.buttonEvent) == 'string' and data.button.buttonEvent ~= '' then
        button = json.encode({ buttonEvent = data.button.buttonEvent, buttonData = data.button.buttonData })
    end

    -- no waiting here: other resources call this through an export, and a yield inside an export would hand them
    -- an answer before the work is done. The player is told once the row is in.
    local mailid = math.random(111111, 999999)
    MySQL.insert('INSERT INTO player_mails (citizenid, sender, subject, message, mailid, `read`, button) VALUES (?, ?, ?, ?, ?, 0, ?)',
        { cid, sender, subject, message, mailid, button }, function()
            local on = Core.OnlineByCid(cid)
            if on then
                Core.Push(on.src, 'mail', {
                    mailid = mailid,
                    sender = sender,
                    subject = subject,
                    message = message,
                    read = false,
                    hasButton = button ~= nil,
                    ts = os.time() * 1000,
                })
            end
        end)
    return true
end

Core.Rpc('mail:list', { rate = 600 }, function(ctx)
    local rows = MySQL.query.await([[
        SELECT mailid, sender, subject, message, `read`, UNIX_TIMESTAMP(`date`) AS ts,
               (button IS NOT NULL AND button <> '' AND button <> '[]' AND button <> '{}') AS hasButton
        FROM player_mails WHERE citizenid = ? ORDER BY `date` DESC, id DESC LIMIT 60]], { ctx.cid }) or {}
    local mails = {}
    for _, row in ipairs(rows) do
        mails[#mails + 1] = {
            mailid = row.mailid,
            sender = row.sender or '',
            subject = row.subject or '',
            message = row.message or '',
            read = row.read == 1 or row.read == true,
            hasButton = row.hasButton == 1 or row.hasButton == true,
            ts = (tonumber(row.ts) or 0) * 1000,
        }
    end
    return { mails = mails }
end)

Core.Rpc('mail:read', { rate = 120 }, function(ctx, a)
    local id = Core.ToInt(a.mailid, 1)
    if not id then return end
    MySQL.update.await('UPDATE player_mails SET `read` = 1 WHERE citizenid = ? AND mailid = ?', { ctx.cid, id })
end)

Core.Rpc('mail:readAll', { rate = 500 }, function(ctx)
    MySQL.update.await('UPDATE player_mails SET `read` = 1 WHERE citizenid = ?', { ctx.cid })
end)

Core.Rpc('mail:delete', { rate = 150 }, function(ctx, a)
    local id = Core.ToInt(a.mailid, 1)
    if not id then return end
    MySQL.query.await('DELETE FROM player_mails WHERE citizenid = ? AND mailid = ?', { ctx.cid, id })
end)

-- Returns the stored button once and clears it. The client then triggers the event itself (the way qb-phone did).
Core.Rpc('mail:button', { rate = 300 }, function(ctx, a)
    local id = Core.ToInt(a.mailid, 1)
    if not id then return { error = 'Mail not found' } end
    local raw = MySQL.scalar.await('SELECT button FROM player_mails WHERE citizenid = ? AND mailid = ? LIMIT 1', { ctx.cid, id })
    local button = raw and raw ~= '' and json.decode(raw) or nil
    if type(button) ~= 'table' or type(button.buttonEvent) ~= 'string' then
        return { error = 'This mail has no action' }
    end
    MySQL.update.await('UPDATE player_mails SET button = NULL, `read` = 1 WHERE citizenid = ? AND mailid = ?', { ctx.cid, id })
    return { event = button.buttonEvent, data = button.buttonData }
end)
