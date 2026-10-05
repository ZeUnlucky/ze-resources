-- The skin engine: what every skin key means, how it is applied to a ped, and what values it may take.
--
-- qb-clothing spelled this out three times (editing, loading, cancelling) with a copy of the same ~100 lines each,
-- and the copies had drifted apart (cancel forgot to divide face features by 10, cheek_2 and the neck wrote into the
-- wrong slot, glasses could not be cleared, ...). Here every key has one definition and one apply function.
--
-- The saved format is unchanged: a table of skin keys, each { item, texture, defaultItem, defaultTexture }
-- (facemix has skinMix / shapeMix instead). Existing rows in `playerskins` and `player_outfits` load as they are.

-- Do not run next to the original qb-clothing: both would answer the same events.
ZE_DISABLED = false
if GetCurrentResourceName() ~= 'qb-clothing' and GetResourceState('qb-clothing') == 'started' then
    local description = GetResourceMetadata('qb-clothing', 'description', 0) or ''
    if not description:find('ze-clothing stand-in', 1, true) then
        ZE_DISABLED = true
        print('^1[ze-clothing] The original qb-clothing is running as well. Move it out of the resources folder and restart. ze-clothing is not starting.^7')
        return
    end
end

Skin = {}

-- ---------------------------------------------------------------------------------------------------------------
-- Definitions
-- ---------------------------------------------------------------------------------------------------------------

local COMPONENTS = { -- skin key -> ped component id, palette used when the item changes
    ['arms'] = { id = 3, palette = 2 },
    ['t-shirt'] = { id = 8, palette = 2 },
    ['torso2'] = { id = 11, palette = 2 },
    ['pants'] = { id = 4, palette = 0 },
    ['vest'] = { id = 9, palette = 2 },
    ['shoes'] = { id = 6, palette = 2 },
    ['bag'] = { id = 5, palette = 2 },
    ['accessory'] = { id = 7, palette = 2 },
    ['decals'] = { id = 10, palette = 2 },
    ['mask'] = { id = 1, palette = 2 },
}

local PROPS = { hat = 0, glass = 1, ear = 2, watch = 6, bracelet = 7 }

local OVERLAYS = { eyebrows = 2, beard = 1, blush = 5, lipstick = 8, makeup = 4, ageing = 3 }

local FEATURES = { -- skin key -> ped face feature index
    nose_0 = 0, nose_1 = 1, nose_2 = 2, nose_3 = 3, nose_4 = 4, nose_5 = 5,
    eyebrown_high = 6, eyebrown_forward = 7,
    cheek_1 = 8, cheek_2 = 9, cheek_3 = 10,
    eye_opening = 11, lips_thickness = 12,
    jaw_bone_width = 13, jaw_bone_back_lenght = 14,
    chimp_bone_lowering = 15, chimp_bone_lenght = 16, chimp_bone_width = 17, chimp_hole = 18,
    neck_thikness = 19,
}

local DEF = {
    face = { kind = 'blend' }, face2 = { kind = 'blend' }, facemix = { kind = 'blend' },
    hair = { kind = 'hair' },
    moles = { kind = 'moles', resetTexture = 10 }, -- picking a mole type should show it at full opacity
    eye_color = { kind = 'eye' },
}
for key, c in pairs(COMPONENTS) do DEF[key] = { kind = 'comp', id = c.id, palette = c.palette } end
for key, id in pairs(PROPS) do DEF[key] = { kind = 'prop', id = id } end
for key, id in pairs(OVERLAYS) do DEF[key] = { kind = 'overlay', id = id } end
for key, id in pairs(FEATURES) do DEF[key] = { kind = 'feature', id = id } end

