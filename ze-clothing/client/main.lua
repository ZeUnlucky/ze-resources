if ZE_DISABLED then return end

-- Menu lifecycle, camera, NUI callbacks and the events other resources trigger.
-- The skin itself (what every key means and how it is applied) lives in skin.lua, the shops and zones in stores.lua.

local QBCore = exports['qb-core']:GetCoreObject()

ZeClothing = {}

local creating = false          -- the menu is open (IsCreatingCharacter)
local cam = -1
local headingToCam = 0.0
local camOffset = 2.0
local customCamLocation = nil   -- vector4, set for job locker rooms
local previousData = nil        -- json of the skin when the menu opened, for Cancel
local previousModel = nil
local removeWear = false
local faceProps = {
    [1] = { Prop = -1, Texture = -1 },
    [2] = { Prop = -1, Texture = -1 },
    [3] = { Prop = -1, Texture = -1 },
    [4] = { Prop = -1, Palette = -1, Texture = -1 }, -- these three are ped components, not props
    [5] = { Prop = -1, Palette = -1, Texture = -1 },
    [6] = { Prop = -1, Palette = -1, Texture = -1 },
}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function playerData()
    return QBCore.Functions.GetPlayerData() or {}
end

local function isFemale()
    local info = playerData().charinfo
    return info ~= nil and tonumber(info.gender) == 1
end

local function hasTracker()
    local meta = playerData().metadata
    return meta ~= nil and meta.tracker and true or false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Model
-- ---------------------------------------------------------------------------------------------------------------

local function modelList()
    return isFemale() and Config.WomanPlayerModels or Config.ManPlayerModels
end

