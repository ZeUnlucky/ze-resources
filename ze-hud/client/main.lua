local QBCore = exports['qb-core']:GetCoreObject()

-- Shared between the client files (map.lua, stress.lua). Plain locals everywhere else.
Hud = {
    S = {},          -- live player settings, same keys as Config.Defaults
    stress = 0,
    seatbelt = false,
    cruise = false,
    inVehicle = false,
    visible = false, -- false while paused, in cinematic mode or logged out
    cinematic = false,
    fuel = -1,
    speedMultiplier = Config.UseMPH and 2.23694 or 3.6,
}

local S = Hud.S
local PlayerData = QBCore.Functions.GetPlayerData() or {}

local hunger, thirst = 100, 100
local nos, nitroActive = 0, false
local harness = false
local dev, radioActive = false, false
local menuOpen = false
local lastPayload

DisplayRadar(false)

local function clamp(value, min, max)
    if value ~= value then return min end -- NaN
    return math.max(min, math.min(max, value))
end

-- Settings ---------------------------------------------------------------------

local KVP = 'zeHudSettings'

local function loadSettings()
    local raw = GetResourceKvpString(KVP)
    local saved = raw and json.decode(raw)
    if type(saved) ~= 'table' then saved = {} end

    for key, default in pairs(Config.Defaults) do
        local value = saved[key]
        if type(value) == type(default) then S[key] = value else S[key] = default end
    end
    if S.mapShape ~= 'square' and S.mapShape ~= 'circle' then
        S.mapShape = Config.Defaults.mapShape
    end
    Hud.cinematic = S.cinematic
end

local function saveSettings()
    SetResourceKvp(KVP, json.encode(S))
end

loadSettings()

-- Sounds and notifications ----------------------------------------------------------
-- Frontend sounds, so there is no dependency on interact-sound.

local SOUNDS = {
    open = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 'soundMenu' },
    close = { 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 'soundMenu' },
    toggle = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 'soundToggle' },
    reset = { 'CANCEL', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 'soundReset' },
    fuel = { 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', nil },
}

function Hud.Sound(kind)
    local sound = SOUNDS[kind]
    if not sound then return end
    if sound[3] and not S[sound[3]] then return end
    PlaySoundFrontend(-1, sound[1], sound[2], true)
end

function Hud.Notify(text, kind)
    QBCore.Functions.Notify(text, kind or 'primary')
end

-- NUI ------------------------------------------------------------------------------

local function pushInit()
    SendNUIMessage({
        action = 'init',
        accent = Config.Accent,
        currency = Config.Currency,
        mph = Config.UseMPH,
        maxSpeed = Config.UseMPH and Config.SpeedMax.mph or Config.SpeedMax.kph,
        voiceLevels = #Config.VoiceRanges,
        stress = not Config.DisableStress,
        mapFrame = Config.MapFrame,
        settings = S,
    })
end

local function pushSettings()
    SendNUIMessage({ action = 'settings', settings = S })
end

local function send(payload)
    local encoded = json.encode(payload)
    if encoded == lastPayload then return end
    lastPayload = encoded
    SendNUIMessage(payload)
end

RegisterNUICallback('ready', function(_, cb)
    pushInit()
    cb('ok')
end)

-- Menu -----------------------------------------------------------------------------

local function openMenu()
    if menuOpen or not LocalPlayer.state.isLoggedIn then return end
    menuOpen = true
    Hud.Sound('open')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'menu', open = true, settings = S })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    Hud.Sound('close')
    SendNUIMessage({ action = 'menu', open = false })
end

RegisterCommand('hudmenu', openMenu, false)
RegisterKeyMapping('hudmenu', 'HUD settings', 'keyboard', Config.OpenMenu)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

local function onSettingChanged(key, value)
    if key == 'mapShape' then
        Hud.ApplyMinimap(true)
    elseif key == 'cinematic' then
        Hud.SetCinematic(value, true)
    end
end

