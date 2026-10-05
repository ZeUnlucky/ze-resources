Buildings = {}

Buildings.MaxFloors = 200

local function warn(text)
    print(('^3[ze-interiors]^7 %s'):format(text))
end

function Buildings.Load()
    local rows = MySQL.query.await('SELECT id, name, entrance, floors FROM ze_buildings') or {}
    Shared.Buildings = {}
    for _, row in ipairs(rows) do
        local e = json.decode(row.entrance or '')
        if type(e) == 'table' and tonumber(e.x) and tonumber(e.y) and tonumber(e.z) then
            Shared.Buildings[row.id] = {
                name = row.name,
                entrance = vector4(e.x + 0.0, e.y + 0.0, e.z + 0.0, (tonumber(e.w) or 0.0) + 0.0),
                floors = math.max(1, math.floor(tonumber(row.floors) or 1)),
            }
        else
            warn(('building #%d "%s" is skipped: its entrance is not valid'):format(row.id, row.name))
        end
    end
end

-- The plain table that goes to the clients (nil for a building that does not exist, which tells them to drop it).
-- The clients need the buildings for the door zone of each one and for the map blips.
function Buildings.Pack(id)
    local building = Shared.Buildings[id]
    if not building then return nil end
    local e = building.entrance
    return { id = id, name = building.name, floors = building.floors, entrance = { x = e.x, y = e.y, z = e.z, w = e.w } }
end

function Buildings.SyncAll(target)
    local list = {}
    for id in pairs(Shared.Buildings) do list[#list + 1] = Buildings.Pack(id) end
    TriggerClientEvent('ze-interiors:SyncBuildings', target or -1, list)
end

function Buildings.Sync(id)
    TriggerClientEvent('ze-interiors:SyncBuilding', -1, id, Buildings.Pack(id))
end

function Buildings.Count(id)
    local count = 0
    for _, house in pairs(Shared.Houses) do
        if house.building == id then count = count + 1 end
    end
    return count
end

function Buildings.Create(name, floors, entrance)
    local plain = json.encode({ x = entrance.x, y = entrance.y, z = entrance.z, w = entrance.w })
    local ok, id = pcall(MySQL.insert.await, 'INSERT INTO ze_buildings (name, entrance, floors) VALUES (?, ?, ?)', { name, plain, floors })
    if not ok or not id then return false, 'The database did not save the building' end

    Shared.Buildings[id] = { name = name, entrance = entrance, floors = floors }
    Buildings.Sync(id)
    return id
end

function Buildings.Delete(id)
    if not Shared.Buildings[id] then return false, 'That building does not exist' end
    if Buildings.Count(id) > 0 then return false, 'Delete the apartments of this building first' end

    local ok = pcall(MySQL.update.await, 'DELETE FROM ze_buildings WHERE id = ?', { id })
    if not ok then return false, 'The database did not delete the building' end

    Shared.Buildings[id] = nil
    Buildings.Sync(id)
    return true
end