-- The order a full skin is applied in (the head blend first, the rest on top of it).
local ORDER = {
    'face', 'hair', 'eyebrows', 'beard', 'blush', 'lipstick', 'makeup', 'ageing', 'moles', 'eye_color',
    'nose_0', 'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5', 'eyebrown_high', 'eyebrown_forward',
    'cheek_1', 'cheek_2', 'cheek_3', 'eye_opening', 'lips_thickness', 'jaw_bone_width', 'jaw_bone_back_lenght',
    'chimp_bone_lowering', 'chimp_bone_lenght', 'chimp_bone_width', 'chimp_hole', 'neck_thikness',
    'pants', 'arms', 't-shirt', 'vest', 'torso2', 'shoes', 'mask', 'decals', 'accessory', 'bag',
    'hat', 'glass', 'ear', 'watch', 'bracelet',
}

-- What an outfit changes: clothes and accessories, never the face or hair.
local OUTFIT_KEYS = {
    'arms', 't-shirt', 'torso2', 'vest', 'decals', 'accessory', 'bag', 'pants', 'shoes',
    'mask', 'hat', 'glass', 'ear', 'watch', 'bracelet',
}

local function entry(item, texture, defaultItem, defaultTexture)
    return { item = item, texture = texture, defaultItem = defaultItem, defaultTexture = defaultTexture }
end

-- The first values are what a fresh skin starts with (the same table qb-clothing started from).
local BASE = {
    face = entry(0, 0, 0, 0), face2 = entry(0, 0, 0, 0),
    facemix = { skinMix = 0, shapeMix = 0, defaultSkinMix = 0.0, defaultShapeMix = 0.0 },
    pants = entry(0, 0, 0, 0), hair = entry(0, 0, 0, 0),
    eyebrows = entry(-1, 1, -1, 1), beard = entry(-1, 1, -1, 1), blush = entry(-1, 1, -1, 1),
    lipstick = entry(-1, 1, -1, 1), makeup = entry(-1, 1, -1, 1), ageing = entry(-1, 0, -1, 0),
    arms = entry(0, 0, 0, 0), ['t-shirt'] = entry(1, 0, 1, 0), torso2 = entry(0, 0, 0, 0),
    vest = entry(0, 0, 0, 0), bag = entry(0, 0, 0, 0), shoes = entry(0, 0, 1, 0),
    mask = entry(0, 0, 0, 0), hat = entry(-1, 0, -1, 0), glass = entry(0, 0, 0, 0),
    ear = entry(-1, 0, -1, 0), watch = entry(-1, 0, -1, 0), bracelet = entry(-1, 0, -1, 0),
    accessory = entry(0, 0, 0, 0), decals = entry(0, 0, 0, 0),
    eye_color = entry(-1, 0, -1, 0), moles = entry(0, 0, -1, 0),
}
for key in pairs(FEATURES) do BASE[key] = entry(0, 0, 0, 0) end

local FREEMODE = { [GetHashKey('mp_m_freemode_01')] = true, [GetHashKey('mp_f_freemode_01')] = true }

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(v)
    return math.floor(v + 0.5)
end

local function copyEntry(src)
    local out = {}
    for k, v in pairs(src) do out[k] = v end
    return out
end

-- ---------------------------------------------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------------------------------------------

-- A fresh skin. With `atDefaults` every key sits on its default (what changing the model does), otherwise it is
-- the table a brand new session starts from.
function Skin.Defaults(atDefaults)
    local data = {}
    for key, e in pairs(BASE) do
        data[key] = copyEntry(e)
        if atDefaults and e.defaultItem ~= nil then
            data[key].item = e.defaultItem
            data[key].texture = e.defaultTexture
        end
    end
    return data
end

-- Fills whatever a saved skin or outfit is missing (older saves have no eye colour, face features, ...).
function Skin.Fill(data)
    if type(data) ~= 'table' then data = {} end
    for key, e in pairs(BASE) do
        if type(data[key]) ~= 'table' then
            data[key] = copyEntry(e)
        else
            for field, value in pairs(e) do
                if data[key][field] == nil then data[key][field] = value end
            end
        end
    end
    return data
end