RegisterNUICallback('set', function(data, cb)
    cb('ok')
    local key = type(data) == 'table' and data.key
    local value = type(data) == 'table' and data.value
    local default = key and Config.Defaults[key]
    if default == nil or type(value) ~= type(default) then return end
    if key == 'mapShape' and value ~= 'square' and value ~= 'circle' then return end
    if S[key] == value then return end

    S[key] = value
    saveSettings()
    Hud.Sound('toggle')
    onSettingChanged(key, value)
    pushSettings()
end)

local function restartHud()
    closeMenu()
    Hud.Sound('reset')
    Hud.Notify(Lang:t('notify.hud_restart'), 'error')
    SendNUIMessage({ action = 'restart' })
    Wait(2600)
    lastPayload = nil
    pushInit()
    Hud.Notify(Lang:t('notify.hud_start'), 'success')
end

local function resetSettings()
    for key, default in pairs(Config.Defaults) do S[key] = default end
    saveSettings()
    Hud.Sound('reset')
    Hud.Notify(Lang:t('notify.hud_reset'), 'success')
    Hud.SetCinematic(S.cinematic, false)
    Hud.ApplyMinimap(false)
    pushSettings()
end

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    local name = type(data) == 'table' and data.name
    if name == 'restart' then
        CreateThread(restartHud)
    elseif name == 'reset' then
        resetSettings()
    end
end)

RegisterCommand('resethud', function()
    CreateThread(restartHud)
end, false)

-- Player data -----------------------------------------------------------------------

local function syncMetadata()
    local metadata = PlayerData and PlayerData.metadata
    if not metadata then return end
    hunger = metadata.hunger or hunger
    thirst = metadata.thirst or thirst
    Hud.stress = metadata.stress or Hud.stress
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData() or {}
    syncMetadata()
    Wait(2000)
    lastPayload = nil
    pushInit()
    Hud.ApplyMinimap(false)
    Wait(1000)
    local metadata = PlayerData.metadata or {}
    if not (metadata.isdead or metadata.inlaststand) then
        SetEntityHealth(PlayerPedId(), 200)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    hunger, thirst = 100, 100
    Hud.stress = 0
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(value)
    PlayerData = value
    syncMetadata()
end)

CreateThread(function()
    Wait(1500)
    pushInit()
    if LocalPlayer.state.isLoggedIn then
        PlayerData = QBCore.Functions.GetPlayerData() or {}
        syncMetadata()
        Hud.ApplyMinimap(false)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    DisplayRadar(true)
end)

-- Events other resources trigger (same names as qb-hud) -------------------------------------

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst) -- qb-core, qb-smallresources
    hunger = newHunger
    thirst = newThirst
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    Hud.stress = newStress
end)

RegisterNetEvent('hud:client:UpdateNitrous', function(level, active) -- qb-mechanicjob
    nos = level or 0
    nitroActive = active and true or false
end)

RegisterNetEvent('hud:client:UpdateHarness', function() -- qb-smallresources
    -- the harness chip only needs to know it is worn, which hasHarness below tracks
end)

RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function() -- qb-smallresources
    Hud.seatbelt = not Hud.seatbelt
end)

RegisterNetEvent('seatbelt:client:ToggleCruise', function() -- qb-smallresources
    Hud.cruise = not Hud.cruise
end)

RegisterNetEvent('qb-admin:client:ToggleDevmode', function()
    dev = not dev
end)

AddEventHandler('pma-voice:radioActive', function(active)
    radioActive = active and true or false
end)

-- Money ------------------------------------------------------------------------------

RegisterNetEvent('hud:client:ShowAccounts', function(kind, amount)
    SendNUIMessage({
        action = 'money',
        mode = 'show',
        type = kind,
        value = math.floor(amount or 0),
    })
end)

