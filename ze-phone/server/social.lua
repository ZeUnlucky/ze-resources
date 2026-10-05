-- Twitter and the advert board. A new tweet or advert is sent to the others as one small message (qb-phone sent the whole
-- feed to everybody each time).

local QBCore = exports['qb-core']:GetCoreObject()

Social = {}

-- ---------------------------------------------------------------------------------------------------------------------
-- Twitter
-- ---------------------------------------------------------------------------------------------------------------------

local function tweetView(row, myCid)
    local picture = row.picture
    if type(picture) ~= 'string' or not picture:find('^https?://') then picture = 'default' end
    local url = row.url
    if type(url) ~= 'string' or not url:find('^https?://') then url = nil end
    return {
        tweetId = row.tweetId,
        firstName = row.firstName or '',
        lastName = row.lastName or '',
        message = row.message or '',
        url = url,
        picture = picture,
        ts = (tonumber(row.ts) or 0) * 1000,
        likes = tonumber(row.likes) or 0,
        liked = row.liked == 1 or row.liked == true,
        mine = row.citizenid == myCid,
    }
end

Core.Rpc('tweets:list', { rate = 800 }, function(ctx)
    local rows = MySQL.query.await([[
        SELECT t.tweetId, t.citizenid, t.firstName, t.lastName, t.message, t.url, t.picture, UNIX_TIMESTAMP(t.date) AS ts,
               (SELECT COUNT(*) FROM phone_tweet_likes l WHERE l.tweetId = t.tweetId) AS likes,
               (SELECT COUNT(*) FROM phone_tweet_likes l2 WHERE l2.tweetId = t.tweetId AND l2.citizenid = ?) AS liked
        FROM phone_tweets t
        WHERE t.date > (NOW() - INTERVAL ? HOUR)
        ORDER BY t.date DESC
        LIMIT ?]], { ctx.cid, Config.Twitter.Hours, Config.Twitter.Max }) or {}

    local tweets = {}
    for _, row in ipairs(rows) do tweets[#tweets + 1] = tweetView(row, ctx.cid) end
    return { tweets = tweets }
end)

Core.Rpc('tweets:post', { rate = Config.Twitter.Cooldown * 1000 }, function(ctx, a)
    local message = Core.Clean(a.message, Config.Twitter.MaxLength)
    local url
    if a.url ~= nil and a.url ~= '' then
        url = Core.SafeUrl(a.url, 500)
        if not url then return { error = 'That photo cannot be posted' } end
    end
    if message == '' and not url then return { error = 'Write something first' } end

    local settings = Core.GetSettings(ctx.Player.PlayerData)
    if settings.airplane then return { error = 'Airplane mode is on' } end
    if not Core.HasPhone(ctx.src) then return { error = 'You do not have a phone' } end

    local tweetId = 'TWEET-' .. math.random(11111111, 99999999)
    local picture = settings.profilepicture
    if picture ~= 'default' and not Core.SafeUrl(picture, 500) then picture = 'default' end

    MySQL.insert.await('INSERT INTO phone_tweets (citizenid, firstName, lastName, message, url, picture, tweetId) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { ctx.cid, ctx.first, ctx.last, message, url or '', picture, tweetId })

    local tweet = {
        tweetId = tweetId,
        firstName = ctx.first,
        lastName = ctx.last,
        message = message,
        url = url,
        picture = picture,
        ts = os.time() * 1000,
        likes = 0,
        liked = false,
        mine = false,
    }
    TriggerClientEvent('ze-phone:client:push', -1, 'tweet', tweet)

    -- @first_last mentions
    local seen, count = {}, 0
    for handle in message:gmatch('@([%w_]+)') do
        handle = handle:lower()
        if not seen[handle] and count < 5 then
            seen[handle] = true
            count = count + 1
            for src, me in pairs(Core.AllOnline()) do
                local mine = (me.first .. '_' .. me.last):lower():gsub('%s+', '_')
                if mine == handle and src ~= ctx.src then
                    Core.Push(src, 'mention', tweet)
                end
            end
        end
    end

    tweet.mine = true
    return { tweet = tweet }
end)

Core.Rpc('tweets:delete', { rate = 400 }, function(ctx, a)
    local id = Core.Clean(a.tweetId, 25)
    if not id:find('^[%w%-]+$') then return { error = 'Tweet not found' } end
    local removed = MySQL.update.await('DELETE FROM phone_tweets WHERE tweetId = ? AND citizenid = ?', { id, ctx.cid })
    if removed and removed > 0 then
        MySQL.query('DELETE FROM phone_tweet_likes WHERE tweetId = ?', { id })
        TriggerClientEvent('ze-phone:client:push', -1, 'tweetDeleted', { tweetId = id })
    end
end)

Core.Rpc('tweets:like', { rate = 250 }, function(ctx, a)
    local id = Core.Clean(a.tweetId, 25)
    if not id:find('^[%w%-]+$') then return { error = 'Tweet not found' } end
    if not MySQL.scalar.await('SELECT 1 FROM phone_tweets WHERE tweetId = ? LIMIT 1', { id }) then
        return { error = 'Tweet not found' }
    end

    local liked = MySQL.scalar.await('SELECT 1 FROM phone_tweet_likes WHERE tweetId = ? AND citizenid = ?', { id, ctx.cid })
    if liked then
        MySQL.query.await('DELETE FROM phone_tweet_likes WHERE tweetId = ? AND citizenid = ?', { id, ctx.cid })
    else
        MySQL.query.await('INSERT IGNORE INTO phone_tweet_likes (tweetId, citizenid) VALUES (?, ?)', { id, ctx.cid })
    end
    local likes = MySQL.scalar.await('SELECT COUNT(*) FROM phone_tweet_likes WHERE tweetId = ?', { id }) or 0
    TriggerClientEvent('ze-phone:client:push', -1, 'tweetLikes', { tweetId = id, likes = likes })
    return { liked = not liked, likes = likes }
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Adverts
-- ---------------------------------------------------------------------------------------------------------------------

local adverts = {}        -- [citizenid] = { id, name, number, message, url, ts, expires }
local lastAdvert = {}     -- [citizenid] = os.time() of the last post
local advertSeq = 0

function Social.AdvertList()
    local list = {}
    for _, ad in pairs(adverts) do
        list[#list + 1] = { id = ad.id, name = ad.name, number = ad.number, message = ad.message, url = ad.url, ts = ad.ts }
    end
    table.sort(list, function(x, y) return x.ts > y.ts end)
    return list
end

Core.Rpc('ads:list', { rate = 800 }, function()
    return { adverts = Social.AdvertList() }
end)

Core.Rpc('ads:post', { rate = 800 }, function(ctx, a)
    local message = Core.Clean(a.message, Config.Adverts.MaxLength)
    if message == '' then return { error = 'You cannot post an empty advert' } end
    local url
    if a.url ~= nil and a.url ~= '' then
        url = Core.SafeUrl(a.url, 500)
        if not url then return { error = 'That photo cannot be posted' } end
    end

    local settings = Core.GetSettings(ctx.Player.PlayerData)
    if settings.airplane then return { error = 'Airplane mode is on' } end
    if not Core.HasPhone(ctx.src) then return { error = 'You do not have a phone' } end

    local now = os.time()
    local wait = (lastAdvert[ctx.cid] or 0) + Config.Adverts.Cooldown - now
    if wait > 0 then return { error = ('Wait %d seconds before posting again'):format(wait) } end

    local price = Config.Adverts.Price
    if price > 0 and not ctx.Player.Functions.RemoveMoney('bank', price, 'phone-advert') then
        return { error = ('An advert costs $%d, you do not have that in the bank'):format(price) }
    end

    advertSeq = advertSeq + 1
    local ad = {
        id = advertSeq,
        name = '@' .. ctx.first .. ctx.last,
        number = ctx.number,
        message = message,
        url = url,
        ts = now * 1000,
        expires = Config.Adverts.DurationMinutes > 0 and (now + Config.Adverts.DurationMinutes * 60) or nil,
    }
    local old = adverts[ctx.cid]
    adverts[ctx.cid] = ad
    lastAdvert[ctx.cid] = now

    if old then TriggerClientEvent('ze-phone:client:push', -1, 'advertRemoved', { id = old.id }) end
    TriggerClientEvent('ze-phone:client:push', -1, 'advert', { id = ad.id, name = ad.name, number = ad.number, message = ad.message, url = ad.url, ts = ad.ts })
    return { ok = true }
end)

Core.Rpc('ads:delete', { rate = 500 }, function(ctx)
    local ad = adverts[ctx.cid]
    if not ad then return end
    adverts[ctx.cid] = nil
    TriggerClientEvent('ze-phone:client:push', -1, 'advertRemoved', { id = ad.id })
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for cid, ad in pairs(adverts) do
            if ad.expires and ad.expires <= now then
                adverts[cid] = nil
                TriggerClientEvent('ze-phone:client:push', -1, 'advertRemoved', { id = ad.id })
            end
        end
    end
end)
