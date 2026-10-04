-- Dropped items live in a bag on the ground. The server creates the bag; the client makes it interactable.

HoldingDrop = false
local bagObject = nil
local heldDrop = nil

local function TargetReady()
    return GetResourceState('qb-target') == 'started'
end

local function AddDropTarget(bag, dropId)
    if not TargetReady() then return end
    exports['qb-target']:AddTargetEntity(bag, {
        options = {
            {
                icon = 'fas fa-backpack',
                label = Shared.Text.openBag,
                action = function()
                    TriggerServerEvent('qb-inventory:server:openDrop', dropId)
                end,
            },
            {
                icon = 'fas fa-hand-pointer',
                label = Shared.Text.pickUpBag,
                action = function()
                    if IsPedArmed(PlayerPedId(), 4) then
                        return QBCore.Functions.Notify(Shared.Text.gunAndBag, 'error', 5500)
                    end
                    if HoldingDrop then
                        return QBCore.Functions.Notify(Shared.Text.holdingBag, 'error', 5500)
                    end
                    NetworkRequestControlOfEntity(bag)
                    AttachEntityToEntity(
                        bag,
                        PlayerPedId(),
                        GetPedBoneIndex(PlayerPedId(), Config.ItemDropObjectBone),
                        Config.ItemDropObjectOffset[1].x,
                        Config.ItemDropObjectOffset[1].y,
                        Config.ItemDropObjectOffset[1].z,
                        Config.ItemDropObjectOffset[2].x,
                        Config.ItemDropObjectOffset[2].y,
                        Config.ItemDropObjectOffset[2].z,
                        true, true, false, true, 1, true
                    )
                    bagObject = bag
                    HoldingDrop = true
                    heldDrop = dropId
                    exports['qb-core']:DrawText(Shared.Text.bagHint)
                end,
            },
        },
        distance = 2.5,
    })
end

-- Waits for the bag to exist on this client. Gives up after a few seconds instead of looping forever.
local function WaitForBag(netId)
    local deadline = GetGameTimer() + 5000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(10) end
    local bag = NetworkGetEntityFromNetworkId(netId)
    while not DoesEntityExist(bag) and GetGameTimer() < deadline do
        Wait(10)
        bag = NetworkGetEntityFromNetworkId(netId)
    end
    return DoesEntityExist(bag) and bag or nil
end

function GetDrops()
    QBCore.Functions.TriggerCallback('qb-inventory:server:GetCurrentDrops', function(drops)
        if not drops then return end
        for dropId, drop in pairs(drops) do
            local bag = NetworkGetEntityFromNetworkId(drop.entityId)
            if DoesEntityExist(bag) then AddDropTarget(bag, dropId) end
        end
    end)
end

-- Called for the player who just dropped something: put the bag on the ground and freeze it there.
function PlaceDropBag(netId)
    CreateThread(function()
        local bag = WaitForBag(netId)
        if not bag then return end
        PlaceObjectOnGroundProperly(bag)
        FreezeEntityPosition(bag, true)
    end)
end

RegisterNetEvent('qb-inventory:client:setupDropTarget', function(netId)
    CreateThread(function()
        local bag = WaitForBag(netId)
        if bag then AddDropTarget(bag, 'drop-' .. netId) end
    end)
end)

RegisterNetEvent('qb-inventory:client:removeDropTarget', function(netId)
    if not TargetReady() then return end
    if not NetworkDoesNetworkIdExist(netId) then return end
    local bag = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(bag) then exports['qb-target']:RemoveTargetEntity(bag) end
end)

-- Carrying a bag: press G to put it down.
CreateThread(function()
    while true do
        if HoldingDrop then
            if IsControlJustPressed(0, 47) then
                DetachEntity(bagObject, true, true)
                local ped = PlayerPedId()
                local coords = GetEntityCoords(ped)
                local forward = GetEntityForwardVector(ped)
                local x, y, z = table.unpack(coords + forward * 0.57)
                SetEntityCoords(bagObject, x, y, z - 0.9, false, false, false, false)
                FreezeEntityPosition(bagObject, true)
                exports['qb-core']:HideText()
                TriggerServerEvent('qb-inventory:server:updateDrop', heldDrop, coords)
                HoldingDrop = false
                bagObject = nil
                heldDrop = nil
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)