local function modelInfo()
    local list = modelList()
    local current = GetEntityModel(PlayerPedId())
    local index = 1
    for i, name in ipairs(list) do
        if GetHashKey(name) == current then
            index = i
            break
        end
    end
    return { index = index, name = list[index], count = #list }
end

-- Blocks until the model is loaded, so call it from a thread. Returns false for a model that does not exist
-- (qb-clothing would wait for it forever).
local function setPlayerModel(model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedComponentVariation(PlayerPedId(), 0, 0, 0, 2)
    return true
end

-- The player can click through models quickly. Only the last one asked for matters, one thread does the switching.
local modelTarget, modelBusy = nil, false
local function switchModel(name)
    modelTarget = name
    if modelBusy then return end
    modelBusy = true
    CreateThread(function()
        while modelTarget do
            local target = modelTarget
            modelTarget = nil
            if setPlayerModel(GetHashKey(target)) then
                Skin.data = Skin.Defaults(true)
                local ped = PlayerPedId()
                Skin.ApplyAll(ped, Skin.data)
                if creating then
                    FreezeEntityPosition(ped, true) -- a new model is a new ped, the old one was the frozen one
                    SendNUIMessage({ action = 'values', values = Skin.DescribeAll(ped) })
                end
            end
        end
        modelBusy = false
    end)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Camera
-- ---------------------------------------------------------------------------------------------------------------

local function positionByRelativeHeading(ped, heading, dist)
    local pedPos = GetEntityCoords(ped)
    local x = pedPos.x + math.cos(heading * (math.pi / 180)) * dist
    local y = pedPos.y + math.sin(heading * (math.pi / 180)) * dist
    return x, y
end

local function enableCam()
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0, 2.0, 0)
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(cam, false)
    if not DoesCamExist(cam) then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
        SetCamCoord(cam, coords.x, coords.y, coords.z + 0.2)
        SetCamRot(cam, 0.0, 0.0, GetEntityHeading(ped) + 180, 2)
    end

    if customCamLocation ~= nil then
        SetCamCoord(cam, customCamLocation.x, customCamLocation.y, customCamLocation.z)
        SetCamRot(cam, 0.0, 0.0, customCamLocation.w, 2)
    end

    headingToCam = GetEntityHeading(ped) + 90
    camOffset = 2.0
end

local function disableCam()
    RenderScriptCams(false, true, 250, true, false)
    DestroyCam(cam, false)
    FreezeEntityPosition(PlayerPedId(), false)
end

local function orbitCam(degrees)
    local ped = PlayerPedId()
    local pedPos = GetEntityCoords(ped)
    local camPos = GetCamCoord(cam)
    headingToCam = headingToCam + degrees
    local x, y = positionByRelativeHeading(ped, headingToCam, camOffset)
    SetCamCoord(cam, x, y, camPos.z)
    PointCamAtCoord(cam, pedPos.x, pedPos.y, camPos.z)
end

-- value from the NUI: 0 whole body, 1 head, 2 torso, 3 legs and shoes
local CAM_PRESETS = {
    [1] = { offset = 0.75, height = 0.65 },
    [2] = { offset = 1.0, height = 0.2 },
    [3] = { offset = 1.0, height = -0.5 },
}

-- ---------------------------------------------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------------------------------------------

local function translations()
    local out = {}
    for key, text in pairs(Lang.phrases) do
        if key:sub(1, 3) == 'ui.' then
            out[key:sub(4)] = text
        end
    end
    return out
end

local function menu(id, label, selected, outfits)
    return { menu = id, label = label, selected = selected or false, outfits = outfits }
end

local function openMenu(menus, title, camLocation)
    if creating then return end
    local ped = PlayerPedId()
    creating = true
    customCamLocation = camLocation
    previousData = json.encode(Skin.data)
    previousModel = GetEntityModel(ped)

    SendNUIMessage({
        action = 'open',
        title = title,
        menus = menus,
        values = Skin.DescribeAll(ped),
        hasTracker = hasTracker(),
        modelSwitch = Config.ModelSwitch and true or false,
        model = modelInfo(),
        tr = translations(),
        accent = Config.Accent,
    })
    SetNuiFocus(true, true)
    SetCursorLocation(Config.CursorStart.x, Config.CursorStart.y)
    FreezeEntityPosition(ped, true)
    enableCam()
end

local function saveSkin()
    TriggerServerEvent('qb-clothing:saveSkin', GetEntityModel(PlayerPedId()), json.encode(Skin.data))
end

-- Cancel: put back the skin (and the model, which the surgeon menu can change) from when the menu opened.
local function revertSkin()
    local previous = json.decode(previousData or '')
    if type(previous) ~= 'table' then return end
    CreateThread(function()
        if previousModel and GetEntityModel(PlayerPedId()) ~= previousModel then
            setPlayerModel(previousModel)
        end
        Skin.data = Skin.Fill(previous)
        Skin.ApplyAll(PlayerPedId(), Skin.data)
    end)
end

local function closeMenu(save)
    if not creating then return end
    SetNuiFocus(false, false)
    if save then saveSkin() else revertSkin() end
    disableCam()
    creating = false
    TriggerEvent('qb-clothing:client:onMenuClose')
end

-- Called by stores.lua and the events below. `kind` is full, clothing, barber or surgeon.
function ZeClothing.Open(kind, camLocation)
    local meta = playerData().metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end

    if kind == 'barber' then
        openMenu({ menu('hair', Lang:t('menu.hair'), true) }, Lang:t('store.barber'), camLocation)
    elseif kind == 'surgeon' then
        openMenu({ menu('features', Lang:t('menu.features'), true) }, Lang:t('store.surgeon'), camLocation)
    elseif kind == 'clothing' then
        openMenu({
            menu('clothing', Lang:t('menu.clothing'), true),
            menu('accessories', Lang:t('menu.accessories')),
        }, Lang:t('store.clothing'), camLocation)
    else -- 'full' (the admin menu) and 'creator' (a brand new character)
        openMenu({
            menu('features', Lang:t('menu.features'), true),
            menu('hair', Lang:t('menu.hair')),
            menu('clothing', Lang:t('menu.clothing')),
            menu('accessories', Lang:t('menu.accessories')),
        }, Lang:t(kind == 'creator' and 'store.creator' or 'store.wardrobe'), camLocation)
    end
end

-- Saved outfits only (outfit changers, houses, apartments, boss menus).
function ZeClothing.OpenOutfits(camLocation)
    local meta = playerData().metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end

    QBCore.Functions.TriggerCallback('qb-clothing:server:getOutfits', function(result)
        openMenu({ menu('outfits', Lang:t('menu.outfits'), true, result) }, Lang:t('store.outfitchanger'), camLocation)
    end)
end

-- Job and gang locker rooms: presets for the rank, plus the player's own outfits and the clothing tabs.
-- `outfitsForJob` is Config.Outfits[job]; the presets are indexed by gender and rank level.
function ZeClothing.OpenRoom(gradeLevel, outfitsForJob, camLocation)
    local meta = playerData().metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end

    local gender = isFemale() and 'female' or 'male'
    local presets = outfitsForJob and outfitsForJob[gender] and outfitsForJob[gender][gradeLevel] or {}
    QBCore.Functions.TriggerCallback('qb-clothing:server:getOutfits', function(result)
        openMenu({
            menu('presets', Lang:t('menu.presets'), true, presets),
            menu('outfits', Lang:t('menu.outfits'), false, result),
            menu('clothing', Lang:t('menu.clothing')),
            menu('accessories', Lang:t('menu.accessories')),
        }, Lang:t('store.room'), camLocation)
    end)
end

-- ---------------------------------------------------------------------------------------------------------------
-- Exports
-- ---------------------------------------------------------------------------------------------------------------

local function reloadSkin(health)
    local ped = PlayerPedId()
    health = health or GetEntityHealth(ped)
    local maxhealth = GetEntityMaxHealth(ped)

    if not setPlayerModel(GetHashKey(isFemale() and 'mp_f_freemode_01' or 'mp_m_freemode_01')) then return end
    Wait(1000) -- safety delay

    TriggerServerEvent('qb-clothes:loadPlayerSkin') -- loads the saved model and clothes
    SetPedMaxHealth(PlayerPedId(), maxhealth)
    Wait(1000)
    SetEntityHealth(PlayerPedId(), health)
end

local API = {
    reloadSkin = reloadSkin,
    IsCreatingCharacter = function() return creating end,
    getOutfits = function(gradeLevel, data) ZeClothing.OpenRoom(gradeLevel, data, nil) end,
}

local ownName = GetCurrentResourceName()
for name, fn in pairs(API) do
    exports(name, fn)
    if ownName ~= 'qb-clothing' then -- the stand-in is called qb-clothing, so exports['qb-clothing'] keeps working
        AddEventHandler(('__cfx_export_qb-clothing_%s'):format(name), function(setCB)
            setCB(fn)
        end)
    end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------------------------------

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- restarted with a player already in: pick their saved skin up again, so the menu does not open on defaults
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
        ZeClothing.LoadStores()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName or not creating then return end
    SetNuiFocus(false, false)
    disableCam()
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-clothes:loadPlayerSkin')
    ZeClothing.LoadStores()
end)

