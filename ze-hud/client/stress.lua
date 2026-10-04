if Config.DisableStress then return end

-- Stress gain -----------------------------------------------------------------------------------

CreateThread(function() -- speeding
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsIn(ped, false)
                local class = GetVehicleClass(veh)
                if Config.VehClassStress[tostring(class)] and not Config.WhitelistedVehicles[GetEntityModel(veh)] then
                    local limit
                    if class == 8 then -- motorcycles have no seatbelt
                        limit = Config.MinimumSpeed
                    else
                        limit = Hud.seatbelt and Config.MinimumSpeed or Config.MinimumSpeedUnbuckled
                    end
                    if GetEntitySpeed(veh) * Hud.speedMultiplier >= limit then
                        TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                    end
                end
            end
        end
        Wait(10000)
    end
end)

CreateThread(function() -- shooting
    while true do
        local wait = 0
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            local weapon = GetSelectedPedWeapon(ped)
            if weapon == `WEAPON_UNARMED` then
                wait = 1000
            elseif IsPedShooting(ped) and not Config.WhitelistedWeaponStress[weapon] then
                if math.random() < Config.StressChance then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
                end
            end
        else
            wait = 1000
        end
        Wait(wait)
    end
end)

-- Stress screen effects ---------------------------------------------------------------------------

local function inRange(list, level)
    for _, entry in ipairs(list) do
        if level >= entry.min and level <= entry.max then return entry end
    end
end

local function blurTime(level)
    local entry = inRange(Config.Intensity.blur, level)
    return entry and entry.intensity or 1500
end

local function effectInterval(level)
    local entry = inRange(Config.EffectInterval, level)
    return entry and math.random(entry.timeout[1], entry.timeout[2]) or 60000
end

local function blur(duration)
    TriggerScreenblurFadeIn(1000.0)
    Wait(duration)
    TriggerScreenblurFadeOut(1000.0)
end

CreateThread(function()
    while true do
        local stress = Hud.stress

        if stress >= 100 then
            local ped = PlayerPedId()
            local duration = blurTime(stress)
            local falls = math.random(2, 4)
            local ragdollTime = falls * 1750

            blur(duration)

            if not IsPedRagdoll(ped) and IsPedOnFoot(ped) and not IsPedSwimming(ped) then
                SetPedToRagdollWithFall(ped, ragdollTime, ragdollTime, 1, GetEntityForwardVector(ped), 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
            end

            Wait(1000)
            for _ = 1, falls do
                Wait(750)
                DoScreenFadeOut(200)
                Wait(1000)
                DoScreenFadeIn(200)
                blur(duration)
            end
        elseif stress >= Config.MinimumStress then
            blur(blurTime(stress))
        end

        Wait(effectInterval(stress))
    end
end)