Skin.data = Skin.Defaults(false)

function Skin.IsFreemode(ped)
    return FREEMODE[GetEntityModel(ped)] == true
end

-- ---------------------------------------------------------------------------------------------------------------
-- Applying
-- ---------------------------------------------------------------------------------------------------------------

local function applyBlend(ped, d)
    SetPedHeadBlendData(ped, d.face.item, d.face2.item, 0, d.face.texture, d.face2.texture, 0,
        d.facemix.shapeMix, d.facemix.skinMix, 0.0, true)
end

-- Applies one key from `data` to the ped.
function Skin.ApplyKey(ped, key, data)
    local def, e = DEF[key], data[key]
    if not def or not e then return end

    local kind = def.kind
    if kind == 'blend' then
        applyBlend(ped, data)
    elseif kind == 'comp' then
        SetPedComponentVariation(ped, def.id, e.item, 0, def.palette)
        SetPedComponentVariation(ped, def.id, e.item, e.texture, 0)
    elseif kind == 'prop' then
        -- item -1 and 0 both mean "none": qb-clothing never loaded a saved prop 0 either
        if e.item > 0 then
            SetPedPropIndex(ped, def.id, e.item, e.texture, true)
        else
            ClearPedProp(ped, def.id)
        end
    elseif kind == 'hair' then
        applyBlend(ped, data)
        SetPedComponentVariation(ped, 2, e.item, 0, 0)
        SetPedHairColor(ped, e.texture, e.texture)
    elseif kind == 'overlay' then
        SetPedHeadOverlay(ped, def.id, e.item, 1.0)
        SetPedHeadOverlayColor(ped, def.id, 1, e.texture, 0)
    elseif kind == 'moles' then
        SetPedHeadOverlay(ped, 9, e.item, e.item < 0 and 0.0 or (e.texture / 10))
    elseif kind == 'eye' then
        if e.item >= 0 then SetPedEyeColor(ped, e.item) end
    elseif kind == 'feature' then
        SetPedFaceFeature(ped, def.id, e.item / 10)
    end
end

-- Applies a whole skin. Heads only exist on the freemode models, so for any other ped the head keys are skipped.
function Skin.ApplyAll(ped, data, freemode)
    if freemode == nil then freemode = Skin.IsFreemode(ped) end
    for _, key in ipairs(ORDER) do
        local kind = DEF[key].kind
        local head = kind == 'blend' or kind == 'hair' or kind == 'overlay' or kind == 'moles' or kind == 'eye' or kind == 'feature'
        if freemode or not head then
            Skin.ApplyKey(ped, key, data)
        end
    end
end

-- Takes the clothing and accessories out of `outfit` (a partial skin) into the current skin and puts them on the ped.
-- Returns nothing; the caller deals with the neck tracker.
function Skin.ApplyOutfit(ped, outfit)
    for _, key in ipairs(OUTFIT_KEYS) do
        local o = outfit[key]
        if type(o) == 'table' then
            local e = Skin.data[key]
            e.item = tonumber(o.item) or e.item
            e.texture = tonumber(o.texture) or e.texture
            Skin.ApplyKey(ped, key, Skin.data)
        end
    end
end

-- ---------------------------------------------------------------------------------------------------------------
-- Limits and changes
-- ---------------------------------------------------------------------------------------------------------------

