-- Gallery (the `phone_gallery` table) and the camera's upload side. The provider and its keys are in config.server.lua.

local QBCore = exports['qb-core']:GetCoreObject()

Core.Rpc('gallery:list', { rate = 600 }, function(ctx)
    local rows = MySQL.query.await('SELECT image, UNIX_TIMESTAMP(`date`) AS ts FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC LIMIT ?',
        { ctx.cid, Config.Camera.MaxPhotos }) or {}
    local photos = {}
    for _, row in ipairs(rows) do
        photos[#photos + 1] = { url = row.image, ts = (tonumber(row.ts) or 0) * 1000 }
    end
    return { photos = photos }
end)

Core.Rpc('gallery:add', { rate = 800 }, function(ctx, a)
    local url = Core.SafeUrl(a.url, 500)
    if not url then return { error = 'That is not a usable image address' } end
    MySQL.insert.await('INSERT INTO phone_gallery (citizenid, image) VALUES (?, ?)', { ctx.cid, url })
    MySQL.query('DELETE FROM phone_gallery WHERE citizenid = ? AND image NOT IN (SELECT image FROM (SELECT image FROM phone_gallery WHERE citizenid = ? ORDER BY `date` DESC LIMIT ?) AS keep)',
        { ctx.cid, ctx.cid, Config.Camera.MaxPhotos })
    return { url = url }
end)

Core.Rpc('gallery:delete', { rate = 300 }, function(ctx, a)
    local url = Core.SafeUrl(a.url, 500)
    if not url then return { error = 'Photo not found' } end
    MySQL.query.await('DELETE FROM phone_gallery WHERE citizenid = ? AND image = ?', { ctx.cid, url })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Camera
-- ---------------------------------------------------------------------------------------------------------------------

-- Tells the client how to upload. For 'webhook' and 'custom' the player's game does the upload (screenshot-basic), so
-- the address and headers have to be sent to it; 'fivemerr' keeps its token here.
QBCore.Functions.CreateCallback('ze-phone:server:cameraConfig', function(src, cb)
    local c = ConfigServer.Camera
    if c.Provider == 'webhook' and c.Webhook ~= '' then
        cb({ provider = 'webhook', url = c.Webhook })
    elseif c.Provider == 'custom' and c.Custom.Url ~= '' then
        cb({ provider = 'custom', url = c.Custom.Url, field = c.Custom.Field, headers = c.Custom.Headers, urlPath = c.Custom.UrlPath })
    elseif c.Provider == 'fivemerr' and c.Fivemerr.Token ~= '' then
        cb({ provider = 'fivemerr' })
    else
        cb({ provider = 'none' })
    end
end)

QBCore.Functions.CreateCallback('ze-phone:server:uploadFivemerr', function(src, cb)
    local c = ConfigServer.Camera
    if c.Provider ~= 'fivemerr' or c.Fivemerr.Token == '' then return cb(nil) end
    if not Core.RateOk(src, 'upload', 3000) then return cb(nil) end

    local done = false
    local function finish(value)
        if done then return end
        done = true
        cb(value)
    end

    exports['screenshot-basic']:requestClientScreenshot(src, { encoding = Config.Camera.Encoding, quality = Config.Camera.Quality }, function(err, data)
        if err or not data then return finish(nil) end
        PerformHttpRequest(c.Fivemerr.Url, function(status, body)
            if status ~= 200 and status ~= 201 then
                print(('^1[ze-phone] Fivemerr upload failed (%s)^7'):format(tostring(status)))
                return finish(nil)
            end
            local ok, res = pcall(json.decode, body or '')
            finish(ok and type(res) == 'table' and res.url or nil)
        end, 'POST', json.encode({ data = data }), { ['Authorization'] = c.Fivemerr.Token, ['Content-Type'] = 'application/json' })
    end)

    SetTimeout(20000, function() finish(nil) end)
end)
