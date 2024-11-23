RegisterNetEvent("ze-timesync:SyncTime")
AddEventHandler("ze-timesync:SyncTime", function(hour, minute, second)
    hour = math.floor(hour+Config.HourDifference)
    minute = math.floor(minute+Config.MinuteDifference)
    second = math.floor(second+Config.SecondDifference)
    if second > 60 then
        second = second - 60
        minute = minute + 1
    elseif second < 0 then
        second = second + 60
        minute = minute - 1
    end
    if minute > 60 then
        minute = minute - 60
        hour = hour + 1
    elseif minute < 0 then
        minute = minute + 60
        hour = hour - 1
    end
    if hour > 24 then
        hour = hour - 24
    elseif hour < 0 then
        hour = hour + 24
    end
    NetworkOverrideClockTime(hour, minute, second)
    print(math.floor(hour+Config.HourDifference) .. ":" .. math.floor(minute+Config.MinuteDifference) .. ":" .. math.floor(second+Config.SecondDifference))
end)

Citizen.CreateThread(function()
    PauseClock(true)
end)