-- What a key may be set to right now. The maximums depend on the ped (and, for textures, on the chosen item).
function Skin.Limits(ped, key, data)
    data = data or Skin.data
    local def, e = DEF[key], data[key]
    local kind = def.kind

    local lim = { minItem = e.defaultItem or 0, maxItem = 0, hasTexture = false, minTexture = 0, maxTexture = 0 }

    if kind == 'comp' then
        lim.maxItem = math.max(GetNumberOfPedDrawableVariations(ped, def.id) - 1, lim.minItem)
        lim.hasTexture = true
        lim.maxTexture = math.max(GetNumberOfPedTextureVariations(ped, def.id, e.item) - 1, 0)
    elseif kind == 'prop' then
        lim.minItem = 0
        lim.maxItem = math.max(GetNumberOfPedPropDrawableVariations(ped, def.id) - 1, 0)
        lim.hasTexture = true
        lim.maxTexture = e.item > 0 and math.max(GetNumberOfPedPropTextureVariations(ped, def.id, e.item) - 1, 0) or 0
    elseif kind == 'hair' then
        lim.maxItem = math.max(GetNumberOfPedDrawableVariations(ped, 2) - 1, 0)
        lim.hasTexture = true
        lim.maxTexture = 63
    elseif kind == 'overlay' then
        lim.minItem = -1
        lim.maxItem = math.max(GetNumHeadOverlayValues(def.id) - 1, -1)
        if key ~= 'ageing' then
            lim.hasTexture = true
            lim.maxTexture = 63
        end
    elseif kind == 'moles' then
        lim.minItem = -1
        lim.maxItem = math.max(GetNumHeadOverlayValues(9) - 1, -1)
        lim.hasTexture = true
        lim.maxTexture = 10
    elseif kind == 'eye' then
        lim.minItem = -1
        lim.maxItem = 31
    elseif kind == 'feature' then
        lim.minItem = -10
        lim.maxItem = 10
    elseif kind == 'blend' then -- face and face2 (the parents)
        lim.minItem = 0
        lim.maxItem = 45
        lim.hasTexture = true
        lim.maxTexture = 45
    end
    return lim
end

-- What the NUI needs to draw one row: the current value and the range.
function Skin.Describe(ped, key)
    local e = Skin.data[key]
    if key == 'facemix' then
        return { shapeMix = e.shapeMix, skinMix = e.skinMix }
    end
    local lim = Skin.Limits(ped, key)
    -- an old save can hold a prop of -1 where the range now starts at 0 ("none"): show it as the first step
    local item = e.item < lim.minItem and lim.minItem or e.item
    return {
        item = item, texture = e.texture,
        minItem = lim.minItem, maxItem = lim.maxItem,
        hasTexture = lim.hasTexture, minTexture = lim.minTexture, maxTexture = lim.maxTexture,
    }
end

function Skin.DescribeAll(ped)
    local out = {}
    for key in pairs(DEF) do
        out[key] = Skin.Describe(ped, key)
    end
    return out
end

-- Changes one value (`kind` is 'item', 'texture', 'shapeMix' or 'skinMix'), applies it and returns the new row.
-- Changing an item puts its texture back to the default, as qb-clothing's menu did.
function Skin.Change(ped, key, kind, value)
    local def, e = DEF[key], Skin.data[key]
    value = tonumber(value)
    if not def or not e or not value then return end

    if key == 'facemix' then
        if kind ~= 'shapeMix' and kind ~= 'skinMix' then return end
        e[kind] = clamp(value, 0.0, 1.0)
        Skin.ApplyKey(ped, key, Skin.data)
        return Skin.Describe(ped, key)
    end

    if kind == 'item' then
        value = round(value)
        -- accessory 13 is the ankle/neck tracker model: step over it, whichever way the player is going
        if key == 'accessory' and value == 13 then
            value = (e.item < 13) and 14 or 12
        end
        local lim = Skin.Limits(ped, key)
        e.item = clamp(value, lim.minItem, lim.maxItem)
        e.texture = def.resetTexture or e.defaultTexture or 0
        lim = Skin.Limits(ped, key)
        e.texture = clamp(e.texture, lim.minTexture, lim.maxTexture)
    elseif kind == 'texture' then
        local lim = Skin.Limits(ped, key)
        if not lim.hasTexture then return end
        e.texture = clamp(round(value), lim.minTexture, lim.maxTexture)
    else
        return
    end

    Skin.ApplyKey(ped, key, Skin.data)
    return Skin.Describe(ped, key)
end
