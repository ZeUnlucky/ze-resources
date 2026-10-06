local QBCore = exports['qb-core']:GetCoreObject()

local helicamActive = false
local lockedVehicle = nil
local losLostAt = nil    -- when line of sight to the locked vehicle was first lost
local nextLosCheck = 0
local fov = (Config.Fov.max + Config.Fov.min) * 0.5

local models = {}
for _, name in ipairs(Config.Models) do
    models[#models + 1] = joaat(name)
end

-- Helpers

local function GetHeli()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return nil end
    for _, hash in ipairs(models) do
        if GetEntityModel(veh) == hash then return veh end
    end
    return nil
end

local function CanUse()
    if not Config.RestrictToLEO then return true end
    local job = QBCore.Functions.GetPlayerData().job
    return job and job.type == 'leo' and job.onduty
end

local function IsHeliHighEnough(heli)
    return GetEntityHeightAboveGround(heli) > Config.MinHeight
end

local function Click()
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
end

local function RotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function DrawTxt(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Finds the vehicle under the crosshair: a precise ray first, then the closest vehicle to the view line
local function GetVehicleInView(cam, heli)
    local origin = GetCamCoord(cam)
    local dir = RotToDir(GetCamRot(cam, 2))

    local ray = StartExpensiveSynchronousShapeTestLosProbe(origin.x, origin.y, origin.z,
        origin.x + dir.x * Config.LockRange, origin.y + dir.y * Config.LockRange, origin.z + dir.z * Config.LockRange,
        10, heli, 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity ~= 0 and IsEntityAVehicle(entity) then
        return entity
    end

    local best, bestOff
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= heli then
            local rel = GetEntityCoords(veh) - origin
            local along = rel.x * dir.x + rel.y * dir.y + rel.z * dir.z
            if along > 5.0 and along < Config.LockRange then
                local off = #(rel - dir * along)
                if off < Config.LockAssist + along * 0.02 and (not bestOff or off < bestOff) then
                    best, bestOff = veh, off
                end
            end
        end
    end
    return best
end

-- True unless world geometry or another vehicle blocks the line from the camera to the vehicle
local function HasLineOfSight(cam, heli, veh)
    local from = GetCamCoord(cam)
    local to = GetEntityCoords(veh)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 16, heli, 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    return hit ~= 1 or entity == veh
end

local function VehicleInfoText(veh)
    local name = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
    local plate = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1')
    local speed = math.ceil(GetEntitySpeed(veh) * 3.6)
    local pos = GetEntityCoords(veh)
    local s1, s2 = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local street = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then street = street .. ' | ' .. GetStreetNameFromHashKey(s2) end
    return ('%s  -  %s  -  %d km/h  -  %s'):format(name, plate, speed, street)
end

local function HandleZoom(cam)
    if IsControlJustPressed(0, 241) then fov = math.max(fov - Config.Fov.speed, Config.Fov.min) end
    if IsControlJustPressed(0, 242) then fov = math.min(fov + Config.Fov.speed, Config.Fov.max) end
    local current = GetCamFov(cam)
    if math.abs(fov - current) < 0.1 then fov = current end
    SetCamFov(cam, current + (fov - current) * 0.05)
end

local function HandleLook(cam, zoomValue)
    local ax, ay = GetDisabledControlNormal(0, 220), GetDisabledControlNormal(0, 221)
    if ax == 0.0 and ay == 0.0 then return end
    local rot = GetCamRot(cam, 2)
    local newZ = rot.z - ax * Config.PanSpeed * (zoomValue + 0.1)
    local newX = math.max(math.min(20.0, rot.x - ay * Config.PanSpeed * (zoomValue + 0.1)), -89.5)
    SetCamRot(cam, newX, 0.0, newZ, 2)
end

local function HideHud()
    HideHelpTextThisFrame()
    HideHudAndRadarThisFrame()
    for _, c in ipairs({ 1, 2, 3, 4, 11, 12, 13, 15, 18, 19 }) do
        HideHudComponentThisFrame(c)
    end
end

local function Unlock(cam)
    if not lockedVehicle then return end
    local rot = GetCamRot(cam, 2)
    StopCamPointing(cam)
    SetCamRot(cam, rot.x, 0.0, rot.z, 2)
    lockedVehicle = nil
end

-- Main loop

local function RunHelicam(heli)
    helicamActive = true
    lockedVehicle = nil

    local scaleform = RequestScaleformMovie('HELI_CAM')
    while not HasScaleformMovieLoaded(scaleform) do Wait(0) end

    local cam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToEntity(cam, heli, 0.0, 0.0, -1.5, true)
    SetCamRot(cam, 0.0, 0.0, GetEntityHeading(heli), 2)
    SetCamFov(cam, fov)
    RenderScriptCams(true, false, 0, true, false)
    SetTimecycleModifier('heliGunCam')
    SetTimecycleModifierStrength(0.3)

    PushScaleformMovieFunction(scaleform, 'SET_CAM_LOGO')
    PushScaleformMovieFunctionParameterInt(0)
    PopScaleformMovieFunctionVoid()

    local ped = PlayerPedId()
    while helicamActive and not IsEntityDead(ped) and GetVehiclePedIsIn(ped, false) == heli and IsHeliHighEnough(heli) do
        -- stop LMB from doing anything else (vehicle weapons, melee) and read it as a disabled control
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 69, true)
        DisableControlAction(0, 92, true)
        DisableControlAction(0, 257, true)

        if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 69) then
            Click()
            if lockedVehicle then
                Unlock(cam)
            else
                local target = GetVehicleInView(cam, heli)
                if target then
                    lockedVehicle = target
                    losLostAt, nextLosCheck = nil, 0
                    PointCamAtEntity(cam, target, 0.0, 0.0, 0.0, true)
                end
            end
        end

        local zoomValue = (1.0 / (Config.Fov.max - Config.Fov.min)) * (fov - Config.Fov.min)
        if lockedVehicle then
            if DoesEntityExist(lockedVehicle) then
                local now = GetGameTimer()
                if now >= nextLosCheck then
                    nextLosCheck = now + 150
                    if HasLineOfSight(cam, heli, lockedVehicle) then
                        losLostAt = nil
                    else
                        losLostAt = losLostAt or now
                    end
                end
                if losLostAt and now - losLostAt >= Config.LosGrace then
                    Unlock(cam)
                else
                    DrawTxt(VehicleInfoText(lockedVehicle), 0.5, 0.88, 0.45)
                end
            else
                Unlock(cam)
            end
        else
            HandleLook(cam, zoomValue)
        end

        HandleZoom(cam)
        HideHud()
        DrawTxt(lockedVehicle and '[LMB] Release target    [Scroll] Zoom    [H] Exit'
            or '[LMB] Lock target    [Scroll] Zoom    [H] Exit', 0.5, 0.94, 0.35)

        PushScaleformMovieFunction(scaleform, 'SET_ALT_FOV_HEADING')
        PushScaleformMovieFunctionParameterFloat(GetEntityCoords(heli).z)
        PushScaleformMovieFunctionParameterFloat(zoomValue)
        PushScaleformMovieFunctionParameterFloat(GetCamRot(cam, 2).z)
        PopScaleformMovieFunctionVoid()
        DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
        Wait(0)
    end

    helicamActive = false
    lockedVehicle = nil
    fov = (Config.Fov.max + Config.Fov.min) * 0.5
    ClearTimecycleModifier()
    RenderScriptCams(false, false, 0, true, false)
    SetScaleformMovieAsNoLongerNeeded(scaleform)
    DestroyCam(cam, false)
end

-- Toggle (H)

RegisterCommand(Config.Command, function()
    if helicamActive then
        Click()
        helicamActive = false
        return
    end

    local heli = GetHeli()
    if not heli or not CanUse() or not IsHeliHighEnough(heli) then return end
    Click()
    CreateThread(function() RunHelicam(heli) end)
end, false)

RegisterKeyMapping(Config.Command, 'Toggle helicopter camera', 'keyboard', Config.DefaultKey)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    helicamActive = false
    RenderScriptCams(false, false, 0, true, false)
    ClearTimecycleModifier()
end)
