local QBCore = exports['qb-core']:GetCoreObject()

local labOpen = false
local pending = {}
local lastRequestId = 0

local function LabRequest(action, payload)
    lastRequestId = lastRequestId + 1
    local requestId = lastRequestId
    local p = promise.new()
    pending[requestId] = p

    SetTimeout(10000, function()
        if pending[requestId] then
            pending[requestId] = nil
            p:resolve({ ok = false, error = "The laboratory did not respond." })
        end
    end)

    TriggerServerEvent("ze-evidence:server:LabRequest", requestId, action, payload)
    return Citizen.Await(p)
end

RegisterNetEvent("ze-evidence:client:LabResponse", function(requestId, result)
    local p = pending[requestId]
    if p then
        pending[requestId] = nil
        p:resolve(result)
    end
end)

local function CloseLab()
    if not labOpen then return end
    labOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

function OpenForensicLab()
    if labOpen then return end
    labOpen = true
    CreateThread(function()
        local result = LabRequest("summary")
        if not labOpen then return end
        if not result.ok then
            labOpen = false
            QBCore.Functions.Notify(result.error, "error", 5000)
            return
        end
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "open", summary = result.data })
    end)
end

RegisterNUICallback("close", function(_, cb)
    CloseLab()
    cb({})
end)

RegisterNUICallback("request", function(data, cb)
    if not labOpen then
        cb({ ok = false, error = "The laboratory is closed." })
        return
    end
    cb(LabRequest(data.action, data.payload))
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() and labOpen then
        SetNuiFocus(false, false)
    end
end)
