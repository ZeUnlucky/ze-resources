-- Containers, what the UI is sent, and the one place where items change hands.
--
-- A "container" is a uniform view over anything that holds items:
--   { id, type, label, sub, items = { [slot] = item }, maxweight, slots, readonly, owner, player, money }
-- The UI only ever names an inventory by id. The server checks the id is the player's own inventory or the one inventory
-- they currently have open (Sessions), so a client can never reach a stash it was not given.

local function PersonLabel(QBPlayer)
    local info = QBPlayer.PlayerData.charinfo or {}
    return (info.firstname or '?') .. ' ' .. (info.lastname or '')
end

function PlayerContainer(src)
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return nil end
    QBPlayer.PlayerData.items = QBPlayer.PlayerData.items or {}
    local money = QBPlayer.PlayerData.money or {}
    return {
        id = 'player',
        type = 'player',
        owner = tonumber(src),
        player = QBPlayer,
        label = PersonLabel(QBPlayer),
        sub = 'Citizen ID  ' .. tostring(QBPlayer.PlayerData.citizenid),
        items = QBPlayer.PlayerData.items,
        maxweight = Config.MaxWeight,
        slots = Config.MaxSlots,
        money = { cash = money.cash, bank = money.bank },
    }
end

function ContainerById(id)
    local kind = Shared.InventoryType(id)

    if kind == 'otherplayer' then
        local targetSrc = tonumber(id:match('^otherplayer%-(%d+)$'))
        local target = targetSrc and QBCore.Functions.GetPlayer(targetSrc)
        if not target then return nil end
        target.PlayerData.items = target.PlayerData.items or {}
        return {
            id = id, type = 'otherplayer', owner = targetSrc, player = target,
            label = PersonLabel(target), sub = 'Searching',
            items = target.PlayerData.items, maxweight = Config.MaxWeight, slots = Config.MaxSlots,
        }
    elseif kind == 'shop' then
        local shop = RegisteredShops[id:sub(6)]
        if not shop then return nil end
        return {
            id = id, type = 'shop', label = shop.label, sub = 'Shop',
            items = shop.items, maxweight = 0, slots = shop.slots, readonly = true, shop = shop,
        }
    elseif kind == 'drop' then
        local drop = Drops[id]
        if not drop then return nil end
        return {
            id = id, type = 'drop', label = 'Ground', sub = 'Dropped bag',
            items = drop.items, maxweight = drop.maxweight, slots = drop.slots,
        }
    end

    local inv = Inventories[id]
    if not inv then return nil end
    local label, sub = inv.label or id, nil
    if kind == 'trunk' then
        label, sub = 'Trunk', 'Vehicle ' .. id:sub(7)
    elseif kind == 'glovebox' then
        label, sub = 'Glovebox', 'Vehicle ' .. id:sub(10)
    end
    return {
        id = id, type = kind, label = label, sub = sub,
        items = inv.items,
        maxweight = inv.maxweight or Config.StashSize.maxweight,
        slots = inv.slots or Config.StashSize.slots,
    }
end

-- Players can only touch their own inventory or the inventory their session points at.
function GetContainer(src, ref)
    if type(ref) ~= 'table' or type(ref.id) ~= 'string' then return nil end
    if ref.id == 'player' then return PlayerContainer(src) end
    local session = Sessions[src]
    if not session or session.id ~= ref.id then return nil end
    return ContainerById(ref.id)
end

-- Persist/refresh whatever the container is backed by after its items changed.
local function CommitContainer(c)
    if c.type == 'player' or c.type == 'otherplayer' then
        c.player.Functions.SetPlayerData('items', c.items)
    elseif Inventories[c.id] then
        Inventories[c.id].dirty = true
    end
end

-- ---------- What the UI is sent ----------

local function NuiItem(item)
    return {
        name = item.name,
        label = item.label or item.name,
        amount = item.amount,
        slot = tonumber(item.slot),
        weight = item.weight or 0,
        type = item.type or 'item',
        image = item.image,
        unique = item.unique and true or false,
        useable = item.useable and true or false,
        description = item.description,
        info = type(item.info) == 'table' and item.info or {},
        price = item.price,
    }
end

