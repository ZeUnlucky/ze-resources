local QBCore = exports['qb-core']:GetCoreObject()

Casings = {}

RegisterServerEvent("ze-evidence:RegisterNewCasing")
AddEventHandler("ze-evidence:RegisterNewCasing", function(casingEntity, weapon)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local serieNumber = nil
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            if weaponItem.info and weaponItem.info ~= '' then
                serieNumber = weaponItem.info.serie
            end
        end
    end
    Casings[casingEntity] = {ammoType = weaponInfo.ammotype, serialNumber = serieNumber}
    TriggerClientEvent("ze-evidence:RegisterNewCasingClient", -1,  casingEntity, serieNumber)
end)

RegisterServerEvent("ze-evidence:CollectCasing")
AddEventHandler("ze-evidence:CollectCasing", function(casing)   
    TriggerClientEvent("ze-evidence:RemoveCasingMenu", -1, casing)
    local info = {}
    info.ammoType = Casings[casing].ammoType
    info.serialNumber = Casings[casing].serialNumber
    
   
    exports['qb-inventory']:AddItem(source, "casing", 1, false, info, 'ze-evidence:gatherCasing')
    Casings[casing] = nil
    DeleteEntity(NetworkGetEntityFromNetworkId(casing))
   
end)

RegisterServerEvent("ze-evidence:debug:ShowEntityId")
AddEventHandler("ze-evidence:debug:ShowEntityId", function(entity)
    TriggerClientEvent("ze-evidence:debug:SendEntityIdToAll", -1, entity)
end)


QBCore.Commands.Add("walk", "walk automatically", {}, false, function(source)
    TriggerClientEvent("ze-walk:walk", source)
end)