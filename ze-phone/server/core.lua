-- Shared server helpers: who is online (by number and citizen id, without asking qb-core every time), cleaning and
-- validating what players send, settings, and the one callback every request of the UI goes through.

local QBCore = exports['qb-core']:GetCoreObject()

Core = {}
Rpcs = {}

-- ---------------------------------------------------------------------------------------------------------------------
-- Online players
-- ---------------------------------------------------------------------------------------------------------------------

local Online = {}      -- [src] = { src, cid, number, first, last, account, picture }
local ByNumber = {}    -- [number] = src
local ByCid = {}       -- [citizenid] = src

local function indexPlayer(data)
    if type(data) ~= 'table' or not data.citizenid or not data.source then return end
    local src = data.source
    local old = Online[src]
    if old then
        if old.number then ByNumber[old.number] = nil end
        ByCid[old.cid] = nil
    end
    local info = data.charinfo or {}
    local meta = data.metadata and data.metadata.phone
    Online[src] = {
        src = src,
        cid = data.citizenid,
        number = info.phone and tostring(info.phone) or nil,
        first = info.firstname or '',
        last = info.lastname or '',
        account = info.account and tostring(info.account) or nil,
        picture = type(meta) == 'table' and meta.profilepicture or nil,
    }
    if Online[src].number then ByNumber[Online[src].number] = src end
    ByCid[data.citizenid] = src
end

local function unindexPlayer(src)
    local old = Online[src]
    if not old then return end
    if old.number then ByNumber[old.number] = nil end
    ByCid[old.cid] = nil
    Online[src] = nil
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if Player and Player.PlayerData then indexPlayer(Player.PlayerData) end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    unindexPlayer(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Core.OnDrop then Core.OnDrop(src) end
    unindexPlayer(src)
end)

CreateThread(function()
    Wait(500)
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        indexPlayer(Player.PlayerData)
    end
end)

function Core.Online(src) return Online[src] end
function Core.OnlineByNumber(number) local s = ByNumber[number]; return s and Online[s] or nil end
function Core.OnlineByCid(cid) local s = ByCid[cid]; return s and Online[s] or nil end
function Core.AllOnline() return Online end

function Core.Player(src) return QBCore.Functions.GetPlayer(src) end

function Core.Notify(src, text, kind)
    TriggerClientEvent('QBCore:Notify', src, text, kind or 'primary')
end

function Core.Push(src, name, data)
    TriggerClientEvent('ze-phone:client:push', src, name, data)
end

function Core.PushCid(cid, name, data)
    local who = ByCid[cid]
    if who then TriggerClientEvent('ze-phone:client:push', who, name, data) end
end

function Core.FullName(first, last)
    local name = ((first or '') .. ' ' .. (last or '')):gsub('^%s+', ''):gsub('%s+$', '')
    return name
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Cleaning what players send
-- ---------------------------------------------------------------------------------------------------------------------

