local S = Hud.S

-- Minimap ----------------------------------------------------------------------------------
-- The component positions below are the ones qb-hud used, so the minimap lands in the same place
-- and Config.MapFrame (the NUI frame around it) keeps lining up.

local applying = false

local function loadTextureDict(dict)
    RequestStreamedTextureDict(dict, false)
    local timeout = GetGameTimer() + 3000
    while not HasStreamedTextureDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(0)
    end
end

local function applySquare(offset)
    loadTextureDict('squaremap')
    SetMinimapClipType(0)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')
    SetMinimapComponentPosition('minimap', 'L', 'B', 0.0 + offset, -0.047, 0.1638, 0.183)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.0 + offset, 0.0, 0.128, 0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01 + offset, 0.025, 0.262, 0.300)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetBigmapActive(true, false)
    SetMinimapClipType(0)
    Wait(50)
    SetBigmapActive(false, false)
end

local function applyCircle(offset)
    loadTextureDict('circlemap')
    SetMinimapClipType(1)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'circlemap', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'circlemap', 'radarmasksm')
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0100 + offset, -0.030, 0.180, 0.258)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.200 + offset, 0.0, 0.065, 0.20)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.00 + offset, 0.015, 0.252, 0.338)
    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetMinimapClipType(1)
    SetBigmapActive(true, false)
    Wait(50)
    SetBigmapActive(false, false)
end

-- announce: tell the player when the shape changed
function Hud.ApplyMinimap(announce)
    if applying then return end
    applying = true

    CreateThread(function()
        -- ultrawide screens push the minimap to the right, pull it back (credit to Dalrae for the solve)
        local defaultAspect = 1920 / 1080
        local width, height = GetActiveScreenResolution()
        local aspect = width / height
        local offset = 0.0
        if aspect > defaultAspect then
            offset = ((defaultAspect - aspect) / 3.6) - 0.008
        end

        local shape = S.mapShape
        if shape == 'circle' then applyCircle(offset) else applySquare(offset) end

        applying = false
        if announce and S.notifyMap then
            Hud.Notify(Lang:t(shape == 'circle' and 'notify.map_circle' or 'notify.map_square'))
        end
    end)
end

CreateThread(function()
    -- keep the minimap scaleform loaded, the bigmap trick above relies on it
    local minimap = RequestScaleformMovie('minimap')
    local timeout = GetGameTimer() + 5000
    while not HasScaleformMovieLoaded(minimap) and GetGameTimer() < timeout do
        Wait(0)
    end

    while true do
        SetBigmapActive(false, false)
        SetRadarZoom(1000)
        Wait(500)
    end
end)

-- Cinematic mode -------------------------------------------------------------------------------

local barHeight, barTarget = 0.0, S.cinematic and Config.CinematicBar or 0.0

function Hud.SetCinematic(enabled, announce)
    Hud.cinematic = enabled and true or false
    barTarget = Hud.cinematic and Config.CinematicBar or 0.0
    if announce and S.notifyCinematic then
        Hud.Notify(Lang:t(Hud.cinematic and 'notify.cinematic_on' or 'notify.cinematic_off'), Hud.cinematic and 'primary' or 'error')
    end
end

CreateThread(function()
    while true do
        if barHeight ~= barTarget then
            barHeight = barHeight + (barTarget - barHeight) * 0.12
            if math.abs(barTarget - barHeight) < 0.0005 then barHeight = barTarget end
        end

        if barHeight > 0.0 then
            -- rects are centred on the screen edge, so the visible bar is half of the rect height
            DrawRect(0.5, 0.0, 1.0, barHeight * 2.0, 0, 0, 0, 255)
            DrawRect(0.5, 1.0, 1.0, barHeight * 2.0, 0, 0, 0, 255)
            Wait(0)
        else
            Wait(barTarget > 0.0 and 0 or 250)
        end
    end
end)
