local ui_on = false
local lastVeh = nil
RegisterCommand("zecui", function(source, args, raw)
	ToggleUI(not ui_on)
end, false)

RegisterCommand("zecui2", function(source, args ,raw)
	SendNUIMessage({
		type = "createItem",
		name = args[1]
	})
end, false)

function ToggleUI(toggle)
	SetNuiFocus(toggle, toggle)
	ui_on = toggle
	SendNUIMessage({
		type = "ze_ui_toggle",
		toggle = toggle
	})
end

RegisterNUICallback('press', function(data, cb)
	if data.key == 'h' or data.key == 'Escape' then
		ToggleUI(false)
	end

    cb('ok')
end)

RegisterNUICallback('clicked', function(data, cb)
	local id = GetPlayerServerId(PlayerId())
	local bool = data.value
	if data.type == "door" then
		TriggerServerEvent("ze:doortoggle", id, data.type2, bool)
	elseif data.type == "wind" then
		TriggerServerEvent("ze:windowtoggle", id, data.type2, bool)
	elseif data.type == "Engine" then
		TriggerServerEvent("ze:enginetoggle", id, bool)
	elseif data.type == "Neon" then
		TriggerServerEvent("ze:neontoggle", id, bool)
	end
	cb('ok')
end)

Citizen.CreateThread(function()
    while true do
        if ui_on then
            DisableControlAction(0, 1, ui_on) -- LookLeftRight
            DisableControlAction(0, 2, ui_on) -- LookUpDown

            DisableControlAction(0, 142, ui_on) -- MeleeAttackAlternate

            --DisableControlAction(0, 106, ui_on) -- VehicleMouseControlOverride

            if IsDisabledControlJustReleased(0, 142) then -- MeleeAttackAlternate
                SendNUIMessage({
                    type = "click"
                })
            end
        end
		Citizen.Wait(0)
    end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1000)
		local veh = GetVehiclePedIsIn(PlayerPedId(), false)
		if veh ~= lastVeh then
			SendNUIMessage({
                    type = "default"
                })
			lastVeh = veh
		end
	end
end)