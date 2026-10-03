local QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
exports['qb-target']:AddGlobalPlayer({
    options = {
      {
        num = 1,
        icon = "fas fa-droplet",
        label = "Take Blood",
        action = function(entity)
            QBCore.Functions.Progressbar("take_blood", "Taking blood", 5000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                local targetSrc = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                TriggerServerEvent("ze-bloodwork:Server:FinishedBloodwork", targetSrc)
            end, function() end)
        end,
        canInteract = function(entity)
          return GetEntityHealth(entity) > Config.HealthChangeOnBloodWork
        end,
        job = Config.Job,
        item = Config.EmptyBloodBagItemName
      },
    },
    distance = 2.5
  })
end)

RegisterNetEvent("ze-bloodwork:client:ChangeHealth", function(amount)
    ChangeHealth(amount)
end)

RegisterNetEvent("ze-bloodwork:client:DoGiveBloodProgbar", function(successful)
	QBCore.Functions.Progressbar("give_blood", "Giving blood", 5000, false, false, {
    disableMovement = true,
    disableCarMovement = true,
    disableMouse = false,
    disableCombat = true,
    }, {}, {}, {}, function() end, function() end)
end)

RegisterNetEvent("ze-bloodwork:client:DoGetBloodProgbar", function(successful)
	QBCore.Functions.Progressbar("give_blood", "Getting blood", 5000, false, false, {
    disableMovement = true,
    disableCarMovement = true,
    disableMouse = false,
    disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ChangeHealth(successful and Config.HealthChangeOnBloodWork or -Config.HealthChangeOnBloodWork)
  end, function() end)
end)

function ChangeHealth(amount)
    SetEntityHealth(PlayerPedId(), GetEntityHealth(PlayerPedId()) + amount)
end