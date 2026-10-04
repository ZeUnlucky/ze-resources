-- Glovebox (when sitting in a vehicle) and trunk (when standing at the back of one).

local function IsBackEngine(model)
    return Config.BackEngineVehicles[model]
end

local function OpenTrunk(vehicle)
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'idle_d', 4.0, 4.0, -1, 50, 0, false, false, false)
    SetVehicleDoorOpen(vehicle, IsBackEngine(GetEntityModel(vehicle)) and 4 or 5, false, false)
end

function CloseTrunk()
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle == 0 or distance > 5 then return end
    LoadAnimDict('amb@prop_human_bum_bin@idle_b')
    TaskPlayAnim(PlayerPedId(), 'amb@prop_human_bum_bin@idle_b', 'exit', 4.0, 4.0, -1, 50, 0, false, false, false)
    SetVehicleDoorShut(vehicle, IsBackEngine(GetEntityModel(vehicle)) and 4 or 5, false)
end

-- Asked by the server when the inventory key is pressed. Answers with the inventory id and the vehicle class, or nothing.
QBCore.Functions.CreateClientCallback('qb-inventory:client:vehicleCheck', function(cb)
    local ped = PlayerPedId()

    -- Glovebox: sitting in a vehicle
    local inVehicle = GetVehiclePedIsIn(ped, false)
    if inVehicle ~= 0 then
        cb('glovebox-' .. GetVehicleNumberPlateText(inVehicle), GetVehicleClass(inVehicle))
        return
    end

    -- Trunk: standing at the back of a vehicle
    local vehicle, distance = QBCore.Functions.GetClosestVehicle()
    if vehicle ~= 0 and distance < 5 then
        local model = GetEntityModel(vehicle)
        local dimensionMin, dimensionMax = GetModelDimensions(model)
        local trunkPos = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, IsBackEngine(model) and dimensionMax.y or dimensionMin.y, 0.0)
        if #(GetEntityCoords(ped) - trunkPos) < 1.5 then
            if GetVehicleDoorLockStatus(vehicle) < 2 then
                OpenTrunk(vehicle)
                cb('trunk-' .. GetVehicleNumberPlateText(vehicle), GetVehicleClass(vehicle))
            else
                QBCore.Functions.Notify(Shared.Text.vehicleLocked, 'error')
                cb(nil)
            end
            return
        end
    end
    cb(nil)
end)
