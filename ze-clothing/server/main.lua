-- Same events and callback names as qb-clothing, so qb-multicharacter, qb-prison, qb-policejob, qb-apartments ...
-- keep working unchanged. What is new: the player is checked before use, what the client sends is validated, and
-- the number of saved outfits per character is capped (Config.MaxOutfits).

-- If the original qb-clothing is still running, both would answer the same events. Refuse to start.
if GetCurrentResourceName() ~= 'qb-clothing' and GetResourceState('qb-clothing') == 'started' then
    local description = GetResourceMetadata('qb-clothing', 'description', 0) or ''
    if not description:find('ze-clothing stand-in', 1, true) then
        print('^1[ze-clothing] The original qb-clothing is running as well. Two clothing scripts answer the same events and data.')
        print('^1[ze-clothing] Move qb-clothing out of the resources folder (not just renamed inside [qb]) and restart. ze-clothing is not starting.^7')
        return
    end
end

local QBCore = exports['qb-core']:GetCoreObject()

local MAX_JSON = 20000      -- a full skin is about 6 KB
local MAX_NAME = 40         -- the outfitname column is varchar(50)

local function getPlayer(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and Player.PlayerData and Player.PlayerData.citizenid then
        return Player
    end
end

local function pushOutfits(src, citizenid)
    local result = MySQL.query.await('SELECT * FROM player_outfits WHERE citizenid = ?', { citizenid })
    TriggerClientEvent('qb-clothing:client:reloadOutfits', src, (result and result[1]) and result or nil)
end

RegisterNetEvent('qb-clothing:saveSkin', function(model, skin)
    local src = source
    local Player = getPlayer(src)
    if not Player then return end
    if type(model) ~= 'number' or type(skin) ~= 'string' or #skin > MAX_JSON then return end

    local ok, decoded = pcall(json.decode, skin)
    if not ok or type(decoded) ~= 'table' then return end

    local citizenid = Player.PlayerData.citizenid
    -- TODO (same as qb-clothing): make citizenid the primary key so this can be one upsert
    MySQL.query.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
    MySQL.insert.await('INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, ?)', {
        citizenid, model, skin, 1,
    })
end)

RegisterNetEvent('qb-clothes:loadPlayerSkin', function()
    local src = source
    local Player = getPlayer(src)
    if not Player then return end

    local result = MySQL.query.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = ?', {
        Player.PlayerData.citizenid, 1,
    })
    if result and result[1] then
        TriggerClientEvent('qb-clothes:loadSkin', src, false, result[1].model, result[1].skin)
    else
        TriggerClientEvent('qb-clothes:loadSkin', src, true)
    end
end)

RegisterNetEvent('qb-clothes:saveOutfit', function(outfitName, model, skinData)
    local src = source
    local Player = getPlayer(src)
    if not Player then return end
    if type(outfitName) ~= 'string' or type(model) ~= 'number' or type(skinData) ~= 'table' then return end

    outfitName = (outfitName:gsub('^%s+', '')):gsub('%s+$', '')
    if #outfitName == 0 or #outfitName > MAX_NAME then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.outfit_name'), 'error')
        return
    end

    local encoded = json.encode(skinData)
    if #encoded > MAX_JSON then return end

    local citizenid = Player.PlayerData.citizenid
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_outfits WHERE citizenid = ?', { citizenid }) or 0
    if count >= Config.MaxOutfits then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.outfit_limit', { max = Config.MaxOutfits }), 'error')
        return
    end

    local outfitId = 'outfit-' .. math.random(1, 10) .. '-' .. math.random(1111, 9999)
    MySQL.insert.await('INSERT INTO player_outfits (citizenid, outfitname, model, skin, outfitId) VALUES (?, ?, ?, ?, ?)', {
        citizenid, outfitName, tostring(model), encoded, outfitId,
    })
    pushOutfits(src, citizenid)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.outfit_saved'), 'success')
end)

RegisterNetEvent('qb-clothing:server:removeOutfit', function(outfitName, outfitId)
    local src = source
    local Player = getPlayer(src)
    if not Player then return end
    if type(outfitName) ~= 'string' or type(outfitId) ~= 'string' then return end

    local citizenid = Player.PlayerData.citizenid
    MySQL.query.await('DELETE FROM player_outfits WHERE citizenid = ? AND outfitname = ? AND outfitId = ?', {
        citizenid, outfitName, outfitId,
    })
    pushOutfits(src, citizenid)
end)

QBCore.Functions.CreateCallback('qb-clothing:server:getOutfits', function(source, cb)
    local Player = getPlayer(source)
    local outfits = {}
    if Player then
        local result = MySQL.query.await('SELECT * FROM player_outfits WHERE citizenid = ?', { Player.PlayerData.citizenid })
        for _, row in ipairs(result or {}) do
            row.skin = json.decode(row.skin)
            outfits[#outfits + 1] = row
        end
    end
    cb(outfits)
end)
