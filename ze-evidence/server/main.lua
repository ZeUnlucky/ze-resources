local QBCore = exports['qb-core']:GetCoreObject()

Casings = {}
Fingerprints = {}
Splatters = {}

RegisterServerEvent("ze-evidence:RegisterNewCasing")
AddEventHandler("ze-evidence:RegisterNewCasing", function(casingEntity, weapon, pos)
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
   
    Casings[casingEntity] = {ammoType = weaponInfo.ammotype, serialNumber = serieNumber, position = pos, id = casingEntity}
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
                if Player.Functions.HasItem("pdfingerprinttape", 1) then
                    local fingerprint = Fingerprints[weaponItem.info.serie]
                    Player.Functions.RemoveItem("pdfingerprinttape", 1)
                    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items["pdfingerprinttape"], 'remove')
                    local info = {}
                    if fingerprint then info.fingerprint = fingerprint end
                    exports['qb-inventory']:AddItem(source, "usedfingerprinttape", 1, false, info, 'ze-evidence:useTape')
                else
                    QBCore.Functions.Notify(source, "You need fingerprint tape!", "error", 5000)
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

RegisterServerEvent("ze-evidence:CreateBloodSplatter")
AddEventHandler("ze-evidence:CreateBloodSplatter", function(victim, splatterID, newPitch, currentRoll, currentYaw)
    FreezeEntityPosition(splatterID, true)
    local player = QBCore.Functions.GetPlayer(source)
    player = not player and "JL;" or player.PlayerData.citizenid
    local dna = Shared.ConvertCitizenIdToDNA(player)
    Splatters[splatterID] = {
        DNA = dna,
        position = GetEntityCoords(splatterID),
        id = splatterID
    }
    TriggerClientEvent("ze-evidence:CreateSplatterMenu", -1, splatterID, dna, newPitch, currentRoll, currentYaw)
end)

RegisterServerEvent("ze-evidence:CollectSplatter", function(splatter, DNA, collectedAndNotDestroyed)
    if collectedAndNotDestroyed then
        local info = {}
        info.DNA = DNA
        exports['qb-inventory']:AddItem(source, "blood_vial", 1, false, info, 'ze-evidence:collectSplatter')
    end
    Splatters[splatter] = nil
    TriggerClientEvent("ze-evidence:DeleteSplatterMenu", -1, splatter)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    TriggerClientEvent("ze-evidence:PlayerJoined", Player.PlayerData.source, Splatters, Casings)
end)