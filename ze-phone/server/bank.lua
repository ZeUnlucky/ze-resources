-- Bank: balance and transfers, invoices (pay, decline, create) and the crypto transaction list.
-- Amounts always come from the database or are checked here: the client only says which invoice or which account.

local QBCore = exports['qb-core']:GetCoreObject()

Bank = {}

local function freshBalance(src, kind)
    local Player = Core.Player(src)
    return Player and Player.PlayerData.money[kind or 'bank'] or 0
end

-- adds money to a character that may be offline, in one statement (no read-modify-write)
local function creditOffline(cid, amount)
    local changed = MySQL.update.await("UPDATE players SET money = JSON_SET(money, '$.bank', JSON_EXTRACT(money, '$.bank') + ?) WHERE citizenid = ?", { amount, cid })
    return changed and changed > 0
end

local function creditCitizen(cid, amount, reason)
    local on = Core.OnlineByCid(cid)
    if on then
        local Player = Core.Player(on.src)
        if Player and Player.Functions.AddMoney('bank', amount, reason) then return true end
    end
    return creditOffline(cid, amount)
end

local function pushHistory(cid, kind, amount, other, note)
    MySQL.insert('INSERT INTO phone_transactions (citizenid, kind, amount, other, note) VALUES (?, ?, ?, ?, ?)',
        { cid, kind, amount, other, note })
    MySQL.query('DELETE FROM phone_transactions WHERE citizenid = ? AND id NOT IN (SELECT id FROM (SELECT id FROM phone_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT ?) AS keep)',
        { cid, cid, Config.Bank.History })
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Overview and transfers
-- ---------------------------------------------------------------------------------------------------------------------

