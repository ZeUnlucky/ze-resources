local QBCore = exports['qb-core']:GetCoreObject()
local boomboxes
local function ChangePlaying(obj, isPlaying)
    boomboxes[obj.ID .. ""].Playing = isPlaying
    TriggerClientEvent("ze-boombox:UpdateBoomboxes", -1, boomboxes)
end
local function StopSong(bb)
    ChangePlaying(bb, false)
    xSound:Destroy(-1, bb.ID)
end

local function tablelength(T)
    local count = 0
    if T ~= nil then
        for _ in pairs(T) do count = count + 1 end
    end
    return count
end

local function findEmptyIndex()
    if boomboxes == nil then
        boomboxes = {}
        return 0
    else
        for i, v in pairs(boomboxes) do
            if v == nil then
                return i
            end
        end
    end
    return tablelength(boomboxes)
end

local function NewBoombox(pos, object)
    local id = findEmptyIndex()
    local boombox = {
        ID = id,
        Position = pos,
        Object = object,
        Volume = 30,
        Playing = false
    }
    boomboxes["" .. id] = boombox
    return boombox
end

local function DeleteBoombox(bb)
    boomboxes['' .. bb.ID] = nil
    TriggerClientEvent("ze-boombox:UpdateBoomboxes", -1, boomboxes)
end
RegisterServerEvent("ze-boombox:updateIndexes")
AddEventHandler("ze-boombox:updateIndexes", function(obj, pos)
	local boombox = NewBoombox(pos, obj)
	TriggerClientEvent("ze-boombox:UpdateBoomboxes", -1, boomboxes)
	TriggerClientEvent('ze-boombox:addIndex', -1, boombox.ID)
end)

RegisterServerEvent('ze-boombox:pickupBoombox')
AddEventHandler('ze-boombox:pickupBoombox', function(bb)
	local src = source
	local xPlayer = QBCore.Functions.GetPlayer(src)
	if not xPlayer then return end
	if bb and bb.ID then
		exports['qs-inventory']:AddItem(src, "boombox", 1)
		xSound:Destroy(-1, bb.ID)
		ChangePlaying(bb, false)
		DeleteBoombox(bb)
	end
end)

RegisterServerEvent('ze-boombox:refundBoombox')
AddEventHandler('ze-boombox:refundBoombox', function(s)
	local src = source
	if s ~= 42 then return end
	local xPlayer = QBCore.Functions.GetPlayer(src)
	if not xPlayer then return end
	if xPlayer ~= nil then
		exports['qs-inventory']:AddItem(src, "boombox", 1)
	end
end)

RegisterServerEvent('ze-boombox:playSong')
AddEventHandler('ze-boombox:playSong', function(id, bb)
	if id ~= nil and bb ~= nil then
		local name = bb.ID
		local src = source
		exports['BiGamer']:createLog({
			EmbedMessage = GetPlayerName(src).. " ("..name..") Played in "..bb.Position.." the song "..id,
			player_id = src,
			channel = "boombox",
			screenshot = false
		})
		ChangePlaying(bb, true)
		xSound:PlayUrlPos(-1, name, id, 30, bb.Position, false)
		xSound:Distance(-1, name, B.boomboxSoundDistance)
		TriggerClientEvent("ze-boombox:playSong", -1, name)
	end
end)

RegisterServerEvent('ze-boombox:stopSong')
AddEventHandler('ze-boombox:stopSong', function(bb)
	if bb ~= nil then
		StopSong(bb)
	end
end)

RegisterServerEvent('ze-boombox:setVolume')
AddEventHandler('ze-boombox:setVolume', function(volume, coords)
	if volume ~= nil and coords ~= nil then
		TriggerClientEvent('ze-boombox:setVolume', -1, volume, coords)
	end
end)

RegisterServerEvent("ze-boombox:changeVolume", function(obj, vol)
    if obj ~= nil and vol ~= nil then
        boomboxes[obj.ID..""].Volume = vol/100
        TriggerClientEvent("ze-boombox:setVolume", -1, obj, vol/100)
        TriggerClientEvent("ze-boombox:UpdateBoomboxes", -1, boomboxes)
    end
end)

RegisterServerEvent("ze-boombox:changePosition", function(obj, pos, ent)
    if obj ~= nil and pos ~= nil and ent ~= nil then
        boomboxes[obj.ID..""].Position = pos
        boomboxes[obj.ID..""].Object = ent
        TriggerClientEvent("ze-boombox:setPosition", -1, obj, pos)
        TriggerClientEvent("ze-boombox:UpdateBoomboxes", -1, boomboxes)
    end
end)

QBCore.Functions.CreateUseableItem('boombox', function(source, item)
	local src = source
	local xPlayer = QBCore.Functions.GetPlayer(src)
	if not xPlayer then return end
	if exports['qs-inventory']:RemoveItem(src, item.name, 1, item.slot) then
		TriggerClientEvent('ze-boombox:placeBoombox', src)
	end
end)