-- A string without control characters, trimmed, cut to `max` characters (not bytes).
function Core.Clean(value, max)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\0-\8\11\12\14-\31\127]', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    local length = utf8.len(value)
    if not length then
        value = value:gsub('[\128-\255]', '')
    elseif max and length > max then
        value = value:sub(1, (utf8.offset(value, max + 1) or (#value + 1)) - 1)
    end
    return value
end

-- http(s) address that is safe to put in an <img src> or a CSS url("..."), or nil
function Core.SafeUrl(url, max)
    if type(url) ~= 'string' then return nil end
    url = url:gsub('^%s+', ''):gsub('%s+$', '')
    if #url < 10 or #url > (max or 400) then return nil end
    if not (url:find('^https://') or url:find('^http://')) then return nil end
    if url:find('[%s<>"\'`\\]') then return nil end
    return url
end

-- Digits only. Phone numbers and account numbers are compared in this form.
function Core.Digits(value)
    return (tostring(value or ''):gsub('%D', ''))
end

function Core.IsNumber(value)
    return type(value) == 'string' and value:find('^%d+$') ~= nil and #value >= 3 and #value <= 15
end

function Core.ToInt(value, min, max)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    if min and n < min then return nil end
    if max and n > max then return nil end
    return n
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Rate limiting
-- ---------------------------------------------------------------------------------------------------------------------

local Rates = {}

function Core.RateOk(src, key, ms)
    local now = GetGameTimer()
    local bucket = Rates[src]
    if not bucket then
        bucket = {}
        Rates[src] = bucket
    end
    local last = bucket[key]
    if last and now - last < ms then return false end
    bucket[key] = now
    return true
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Requests from the UI
-- ---------------------------------------------------------------------------------------------------------------------

-- Core.Rpc('name', { rate = 300 }, function(ctx, args) return result end)
-- ctx: { src, cid, number, first, last, name, Player }. Return a table, or nil for { ok = true }. { error = 'text' } shows in the UI.
function Core.Rpc(name, opts, fn)
    if type(opts) == 'function' then
        fn = opts
        opts = {}
    end
    Rpcs[name] = { fn = fn, rate = opts.rate or 120 }
end

QBCore.Functions.CreateCallback('ze-phone:rpc', function(src, cb, name, args)
    local entry = Rpcs[name]
    if not entry then return cb({ error = 'Unknown request' }) end

    local me = Online[src]
    if not me then return cb({ error = 'Not logged in' }) end
    if not DB.Ready then return cb({ error = 'The phone is still starting' }) end
    if not Core.RateOk(src, name, entry.rate) then return cb({ error = 'Slow down a little' }) end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb({ error = 'Not logged in' }) end

    local ctx = {
        src = src,
        cid = me.cid,
        number = me.number,
        first = me.first,
        last = me.last,
        name = Core.FullName(me.first, me.last),
        Player = Player,
    }

    local ok, result = pcall(entry.fn, ctx, type(args) == 'table' and args or {})
    if not ok then
        print(('^1[ze-phone] request "%s" failed: %s^7'):format(name, tostring(result)))
        return cb({ error = 'Something went wrong' })
    end
    cb(result == nil and { ok = true } or result)
end)

QBCore.Functions.CreateCallback('qb-phone:server:HasPhone', function(src, cb)
    cb(Core.HasPhone(src))
end)

function Core.HasPhone(src)
    if not Config.Item then return true end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.GetItemByName(Config.Item) ~= nil
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Looking players up by phone number or account number
-- ---------------------------------------------------------------------------------------------------------------------

local numberCache = {}   -- [number] = citizenid, positive answers only (numbers never change hands)

function Core.CidByNumber(number)
    if not Core.IsNumber(number) then return nil end
    local on = ByNumber[number]
    if on then return Online[on].cid end
    local cid = numberCache[number]
    if cid then return cid end
    cid = MySQL.scalar.await("SELECT citizenid FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) = ? LIMIT 1", { number })
    if cid then numberCache[number] = cid end
    return cid
end

local profiles = {}   -- [number] = { name, number, picture, cid, expires }

local function cleanPicture(url)
    if type(url) == 'string' and (url:find('^https?://')) then return url end
    return nil
end

-- name and picture for a list of phone numbers, as { [number] = { name, picture, cid } }
function Core.Profiles(numbers)
    local out, missing = {}, {}
    local now = GetGameTimer()
    for _, number in ipairs(numbers) do
        local on = ByNumber[number]
        if on then
            local me = Online[on]
            out[number] = { name = Core.FullName(me.first, me.last), picture = cleanPicture(me.picture), cid = me.cid }
        else
            local hit = profiles[number]
            if hit and hit.expires > now then
                out[number] = hit
            elseif Core.IsNumber(number) then
                missing[#missing + 1] = number
            end
        end
    end

    if #missing > 0 then
        local rows = MySQL.query.await(
            "SELECT citizenid, charinfo, JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.phone.profilepicture')) AS pic FROM players " ..
            "WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone')) IN (" .. DB.Marks(#missing) .. ")", missing) or {}
        for _, row in ipairs(rows) do
            local info = json.decode(row.charinfo or '{}') or {}
            local number = info.phone and tostring(info.phone)
            if number then
                local entry = {
                    name = Core.FullName(info.firstname, info.lastname),
                    picture = cleanPicture(row.pic),
                    cid = row.citizenid,
                    expires = now + 120000,
                }
                profiles[number] = entry
                numberCache[number] = row.citizenid
                out[number] = entry
            end
        end
    end
    return out
end

function Core.ProfileOf(number)
    return Core.Profiles({ number })[number]
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Settings (stored in the character's `phone` metadata, which is where qb-phone kept background and profilepicture)
-- ---------------------------------------------------------------------------------------------------------------------

local function idIn(list, id)
    for _, item in ipairs(list) do
        if item.id == id then return true end
    end
    return false
end

local Defaults = {
    background = 'ember',
    profilepicture = 'default',
    accent = false,
    ringtone = 'default',
    texttone = 'default',
    dnd = false,
    airplane = false,
    silent = false,
    anonymous = false,
    brightness = 100,
    favorites = {},
    order = {},
    muted = {},
}

-- the two stock qb-phone backgrounds become the default one
local LegacyBackgrounds = { ['default-qbcore'] = 'ember', ['background-1'] = 'dusk' }

function Core.GetSettings(playerData)
    local meta = playerData.metadata and playerData.metadata.phone
    if type(meta) ~= 'table' then meta = {} end
    local out = {}
    for key, default in pairs(Defaults) do
        if meta[key] ~= nil then out[key] = meta[key] else out[key] = default end
    end
    if LegacyBackgrounds[out.background] then out.background = LegacyBackgrounds[out.background] end
    if type(out.favorites) ~= 'table' then out.favorites = {} end
    if type(out.order) ~= 'table' then out.order = {} end
    if type(out.muted) ~= 'table' then out.muted = {} end
    return out
end

-- Takes only the keys we know, with the right types. Returns the clean patch.
local function cleanPatch(patch)
    local out = {}
    if type(patch.background) == 'string' then
        if idIn(Config.Wallpapers, patch.background) then
            out.background = patch.background
        else
            local url = Core.SafeUrl(patch.background, 500)
            if url then out.background = url end
        end
    end
    if type(patch.profilepicture) == 'string' then
        if patch.profilepicture == 'default' then
            out.profilepicture = 'default'
        else
            local url = Core.SafeUrl(patch.profilepicture, 500)
            if url then out.profilepicture = url end
        end
    end
    if patch.accent == false then
        out.accent = false
    elseif type(patch.accent) == 'string' and patch.accent:find('^#%x%x%x%x%x%x$') then
        out.accent = patch.accent
    end
    if type(patch.ringtone) == 'string' and idIn(Config.Ringtones, patch.ringtone) then out.ringtone = patch.ringtone end
    if type(patch.texttone) == 'string' and idIn(Config.TextTones, patch.texttone) then out.texttone = patch.texttone end
    for _, key in ipairs({ 'dnd', 'airplane', 'silent', 'anonymous' }) do
        if type(patch[key]) == 'boolean' then out[key] = patch[key] end
    end
    local brightness = tonumber(patch.brightness)
    if brightness then out.brightness = math.max(30, math.min(100, math.floor(brightness))) end
    if type(patch.favorites) == 'table' then
        local list = {}
        for _, n in ipairs(patch.favorites) do
            if Core.IsNumber(n) and #list < 40 then list[#list + 1] = n end
        end
        out.favorites = list
    end
    if type(patch.order) == 'table' then
        local list = {}
        for _, id in ipairs(patch.order) do
            if type(id) == 'string' and id:find('^[%w_]+$') and #list < 60 then list[#list + 1] = id end
        end
        out.order = list
    end
    if type(patch.muted) == 'table' then
        local map, count = {}, 0
        for id, on in pairs(patch.muted) do
            if type(id) == 'string' and id:find('^[%w_]+$') and on == true and count < 60 then
                map[id] = true
                count = count + 1
            end
        end
        out.muted = map
    end
    return out
end

function Core.SaveSettings(ctx, patch)
    local clean = cleanPatch(patch)
    local current = Core.GetSettings(ctx.Player.PlayerData)
    for key, value in pairs(clean) do current[key] = value end
    ctx.Player.Functions.SetMetaData('phone', current)

    local me = Online[ctx.src]
    if me and clean.profilepicture ~= nil then
        me.picture = current.profilepicture
        profiles[ctx.number] = nil
    end
    return current
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Jobs
-- ---------------------------------------------------------------------------------------------------------------------

function Core.CanMDT(playerData)
    local job = playerData.job
    if not job then return false end
    local allowed = false
    for _, name in ipairs(Config.MDT.Jobs) do
        if job.name == name then allowed = true end
    end
    for _, kind in ipairs(Config.MDT.Types) do
        if job.type == kind then allowed = true end
    end
    if not allowed then return false end
    if Config.MDT.RequireDuty and not job.onduty then return false end
    return true
end

function Core.Debug(...)
    if Config.Debug then print('^3[ze-phone]^7', ...) end
end
