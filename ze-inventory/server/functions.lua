-- The inventory API. Every function here is also registered as an export (see server/compat.lua), both as
-- exports['ze-inventory'] and, so the rest of the server keeps working untouched, as exports['qb-inventory'].

local function GetFirstFreeSlot(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then return i end
    end
    return nil
end

local function SetupShopItems(shopItems)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = QBCore.Shared.Items[tostring(item.name):lower()]
            if itemInfo then
                items[slot] = {
                    name = itemInfo['name'],
                    amount = tonumber(item.amount),
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot,
                }
                slot = slot + 1
            end
        end
    end
    return items
end

function IsBusy(src)
    local ok, busy = pcall(function() return Player(src).state.inv_busy end)
    return ok and busy or false
end

-- Finds the item table, weight limit and slot count for a player (by server id), a stash, or a drop.
function ResolveInventory(identifier)
    local player = tonumber(identifier) ~= nil and QBCore.Functions.GetPlayer(identifier) or nil
    if player then
        player.PlayerData.items = player.PlayerData.items or {}
        return player.PlayerData.items, Config.MaxWeight, Config.MaxSlots, player
    elseif Inventories[identifier] then
        local inv = Inventories[identifier]
        return inv.items, inv.maxweight or Config.StashSize.maxweight, inv.slots or Config.StashSize.slots, nil
    elseif Drops[identifier] then
        local drop = Drops[identifier]
        return drop.items, drop.maxweight, drop.slots, nil
    end
    return nil
end

-- After anything changes an inventory behind the player's back, refresh every open UI that shows it.
local function Changed(identifier, player)
    if player then
        SyncViewers(tonumber(identifier))
    else
        if Inventories[identifier] then Inventories[identifier].dirty = true end
        SyncViewers(identifier)
    end
end

-- ---------- Loading and saving ----------

function LoadInventory(source, citizenid)
    local stored = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    local loaded = {}
    if type(stored) ~= 'string' then return loaded end
    local inventory = json.decode(stored)
    if type(inventory) ~= 'table' or not next(inventory) then return loaded end

    local missing = {}
    for _, item in pairs(inventory) do
        if type(item) == 'table' and item.name then
            local itemInfo = QBCore.Shared.Items[tostring(item.name):lower()]
            local slot = tonumber(item.slot)
            if itemInfo and slot then
                loaded[slot] = BuildItem(itemInfo, tonumber(item.amount) or 1, type(item.info) == 'table' and item.info or {}, slot)
            elseif not itemInfo then
                missing[#missing + 1] = tostring(item.name):lower()
            end
        end
    end

    if #missing > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(source and GetPlayerName(source) or citizenid, table.concat(missing, ', ')))
    end
    return loaded
end

function SaveInventory(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local QBPlayer = QBCore.Functions.GetPlayer(source)
        if not QBPlayer then return end
        PlayerData = QBPlayer.PlayerData
    end

    local items = PlayerData.items
    local list = {}
    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                list[#list + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(list), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

-- ---------- Reading ----------

-- Lowest slot first, so "the first stack" is always the same stack.
function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    local wanted = tostring(itemName):lower()
    for slot, item in pairs(items) do
        if item.name:lower() == wanted then slotsFound[#slotsFound + 1] = tonumber(slot) end
    end
    table.sort(slotsFound)
    return slotsFound
end

function GetFirstSlotByItem(items, itemName)
    if not items then return nil end
    local wanted = tostring(itemName):lower()
    local first
    for slot, item in pairs(items) do
        if item.name:lower() == wanted then
            slot = tonumber(slot)
            if not first or slot < first then first = slot end
        end
    end
    return first
end

function GetItemBySlot(source, slot)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return nil end
    return QBPlayer.PlayerData.items[tonumber(slot)]
end

function GetTotalWeight(items)
    if not items then return 0 end
    local weight = 0
    for _, item in pairs(items) do
        local amount = item.amount
        if type(amount) ~= 'number' then amount = 1 end
        weight = weight + ((item.weight or 0) * amount)
    end
    return tonumber(weight)
end

function GetItemByName(source, item)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return nil end
    local items = QBPlayer.PlayerData.items
    local slot = GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

function GetItemsByName(source, item)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return nil end
    local playerItems = QBPlayer.PlayerData.items
    local found = {}
    for _, slot in ipairs(GetSlotsByItem(playerItems, item)) do
        found[#found + 1] = playerItems[slot]
    end
    return found
end

-- Returns used slots and free slots. For an unknown inventory: 0 used, and whatever slot count is known.
function GetSlots(identifier)
    local inventory, _, maxSlots = ResolveInventory(identifier)
    if not inventory then return 0, maxSlots end
    local used = 0
    for _, item in pairs(inventory) do
        if item then used = used + 1 end
    end
    return used, maxSlots - used
end

function GetItemCount(source, items)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return nil end
    local isTable = type(items) == 'table'
    local wanted = {}
    if isTable then
        for _, name in pairs(items) do wanted[name] = true end
    end
    local count = 0
    for _, item in pairs(QBPlayer.PlayerData.items) do
        if (isTable and wanted[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end

function GetFreeWeight(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return 0 end
    return Config.MaxWeight - GetTotalWeight(QBPlayer.PlayerData.items)
end

-- Checks the same amount-per-stack rules as the original qb-inventory: a stack must hold the whole amount.
function HasItem(source, items, amount)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return false end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    for _, itemData in pairs(QBPlayer.PlayerData.items) do
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
    return false
end

-- Returns true, or false plus 'weight' / 'slots' saying why not.
function CanAddItem(identifier, item, amount)
    local itemData = QBCore.Shared.Items[tostring(item):lower()]
    if not itemData then return false end
    amount = tonumber(amount) or 1

    local items, maxweight, slots = ResolveInventory(identifier)
    if not items then
        print('CanAddItem: Inventory not found')
        return false
    end

    if GetTotalWeight(items) + (itemData.weight * amount) > maxweight then
        return false, 'weight'
    end

    local used = 0
    local canStack = false
    for _, v in pairs(items) do
        used = used + 1
        if not itemData.unique and v.name == itemData.name then canStack = true end
    end
    if used >= slots and not canStack then
        return false, 'slots'
    end
    return true
end

-- ---------- Changing items ----------

function AddItem(identifier, item, amount, slot, info, reason)
    if type(item) ~= 'string' then
        print('AddItem: Invalid item')
        return false
    end
    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        print('AddItem: Invalid item')
        return false
    end
    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then
        print('AddItem: Invalid amount')
        return false
    end

    local inventory, inventoryWeight, inventorySlots, player = ResolveInventory(identifier)
    if not inventory then
        print('AddItem: Inventory not found')
        return false
    end

    if GetTotalWeight(inventory) + (itemInfo.weight * amount) > inventoryWeight then
        print('AddItem: Not enough weight available')
        return false
    end

    slot = tonumber(slot)
    local stacked = false
    if not itemInfo.unique then
        if slot then
            local existing = inventory[slot]
            if existing and existing.name == itemInfo.name then
                existing.amount = existing.amount + amount
                stacked = true
            end
        else
            local first = GetFirstSlotByItem(inventory, itemInfo.name)
            if first then
                inventory[first].amount = inventory[first].amount + amount
                slot = first
                stacked = true
            end
        end
    end

    if not stacked then
        -- Never overwrite another item: an unusable requested slot falls back to the first free one.
        if not slot or slot < 1 or slot > inventorySlots or inventory[slot] then
            slot = GetFirstFreeSlot(inventory, inventorySlots)
        end
        if not slot then
            print('AddItem: No free slot available')
            return false
        end

        local newItem = BuildItem(itemInfo, amount, type(info) == 'table' and Shared.DeepCopy(info) or {}, slot)
        if itemInfo.type == 'weapon' then
            if not newItem.info.serie then
                newItem.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
            end
            if not newItem.info.quality then
                newItem.info.quality = 100
            end
        end
        inventory[slot] = newItem
    end

    if player then player.Functions.SetPlayerData('items', inventory) end
    Changed(identifier, player)

    local invName = player and (GetPlayerName(identifier) .. ' (' .. identifier .. ')') or identifier
    LogEvent('Item Added', 'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. (reason or 'No reason specified') .. '\n' ..
        '**Resource:** ' .. (GetInvokingResource() or GetCurrentResourceName()))
    return true
end

-- With no slot given it removes from the first stack that can cover the amount, and otherwise spreads the removal
-- over several stacks (lowest slot first). With a slot given it only touches that slot.
function RemoveItem(identifier, item, amount, slot, reason)
    if type(item) ~= 'string' or not QBCore.Shared.Items[item:lower()] then
        print('RemoveItem: Invalid item')
        return false
    end
    local inventory, _, _, player = ResolveInventory(identifier)
    if not inventory then
        print('RemoveItem: Inventory not found')
        return false
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then
        print('RemoveItem: Invalid amount')
        return false
    end

    local name = item:lower()
    slot = tonumber(slot)
    local plan = {} -- list of { slot, amount to take }

    if slot then
        local invItem = inventory[slot]
        if not invItem or invItem.name:lower() ~= name then
            print('RemoveItem: Item not found in slot')
            return false
        end
        if invItem.amount < amount then
            print('RemoveItem: Not enough items in slot')
            return false
        end
        plan[1] = { slot, amount }
    else
        local slots = GetSlotsByItem(inventory, name)
        if #slots == 0 then
            print('RemoveItem: Slot not found')
            return false
        end
        for _, s in ipairs(slots) do
            if inventory[s].amount >= amount then
                plan[1] = { s, amount }
                break
            end
        end
        if #plan == 0 then
            local remaining = amount
            for _, s in ipairs(slots) do
                local take = math.min(inventory[s].amount, remaining)
                plan[#plan + 1] = { s, take }
                remaining = remaining - take
                if remaining <= 0 then break end
            end
            if remaining > 0 then
                print('RemoveItem: Not enough items in slot')
                return false
            end
        end
    end

    local removedWeapon = false
    for _, step in ipairs(plan) do
        local invItem = inventory[step[1]]
        invItem.amount = invItem.amount - step[2]
        if invItem.amount <= 0 then
            inventory[step[1]] = nil
            if invItem.type == 'weapon' then removedWeapon = invItem.name end
        end
    end

    if player then
        player.Functions.SetPlayerData('items', inventory)
        if removedWeapon then checkWeapon(identifier, removedWeapon) end
    end
    Changed(identifier, player)

    local invName = player and (GetPlayerName(identifier) .. ' (' .. identifier .. ')') or identifier
    LogEvent('Item Removed', 'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. plan[1][1] .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. (reason or 'No reason specified') .. '\n' ..
        '**Resource:** ' .. (GetInvokingResource() or GetCurrentResourceName()))
    return true
end

function SetItemData(source, itemName, key, val, slot)
    if not itemName or not key then return false end
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return nil end
    local item
    if slot then
        item = QBPlayer.PlayerData.items[tonumber(slot)]
        if not item or item.name:lower() ~= itemName:lower() then return false end
    else
        item = GetItemByName(source, itemName)
        if not item then return false end
    end
    item[key] = val
    QBPlayer.PlayerData.items[item.slot] = item
    QBPlayer.Functions.SetPlayerData('items', QBPlayer.PlayerData.items)
    SyncViewers(tonumber(source))
    return true
end

function SetInventory(identifier, items, reason)
    local player = tonumber(identifier) ~= nil and QBCore.Functions.GetPlayer(identifier) or nil
    if not player and not Inventories[identifier] and not Drops[identifier] then
        print('SetInventory: Inventory not found')
        return
    end

    if player then
        player.Functions.SetPlayerData('items', items)
    elseif Drops[identifier] then
        Drops[identifier].items = items
    elseif Inventories[identifier] then
        Inventories[identifier].items = items
    end
    Changed(identifier, player)

    local invName = player and (GetPlayerName(identifier) .. ' (' .. identifier .. ')') or identifier
    LogEvent('Inventory Set', 'blue',
        '**Inventory:** ' .. invName .. '\n' ..
        '**Items:** ' .. json.encode(items) .. '\n' ..
        '**Reason:** ' .. (reason or 'No reason specified') .. '\n' ..
        '**Resource:** ' .. (GetInvokingResource() or GetCurrentResourceName()))
end

function ClearInventory(source, filterItems)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    if not QBPlayer then return end
    local kept = {}
    if filterItems then
        local names = type(filterItems) == 'string' and { filterItems } or filterItems
        if type(names) == 'table' then
            for _, itemName in ipairs(names) do
                local item = GetItemByName(source, itemName)
                if item then kept[item.slot] = item end
            end
        end
    end
    QBPlayer.Functions.SetPlayerData('items', kept)
    if not QBPlayer.Offline then
        LogEvent('ClearInventory', 'red', string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), QBPlayer.PlayerData.citizenid, source))
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then RemoveWeaponFromPed(ped, weapon) end
        SyncViewers(tonumber(source))
    end
end

-- Runs whatever function a resource registered with QBCore.Functions.CreateUseableItem.
function UseItem(itemName, ...)
    local itemData = QBCore.Functions.CanUseItem(itemName)
    if type(itemData) == 'table' and itemData.func then
        itemData.func(...)
    end
end

-- ---------- Stashes and shops ----------

function CreateInventory(identifier, data)
    if not identifier then return end
    if Inventories[identifier] then return end
    InitializeInventory(identifier, data)
end

function GetInventory(identifier)
    return Inventories[identifier]
end

function RemoveInventory(identifier)
    if Inventories[identifier] then Inventories[identifier] = nil end
end

function ClearStash(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode({}), identifier })
    SyncViewers(identifier)
end

function CreateShop(shopData)
    if shopData.name then
        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = SetupShopItems(shopData.items),
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    RegisteredShops[shopName] = {
                        name = shopName,
                        label = data.label,
                        coords = data.coords,
                        slots = #data.items,
                        items = SetupShopItems(data.items),
                    }
                else
                    CreateShop(data)
                end
            end
        end
    end
end

-- ---------- Opening and closing ----------

function CloseInventory(source, identifier)
    TriggerClientEvent('qb-inventory:client:closeInv', source)
    CloseSession(source)
end

function OpenInventory(source, identifier, data)
    if IsBusy(source) then return end
    if not QBCore.Functions.GetPlayer(source) then return end

    if not identifier then
        Sessions[source] = {}
        OpenUI(source, nil)
        return
    end

    if type(identifier) ~= 'string' then
        print('Inventory tried to open an invalid identifier')
        return
    end

    local inventory = Inventories[identifier]
    if inventory and inventory.isOpen and inventory.isOpen ~= source then
        Notify(source, Shared.Text.inUse)
        return
    end

    if not inventory then inventory = InitializeInventory(identifier, data) end
    inventory.maxweight = (data and data.maxweight) or inventory.maxweight or Config.StashSize.maxweight
    inventory.slots = (data and data.slots) or inventory.slots or Config.StashSize.slots
    inventory.label = (data and data.label) or inventory.label or identifier
    inventory.isOpen = source

    Sessions[source] = { id = identifier }
    OpenUI(source, ContainerById(identifier))
end

function OpenShop(source, name)
    if not name then return end
    if not QBCore.Functions.GetPlayer(source) then return end
    local shop = RegisteredShops[name]
    if not shop then return end
    if IsBusy(source) then return end

    if shop.coords then
        local shopCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
        if #(GetEntityCoords(GetPlayerPed(source)) - shopCoords) > 5.0 then return end
    end

    Sessions[source] = { id = 'shop-' .. shop.name }
    OpenUI(source, ContainerById('shop-' .. shop.name))
end

function OpenInventoryById(source, targetId)
    targetId = tonumber(targetId)
    local QBPlayer = QBCore.Functions.GetPlayer(source)
    local TargetPlayer = targetId and QBCore.Functions.GetPlayer(targetId)
    if not QBPlayer or not TargetPlayer then return end

    -- If they are looking at their own inventory, close it first and give the client a moment to finish.
    if Sessions[targetId] then CloseInventory(targetId) end
    Wait(1500)
    if not QBCore.Functions.GetPlayer(source) or not QBCore.Functions.GetPlayer(targetId) then return end

    SetBusy(targetId, true)
    Sessions[source] = { id = 'otherplayer-' .. targetId }
    OpenUI(source, ContainerById('otherplayer-' .. targetId))
end

-- Same logic as pressing the inventory key: a vehicle's glovebox or trunk if the player is at one, otherwise just themselves.
function OpenFromKey(src)
    if IsBusy(src) then return end
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    local meta = QBPlayer.PlayerData.metadata
    if meta['isdead'] or meta['inlaststand'] or meta['ishandcuffed'] then return end

    QBCore.Functions.TriggerClientCallback('qb-inventory:client:vehicleCheck', src, function(inventory, class)
        if not inventory then return OpenInventory(src) end
        local storage = Config.VehicleStorage[class] or Config.VehicleStorage.default
        if inventory:find('^trunk%-') then
            if storage.trunkSlots <= 0 then return Notify(src, Shared.Text.noStorage) end
            OpenInventory(src, inventory, { slots = storage.trunkSlots, maxweight = storage.trunkWeight })
        elseif inventory:find('^glovebox%-') then
            if storage.gloveboxSlots <= 0 then return Notify(src, Shared.Text.noStorage) end
            OpenInventory(src, inventory, { slots = storage.gloveboxSlots, maxweight = storage.gloveboxWeight })
        end
    end)
end