function ToNui(c)
    local list = {}
    for slot, item in pairs(c.items) do
        if item then
            if not item.slot then item.slot = tonumber(slot) end
            list[#list + 1] = NuiItem(item)
        end
    end
    table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return {
        id = c.id,
        type = c.type,
        label = c.label,
        sub = c.sub,
        maxWeight = c.maxweight,
        slots = c.slots,
        readonly = c.readonly or false,
        money = c.money,
        items = list,
    }
end

-- Opens the UI for a player. `other` is the second inventory (a container) or nil.
function OpenUI(src, other)
    local pc = PlayerContainer(src)
    if not pc then return end
    Sessions[src] = Sessions[src] or {}
    if other then Sessions[src].id = other.id end
    SetBusy(src, true)
    TriggerClientEvent('ze-inventory:client:open', src, {
        player = ToNui(pc),
        other = other and ToNui(other) or nil,
    })
end

local function Snapshots(src)
    local out = {}
    local pc = PlayerContainer(src)
    if pc then out.player = ToNui(pc) end
    local session = Sessions[src]
    if session and session.id then
        local other = ContainerById(session.id)
        out.other = other and ToNui(other) or false -- false tells the UI the second inventory is gone
    end
    return out
end

function PushSync(src)
    if not Sessions[src] then return end
    TriggerClientEvent('ze-inventory:client:sync', src, Snapshots(src))
end

-- `key` is a player's server id or an inventory id. Refreshes every open UI that is showing it.
function SyncViewers(key, except)
    if key == nil then return end
    for viewer, session in pairs(Sessions) do
        if viewer ~= except then
            if viewer == key or session.id == key or (type(key) == 'number' and session.id == 'otherplayer-' .. key) then
                PushSync(viewer)
            end
        end
    end
end

local function ViewerKey(c)
    if c.type == 'player' or c.type == 'otherplayer' then return c.owner end
    return c.id
end

-- Every result carries fresh snapshots, so the UI always ends up showing what the server actually has.
local function Reply(src, ok, message)
    local result = Snapshots(src)
    result.ok = ok
    result.message = message
    return result
end

-- ---------- Moving items ----------

local function CanStack(a, b)
    return not a.unique and not b.unique and a.name == b.name
end

local function FirstSlotFor(c, item)
    local empty
    for i = 1, c.slots do
        local existing = c.items[i]
        if existing then
            if CanStack(existing, item) then return i end
        elseif not empty then
            empty = i
        end
    end
    return empty
end

local function PurchaseFromShop(src, A, B, fromSlot, toSlotRaw, amount)
    if B.type ~= 'player' then return Reply(src, false, Shared.Text.denied) end
    local QBPlayer = B.player
    local shop = A.shop
    local entry = A.items[fromSlot]

    if shop.coords then
        local coords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
        if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 10.0 then return Reply(src, false, Shared.Text.denied) end
    end
    if entry.amount and amount > entry.amount then return Reply(src, false, Shared.Text.outOfStock) end

    local canAdd, reason = CanAddItem(src, entry.name, amount)
    if not canAdd then
        return Reply(src, false, reason == 'slots' and Shared.Text.noSpace or Shared.Text.cannotHold)
    end

    local price = (tonumber(entry.price) or 0) * amount
    if price > 0 then
        if (QBPlayer.PlayerData.money.cash or 0) < price then return Reply(src, false, Shared.Text.notEnoughCash) end
        if not QBPlayer.Functions.RemoveMoney('cash', price, 'shop-purchase') then
            return Reply(src, false, Shared.Text.notEnoughCash)
        end
    end

    if not AddItem(src, entry.name, amount, tonumber(toSlotRaw), entry.info, 'shop-purchase') then
        if price > 0 then QBPlayer.Functions.AddMoney('cash', price, 'shop-purchase-refund') end
        return Reply(src, false, Shared.Text.cannotHold)
    end

    if entry.amount then
        entry.amount = entry.amount - amount
        if entry.amount <= 0 then A.items[fromSlot] = nil end
    end
    TriggerEvent('qb-shops:server:UpdateShopItems', shop.name, { name = entry.name, slot = fromSlot }, amount)
    return Reply(src, true)
end

function MoveItem(src, data)
    if type(data) ~= 'table' or type(data.from) ~= 'table' or type(data.to) ~= 'table' then
        return Reply(src, false, Shared.Text.denied)
    end
    local A = GetContainer(src, data.from)
    local B = GetContainer(src, data.to)
    if not A or not B then return Reply(src, false, Shared.Text.denied) end

    local fromSlot = math.floor(tonumber(data.from.slot) or 0)
    local item = A.items[fromSlot]
    if fromSlot < 1 or fromSlot > A.slots or not item then return Reply(src, false, Shared.Text.denied) end
    -- The UI says which item it believes it is moving; if that is stale, refuse and let the reply resync it.
    if data.name and data.name ~= item.name then return Reply(src, false, Shared.Text.denied) end
    if B.readonly then return Reply(src, false, Shared.Text.readonly) end

    local amount = math.floor(tonumber(data.amount) or item.amount)
    if amount < 1 then return Reply(src, false, Shared.Text.denied) end
    amount = math.min(amount, item.amount)
    if item.unique then amount = item.amount end

    if A.type == 'shop' then
        return PurchaseFromShop(src, A, B, fromSlot, data.to.slot, amount)
    end

    local cross = A.id ~= B.id
    local toSlot = math.floor(tonumber(data.to.slot) or 0)
    if toSlot < 1 or toSlot > B.slots then
        toSlot = FirstSlotFor(B, item)
        if not toSlot then return Reply(src, false, Shared.Text.noSpace) end
    end
    if not cross and toSlot == fromSlot then return Reply(src, true) end

    local dst = B.items[toSlot]
    local stack = dst ~= nil and CanStack(item, dst)
    local swap = dst ~= nil and not stack
    if swap and amount ~= item.amount then return Reply(src, false, Shared.Text.occupied) end

    if cross then
        local going = (item.weight or 0) * amount
        local coming = swap and ((dst.weight or 0) * dst.amount) or 0
        local bDelta = going - coming
        local aDelta = coming - going
        if (B.maxweight or 0) > 0 and bDelta > 0 and GetTotalWeight(B.items) + bDelta > B.maxweight then
            return Reply(src, false, Shared.Text.tooHeavy)
        end
        if (A.maxweight or 0) > 0 and aDelta > 0 and GetTotalWeight(A.items) + aDelta > A.maxweight then
            return Reply(src, false, Shared.Text.tooHeavy)
        end

        -- A weapon leaving someone's hands (or being swapped out of them) is put away first.
        if item.type == 'weapon' and (A.type == 'player' or A.type == 'otherplayer') then checkWeapon(A.owner, item) end
        if swap and dst.type == 'weapon' and (B.type == 'player' or B.type == 'otherplayer') then checkWeapon(B.owner, dst) end
    end

    -- Everything is checked; from here on nothing can fail halfway.
    if stack then
        dst.amount = dst.amount + amount
        item.amount = item.amount - amount
        if item.amount <= 0 then A.items[fromSlot] = nil end
    elseif swap then
        A.items[fromSlot] = dst
        B.items[toSlot] = item
        dst.slot = fromSlot
        item.slot = toSlot
    elseif amount == item.amount then
        A.items[fromSlot] = nil
        B.items[toSlot] = item
        item.slot = toSlot
    else
        local part = Shared.DeepCopy(item)
        part.amount = amount
        part.slot = toSlot
        item.amount = item.amount - amount
        B.items[toSlot] = part
    end

    CommitContainer(A)
    if cross then CommitContainer(B) end
    SyncViewers(ViewerKey(A), src)
    if cross then SyncViewers(ViewerKey(B), src) end

    if cross then
        LogEvent('Item Moved', 'blue',
            '**From:** ' .. A.id .. ' (slot ' .. fromSlot .. ')\n' ..
            '**To:** ' .. B.id .. ' (slot ' .. toSlot .. ')\n' ..
            '**Item:** ' .. item.name .. '\n' ..
            '**Amount:** ' .. amount .. '\n' ..
            '**By:** ' .. GetPlayerName(src) .. ' (' .. src .. ')')
    end
    return Reply(src, true)
end

-- ---------- Dropping and giving ----------

function DropFromPlayer(src, slot, amount)
    local pc = PlayerContainer(src)
    if not pc then return { ok = false, message = Shared.Text.denied } end
    slot = math.floor(tonumber(slot) or 0)
    local item = pc.items[slot]
    if not item then return Reply(src, false, Shared.Text.missingItem) end
    amount = math.floor(tonumber(amount) or item.amount)
    if amount < 1 then return Reply(src, false, Shared.Text.denied) end
    amount = math.min(amount, item.amount)
    if item.unique then amount = item.amount end

    -- Already looking at a bag? Drop into it.
    local session = Sessions[src]
    if session and session.id and Shared.InventoryType(session.id) == 'drop' then
        return MoveItem(src, { from = { id = 'player', slot = slot }, to = { id = session.id }, amount = amount, name = item.name })
    end
    -- Another inventory is open (stash, trunk...): do not mix it up with a ground drop.
    if session and session.id then return Reply(src, false, Shared.Text.denied) end

    local coords = GetEntityCoords(GetPlayerPed(src))
    local bag = CreateObjectNoOffset(Config.ItemDropObject, coords.x + 0.5, coords.y + 0.5, coords.z, true, true, false)
    if not bag or bag == 0 or not DoesEntityExist(bag) then return Reply(src, false, Shared.Text.denied) end

    local netId = NetworkGetNetworkIdFromEntity(bag)
    local dropId = 'drop-' .. netId
    Drops[dropId] = {
        name = dropId,
        label = 'Drop',
        items = {},
        entityId = netId,
        createdTime = os.time(),
        coords = coords,
        maxweight = Config.DropSize.maxweight,
        slots = Config.DropSize.slots,
        isOpen = src,
    }
    Sessions[src] = Sessions[src] or {}
    Sessions[src].id = dropId

    local result = MoveItem(src, { from = { id = 'player', slot = slot }, to = { id = dropId, slot = 1 }, amount = amount, name = item.name })
    if not result.ok then
        -- Nothing moved: take the empty bag away again.
        Drops[dropId] = nil
        Sessions[src].id = nil
        if DoesEntityExist(bag) then DeleteEntity(bag) end
        local fresh = Snapshots(src)
        fresh.ok, fresh.message = false, result.message
        return fresh
    end

    TriggerClientEvent('qb-inventory:client:setupDropTarget', -1, netId)
    result.dropNetId = netId
    return result
end

function GiveToPlayer(src, target, slot, amount)
    target = tonumber(target)
    local giver = QBCore.Functions.GetPlayer(src)
    local receiver = target and QBCore.Functions.GetPlayer(target)
    if not giver or not receiver or target == src then return Reply(src, false, Shared.Text.cannotGive) end

    local function unable(p)
        local meta = p.PlayerData.metadata
        return meta['isdead'] or meta['inlaststand'] or meta['ishandcuffed']
    end
    if unable(giver) or unable(receiver) then return Reply(src, false, Shared.Text.cannotGive) end

    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target)))
    if distance > 5.0 then return Reply(src, false, Shared.Text.tooFar) end

    slot = math.floor(tonumber(slot) or 0)
    local item = giver.PlayerData.items[slot]
    if not item then return Reply(src, false, Shared.Text.missingItem) end
    local itemInfo = QBCore.Shared.Items[item.name]
    if not itemInfo then return Reply(src, false, Shared.Text.cannotGive) end

    amount = math.floor(tonumber(amount) or item.amount)
    if amount < 1 then return Reply(src, false, Shared.Text.denied) end
    amount = math.min(amount, item.amount)
    if item.unique then amount = item.amount end

    if not CanAddItem(target, item.name, amount) then
        return Reply(src, false, "The other person can't carry that")
    end

    local name, info = item.name, Shared.DeepCopy(item.info)
    if not RemoveItem(src, name, amount, slot, 'Item given to ID #' .. target) then
        return Reply(src, false, Shared.Text.cannotGive)
    end
    if not AddItem(target, name, amount, false, info, 'Item given from ID #' .. src) then
        AddItem(src, name, amount, slot, info, 'Give failed, item returned')
        return Reply(src, false, Shared.Text.cannotGive)
    end

    TriggerClientEvent('qb-inventory:client:giveAnim', src)
    TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'remove', amount)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    TriggerClientEvent('qb-inventory:client:ItemBox', target, itemInfo, 'add', amount)
    return Reply(src, true)
end
