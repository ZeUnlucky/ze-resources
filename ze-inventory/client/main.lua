QBCore = exports['qb-core']:GetCoreObject()
PlayerData = nil
CurrentOther = nil -- id of the second inventory the UI is showing right now, if any

local uiOpen = false
local hotbarShown = false   -- the Z toggle: bar stays up until toggled off
local flashUntil = 0        -- a slot was just used: bar stays up briefly
local flashActive = nil
local SendHotbar            -- defined with the quick-slot bar below; CloseUI needs it first

-- ---------- Helpers ----------

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function UiConfig()
    return {
        accent = Config.UI.accent,
        currency = Config.UI.currency,
        closeKeys = Config.UI.closeKeys,
        hotbarSlots = Config.HotbarSlots,
        hotbarMs = Config.UI.hotbarMs,
        imagePath = ('nui://%s/html/images/'):format(GetCurrentResourceName()),
    }
end

local function IsIncapacitated()
    local meta = PlayerData and PlayerData.metadata
    return meta and (meta['isdead'] or meta['inlaststand'] or meta['ishandcuffed']) or false
end

-- ---------- Weapon attachments ----------
-- qb-weapons knows which attachment is which component. The UI only needs a label and the attachment's item name,
-- so it can offer "Remove" in the weapon's menu.

local function AttachmentConfig()
    if GetResourceState('qb-weapons') ~= 'started' then return nil end
    local ok, config = pcall(function() return exports['qb-weapons']:getConfigWeaponAttachments() end)
    return ok and config or nil
end

local function FormatAttachments(item, config)
    local list = {}
    for attachmentType, weapons in pairs(config) do
        local component = weapons[item.name]
        if component then
            for _, equipped in pairs(item.info.attachments) do
                if equipped.component == component then
                    local def = QBCore.Shared.Items[attachmentType]
                    list[#list + 1] = { attachment = attachmentType, label = def and def.label or 'Unknown' }
                end
            end
        end
    end
    return #list > 0 and list or nil
end

local function Decorate(payload)
    local inv = payload and payload.player
    if not inv or type(inv.items) ~= 'table' then return end
    local config
    for _, item in ipairs(inv.items) do
        local attachments = type(item.info) == 'table' and item.info.attachments
        if item.type == 'weapon' and type(attachments) == 'table' and #attachments > 0 then
            config = config or AttachmentConfig()
            if config then item.attachments = FormatAttachments(item, config) end
        end
    end
end

-- ---------- Opening, updating, closing ----------

local function CloseUI(tellServer)
    if uiOpen then
        uiOpen = false
        SendNUIMessage({ action = 'close' })
        SetNuiFocus(false, false)
    end
    if CurrentOther and CurrentOther:find('^trunk%-') then CloseTrunk() end
    CurrentOther = nil
    if hotbarShown and PlayerData then SendHotbar({ persist = true }) end -- the toggled bar was hidden while the UI was open
    if tellServer then TriggerServerEvent('qb-inventory:server:closeInventory') end
end

RegisterNetEvent('ze-inventory:client:open', function(payload)
    if type(payload) ~= 'table' then return end
    Decorate(payload)
    CurrentOther = payload.other and payload.other.id or nil
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', config = UiConfig(), player = payload.player, other = payload.other })
end)

-- `other = false` means the second inventory is gone (the UI hides its panel); a missing key means "unchanged".
local function PushUpdate(payload)
    Decorate(payload)
    if payload.other ~= nil then CurrentOther = payload.other and payload.other.id or nil end
    if uiOpen then
        SendNUIMessage({ action = 'update', player = payload.player, other = payload.other })
    end
end

RegisterNetEvent('ze-inventory:client:sync', function(payload)
    if type(payload) == 'table' then PushUpdate(payload) end
end)

RegisterNetEvent('qb-inventory:client:closeInv', function()
    CloseUI(true)
end)

-- ---------- Quick-slot bar ----------

local function HotbarItems()
    local items = {}
    if PlayerData and type(PlayerData.items) == 'table' then
        for i = 1, Config.HotbarSlots do items[i] = PlayerData.items[i] end
    end
    return items
end

function SendHotbar(extra)
    local message = { action = 'hotbar', items = HotbarItems() }
    for k, v in pairs(extra or {}) do message[k] = v end
    SendNUIMessage(message)
end

RegisterNetEvent('qb-inventory:client:hotbar', function()
    if uiOpen then return end
    hotbarShown = not hotbarShown
    if hotbarShown then
        SendHotbar({ persist = true })
    else
        SendNUIMessage({ action = 'hotbar', show = false })
    end
end)

-- ---------- Notices ----------

local function ItemBox(itemData, kind, amount)
    if type(itemData) ~= 'table' or not itemData.name then return end
    SendNUIMessage({
        action = 'itemBox',
        name = itemData.name,
        label = itemData.label,
        image = itemData.image,
        amount = amount,
        kind = kind,
    })
end

RegisterNetEvent('qb-inventory:client:ItemBox', ItemBox)
RegisterNetEvent('inventory:client:ItemBox', ItemBox) -- the older event name some resources still use

-- Shows which items something needs (a lockpick for a door, and so on).
RegisterNetEvent('qb-inventory:client:requiredItems', function(items, show)
    local list = {}
    if show and type(items) == 'table' then
        for _, entry in pairs(items) do
            local def = QBCore.Shared.Items[entry.name]
            list[#list + 1] = {
                item = entry.name,
                label = def and def.label or entry.name,
                image = entry.image or (def and def.image),
            }
        end
    end
    SendNUIMessage({ action = 'requiredItem', items = list, toggle = show and true or false })
end)

RegisterNetEvent('qb-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

-- ---------- Player data ----------

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = QBCore.Functions.GetPlayerData()
    GetDrops()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = nil
    hotbarShown = false
    if uiOpen then CloseUI(false) end
    SendNUIMessage({ action = 'hotbar', show = false })
end)

RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    -- Keep a visible quick-slot bar in step with what the player is carrying.
    if not uiOpen then
        if hotbarShown then
            SendHotbar({ persist = true })
        elseif flashUntil > GetGameTimer() then
            SendHotbar({ active = flashActive })
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = QBCore.Functions.GetPlayerData()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and uiOpen then
        SetNuiFocus(false, false)
    end
end)

