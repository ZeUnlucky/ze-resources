-- House manager menu, client side: opens the NUI and relays its callbacks to server/menu.lua.
-- The UI contract (what the NUI sends and expects back) is in README.md.
local QBCore = exports['qb-core']:GetCoreObject()

local menuOpen = false

-- Asks the server for the data and shows the menu. The server answers nothing if the player has no permission.
local function openMenu()
    if menuOpen then return end
    QBCore.Functions.TriggerCallback('ze-interiors:menu:getData', function(data)
        if not data then return end
        menuOpen = true
        SendNUIMessage({
            action = 'open',
            interiors = data.interiors,
            buildings = data.buildings,
            houses = data.houses
        })
        SetNuiFocus(true, true)
    end)
end

-- Calls a server callback and hands its answer to the NUI. `fallback` is what the UI gets when the server does not answer.
local function relay(name, data, cb, fallback)
    QBCore.Functions.TriggerCallback(name, function(result)
        cb(result or fallback)
    end, data)
end

RegisterNetEvent('ze-interiors:menu:open', openMenu)

-- ---------------------------------------------------------------- NUI callbacks
-- Reply to every one with cb(...), otherwise the UI waits for it.

-- The UI closed itself (Escape or the X).
RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Reload the lists after a change. Reply: { interiors = {...}, houses = {...} } (see server/menu.lua).
RegisterNUICallback('getData', function(_, cb)
    relay('ze-interiors:menu:getData', nil, cb, {})
end)

-- "Use my position" on an entrance. Reply: { x, y, z, w } where w is the heading.
RegisterNUICallback('getPosition', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    cb({ x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped) })
end)

-- "Set waypoint" on a house row. data = { house = house id }. Reply: { ok, message?, error? }
-- Needs no server round trip: the client already has every house's entrances (synced by server/houses.lua).
-- The menu only opens for players with permission, but a NUI callback can be called by anything, so check that it is open.
RegisterNUICallback('setWaypoint', function(data, cb)
    local house = menuOpen and type(data) == 'table' and Shared.Houses[tonumber(data.house)] or nil
    local door = house and house.entrances[1]
    if not door then return cb({ ok = false, error = 'That house does not exist' }) end

    SetNewWaypoint(door.x, door.y)
    cb({ ok = true, message = ('Waypoint set to %s'):format(house.name) })
end)

-- Checks the buyer's player id while it is typed. data = { id = number }. Reply: { ok, name?, citizenid?, error? }
RegisterNUICallback('lookupPlayer', function(data, cb)
    relay('ze-interiors:menu:lookupPlayer', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Add house. data = { name = string, interior = interior id, entrances = { { exit, x, y, z, w }, ... } }
-- An apartment sends { name, interior, apartment = true, building = building id, floor = number } instead of the entrances.
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('createHouse', function(data, cb)
    relay('ze-interiors:menu:createHouse', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Add building. data = { name = string, floors = number, entrance = { x, y, z, w } }
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('createBuilding', function(data, cb)
    relay('ze-interiors:menu:createBuilding', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Delete a building. data = { building = building id }
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('deleteBuilding', function(data, cb)
    relay('ze-interiors:menu:deleteBuilding', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Edit house. data = { house = house id, name = string, entrances = { { exit, x, y, z, w }, ... } }
-- (an apartment sends building and floor instead of the entrances)
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('updateHouse', function(data, cb)
    relay('ze-interiors:menu:updateHouse', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Access, saved straight away from the edit form. All reply { ok, error?, message? }.
-- setLocked { house, locked }, setOwner { house, player }, removeOwner { house }, addKey { house, player }, removeKey { house, citizenid }
for _, name in ipairs({ 'setLocked', 'setOwner', 'removeOwner', 'addKey', 'removeKey' }) do
    RegisterNUICallback(name, function(data, cb)
        relay('ze-interiors:menu:' .. name, data, cb, { ok = false, error = 'No answer from the server' })
    end)
end

-- Sell a house to a player. data = { house = house id, player = server id }
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('sellHouse', function(data, cb)
    relay('ze-interiors:menu:sellHouse', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- Delete a house. data = { house = house id }
-- Reply: { ok = bool, error? = string, message? = string }
RegisterNUICallback('deleteHouse', function(data, cb)
    relay('ze-interiors:menu:deleteHouse', data, cb, { ok = false, error = 'No answer from the server' })
end)

-- never leave the cursor stuck on the screen if the resource stops with the menu open
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and menuOpen then
        SetNuiFocus(false, false)
    end
end)