RegisterNetEvent('hud:client:OnMoneyChange', function(kind, amount, isMinus)
    local money = PlayerData.money or {}
    SendNUIMessage({
        action = 'money',
        mode = 'change',
        type = kind,
        cash = math.floor(money.cash or 0),
        bank = math.floor(money.bank or 0),
        amount = math.floor(amount or 0),
        minus = isMinus and true or false,
    })
end)

-- Vehicle helpers ----------------------------------------------------------------------

local fuelCache = { veh = 0, time = 0, value = -1 }

local function getFuel(veh)
    local now = GetGameTimer()
    if fuelCache.veh ~= veh or now - fuelCache.time > 2000 then
        fuelCache.veh, fuelCache.time = veh, now
        local ok, fuel = pcall(function()
            return exports[Config.FuelResource]:GetFuel(veh)
        end)
        fuelCache.value = (ok and type(fuel) == 'number') and math.floor(fuel) or -1
    end
    return fuelCache.value
end

local function getGear(veh)
    local gear = GetVehicleCurrentGear(veh)
    if gear > 0 then return tostring(gear) end
    -- gear 0 is both reverse and neutral, tell them apart by the direction of travel
    local forward = GetEntitySpeedVector(veh, true).y
    return forward < -0.5 and 'R' or 'N'
end

local function getVoiceLevel()
    local proximity = LocalPlayer.state.proximity
    local distance = proximity and proximity.distance
    if not distance then return 2 end
    for level, range in ipairs(Config.VoiceRanges) do
        if distance <= range + 0.05 then return level end
    end
    return #Config.VoiceRanges
end

-- Vehicle classes: 8 motorcycles, 13 cycles, 14 boats, 15 helicopters, 16 planes, 21 trains
local function vehicleData(veh)
    local class = GetVehicleClass(veh)
    if class == 13 then return false end -- cycles keep the on-foot HUD

    local air = class == 15 or class == 16
    local boat = class == 14
    local fuel = getFuel(veh)
    Hud.fuel = fuel

    local data = {
        speed = math.ceil(GetEntitySpeed(veh) * Hud.speedMultiplier),
        fuel = fuel,
        engine = clamp(math.floor(GetVehicleEngineHealth(veh) / 10), 0, 100),
        nitro = nos,
        nitroOn = nitroActive,
        belt = Hud.seatbelt,
        beltable = not (air or boat or class == 8),
        harness = harness,
        cruise = Hud.cruise,
        air = air,
    }

    if not air and not boat then
        data.rpm = math.floor(clamp(GetVehicleCurrentRpm(veh), 0.0, 1.0) * 100) / 100
        data.gear = getGear(veh)
    end

    if air then
        local z = GetEntityCoords(veh).z
        data.alt = math.max(0, math.floor(Config.UseMPH and z * 3.28084 or z))
    end

    return data
end

-- Main loop ----------------------------------------------------------------------------

