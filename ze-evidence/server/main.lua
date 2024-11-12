local QBCore = exports['qb-core']:GetCoreObject()

Casings = {}
Fingerprints = {}

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
                Fingerprints[serieNumber] = Shared.ConvertCitizenIdToFingerprint(Player.PlayerData.citizenid)
            end
        end
    end
    Player.PlayerData.metadata["gunpowder"] = true
   
    Casings[casingEntity] = {ammoType = weaponInfo.ammotype, serialNumber = serieNumber}
    TriggerClientEvent("ze-evidence:RegisterNewCasingClient", -1,  casingEntity, serieNumber)
end)

QBCore.Commands.Add("checkfinger", "Checks held gun for a fingerprint", {}, false, function(source)
    local weapon = GetSelectedPedWeapon(GetPlayerPed(source))
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local Player = QBCore.Functions.GetPlayer(source)
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            if weaponItem.info and weaponItem.info ~= '' then
                local fingerprint = Fingerprints[weaponItem.info.serie]
                if fingerprint then
                    QBCore.Functions.Notify(source, "Fingerprint is "..fingerprint , "success", 15000)
                else
                    QBCore.Functions.Notify(source, "No fingerprint on gun", "error", 5000)
                end
            end
        end
    end
    
end)

QBCore.Commands.Add("wipefinger", "Wipes fingerprint from held gun", {}, false, function(source)
    local weapon = GetSelectedPedWeapon(GetPlayerPed(source))
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local Player = QBCore.Functions.GetPlayer(source)
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            if weaponItem.info and weaponItem.info ~= '' then
                Fingerprints[weaponItem.info.serie] = nil
               
                QBCore.Functions.Notify(source, "Cleaned fingerprint from gun", "success", 5000)
            end
        end
    end
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

QBCore.Commands.Add("testconverter", "temp!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", {}, false, function(source)
    Shared.ConvertCitizenIdToFingerprint( QBCore.Functions.GetPlayer(source).PlayerData.citizenid)
end)



RegisterServerEvent("ze-evidence:debug:ShowEntityId")
AddEventHandler("ze-evidence:debug:ShowEntityId", function(entity)
    TriggerClientEvent("ze-evidence:debug:SendEntityIdToAll", -1, entity)
end)

