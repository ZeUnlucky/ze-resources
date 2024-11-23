Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        TriggerClientEvent("ze-timesync:SyncTime", -1, os.date("%H"), os.date("%M"), os.date("%S"))      
        if Config.UsingQB then
            TriggerClientEvent("qb-weathersync:client:DisableSync", -1)
        end
    end
end)