CreateThread(function()
    local wasInVehicle = false

    while true do
        local ped = PlayerPedId()
        local loggedIn = LocalPlayer.state.isLoggedIn
        local veh = loggedIn and GetVehiclePedIsIn(ped, false) or 0
        local inVehicle = veh ~= 0

        Hud.inVehicle = inVehicle

        if wasInVehicle and not inVehicle then
            Hud.seatbelt = false
            Hud.cruise = false
            Hud.fuel = -1
            harness = false
        end
        wasInVehicle = inVehicle

        if loggedIn then
            local playerId = PlayerId()
            local metadata = PlayerData.metadata or {}
            local show = not IsPauseMenuActive() and not Hud.cinematic
            Hud.visible = show

            -- the minimap shows in vehicles, or on foot if the player wants it
            local radar = not S.hideMap and not Hud.cinematic and (inVehicle or S.minimapOnFoot)
            DisplayRadar(radar)
            Hud.radar = radar

            local weapon = GetSelectedPedWeapon(ped)
            local maxHealth = GetEntityMaxHealth(ped) - 100
            local health = maxHealth > 0 and ((GetEntityHealth(ped) - 100) / maxHealth) * 100 or 0

            local underwater = IsPedSwimmingUnderWater(ped)
            local stamina
            if underwater then
                stamina = GetPlayerUnderwaterTimeRemaining(playerId) * 10
            else
                stamina = 100 - GetPlayerSprintStaminaRemaining(playerId)
            end

            send({
                action = 'tick',
                show = show,
                health = math.floor(clamp(health, 0, 100)),
                dead = (IsEntityDead(ped) or metadata.inlaststand or metadata.isdead) and true or false,
                armor = GetPedArmour(ped),
                hunger = math.floor(hunger),
                thirst = math.floor(thirst),
                stress = math.floor(Hud.stress),
                stamina = math.floor(clamp(stamina, 0, 100)),
                underwater = underwater,
                voice = getVoiceLevel(),
                talking = NetworkIsPlayerTalking(playerId),
                radio = tonumber(LocalPlayer.state.radioChannel) or 0,
                radioActive = radioActive,
                armed = weapon ~= `WEAPON_UNARMED` and not Config.WhitelistedWeaponArmed[weapon],
                chute = GetPedParachuteState(ped) >= 0,
                dev = dev,
                radar = radar,
                frame = radar and S.mapFrame,
                veh = inVehicle and vehicleData(veh),
            })
        else
            Hud.visible = false
            send({ action = 'tick', show = false })
        end

        if inVehicle then
            Wait(S.optimized and Config.Tick.vehOptimized or Config.Tick.vehSynced)
        else
            Wait(S.optimized and Config.Tick.footOptimized or Config.Tick.footSynced)
        end
    end
end)

-- Harness: shown while the player carries one, in a vehicle
CreateThread(function()
    while true do
        Wait(1000)
        if Hud.inVehicle then
            local found = false
            for _, item in pairs(PlayerData.items or {}) do
                if item.name == 'harness' then
                    found = true
                    break
                end
            end
            harness = found
        end
    end
end)

-- Low fuel alert
CreateThread(function()
    while true do
        if Hud.inVehicle and S.notifyFuel and Hud.fuel >= 0 and Hud.fuel <= Config.LowFuelLevel then
            Hud.Sound('fuel')
            Hud.Notify(Lang:t('notify.low_fuel'), 'error')
            Wait(Config.LowFuelRepeat)
        else
            Wait(5000)
        end
    end
end)

-- Compass --------------------------------------------------------------------------------

local street = { time = 0, street1 = '', street2 = '', area = '' }

local function getStreet(ped)
    local now = GetGameTimer()
    if now - street.time > 1500 then
        street.time = now
        local pos = GetEntityCoords(ped)
        local hash1, hash2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
        street.street1 = GetStreetNameFromHashKey(hash1) or ''
        street.street2 = hash2 ~= 0 and (GetStreetNameFromHashKey(hash2) or '') or ''
        local label = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z))
        street.area = (label and label ~= 'NULL') and label or ''
    end
    return street
end

CreateThread(function()
    local lastKey, wasShown = '', false

    while true do
        Wait(S.compassOptimized and 50 or 0)

        local show = Hud.visible and S.compassShow and (Hud.inVehicle or S.compassOnFoot)
        if show then
            local ped = PlayerPedId()
            local heading
            if S.compassFollowCam then
                heading = 360.0 - ((GetGameplayCamRot(0).z + 360.0) % 360.0)
            else
                heading = 360.0 - GetEntityHeading(ped)
            end
            heading = math.floor(heading + 0.5) % 360

            local where = getStreet(ped)
            local key = ('%d|%s|%s|%s'):format(heading, where.street1, where.street2, where.area)
            if key ~= lastKey or not wasShown then
                lastKey = key
                SendNUIMessage({
                    action = 'compass',
                    show = true,
                    heading = heading,
                    street1 = where.street1,
                    street2 = where.street2,
                    area = where.area,
                })
            end
        elseif wasShown then
            lastKey = ''
            SendNUIMessage({ action = 'compass', show = false })
        end
        wasShown = show and true or false
    end
end)