Core.Rpc('bank:overview', { rate = 600 }, function(ctx)
    local money = ctx.Player.PlayerData.money or {}
    local rows = MySQL.query.await(
        'SELECT kind, amount, other, note, UNIX_TIMESTAMP(created) AS ts FROM phone_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT ?',
        { ctx.cid, Config.Bank.History }) or {}
    local history = {}
    for _, row in ipairs(rows) do
        history[#history + 1] = { kind = row.kind, amount = row.amount, other = row.other or '', note = row.note or '', ts = (tonumber(row.ts) or 0) * 1000 }
    end
    return {
        cash = money.cash or 0,
        bank = money.bank or 0,
        crypto = money.crypto or 0,
        account = ctx.Player.PlayerData.charinfo and ctx.Player.PlayerData.charinfo.account or '',
        history = history,
    }
end)

Core.Rpc('bank:transfer', { rate = 1200 }, function(ctx, a)
    local amount = Core.ToInt(a.amount, 1, Config.Bank.MaxTransfer)
    if not amount then
        return { error = ('Enter an amount between $1 and $%d'):format(Config.Bank.MaxTransfer) }
    end
    local to = Core.Clean(tostring(a.to or ''), 40):gsub('%s+', '')
    if to == '' then return { error = 'Enter the account number' } end
    local note = Core.Clean(tostring(a.note or ''), 120)

    local settings = Core.GetSettings(ctx.Player.PlayerData)
    if settings.airplane then return { error = 'Airplane mode is on' } end

    local info = ctx.Player.PlayerData.charinfo or {}
    if tostring(info.account) == to then return { error = 'You cannot transfer to yourself' } end

    -- who owns the account?
    local targetCid, targetName
    for _, me in pairs(Core.AllOnline()) do
        if me.account == to then
            targetCid, targetName = me.cid, Core.FullName(me.first, me.last)
            break
        end
    end
    if not targetCid then
        local row = MySQL.single.await("SELECT citizenid, charinfo FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.account')) = ? LIMIT 1", { to })
        if row then
            local ci = json.decode(row.charinfo or '{}') or {}
            targetCid, targetName = row.citizenid, Core.FullName(ci.firstname, ci.lastname)
        end
    end
    if not targetCid then return { error = 'This account number does not exist' } end
    if targetCid == ctx.cid then return { error = 'You cannot transfer to yourself' } end

    if not ctx.Player.Functions.RemoveMoney('bank', amount, 'phone-transfer-to-' .. targetCid) then
        return { error = 'You do not have enough money in your bank' }
    end
    if not creditCitizen(targetCid, amount, 'phone-transfer-from-' .. ctx.cid) then
        ctx.Player.Functions.AddMoney('bank', amount, 'phone-transfer-refund')
        return { error = 'The transfer failed' }
    end

    pushHistory(ctx.cid, 'out', amount, targetName, note)
    pushHistory(targetCid, 'in', amount, ctx.name, note)

    local on = Core.OnlineByCid(targetCid)
    if on then
        Core.Push(on.src, 'bankIn', { amount = amount, from = ctx.name, note = note, bank = freshBalance(on.src) })
    end
    return { ok = true, bank = freshBalance(ctx.src), to = targetName }
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Invoices
-- ---------------------------------------------------------------------------------------------------------------------

local function discordLog(text)
    local hook = ConfigServer.InvoiceLogWebhook
    if not hook or hook == '' then return end
    PerformHttpRequest(hook, function() end, 'POST', json.encode({ content = text }), { ['Content-Type'] = 'application/json' })
end

Core.Rpc('invoices:list', { rate = 600 }, function(ctx)
    local rows = MySQL.query.await('SELECT id, amount, society, sender, candecline, reason FROM phone_invoices WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { ctx.cid }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = {
            id = row.id,
            amount = row.amount,
            society = row.society or '',
            sender = row.sender or '',
            candecline = row.candecline == 1,
            reason = type(row.reason) == 'string' and row.reason or '',
        }
    end
    return { invoices = list }
end)

Core.Rpc('invoices:pay', { rate = 1000 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return { error = 'Invoice not found' } end

    local row = MySQL.single.await('SELECT id, amount, society, sender, sendercitizenid FROM phone_invoices WHERE id = ? AND citizenid = ?', { id, ctx.cid })
    if not row then return { error = 'Invoice not found' } end
    local amount, society = row.amount, row.society

    if not ctx.Player.Functions.RemoveMoney('bank', amount, 'paid-invoice') then
        return { error = 'You do not have enough money in your bank' }
    end
    local removed = MySQL.update.await('DELETE FROM phone_invoices WHERE id = ? AND citizenid = ?', { id, ctx.cid })
    if not removed or removed == 0 then
        ctx.Player.Functions.AddMoney('bank', amount, 'paid-invoice-refund')
        return { error = 'Invoice not found' }
    end

    local rate = Config.Billing.Commissions[society]
    local mail
    if rate and row.sendercitizenid then
        local commission = QBCore.Shared.Round(amount * rate)
        if commission > 0 then creditCitizen(row.sendercitizenid, commission, 'invoice-commission') end
        mail = {
            sender = 'Billing Department',
            subject = 'Commission received',
            message = ('You received a commission of $%s when %s paid a bill of $%s.'):format(commission, ctx.name, amount),
        }
    else
        mail = {
            sender = 'Billing Department',
            subject = 'Invoice paid',
            message = ('%s paid an invoice of $%s.'):format(ctx.name, amount),
        }
    end
    if row.sendercitizenid then Mail.Send(row.sendercitizenid, mail) end

    pushHistory(ctx.cid, 'out', amount, society, 'Invoice')
    pcall(function() exports['qb-banking']:AddMoney(society, amount, 'Phone invoice') end)
    TriggerEvent('qb-phone:server:paidInvoice', ctx.src, id)
    discordLog(('%s (%s) paid an invoice of $%s to %s.'):format(ctx.name, ctx.cid, amount, society))

    return { ok = true, bank = freshBalance(ctx.src) }
end)

Core.Rpc('invoices:decline', { rate = 600 }, function(ctx, a)
    local id = Core.ToInt(a.id, 1)
    if not id then return { error = 'Invoice not found' } end
    local row = MySQL.single.await('SELECT id, amount, sendercitizenid FROM phone_invoices WHERE id = ? AND citizenid = ? AND candecline = 1', { id, ctx.cid })
    if not row then return { error = 'This invoice cannot be declined' } end

    TriggerEvent('qb-phone:server:declinedInvoice', ctx.src, id)
    MySQL.query.await('DELETE FROM phone_invoices WHERE id = ? AND citizenid = ?', { id, ctx.cid })
    if row.sendercitizenid then
        Mail.Send(row.sendercitizenid, {
            sender = 'Billing Department',
            subject = 'Invoice declined',
            message = ('%s declined an invoice of $%s.'):format(ctx.name, row.amount),
        })
    end
    return { ok = true }
end)

-- billerSrc sends an invoice to billedSrc. Returns true, or false and a message.
function Bank.CreateInvoice(billerSrc, billedSrc, amount, reason, needNear)
    if not billerSrc or not billedSrc then return false, 'Player not online' end
    local biller = Core.Player(billerSrc)
    local billed = Core.Player(billedSrc)
    if not biller or not billed then return false, 'Player not online' end

    local job = biller.PlayerData.job or {}
    if not Config.Billing.Jobs[job.name] then return false, 'No access' end
    if not job.onduty then return false, 'You have to be on duty' end
    if biller.PlayerData.citizenid == billed.PlayerData.citizenid then return false, 'You cannot bill yourself' end

    amount = Core.ToInt(amount, 1, Config.Billing.MaxAmount)
    if not amount then return false, ('The amount has to be between $1 and $%d'):format(Config.Billing.MaxAmount) end

    if needNear then
        local distance = Core.Distance(billerSrc, billedSrc)
        if not distance or distance > 10.0 then return false, 'They are not close enough' end
    end

    reason = Core.Clean(tostring(reason or ''), 120)
    local id = MySQL.insert.await(
        'INSERT INTO phone_invoices (citizenid, amount, society, sender, sendercitizenid, reason) VALUES (?, ?, ?, ?, ?, ?)',
        { billed.PlayerData.citizenid, amount, job.name, biller.PlayerData.charinfo.firstname, biller.PlayerData.citizenid, reason ~= '' and reason or nil })

    Core.Push(billedSrc, 'invoice', { id = id, amount = amount, society = job.name, sender = biller.PlayerData.charinfo.firstname, reason = reason })
    Core.Notify(billedSrc, 'You received a new invoice')
    return true
end

Core.Rpc('invoices:create', { rate = 1500 }, function(ctx, a)
    local target = Core.ToInt(a.id, 1)
    if not target then return { error = 'Choose who to bill' } end
    local ok, err = Bank.CreateInvoice(ctx.src, target, a.amount, a.reason, true)
    if not ok then return { error = err } end
    return { ok = true }
end)

QBCore.Commands.Add('bill', 'Bill a player', {
    { name = 'id', help = 'Player ID' },
    { name = 'amount', help = 'Amount' },
}, false, function(source, args)
    local ok, err = Bank.CreateInvoice(source, tonumber(args[1]), args[2], nil, false)
    if ok then
        Core.Notify(source, 'Invoice successfully sent', 'success')
    else
        Core.Notify(source, err, 'error')
    end
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Crypto transactions (qb-crypto tells the client, the client tells us)
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNetEvent('ze-phone:server:addTransaction', function(title, message)
    local src = source
    local me = Core.Online(src)
    if not me or not Core.RateOk(src, 'cryptotx', 250) then return end
    title = Core.Clean(tostring(title or ''), 50)
    message = Core.Clean(tostring(message or ''), 50)
    if title == '' then return end
    MySQL.insert('INSERT INTO crypto_transactions (citizenid, title, message) VALUES (?, ?, ?)', { me.cid, title, message })
end)

Core.Rpc('crypto:transactions', { rate = 600 }, function(ctx)
    local rows = MySQL.query.await('SELECT title, message, UNIX_TIMESTAMP(`date`) AS ts FROM crypto_transactions WHERE citizenid = ? ORDER BY id DESC LIMIT 40', { ctx.cid }) or {}
    local list = {}
    for _, row in ipairs(rows) do
        list[#list + 1] = { title = row.title or '', message = row.message or '', ts = (tonumber(row.ts) or 0) * 1000 }
    end
    return { transactions = list }
end)
