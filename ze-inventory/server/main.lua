QBCore = exports['qb-core']:GetCoreObject()

Inventories = {}      -- id -> { items = { [slot] = item }, isOpen = false | source, label, maxweight, slots, dirty }
Drops = {}            -- 'drop-<netId>' -> { name, label, items, entityId, createdTime, coords, maxweight, slots, isOpen }
RegisteredShops = {}  -- name -> { name, label, coords, slots, items }
Sessions = {}         -- source -> { id = '<id of the second inventory they have open>' }. Exists while their UI is open.

-- ---------- Small helpers (shared by every server file) ----------

function Notify(src, message, kind)
    TriggerClientEvent('QBCore:Notify', src, message, kind or 'error')
end

function LogEvent(title, color, message)
    TriggerEvent('qb-log:server:CreateLog', 'playerinventory', title, color, message)
end

-- Server-side state bag other resources read to know the inventory/progress UI is busy.
function SetBusy(src, busy)
    pcall(function() Player(src).state.inv_busy = busy end)
end

function BuildItem(itemInfo, amount, info, slot)
    return {
        name = itemInfo.name,
        amount = amount,
        info = info or {},
        label = itemInfo.label,
        description = itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        unique = itemInfo.unique,
        useable = itemInfo.useable,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        slot = slot,
        combinable = itemInfo.combinable,
    }
end

-- Rows are stored as a list of { name, amount, info, type, slot }. Older rows (a table keyed by slot, holding whole
-- item objects) load fine too. Item definitions are always re-read from QBCore.Shared.Items, so label/weight changes
-- apply immediately. Items whose definition no longer exists are kept in stashes rather than silently deleted.
function HydrateItems(raw)
    local items = {}
    if type(raw) ~= 'table' then return items end
    for key, item in pairs(raw) do
        if type(item) == 'table' and item.name then
            local slot = tonumber(item.slot) or tonumber(key)
            if slot then
                local def = QBCore.Shared.Items[tostring(item.name):lower()]
                local info = type(item.info) == 'table' and item.info or {}
                if def then
                    items[slot] = BuildItem(def, tonumber(item.amount) or 1, info, slot)
                else
                    item.slot = slot
                    item.info = info
                    item.weight = tonumber(item.weight) or 0
                    item.label = item.label or item.name
                    items[slot] = item
                end
            end
        end
    end
    return items
end

function SerializeItems(items)
    local list = {}
    for slot, item in pairs(items) do
        if item then
            list[#list + 1] = {
                name = item.name,
                amount = item.amount,
                info = item.info,
                type = item.type,
                slot = tonumber(item.slot) or tonumber(slot),
            }
        end
    end
    table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return json.encode(list)
end

function InitializeInventory(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots,
        dirty = false,
    }
    return Inventories[inventoryId]
end

-- ---------- Stash persistence ----------

local SAVE_SQL = 'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?'

function SaveStash(id, wait)
    local inv = Inventories[id]
    if not inv then return end
    local encoded = SerializeItems(inv.items)
    inv.dirty = false
    if wait then
        MySQL.prepare.await(SAVE_SQL, { id, encoded, encoded })
    else
        MySQL.prepare(SAVE_SQL, { id, encoded, encoded })
    end
end

function SaveAllStashes(onlyDirty, wait)
    for id, inv in pairs(Inventories) do
        if not onlyDirty or inv.dirty then SaveStash(id, wait) end
    end
end

CreateThread(function()
    local rows = MySQL.query.await('SELECT identifier, items FROM inventories', {})
    local loaded = 0
    for i = 1, #(rows or {}) do
        local row = rows[i]
        if not Inventories[row.identifier] then
            Inventories[row.identifier] = {
                items = HydrateItems(json.decode(row.items)),
                isOpen = false,
                label = row.identifier,
                maxweight = Config.StashSize.maxweight,
                slots = Config.StashSize.slots,
                dirty = false,
            }
            loaded = loaded + 1
        end
    end
    if loaded > 0 then print(('^2[ze-inventory]^7 %d inventories loaded'):format(loaded)) end
end)

CreateThread(function()
    while true do
        Wait(Config.StashSaveInterval * 60000)
        SaveAllStashes(true, false)
    end
end)