-- admin menu: /clothing
RegisterNetEvent('qb-clothing:client:openMenu', function()
    ZeClothing.Open('full', nil)
end)

RegisterNetEvent('qb-clothing:client:openOutfitMenu', function()
    ZeClothing.OpenOutfits(nil)
end)

RegisterNetEvent('qb-clothing:client:reloadOutfits', function(myOutfits)
    SendNUIMessage({ action = 'outfits', outfits = myOutfits or {} })
end)

-- A brand new character: freemode model of their gender, everything on its default, then the full menu.
RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
    QBCore.Functions.GetPlayerData(function(pData)
        local female = pData and pData.charinfo and tonumber(pData.charinfo.gender) == 1
        CreateThread(function()
            if setPlayerModel(GetHashKey(female and 'mp_f_freemode_01' or 'mp_m_freemode_01')) then
                Skin.data = Skin.Defaults(true)
                Skin.ApplyAll(PlayerPedId(), Skin.data)
            end
            ZeClothing.Open('creator', nil)
        end)
    end)
end)

-- The server sends the saved model and skin after login. `isNew` is true when the character has none.
RegisterNetEvent('qb-clothes:loadSkin', function(isNew, model, data)
    if isNew or not model or not data then return end
    CreateThread(function()
        model = tonumber(model)
        if not model or not setPlayerModel(model) then return end
        local decoded = type(data) == 'string' and json.decode(data) or data
        if type(decoded) ~= 'table' then return end
        TriggerEvent('qb-clothing:client:loadPlayerClothing', decoded, PlayerPedId())
    end)
end)

