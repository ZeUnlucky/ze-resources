Shared = {}

-- Player-facing strings in one place.
Shared.Text = {
    noSpace = 'No room for that item',
    tooHeavy = 'Too heavy to carry',
    readonly = 'You cannot put items here',
    occupied = 'That slot is taken by another item',
    denied = 'That did not work',
    inUse = 'This inventory is currently in use',
    noStorage = 'This vehicle has no storage',
    vehicleLocked = 'Vehicle locked',
    nobodyNearby = 'No one nearby!',
    tooFar = 'You are too far away to give items!',
    cannotGive = "Can't give item!",
    notEnoughCash = 'You do not have enough money',
    outOfStock = 'Cannot purchase larger quantity than currently in stock',
    cannotHold = 'Cannot hold item',
    missingItem = "You don't have this item!",
    holdingBag = "You're already holding a bag, go drop it!",
    gunAndBag = 'You can not be holding a gun and a bag!',
    pickUpBag = 'Pick up bag',
    openBag = 'Open Bag',
    vending = 'Vending Machine',
    bagHint = 'Press [G] to drop the bag',
}

-- Inventory ids are plain strings. Their prefix says what kind of inventory they are.
function Shared.InventoryType(id)
    if id == 'player' then return 'player' end
    if type(id) ~= 'string' then return 'stash' end
    if id:find('^trunk%-') then return 'trunk' end
    if id:find('^glovebox%-') then return 'glovebox' end
    if id:find('^drop%-') then return 'drop' end
    if id:find('^shop%-') then return 'shop' end
    if id:find('^otherplayer%-') then return 'otherplayer' end
    return 'stash'
end

function Shared.DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = Shared.DeepCopy(v) end
    return copy
end