CreateThread(function()
    while true do
        for id, drop in pairs(Drops) do
            if drop and not drop.isOpen and drop.createdTime + (Config.CleanupDropTime * 60) < os.time() then
                local entity = NetworkGetEntityFromNetworkId(drop.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[id] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
end)

-- ---------- Sessions ----------

-- Forget everything a player had open: unlock their stash, free the person they were searching.
function ReleaseSession(src)
    local session = Sessions[src]
    Sessions[src] = nil
    for id, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
            if inv.dirty then SaveStash(id, false) end
        end
    end
    for _, drop in pairs(Drops) do
        if drop.isOpen == src then drop.isOpen = false end
    end
    if session and session.id then
        local targetSrc = session.id:match('^otherplayer%-(%d+)$')
        if targetSrc then SetBusy(tonumber(targetSrc), false) end
    end
end

AddEventHandler('playerDropped', function()
    ReleaseSession(source)
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    SaveAllStashes(true, true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SaveAllStashes(true, true)
    for src in pairs(Sessions) do SetBusy(src, false) end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

-- ---------- Player methods (Player.Functions.AddItem and friends) ----------

local function AddPlayerMethods(src)
    QBCore.Functions.AddPlayerMethod(src, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(src, item, amount, slot, info, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(src, item, amount, slot, reason)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemBySlot', function(slot)
        return GetItemBySlot(src, slot)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemByName', function(item)
        return GetItemByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'GetItemsByName', function(item)
        return GetItemsByName(src, item)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'ClearInventory', function(filterItems)
        ClearInventory(src, filterItems)
    end)
    QBCore.Functions.AddPlayerMethod(src, 'SetInventory', function(items)
        SetInventory(src, items)
    end)
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(QBPlayer)
    AddPlayerMethods(QBPlayer.PlayerData.source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(QBCore.Functions.GetQBPlayers()) do
        AddPlayerMethods(src)
        SetBusy(src, false)
    end
end)

-- ---------- Weapons ----------

-- If the item being taken away is the weapon in the player's hand, put it away.
function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

-- ---------- Events ----------

RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return end
    if type(data) ~= 'table' then return end
    CreateShop({
        name = 'vending',
        label = Shared.Text.vending,
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems,
    })
    OpenShop(src, 'vending')
end)

-- Finishes whatever the player had open: saves their stash, deletes an emptied drop bag, frees the lock.
function CloseSession(src)
    SetBusy(src, false)
    local session = Sessions[src]
    if not session then return end
    local id = session.id

    if id and Drops[id] then
        local drop = Drops[id]
        drop.isOpen = false
        if next(drop.items) == nil then
            local entityId = drop.entityId
            Drops[id] = nil
            TriggerClientEvent('qb-inventory:client:removeDropTarget', -1, entityId)
            CreateThread(function()
                Wait(500)
                local entity = NetworkGetEntityFromNetworkId(entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
            end)
        end
    elseif id and Inventories[id] then
        Inventories[id].isOpen = false
        SaveStash(id, false)
    end
    ReleaseSession(src)
end

-- Fired by the client when its UI closes. It always uses the server's own record of what is open, never a client-sent id.
RegisterNetEvent('qb-inventory:server:closeInventory', function()
    CloseSession(source)
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    local slot = type(item) == 'table' and tonumber(item.slot) or tonumber(item)
    if not slot then return end
    local itemData = GetItemBySlot(src, slot)
    if not itemData then return end
    local itemInfo = QBCore.Shared.Items[itemData.name]
    if not itemInfo then return end
    local info = type(itemData.info) == 'table' and itemData.info or {}

    local function nearbyPlayers()
        local coords = GetEntityCoords(GetPlayerPed(src))
        local nearby = {}
        for _, target in pairs(QBCore.Functions.GetPlayers()) do
            if #(coords - GetEntityCoords(GetPlayerPed(target))) < 3.0 then nearby[#nearby + 1] = target end
        end
        return nearby
    end

    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, info.quality and info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local gender = info.gender == 0 and 'Male' or 'Female'
        for _, target in pairs(nearbyPlayers()) do
            TriggerClientEvent('chat:addMessage', target, {
                template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
                args = { 'ID Card', info.citizenid, info.firstname, info.lastname, info.birthdate, gender, info.nationality },
            })
        end
    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        for _, target in pairs(nearbyPlayers()) do
            TriggerClientEvent('chat:addMessage', target, {
                template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>First Name:</strong> {1} <br><strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br><strong>Licenses:</strong> {4}</div></div>',
                args = { 'Drivers License', info.firstname, info.lastname, info.birthdate, info.type },
            })
        end
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end

    -- Items flagged shouldClose close the inventory after use.
    if itemInfo.shouldClose and Sessions[src] then CloseInventory(src) end
end)

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return end
    if type(dropId) ~= 'string' then return end
    local drop = Drops[dropId]
    if not drop or drop.isOpen then return end
    if Sessions[src] and Sessions[src].id then return end -- already has something open
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - drop.coords)
    if distance > 2.5 then return end
    drop.isOpen = src
    Sessions[src] = { id = dropId }
    OpenUI(src, ContainerById(dropId))
end)

RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
    local drop = type(dropId) == 'string' and Drops[dropId]
    if not drop or not coords then return end
    drop.coords = vector3(coords.x, coords.y, coords.z)
end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)

-- The key mapping on the client asks for the inventory; the same logic backs the /inventory command.
RegisterNetEvent('ze-inventory:server:requestOpen', function()
    OpenFromKey(source)
end)

-- ---------- Callbacks ----------

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    local drops = {}
    for id, drop in pairs(Drops) do
        drops[id] = { name = drop.name, entityId = drop.entityId, coords = drop.coords }
    end
    cb(drops)
end)

QBCore.Functions.CreateCallback('ze-inventory:server:moveItem', function(src, cb, data)
    cb(MoveItem(src, data))
end)

QBCore.Functions.CreateCallback('ze-inventory:server:dropItem', function(src, cb, slot, amount)
    cb(DropFromPlayer(src, slot, amount))
end)

QBCore.Functions.CreateCallback('ze-inventory:server:giveItem', function(src, cb, target, slot, amount)
    cb(GiveToPlayer(src, target, slot, amount))
end)