-- Also used by qb-multicharacter to dress its preview ped, which is why `ped` can be someone else.
RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function(data, ped)
    if type(data) ~= 'table' then return end
    local own = PlayerPedId()
    ped = ped or own

    data = Skin.Fill(data)
    for i = 0, 11 do
        SetPedComponentVariation(ped, i, 0, 0, 0)
    end
    for i = 0, 7 do
        ClearPedProp(ped, i)
    end
    Skin.ApplyAll(ped, data)

    if ped == own then
        Skin.data = data
    end
end)

-- Puts an outfit on (prison uniforms, police tracker, parachute, saved outfits). `oData.outfitData` holds the
-- skin keys to change, as a table or as json.
RegisterNetEvent('qb-clothing:client:loadOutfit', function(oData)
    if type(oData) ~= 'table' then return end
    local data = oData.outfitData
    if type(data) == 'string' then data = json.decode(data) end
    if type(data) ~= 'table' then return end

    local ped = PlayerPedId()
    Skin.ApplyOutfit(ped, data)

    if hasTracker() then
        SetPedComponentVariation(ped, 7, 13, 0, 0)
    elseif data.accessory == nil then
        -- an outfit without a neck accessory takes the current one off
        Skin.data.accessory.item = 0
        Skin.data.accessory.texture = 0
        SetPedComponentVariation(ped, 7, -1, 0, 2)
    end

    if oData.outfitName ~= nil then
        QBCore.Functions.Notify(Lang:t('notify.outfit_chosen', { outfit = oData.outfitName }))
    end
    if creating then
        SendNUIMessage({ action = 'values', values = Skin.DescribeAll(ped) })
    end
end)

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(5)
    end
end

-- 1 hat, 2 glasses, 3 ear piece, 4 mask, 5 top: take it off or put it back on with an animation (radial menu).
RegisterNetEvent('qb-clothing:client:adjustfacewear', function(wearType)
    local meta = playerData().metadata
    if meta and meta.ishandcuffed then return end
    removeWear = not removeWear

    local ped = PlayerPedId()
    local animSet, animOn, animOff = 'mp_masks@on_foot', 'put_on_mask', 'put_on_mask'
    local propIndex = 0

    faceProps[6].Prop = GetPedDrawableVariation(ped, 0)
    faceProps[6].Palette = GetPedPaletteVariation(ped, 0)
    faceProps[6].Texture = GetPedTextureVariation(ped, 0)

    for i = 0, 3 do
        if GetPedPropIndex(ped, i) ~= -1 then
            faceProps[i + 1].Prop = GetPedPropIndex(ped, i)
        end
        if GetPedPropTextureIndex(ped, i) ~= -1 then
            faceProps[i + 1].Texture = GetPedPropTextureIndex(ped, i)
        end
    end

    if GetPedDrawableVariation(ped, 1) ~= -1 then
        faceProps[4].Prop = GetPedDrawableVariation(ped, 1)
        faceProps[4].Palette = GetPedPaletteVariation(ped, 1)
        faceProps[4].Texture = GetPedTextureVariation(ped, 1)
    end

    if GetPedDrawableVariation(ped, 11) ~= -1 then
        faceProps[5].Prop = GetPedDrawableVariation(ped, 11)
        faceProps[5].Palette = GetPedPaletteVariation(ped, 11)
        faceProps[5].Texture = GetPedTextureVariation(ped, 11)
    end

    if wearType == 1 then
        propIndex = 0
    elseif wearType == 2 then
        propIndex = 1
        animSet, animOn, animOff = 'clothingspecs', 'take_off', 'take_off'
    elseif wearType == 3 then
        propIndex = 2
    elseif wearType == 4 then
        propIndex = 1
        if removeWear then
            animSet, animOn, animOff = 'missfbi4', 'takeoff_mask', 'takeoff_mask'
        end
    elseif wearType == 5 then
        propIndex = 11
        animSet, animOn, animOff = 'oddjobs@basejump@ig_15', 'puton_parachute', 'puton_parachute'
    end

    loadAnimDict(animSet)
    if wearType == 5 and removeWear then
        SetPedComponentVariation(ped, 3, 2, faceProps[6].Texture, faceProps[6].Palette)
    end

    if removeWear then
        TaskPlayAnim(ped, animSet, animOff, 4.0, 3.0, -1, 49, 1.0, false, false, false)
        Wait(500)
        if wearType ~= 5 then
            if wearType == 4 then
                SetPedComponentVariation(ped, propIndex, -1, -1, -1)
            elseif wearType ~= 2 then
                ClearPedProp(ped, propIndex)
            end
        end
    else
        TaskPlayAnim(ped, animSet, animOn, 4.0, 3.0, -1, 49, 1.0, false, false, false)
        Wait(500)
        if wearType ~= 5 and wearType ~= 2 then
            if wearType == 4 then
                SetPedComponentVariation(ped, propIndex, faceProps[wearType].Prop, faceProps[wearType].Texture, faceProps[wearType].Palette)
            else
                SetPedPropIndex(ped, propIndex, faceProps[propIndex + 1].Prop, faceProps[propIndex + 1].Texture, false)
            end
        end
    end

    if wearType == 5 then
        if not removeWear then
            SetPedComponentVariation(ped, 3, 1, faceProps[6].Texture, faceProps[6].Palette)
            SetPedComponentVariation(ped, propIndex, faceProps[wearType].Prop, faceProps[wearType].Texture, faceProps[wearType].Palette)
        else
            SetPedComponentVariation(ped, propIndex, -1, -1, -1)
        end
        Wait(1800)
    end

    if wearType == 2 then
        Wait(600)
        if removeWear then
            ClearPedProp(ped, propIndex)
        else
            Wait(140)
            SetPedPropIndex(ped, propIndex, faceProps[propIndex + 1].Prop, faceProps[propIndex + 1].Texture, false)
        end
    end

    if wearType == 4 and removeWear then
        Wait(1200)
    end
    ClearPedTasks(ped)
end)

