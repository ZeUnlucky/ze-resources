-- The camera: the phone leaves the screen, the game's phone camera comes up (selfie switch included), a photo is uploaded
-- the way config.server.lua says and saved in the gallery. The result goes back to the UI as the push 'photoTaken' { url },
-- so whichever app asked for a photo (Camera, Messages, Twitter, adverts) can use it.

local QBCore = exports['qb-core']:GetCoreObject()

local active = false      -- the camera view is up
local taking = false      -- a photo is being uploaded: the controls are off, the HUD stays hidden
local front = false

-- 'data.url' / 'attachments.1.proxy_url': a path into the answer of the upload server
local function jsonPath(node, path)
    for key in tostring(path):gmatch('[^%.]+') do
        if type(node) ~= 'table' then return nil end
        node = node[tonumber(key) or key]
    end
    return node
end

-- Uploads what is on screen. Returns the image address, or nil.
local function upload(cfg)
    if cfg.provider == 'fivemerr' then
        return Phone.Await('ze-phone:server:uploadFivemerr', 25000)
    end
    if GetResourceState('screenshot-basic') ~= 'started' then return nil end

    local url, field = cfg.url, cfg.field or 'files[]'
    if cfg.provider == 'webhook' then
        field = 'files[]'
        if not url:find('wait=', 1, true) then
            url = url .. (url:find('?', 1, true) and '&' or '?') .. 'wait=true'   -- without it Discord answers with nothing
        end
    end

    local p = promise.new()
    local done = false
    exports['screenshot-basic']:requestScreenshotUpload(url, field, {
        encoding = Config.Camera.Encoding,
        quality = Config.Camera.Quality,
        headers = cfg.headers,
    }, function(data)
        if done then return end
        done = true
        p:resolve(data)
    end)
    SetTimeout(25000, function()
        if done then return end
        done = true
        p:resolve(nil)
    end)

    local data = Citizen.Await(p)
    if type(data) ~= 'string' then return nil end
    local ok, res = pcall(json.decode, data)
    if not ok or type(res) ~= 'table' then return nil end

    if cfg.provider == 'webhook' then
        local attachment = res.attachments and res.attachments[1]
        return attachment and (attachment.url or attachment.proxy_url) or nil
    end
    local found = jsonPath(res, cfg.urlPath or 'url')
    return type(found) == 'string' and found or nil
end

local function leave(url)
    if front then Citizen.InvokeNative(0x2491A93618B7D838, false) end
    DestroyMobilePhone()
    CellCamActivate(false, false)
    active, taking, front = false, false, false
    Phone.inCamera = false
    Phone.Send('camera', { on = false })
    Wait(300)
    Phone.Reopen()
    Phone.Push('photoTaken', { url = url })
end

local function flip()
    front = not front
    Citizen.InvokeNative(0x2491A93618B7D838, front)   -- CELL_CAM_ACTIVATE_SELFIE_MODE
end

local function takePhoto(cfg)
    taking = true
    Phone.Send('camera', { on = false })    -- nothing of the UI may end up in the picture
    Wait(250)
    local url = upload(cfg)
    if url then
        local saved = Phone.RpcAwait('gallery:add', { url = url })
        if not saved or saved.error then
            Phone.Notify(saved and saved.error or 'The photo could not be saved', 'error')
            url = nil
        else
            url = saved.url
        end
    else
        Phone.Notify('The photo could not be uploaded', 'error')
    end
    leave(url)
end

local function run(cfg)
    Phone.inCamera = true
    Anim.Stop()
    Phone.Close(false, true)
    active, taking, front = true, false, false

    CreateMobilePhone(1)
    CellCamActivate(true, true)
    Phone.Send('camera', { on = true })

    while active do
        if not taking then
            if IsControlJustPressed(1, 27) then
                flip()
            elseif IsControlJustPressed(1, 177) or IsEntityDead(PlayerPedId()) then
                leave(nil)
                break
            elseif IsControlJustPressed(1, 176) then
                CreateThread(function() takePhoto(cfg) end)
            end
        end
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(8)
        HideHudComponentThisFrame(9)
        HideHudComponentThisFrame(19)
        HideHudAndRadarThisFrame()
        EnableAllControlActions(0)
        Wait(0)
    end
end

RegisterNUICallback('camera:open', function(_, cb)
    if Phone.inCamera then return cb({ error = 'The camera is already open' }) end
    if Call.InCall() then return cb({ error = 'Hang up first' }) end

    QBCore.Functions.TriggerCallback('ze-phone:server:cameraConfig', function(cfg)
        if type(cfg) ~= 'table' or cfg.provider == 'none' then
            return cb({ error = 'The camera is not set up on this server' })
        end
        cb({ ok = true })
        CreateThread(function() run(cfg) end)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not active then return end
    DestroyMobilePhone()
    CellCamActivate(false, false)
end)
