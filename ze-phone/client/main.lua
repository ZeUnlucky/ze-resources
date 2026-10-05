-- ze-phone client: state, opening and closing, the bridge to the NUI, and the events other resources send to qb-phone.
-- Calls are in calls.lua, the prop and animations in anim.lua, the camera in camera.lua, the app callbacks in apps.lua.

local QBCore = exports['qb-core']:GetCoreObject()

Phone = {
    open = false,          -- the UI is up and has the cursor
    booted = false,
    typing = false,        -- a text field has focus: keys go to the field, not to the game
    inCamera = false,
    hasPhone = false,
    hasPhoneAt = 0,
    settings = {},         -- last settings the server sent, for the ringtone and the silent switch
    bootData = nil,
}

local disabled = {}
for _, control in ipairs(Config.DisabledControls) do disabled[#disabled + 1] = control end

-- ---------------------------------------------------------------------------------------------------------------------
-- Helpers other files use
-- ---------------------------------------------------------------------------------------------------------------------

function Phone.Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function Phone.Push(name, data, mute)
    SendNUIMessage({ action = 'push', name = name, data = data, mute = mute or false })
end

function Phone.Notify(text, kind)
    QBCore.Functions.Notify(text, kind or 'primary')
end

-- the server's answer to one request of the UI (see Core.Rpc in server/core.lua)
function Phone.Rpc(name, args, cb)
    QBCore.Functions.TriggerCallback('ze-phone:rpc', function(result)
        if name == 'settings:save' and type(result) == 'table' and result.settings then
            Phone.settings = result.settings
        end
        if cb then cb(result) end
    end, name, args or {})
end

-- Waits for a callback (any resource's QBCore callback) but never longer than `timeout` ms: a callback that does not
-- exist, or one that forgets to answer, must not freeze a screen forever. Call it from a thread or a NUI callback.
function Phone.Await(name, timeout, ...)
    local p = promise.new()
    local done = false
    QBCore.Functions.TriggerCallback(name, function(...)
        if done then return end
        done = true
        p:resolve(table.pack(...))
    end, ...)
    SetTimeout(timeout or 6000, function()
        if done then return end
        done = true
        p:resolve(nil)
    end)
    local result = Citizen.Await(p)
    if not result then return nil end
    return table.unpack(result, 1, result.n)
end

-- Phone.Rpc for code that wants the answer inline (call it from a thread or a NUI callback)
function Phone.RpcAwait(name, args, timeout)
    local p = promise.new()
    local done = false
    Phone.Rpc(name, args, function(result)
        if done then return end
        done = true
        p:resolve(result)
    end)
    SetTimeout(timeout or 8000, function()
        if done then return end
        done = true
        p:resolve(nil)
    end)
    return Citizen.Await(p)
end

function Phone.CanMDT(data)
    local job = data and data.job
    if not job then return false end
    local ok = false
    for _, name in ipairs(Config.MDT.Jobs) do
        if job.name == name then ok = true end
    end
    for _, kind in ipairs(Config.MDT.Types) do
        if job.type == kind then ok = true end
    end
    if not ok then return false end
    if Config.MDT.RequireDuty and not job.onduty then return false end
    return true
end

local function playerSummary()
    local data = QBCore.Functions.GetPlayerData() or {}
    local money = data.money or {}
    local job = data.job or {}
    return {
        id = GetPlayerServerId(PlayerId()),
        money = { cash = money.cash or 0, bank = money.bank or 0, crypto = money.crypto or 0 },
        job = {
            name = job.name,
            label = job.label,
            type = job.type,
            onduty = job.onduty,
            grade = job.grade and job.grade.name or nil,
            canBill = (job.name and Config.Billing.Jobs[job.name]) and true or false,
        },
        mdt = Phone.CanMDT(data),
    }
end

local function timePayload()
    return {
        h = GetClockHours(),
        m = GetClockMinutes(),
        day = GetClockDayOfMonth(),
        month = GetClockMonth(),
        year = GetClockYear(),
        weekday = GetClockDayOfWeek(),
    }
end

local function buildUiConfig()
    local apps = {}
    for _, app in ipairs(Config.Apps) do
        if app.enabled ~= false then
            local available = true
            if app.requires then
                local state = GetResourceState(app.requires)
                available = state == 'started' or state == 'starting'
            end
            if available then
                apps[#apps + 1] = { id = app.id, dock = app.dock or false, mdt = app.mdt or false, jobs = app.jobs }
            end
        end
    end

    local places = {}
    for _, place in ipairs(Config.Places) do
        places[#places + 1] = { label = place[1], category = place[2], x = place[3], y = place[4] }
    end

    local ringtones, texttones = {}, {}
    for _, t in ipairs(Config.Ringtones) do ringtones[#ringtones + 1] = { id = t.id, label = t.label } end
    for _, t in ipairs(Config.TextTones) do texttones[#texttones + 1] = { id = t.id, label = t.label } end

    return {
        accent = Config.Accent,
        apps = apps,
        wallpapers = Config.Wallpapers,
        accents = Config.Accents,
        ringtones = ringtones,
        texttones = texttones,
        places = places,
        keys = { open = Config.OpenKey, answer = Config.AnswerKey, hangup = Config.HangupKey },
        limits = {
            message = Config.Messages.MaxLength,
            tweet = Config.Twitter.MaxLength,
            advert = Config.Adverts.MaxLength,
            advertPrice = Config.Adverts.Price,
            transfer = Config.Bank.MaxTransfer,
            billing = Config.Billing.MaxAmount,
        },
        walk = Config.WalkWhileOpen,
    }
end

function Phone.SendInit()
    if not Phone.bootData then return end
    Phone.Send('init', {
        ui = buildUiConfig(),
        boot = Phone.bootData,
        player = playerSummary(),
        time = timePayload(),
    })
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------------------------------------------------

function Phone.Boot(attempt)
    attempt = attempt or 1
    Phone.Rpc('boot', {}, function(res)
        if type(res) ~= 'table' or res.error then
            if attempt < 5 and LocalPlayer.state.isLoggedIn then
                SetTimeout(3000, function() Phone.Boot(attempt + 1) end)
            end
            return
        end
        Phone.booted = true
        Phone.bootData = res
        Phone.settings = res.settings or {}
        Phone.SendInit()
    end)
end

local function reset()
    if Phone.open then Phone.Close(true) end
    Phone.booted = false
    Phone.bootData = nil
    Phone.hasPhone = false
    Phone.settings = {}
    Phone.Send('reset')
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(300)
    Phone.Boot()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', reset)

RegisterNetEvent('qb-phone:RefreshPhone', function()
    Phone.Boot()
end)

CreateThread(function()
    Wait(800)
    if LocalPlayer.state.isLoggedIn then Phone.Boot() end
end)

RegisterNUICallback('ready', function(_, cb)
    Phone.SendInit()
    cb('ok')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    Wait(50)
    Phone.Send('player', playerSummary())
end)

local moneyTimer = false
RegisterNetEvent('QBCore:Client:OnMoneyChange', function()
    if moneyTimer then return end
    moneyTimer = true
    SetTimeout(400, function()
        moneyTimer = false
        Phone.Send('player', playerSummary())
    end)
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Does the player have a phone? (asked when the phone opens and now and then when something arrives)
-- ---------------------------------------------------------------------------------------------------------------------

function Phone.RefreshHasPhone(cb)
    QBCore.Functions.TriggerCallback('qb-phone:server:HasPhone', function(has)
        Phone.hasPhone = has and true or false
        Phone.hasPhoneAt = GetGameTimer()
        if cb then cb(Phone.hasPhone) end
    end)
end

-- the last known answer; asks again in the background when it is stale
function Phone.HasPhoneCached()
    if GetGameTimer() - Phone.hasPhoneAt > 8000 then Phone.RefreshHasPhone() end
    return Phone.hasPhone
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Opening and closing
-- ---------------------------------------------------------------------------------------------------------------------

local function canUse(data)
    local meta = data.metadata or {}
    return not (meta.ishandcuffed or meta.inlaststand or meta.isdead or IsPauseMenuActive())
end

local function showUi()
    Phone.open = true
    Phone.typing = false
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.WalkWhileOpen)
    Phone.Send('open', { player = playerSummary(), time = timePayload(), call = Call and Call.Snapshot and Call.Snapshot() or nil })
    Anim.OnOpen()

    -- while it is open: switch off the controls that would act under the cursor, close it when the player cannot use it
    CreateThread(function()
        while Phone.open do
            for i = 1, #disabled do DisableControlAction(0, disabled[i], true) end
            Wait(0)
        end
    end)

    CreateThread(function()
        local lastMinute = -1
        while Phone.open do
            local data = QBCore.Functions.GetPlayerData() or {}
            if not canUse(data) then
                Phone.Close(true)
                break
            end
            local minute = GetClockMinutes()
            if minute ~= lastMinute then
                lastMinute = minute
                Phone.Send('time', timePayload())
            end
            Wait(500)
        end
    end)
end

function Phone.Open()
    if Phone.open or Phone.inCamera then return end
    if not LocalPlayer.state.isLoggedIn then return end
    local data = QBCore.Functions.GetPlayerData() or {}
    if not canUse(data) then
        Phone.Notify('Action not available at the moment..', 'error')
        return
    end
    if not Phone.booted then
        Phone.Notify('The phone is still starting', 'error')
        Phone.Boot()
        return
    end
    Phone.RefreshHasPhone(function(has)
        if not has then
            Phone.Notify("You don't have a phone", 'error')
            return
        end
        if Phone.open or Phone.inCamera then return end
        showUi()
    end)
end

-- Used by the camera to come back without asking again.
function Phone.Reopen()
    if Phone.open then return end
    showUi()
end

-- keepAnim: the camera takes over the animation itself
function Phone.Close(force, keepAnim)
    if not Phone.open then return end
    Phone.open = false
    Phone.typing = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    Phone.Send('close', { force = force == true })
    if not keepAnim then Anim.OnClose() end
end

RegisterCommand('phone', function()
    if Phone.open then
        Phone.Close()
    else
        Phone.Open()
    end
end, false)

RegisterKeyMapping('phone', 'Open Phone', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb)
    Phone.Close()
    cb('ok')
end)

RegisterNUICallback('typing', function(data, cb)
    Phone.typing = data and data.on == true
    if Phone.open then SetNuiFocusKeepInput(Config.WalkWhileOpen and not Phone.typing) end
    cb('ok')
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Requests from the UI
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('rpc', function(data, cb)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return cb({ error = 'Bad request' }) end
    Phone.Rpc(data.name, data.args, function(result)
        cb(result or { error = 'No answer from the server' })
    end)
end)

-- sounds: the UI cannot play GTA sounds itself
local previewSound = nil
local function toneOf(list, id)
    for _, t in ipairs(list) do
        if t.id == id then return t end
    end
    return list[1]
end

function Phone.PlayTone(list, id)
    local tone = toneOf(list, id)
    PlaySoundFrontend(-1, tone.name, tone.set, true)
end

RegisterNUICallback('sound', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local kind = data.kind
    if kind == 'text' then
        if not Phone.settings.silent then Phone.PlayTone(Config.TextTones, Phone.settings.texttone) end
    elseif kind == 'previewText' then
        Phone.PlayTone(Config.TextTones, data.id)
    elseif kind == 'previewRing' then
        if previewSound then
            StopSound(previewSound)
            ReleaseSoundId(previewSound)
            previewSound = nil
        end
        local tone = toneOf(Config.Ringtones, data.id)
        previewSound = GetSoundId()
        local mine = previewSound
        PlaySoundFrontend(mine, tone.name, tone.set, true)
        SetTimeout(2600, function()
            if previewSound == mine then
                StopSound(mine)
                ReleaseSoundId(mine)
                previewSound = nil
            end
        end)
    elseif kind == 'alert' then
        if not Phone.settings.silent then
            PlaySoundFrontend(-1, 'Event_Message_Purple', 'GTAO_FM_Events_Soundset', true)
        end
    elseif kind == 'timer' then
        PlaySoundFrontend(-1, 'Timer_10s', 'DLC_HALLOWEEN_FVJ_Sounds', true)
    end
end)

RegisterNUICallback('waypoint', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        if data.label then Phone.Notify('GPS set: ' .. tostring(data.label):sub(1, 60), 'success') end
    end
    cb('ok')
end)

RegisterNUICallback('waypointClear', function(_, cb)
    SetWaypointOff()
    cb('ok')
end)

-- where the player is, for the Maps app
RegisterNUICallback('location', function(_, cb)
    local ped = PlayerPedId()
    local at = GetEntityCoords(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(at.x, at.y, at.z)
    local street = GetStreetNameFromHashKey(streetHash)
    local cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or ''
    local zone = GetLabelText(GetNameOfZone(at.x, at.y, at.z))
    cb({
        x = math.floor(at.x * 10) / 10,
        y = math.floor(at.y * 10) / 10,
        street = street,
        cross = cross,
        zone = zone ~= 'NULL' and zone or '',
        heading = math.floor(GetEntityHeading(ped)),
    })
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Events other resources send to qb-phone
-- ---------------------------------------------------------------------------------------------------------------------

-- everything the server wants the UI to know (new message, mail, tweet, ...)
RegisterNetEvent('ze-phone:client:push', function(name, data)
    Phone.Push(name, data, not Phone.HasPhoneCached())
end)

RegisterNetEvent('qb-phone:client:addPoliceAlert', function(alert)
    if type(alert) ~= 'table' then return end
    if not Phone.CanMDT(QBCore.Functions.GetPlayerData()) then return end
    Phone.Push('policeAlert', {
        title = tostring(alert.title or 'Alert'),
        description = tostring(alert.description or ''),
        coords = type(alert.coords) == 'table' and { x = alert.coords.x, y = alert.coords.y, z = alert.coords.z } or nil,
    }, not Phone.HasPhoneCached())
end)

RegisterNetEvent('qb-phone:client:AddTransaction', function(_, _, message, title)
    Phone.Push('cryptoTx', { title = title, message = message }, not Phone.HasPhoneCached())
    TriggerServerEvent('ze-phone:server:addTransaction', title, message)
end)

RegisterNetEvent('qb-phone:client:RemoveBankMoney', function(amount)
    amount = tonumber(amount)
    if amount and amount > 0 then
        Phone.Push('bankOut', { amount = amount }, not Phone.HasPhoneCached())
    end
end)

RegisterNetEvent('qb-phone:client:AcceptorDenyInvoice', function(id, sender, society, _, amount)
    Phone.Push('invoice', { id = id, sender = sender, society = society, amount = amount }, not Phone.HasPhoneCached())
end)

RegisterNetEvent('qb-phone:client:RaceNotify', function(message)
    Phone.Push('notify', { app = 'racing', title = 'Racing', text = tostring(message or '') }, not Phone.HasPhoneCached())
end)

RegisterNetEvent('qb-phone:client:UpdateLapraces', function()
    Phone.Push('racesChanged', {})
end)

RegisterNetEvent('qb-phone:client:CustomNotification', function(title, text, icon, color, timeout)
    Phone.Push('notify', {
        title = tostring(title or ''),
        text = tostring(text or ''),
        icon = type(icon) == 'string' and icon or nil,
        color = type(color) == 'string' and color or nil,
        timeout = tonumber(timeout),
    }, not Phone.HasPhoneCached())
end)

-- qb-radialmenu: give your contact details to the nearest player
RegisterNetEvent('qb-phone:client:GiveContactDetails', function()
    local me = PlayerId()
    local here = GetEntityCoords(PlayerPedId())
    local nearest, nearestDistance = nil, 2.6
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local distance = #(GetEntityCoords(GetPlayerPed(player)) - here)
            if distance < nearestDistance then
                nearest, nearestDistance = player, distance
            end
        end
    end
    if nearest then
        TriggerServerEvent('qb-phone:server:GiveContactDetails', GetPlayerServerId(nearest))
    else
        Phone.Notify('No one nearby!', 'error')
    end
end)

-- ---------------------------------------------------------------------------------------------------------------------
-- Clean up
-- ---------------------------------------------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if previewSound then
        StopSound(previewSound)
        ReleaseSoundId(previewSound)
    end
end)