RegisterCommand('refreshskin', function()
    reloadSkin(GetEntityHealth(PlayerPedId()))
end, false)

-- ---------------------------------------------------------------------------------------------------------------
-- NUI callbacks
-- ---------------------------------------------------------------------------------------------------------------

-- One row was changed. The reply is the row's new state (its range can change with the item).
RegisterNUICallback('updateSkin', function(data, cb)
    local ped = PlayerPedId()
    if data.clothingType == 'accessory' and hasTracker() then
        QBCore.Functions.Notify(Lang:t('notify.error_bracelet'), 'error')
        cb(Skin.Describe(ped, 'accessory'))
        return
    end
    cb(Skin.Change(ped, data.clothingType, data.type, data.articleNumber) or {})
end)

RegisterNUICallback('close', function(data, cb)
    cb('ok')
    closeMenu(data and data.save == true)
end)

RegisterNUICallback('selectOutfit', function(data, cb)
    cb('ok')
    TriggerEvent('qb-clothing:client:loadOutfit', data)
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    cb('ok')
    local name = type(data.outfitName) == 'string' and data.outfitName or ''
    TriggerServerEvent('qb-clothes:saveOutfit', name, GetEntityModel(PlayerPedId()), Skin.data)
end)

RegisterNUICallback('removeOutfit', function(data, cb)
    cb('ok')
    if type(data.outfitName) ~= 'string' or type(data.outfitId) ~= 'string' then return end
    TriggerServerEvent('qb-clothing:server:removeOutfit', data.outfitName, data.outfitId)
    QBCore.Functions.Notify(Lang:t('notify.outfit_deleted', { outfit = data.outfitName }))
end)

RegisterNUICallback('setCurrentPed', function(data, cb)
    local list = modelList()
    local index = clamp(math.floor((tonumber(data.ped) or 1) + 0.5), 1, #list)
    cb({ index = index, name = list[index], count = #list })
    switchModel(list[index])
end)

RegisterNUICallback('setupCam', function(data, cb)
    cb('ok')
    local preset = CAM_PRESETS[tonumber(data.value)] or { offset = 2.0, height = 0.2 }
    local ped = PlayerPedId()
    local pedPos = GetEntityCoords(ped)
    camOffset = preset.offset
    local x, y = positionByRelativeHeading(ped, headingToCam, camOffset)
    SetCamCoord(cam, x, y, pedPos.z + preset.height)
    PointCamAtCoord(cam, pedPos.x, pedPos.y, pedPos.z + preset.height)
end)

RegisterNUICallback('rotateRight', function(_, cb)
    cb('ok')
    orbitCam(2.5)
end)

RegisterNUICallback('rotateLeft', function(_, cb)
    cb('ok')
    orbitCam(-2.5)
end)
