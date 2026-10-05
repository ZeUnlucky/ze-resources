-- The client side of a phone call: ring tones, voice channel and the call screen. The server decides everything else
-- (server/calls.lua): who is calling whom, busy lines, do not disturb, timeouts, the call list.

local QBCore = exports['qb-core']:GetCoreObject()

Call = {
    phase = 'idle',        -- 'idle', 'outgoing', 'incoming', 'active'
    id = nil,
    number = nil,
    anonymous = false,
    picture = nil,
    since = nil,           -- GetGameTimer() when the call was answered
    joined = false,        -- in the voice channel
}

function Call.InCall()
    return Call.phase ~= 'idle'
end

function Call.Snapshot()
    return {
        phase = Call.phase,
        number = Call.number,
        anonymous = Call.anonymous,
        picture = Call.picture,
        elapsed = Call.since and math.floor((GetGameTimer() - Call.since) / 1000) or 0,
    }
end

local function sendState(extra)
    local state = Call.Snapshot()
    if extra then
        for k, v in pairs(extra) do state[k] = v end
    end
    Phone.Send('call', state)
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Tones (GTA frontend sounds, repeated until the call changes)
-- ---------------------------------------------------------------------------------------------------------------------

local toneId = nil
local toneToken = 0

local function stopTone()
    toneToken = toneToken + 1
    if toneId then
        StopSound(toneId)
        ReleaseSoundId(toneId)
        toneId = nil
    end
end

local function startTone(name, set)
    stopTone()
    toneToken = toneToken + 1
    local token = toneToken
    local sid = GetSoundId()
    toneId = sid
    PlaySoundFrontend(sid, name, set, true)
    CreateThread(function()
        while toneToken == token do
            Wait(700)
            if toneToken ~= token then break end
            if HasSoundFinished(sid) then PlaySoundFrontend(sid, name, set, true) end
        end
    end)
end

local function ringtone()
    local wanted = Phone.settings.ringtone
    for _, t in ipairs(Config.Ringtones) do
        if t.id == wanted then return t end
    end
    return Config.Ringtones[1]
end

-- ---------------------------------------------------------------------------------------------------------------------
-- Voice
-- ---------------------------------------------------------------------------------------------------------------------

local function voiceAvailable()
    return Config.Calls.Voice == 'pma-voice' and GetResourceState('pma-voice') == 'started'
end

local function voiceJoin(id)
    if not voiceAvailable() or Call.joined then return end
    Call.joined = true
    pcall(function() exports['pma-voice']:addPlayerToCall(id) end)
end

local function voiceLeave(id)
    if not Call.joined then return end
    Call.joined = false
    if voiceAvailable() then
        pcall(function() exports['pma-voice']:removePlayerFromCall(id) end)
    end
end

-- ---------------------------------------------------------------------------------------------------------------------
-- From the UI
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNUICallback('call:start', function(data, cb)
    if Call.phase ~= 'idle' then return cb({ error = 'You are already in a call' }) end
    local number = tostring(data and data.number or ''):gsub('%D', '')
    local anonymous = data and data.anonymous == true

    QBCore.Functions.TriggerCallback('ze-phone:server:call', function(res)
        if type(res) ~= 'table' or not res.ok then
            return cb(res or { error = 'The call failed' })
        end
        Call.phase = 'outgoing'
        Call.id = res.id
        Call.number = number
        Call.anonymous = anonymous
        Call.picture = nil
        Call.since = nil
        Call.joined = false
        startTone('Dial_and_Remote_Ring', 'Phone_SoundSet_Default')
        sendState()
        cb({ ok = true })
    end, number, anonymous)
end)

RegisterNUICallback('call:answer', function(_, cb)
    if Call.phase == 'incoming' then TriggerServerEvent('ze-phone:server:answer') end
    cb('ok')
end)

RegisterNUICallback('call:hangup', function(_, cb)
    if Call.phase ~= 'idle' then TriggerServerEvent('ze-phone:server:hangup') end
    cb('ok')
end)

RegisterNUICallback('call:state', function(_, cb)
    cb(Call.Snapshot())
end)

-- keys, for when the phone is in the pocket
RegisterCommand('zephone_answer', function()
    if Call.phase == 'incoming' then TriggerServerEvent('ze-phone:server:answer') end
end, false)
RegisterKeyMapping('zephone_answer', 'Phone: answer a call', 'keyboard', Config.AnswerKey)

RegisterCommand('zephone_hangup', function()
    if Call.phase ~= 'idle' then TriggerServerEvent('ze-phone:server:hangup') end
end, false)
RegisterKeyMapping('zephone_hangup', 'Phone: hang up or decline', 'keyboard', Config.HangupKey)

-- ---------------------------------------------------------------------------------------------------------------------
-- From the server
-- ---------------------------------------------------------------------------------------------------------------------

RegisterNetEvent('ze-phone:client:incoming', function(info)
    if Call.phase ~= 'idle' or type(info) ~= 'table' then return end
    Call.phase = 'incoming'
    Call.id = info.id
    Call.number = info.number
    Call.anonymous = info.anonymous == true
    Call.picture = info.picture
    Call.since = nil
    Call.joined = false

    if not Phone.settings.silent then
        local tone = ringtone()
        startTone(tone.name, tone.set)
    end
    sendState()
end)

RegisterNetEvent('ze-phone:client:callState', function(state, info)
    if state ~= 'active' or Call.phase == 'idle' then return end
    if type(info) == 'table' and info.id and Call.id and info.id ~= Call.id then return end
    Call.phase = 'active'
    Call.since = GetGameTimer()
    stopTone()
    voiceJoin(Call.id)
    Anim.OnCallActive()
    sendState()
end)

RegisterNetEvent('ze-phone:client:callEnded', function(info)
    if type(info) ~= 'table' then return end
    if Call.id and info.id and info.id ~= Call.id then return end
    local wasActive = Call.phase == 'active'
    stopTone()
    voiceLeave(Call.id)

    Call.phase = 'idle'
    Call.id = nil
    Call.number = nil
    Call.anonymous = false
    Call.picture = nil
    Call.since = nil

    if not Phone.settings.silent then PlaySoundFrontend(-1, 'Hang_Up', 'Phone_SoundSet_Default', true) end
    Anim.OnCallEnded()

    sendState({ ended = { reason = info.reason, by = info.by, duration = info.duration or 0, wasActive = wasActive }, log = info.log })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopTone()
    voiceLeave(Call.id)
end)
