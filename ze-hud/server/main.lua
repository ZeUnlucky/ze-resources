local QBCore = exports['qb-core']:GetCoreObject()

-- Same commands and events as qb-hud, so everything that already talks to the HUD keeps working
-- (qb-core money/needs, qb-smallresources, qb-ambulancejob, qb-vehiclekeys, ...).

QBCore.Commands.Add('cash', 'Check Cash Balance', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    TriggerClientEvent('hud:client:ShowAccounts', source, 'cash', Player.PlayerData.money.cash)
end)

QBCore.Commands.Add('bank', 'Check Bank Balance', {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    TriggerClientEvent('hud:client:ShowAccounts', source, 'bank', Player.PlayerData.money.bank)
end)

QBCore.Commands.Add('dev', 'Enable/Disable developer Mode', {}, false, function(source)
    TriggerClientEvent('qb-admin:client:ToggleDevmode', source)
end, 'admin')

-- Stress ----------------------------------------------------------------------

-- Clients choose the amount, so keep it inside what real callers send (largest gain is the bank
-- robbery at 8, the ambulance job relieves a flat 100 on revive).
local MAX_GAIN = 20
local MAX_RELIEVE = 100

local function changeStress(src, delta)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local current = Player.PlayerData.metadata['stress'] or 0
    local newStress = math.max(0, math.min(100, current + delta))

    Player.Functions.SetMetaData('stress', newStress)
    TriggerClientEvent('hud:client:UpdateStress', src, newStress)
    return Player
end

RegisterNetEvent('hud:server:GainStress', function(amount)
    if Config.DisableStress then return end
    local src = source
    if type(amount) ~= 'number' then return end
    amount = math.max(0, math.min(MAX_GAIN, amount))

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local job = Player.PlayerData.job
    if Config.WhitelistedJobs[job.type] or Config.WhitelistedJobs[job.name] then return end

    if changeStress(src, amount) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.stress_gain'), 'error', 1500)
    end
end)

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    if Config.DisableStress then return end
    local src = source
    if type(amount) ~= 'number' then return end
    amount = math.max(0, math.min(MAX_RELIEVE, amount))

    if changeStress(src, -amount) then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.stress_removed'))
    end
end)
