-- The floors and apartments menu of a building, client side: opens the NUI for the Apartments option at a building's
-- entrance (client.lua fires ze-interiors:OpenBuilding) and relays its callbacks to server/lobby.lua.
local QBCore = exports['qb-core']:GetCoreObject()

local lobbyOpen = false

-- Asks the server for the building (floors, apartments and what this player may do) and shows the menu.
AddEventHandler('ze-interiors:OpenBuilding', function(id)
    if lobbyOpen then return end
    QBCore.Functions.TriggerCallback('ze-interiors:lobby:getBuilding', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.error or 'No answer from the server', 'error', 5000)
        end
        lobbyOpen = true
        SendNUIMessage({ action = 'openLobby', building = res.building })
        SetNuiFocus(true, true)
    end, { building = id })
end)

-- ---------------------------------------------------------------- NUI callbacks
-- Reply to every one with cb(...), otherwise the UI waits for it.

-- The UI closed itself (Escape, the X, or after entering an apartment).
RegisterNUICallback('lobbyClose', function(_, cb)
    lobbyOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Reload the building after an action. data = { building = building id }. Reply: { ok, building?, error? }
RegisterNUICallback('lobbyGet', function(data, cb)
    if not lobbyOpen then return cb({ ok = false, error = 'The menu is closed' }) end
    QBCore.Functions.TriggerCallback('ze-interiors:lobby:getBuilding', function(res)
        cb(res or { ok = false, error = 'No answer from the server' })
    end, data)
end)

-- data = { house = apartment id, action = 'enter' | 'lock' | 'unlock' | 'breach' | 'lockpick' }. Reply: { ok, message?, error? }
RegisterNUICallback('lobbyAct', function(data, cb)
    if not lobbyOpen then return cb({ ok = false, error = 'The menu is closed' }) end
    QBCore.Functions.TriggerCallback('ze-interiors:lobby:act', function(res)
        cb(res or { ok = false, error = 'No answer from the server' })
    end, data)
end)

-- never leave the cursor stuck on the screen if the resource stops with the menu open
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and lobbyOpen then
        SetNuiFocus(false, false)
    end
end)
