-- Registers the public API.
--
-- qb-core, and about 48 other resources on this server, call exports['qb-inventory']. This resource answers those calls
-- itself, so nothing else needs editing. qb-core also checks GetResourceState('qb-inventory') before it will load, save
-- or use any inventory, which is why a tiny stand-in resource called qb-inventory has to exist (see the INSTALL notes).

local ownName = GetCurrentResourceName()
local asQbInventory = ownName ~= 'qb-inventory' -- if this folder is renamed qb-inventory, no impersonation is needed

local API = {
    LoadInventory = LoadInventory,
    SaveInventory = SaveInventory,
    SetInventory = SetInventory,
    SetItemData = SetItemData,
    UseItem = UseItem,
    GetSlotsByItem = GetSlotsByItem,
    GetFirstSlotByItem = GetFirstSlotByItem,
    GetItemBySlot = GetItemBySlot,
    GetTotalWeight = GetTotalWeight,
    GetItemByName = GetItemByName,
    GetItemsByName = GetItemsByName,
    GetSlots = GetSlots,
    GetItemCount = GetItemCount,
    CanAddItem = CanAddItem,
    GetFreeWeight = GetFreeWeight,
    ClearInventory = ClearInventory,
    HasItem = HasItem,
    CloseInventory = CloseInventory,
    OpenInventoryById = OpenInventoryById,
    ClearStash = ClearStash,
    CreateShop = CreateShop,
    OpenShop = OpenShop,
    OpenInventory = OpenInventory,
    CreateInventory = CreateInventory,
    GetInventory = GetInventory,
    RemoveInventory = RemoveInventory,
    AddItem = AddItem,
    RemoveItem = RemoveItem,
}

for name, fn in pairs(API) do
    exports(name, fn)
    if asQbInventory then
        AddEventHandler(('__cfx_export_qb-inventory_%s'):format(name), function(setCB)
            setCB(fn)
        end)
    end
end

-- Check the setup a few seconds after start, once the other resources have had time to come up.
CreateThread(function()
    Wait(10000)
    if not asQbInventory then return end

    local state = GetResourceState('qb-inventory')
    local description = GetResourceMetadata('qb-inventory', 'description', 0) or ''
    if state == 'missing' then
        print('^1[ze-inventory] qb-core only loads, saves and uses inventories while a resource called "qb-inventory" exists.')
        print('^1[ze-inventory] Add the stand-in resource (the "qb-inventory" folder next to ze-inventory) and ensure it, or rename this folder to qb-inventory.^7')
    elseif state == 'started' and not description:find('ze-inventory stand-in', 1, true) then
        print('^1[ze-inventory] The original qb-inventory is running as well. Two inventories will fight over the same events and data.')
        print('^1[ze-inventory] Stop it and remove it from the resources folder (move it outside, not just renamed inside [qb]).^7')
    end
end)