-- ---------- Exports ----------

--- Does the player have this item (or all of these items) in their inventory? Same rules as the server export.
function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    if PlayerData and type(PlayerData.items) == 'table' then
        for _, itemData in pairs(PlayerData.items) do
            if isTable then
                for k, v in pairs(items) do
                    if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                        count = count + 1
                        if count == totalItems then return true end
                    end
                end
            else
                if itemData and itemData.name == items and (not amount or itemData.amount >= amount) then
                    return true
                end
            end
        end
    end
    return false
end

exports('HasItem', HasItem)
if GetCurrentResourceName() ~= 'qb-inventory' then
    AddEventHandler('__cfx_export_qb-inventory_HasItem', function(setCB) setCB(HasItem) end)
end

-- ---------- UI callbacks ----------

-- The server answers every action with { ok, message, player, other }. The snapshots go to the UI first, so it shows
-- what the server really has; then the UI is told whether to keep or undo its own prediction.
local function Finish(result, cb)
    if Config.Debug and type(result) == 'table' then
        local count, slots = 0, {}
        for _, item in pairs(result.player and result.player.items or {}) do
            count = count + 1
            slots[#slots + 1] = tostring(item.slot) .. ':' .. tostring(item.name)
        end
        print(('[ze-inventory] server answered: ok=%s message=%s items received=%d [%s]'):format(
            tostring(result.ok), tostring(result.message), count, table.concat(slots, ', ')))
    end
    if type(result) ~= 'table' then return cb(false) end
    if result.player or result.other ~= nil then
        PushUpdate({ player = result.player, other = result.other })
    end
    if result.ok then cb(true) else cb({ ok = false, message = result.message }) end
end

RegisterNUICallback('ready', function(_, cb)
    cb('ok')
end)

RegisterNUICallback('resync', function(_, cb)
    TriggerServerEvent('ze-inventory:server:requestSync')
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    CloseUI(true)
    cb('ok')
end)

RegisterNUICallback('moveItem', function(data, cb)
    QBCore.Functions.TriggerCallback('ze-inventory:server:moveItem', function(result)
        Finish(result, cb)
    end, data)
end)

RegisterNUICallback('useItem', function(data, cb)
    local slot = tonumber(data.slot)
    local item = slot and PlayerData and PlayerData.items and PlayerData.items[slot]
    if item and item.type == 'weapon' and HoldingDrop then
        QBCore.Functions.Notify(Shared.Text.holdingBag, 'error', 5500)
        return cb(false)
    end
    if slot then TriggerServerEvent('qb-inventory:server:useItem', { slot = slot }) end
    cb(true)
end)

RegisterNUICallback('giveItem', function(data, cb)
    local player, distance = QBCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
    if player == -1 or distance >= Config.GiveDistance then
        QBCore.Functions.Notify(Shared.Text.nobodyNearby, 'error')
        return cb({ ok = false, message = Shared.Text.nobodyNearby })
    end
    QBCore.Functions.TriggerCallback('ze-inventory:server:giveItem', function(result)
        Finish(result, cb)
    end, GetPlayerServerId(player), data.slot, data.amount)
end)

RegisterNUICallback('dropItem', function(data, cb)
    QBCore.Functions.TriggerCallback('ze-inventory:server:dropItem', function(result)
        if type(result) == 'table' and result.ok and result.dropNetId then
            LoadAnimDict('pickup_object')
            TaskPlayAnim(PlayerPedId(), 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
            PlaceDropBag(result.dropNetId)
        end
        Finish(result, cb)
    end, data.slot, data.amount)
end)

-- data = { slot, name, attachment } where attachment is the attachment item's name
RegisterNUICallback('removeAttachment', function(data, cb)
    local slot = tonumber(data.slot)
    local item = slot and PlayerData and PlayerData.items and PlayerData.items[slot]
    local config = AttachmentConfig()
    local component = config and config[data.attachment] and item and config[data.attachment][item.name]
    if not item or item.name ~= data.name or not component then return cb(false) end

    QBCore.Functions.TriggerCallback('qb-weapons:server:RemoveAttachment', function(remaining)
        if remaining == false then return cb(false) end
        RemoveWeaponComponentFromPed(PlayerPedId(), joaat(item.name), joaat(component))
        cb(true)
    end, { attachment = data.attachment }, item)
end)

-- ---------- Key mappings ----------

RegisterCommand('openInv', function()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    TriggerServerEvent('ze-inventory:server:requestOpen')
end, false)
RegisterKeyMapping('openInv', 'Open Inventory', 'keyboard', Config.Keybinds.Open)

RegisterCommand('toggleHotbar', function()
    TriggerEvent('qb-inventory:client:hotbar')
end, false)
RegisterKeyMapping('toggleHotbar', 'Toggles keybind slots', 'keyboard', Config.Keybinds.Hotbar)

for i = 1, math.min(Config.HotbarSlots, 9) do
    RegisterCommand('slot_' .. i, function()
        if uiOpen or not PlayerData or not PlayerData.items or IsIncapacitated() then return end
        local item = PlayerData.items[i]
        if not item then return end
        if item.type == 'weapon' and HoldingDrop then
            return QBCore.Functions.Notify(Shared.Text.holdingBag, 'error', 5500)
        end
        TriggerServerEvent('qb-inventory:server:useItem', { slot = i })
        if not hotbarShown then
            flashUntil = GetGameTimer() + Config.UI.hotbarMs
            flashActive = i
            SendHotbar({ active = i })
        end
    end, false)
    RegisterKeyMapping('slot_' .. i, 'Uses the item in slot ' .. i, 'keyboard', tostring(i))
end

-- ---------- Vending machines ----------

CreateThread(function()
    local waited = 0
    while GetResourceState('qb-target') ~= 'started' and waited < 30000 do
        Wait(500)
        waited = waited + 500
    end
    if GetResourceState('qb-target') ~= 'started' then return end
    exports['qb-target']:AddTargetModel(Config.VendingObjects, {
        options = {
            {
                type = 'server',
                event = 'qb-inventory:server:openVending',
                icon = 'fa-solid fa-cash-register',
                label = Shared.Text.vending,
            },
        },
        distance = 2.5,
    })
end)
