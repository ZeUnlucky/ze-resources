-- The phone in the player's hand: the prop and the animations.
--   open, no call:       cellphone_text_in            close: cellphone_text_out, then the prop goes
--   open, in a call:     cellphone_call_to_text       close: cellphone_text_to_call (the phone stays up to the ear)
--   call, phone closed:  cellphone_call_listen_base
-- Inside a vehicle the same names are played from anim@cellphone@in_car@ps.

Anim = {}

local PROP_MODEL = `prop_npc_phone_02`
local phoneProp = 0
local current = nil            -- { name = 'cellphone_text_in' } what should be playing right now
local watching = false

local function dictionary()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return 'anim@cellphone@in_car@ps' end
    return 'cellphone@'
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function play(name)
    local ped = PlayerPedId()
    local dict = dictionary()
    if not loadDict(dict) then return end
    TaskPlayAnim(ped, dict, name, 3.0, 3.0, -1, 50, 0, false, false, false)
end

-- keeps the animation going: it ends by itself, and getting in or out of a car cancels it
local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while current do
            local ped = PlayerPedId()
            local dict = dictionary()
            if not IsEntityPlayingAnim(ped, dict, current.name, 3) then
                play(current.name)
            end
            Wait(500)
        end
        watching = false
    end)
end

function Anim.DeleteProp()
    if phoneProp ~= 0 then
        if DoesEntityExist(phoneProp) then DeleteEntity(phoneProp) end
        phoneProp = 0
    end
end

function Anim.CreateProp()
    Anim.DeleteProp()
    RequestModel(PROP_MODEL)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(PROP_MODEL) do
        if GetGameTimer() > timeout then return end
        Wait(10)
    end
    local ped = PlayerPedId()
    phoneProp = CreateObject(PROP_MODEL, 1.0, 1.0, 1.0, true, true, false)
    local bone = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(phoneProp, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, false, 2, true)
    SetModelAsNoLongerNeeded(PROP_MODEL)
end

-- plays `name` (and keeps it playing) until something else is asked for
function Anim.Play(name)
    current = { name = name }
    CreateThread(function()
        play(name)
        watch()
    end)
end

-- the phone goes away: stop the animation and delete the prop
function Anim.Stop()
    local old = current
    current = nil
    local ped = PlayerPedId()
    if old then StopAnimTask(ped, dictionary(), old.name, 2.5) end
    Anim.DeleteProp()
end

function Anim.OnOpen()
    CreateThread(function()
        if Call and Call.InCall() then
            Anim.Play('cellphone_call_to_text')
        else
            Anim.Play('cellphone_text_in')
        end
        SetTimeout(250, function()
            if phoneProp == 0 and (Phone.open or (Call and Call.InCall())) then
                CreateThread(Anim.CreateProp)
            end
        end)
    end)
end

function Anim.OnClose()
    if Call and Call.InCall() then
        Anim.Play('cellphone_text_to_call')
        return
    end
    Anim.Play('cellphone_text_out')
    SetTimeout(400, function()
        -- the player might have opened it again in these 400 ms
        if not Phone.open and not (Call and Call.InCall()) then Anim.Stop() end
    end)
end

-- a call was answered: the phone goes to the ear (or stays in the hand while it is open)
function Anim.OnCallActive()
    if phoneProp == 0 then CreateThread(Anim.CreateProp) end
    if Phone.open then
        Anim.Play('cellphone_text_to_call')
    else
        Anim.Play('cellphone_call_listen_base')
    end
end

function Anim.OnCallEnded()
    if not Phone.open then
        Anim.Stop()
    else
        Anim.Play('cellphone_text_in')
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local held = current ~= nil or phoneProp ~= 0
    current = nil
    Anim.DeleteProp()
    if held then ClearPedTasks(PlayerPedId()) end
end)
