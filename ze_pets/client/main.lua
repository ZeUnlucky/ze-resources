local QBCore = exports['qb-core']:GetCoreObject()

local EquippedPet = nil
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SpawnDealer()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        SpawnDealer()
    end
end)

function SpawnDealer()
    local Model = GetHashKey(Config.PetDealerPed)
	RequestModel(Model)
	while not HasModelLoaded(Model) do
		Citizen.Wait(50)
	end
    PetDealer = CreatePed(0, Model, Config.PetDealerLocation, false, false)
    FreezeEntityPosition(PetDealer, true)
    SetEntityInvincible(PetDealer, true)
    SetModelAsNoLongerNeeded(Model)
end

RegisterNetEvent("ze_pets:SpawnPet")
AddEventHandler("ze_pets:SpawnPet", function(type, name)
    local Model = GetHashKey(type)
	RequestModel(Model)
	while not HasModelLoaded(Model) do
		Citizen.Wait(50)
	end
	local PedPosition = GetEntityCoords(PlayerPedId(), false)
	EquippedPet = CreatePed(28, Model, PedPosition.x, PedPosition.y, PedPosition.z, GetEntityHeading(PlayerPedId()), true, true)
	SetEntityAsMissionEntity(EquippedPet, true, true)
	SetModelAsNoLongerNeeded(Model)

	Citizen.CreateThread(function()
		while EquippedPet ~= nil do
			Wait(5000)
			TaskFollowToOffsetOfEntity(EquippedPet, PlayerPedId(), 0.0, 0.0, 0.0, 2.0, -1, 1.0, true)
		end
	end)
    exports['qb-target']:AddTargetEntity(EquippedPet, {
        options = {
			{
				num = 1,
				type = "client",
				label = "Send pet back home",
				action = function(entity)
					DeletePed(entity)
					EquippedPet = nil
					QBCore.Functions.Notify("Pet sent home!", "success", 5000)
				end
			}
        },
        distance = 2.5
    })

end)

TriggerEvent('chat:addSuggestion', '/pet', 'Spawns in a pet', {
	{name="animalType", help="Type of animal to spawn [dog/cat/cow]"},
    {name="animalName", help="The name of the animal"},
  })

